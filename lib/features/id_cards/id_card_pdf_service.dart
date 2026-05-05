import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/core/services/auth_service.dart';
import 'package:ghanaclass_school_management/features/id_cards/id_card_design.dart';

class IdCardPdfService {
  final AppDatabase _db;
  final AuthService _authService;

  const IdCardPdfService(this._db, this._authService);

  static const _cardFormat = PdfPageFormat(85.6 * PdfPageFormat.mm, 53.98 * PdfPageFormat.mm);

  Future<void> printStudentIdCards({required List<int> studentIds, IdCardStyle style = const IdCardStyle()}) async {
    final bytes = await buildStudentIdCardsPdf(studentIds: studentIds, style: style);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> printStaffIdCards({required List<int> staffIds, IdCardStyle style = const IdCardStyle()}) async {
    final bytes = await buildStaffIdCardsPdf(staffIds: staffIds, style: style);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<Uint8List> buildStudentIdCardsPdf({required List<int> studentIds, IdCardStyle style = const IdCardStyle()}) async {
    final doc = pw.Document();
    final fontBold = await PdfGoogleFonts.openSansBold();
    final fontRegular = await PdfGoogleFonts.openSansRegular();

    final identity = await _authService.getInstitutionalIdentity();
    final schoolName = identity?.schoolName.trim().isNotEmpty == true ? identity!.schoolName.trim() : 'School';
    final schoolEmail = identity?.officialEmail.trim().isNotEmpty == true ? identity!.officialEmail.trim() : '';
    final schoolAddress = identity?.address?.trim() ?? '';
    final schoolPhone = identity?.phoneNumber?.trim() ?? '';
    final schoolMotto = identity?.motto?.trim() ?? '';

    final logoImage = _tryLoadMemoryImage(identity?.logoBytes) ?? await _tryLoadImage(identity?.logoPath);
    final brand = _SchoolBrand(
      name: schoolName,
      email: schoolEmail,
      address: schoolAddress,
      phone: schoolPhone,
      motto: schoolMotto,
      logo: logoImage,
    );

    for (final id in studentIds) {
      final student = await (_db.select(_db.students)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (student == null) continue;

      final classLabel = await _studentClassLabel(student);
      final photoImage = await _tryLoadImage(student.photoPath);

      doc.addPage(
        pw.Page(
          pageFormat: _cardFormat,
          margin: pw.EdgeInsets.zero,
          build: (_) => _buildStudentCard(
            student: student,
            classLabel: classLabel,
            brand: brand,
            photo: photoImage,
            fontBold: fontBold,
            fontRegular: fontRegular,
            style: style,
          ),
        ),
      );
    }

    return doc.save();
  }

  Future<Uint8List> buildStaffIdCardsPdf({required List<int> staffIds, IdCardStyle style = const IdCardStyle()}) async {
    final doc = pw.Document();
    final fontBold = await PdfGoogleFonts.openSansBold();
    final fontRegular = await PdfGoogleFonts.openSansRegular();

    final identity = await _authService.getInstitutionalIdentity();
    final schoolName = identity?.schoolName.trim().isNotEmpty == true ? identity!.schoolName.trim() : 'School';
    final schoolEmail = identity?.officialEmail.trim().isNotEmpty == true ? identity!.officialEmail.trim() : '';
    final schoolAddress = identity?.address?.trim() ?? '';
    final schoolPhone = identity?.phoneNumber?.trim() ?? '';
    final schoolMotto = identity?.motto?.trim() ?? '';

    final logoImage = _tryLoadMemoryImage(identity?.logoBytes) ?? await _tryLoadImage(identity?.logoPath);
    final brand = _SchoolBrand(
      name: schoolName,
      email: schoolEmail,
      address: schoolAddress,
      phone: schoolPhone,
      motto: schoolMotto,
      logo: logoImage,
    );

    for (final id in staffIds) {
      final staff = await (_db.select(_db.staff)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (staff == null) continue;

      final photoImage = await _tryLoadImage(staff.photoPath);

      doc.addPage(
        pw.Page(
          pageFormat: _cardFormat,
          margin: pw.EdgeInsets.zero,
          build: (_) => _buildStaffCard(
            staff: staff,
            brand: brand,
            photo: photoImage,
            fontBold: fontBold,
            fontRegular: fontRegular,
            style: style,
          ),
        ),
      );
    }

    return doc.save();
  }

  Future<String> _studentClassLabel(Student student) async {
    final id = student.classId;
    if (id == null) return 'N/A';

    final cls = await (_db.select(_db.schoolClasses)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (cls == null) return 'N/A';

    final code = cls.classCode.trim();
    final name = cls.className.trim();
    if (code.isNotEmpty && name.isNotEmpty) return '$code ($name)';
    return code.isNotEmpty ? code : (name.isNotEmpty ? name : 'N/A');
  }

  Future<pw.ImageProvider?> _tryLoadImage(String? path) async {
    final p = path?.trim();
    if (p == null || p.isEmpty) return null;

    try {
      final file = File(p);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      return pw.MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  pw.ImageProvider? _tryLoadMemoryImage(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) return null;
    return pw.MemoryImage(bytes);
  }

  pw.Widget _buildStudentCard({
    required Student student,
    required String classLabel,
    required _SchoolBrand brand,
    required pw.ImageProvider? photo,
    required pw.Font fontBold,
    required pw.Font fontRegular,
    required IdCardStyle style,
  }) {
    switch (style.template) {
      case IdCardTemplate.modern:
        return _buildStudentCardModern(
          student: student,
          classLabel: classLabel,
          brand: brand,
          photo: photo,
          fontBold: fontBold,
          fontRegular: fontRegular,
          style: style,
        );
      case IdCardTemplate.minimal:
        return _buildStudentCardMinimal(
          student: student,
          classLabel: classLabel,
          brand: brand,
          photo: photo,
          fontBold: fontBold,
          fontRegular: fontRegular,
          style: style,
        );
      case IdCardTemplate.classic:
        return _buildStudentCardClassic(
          student: student,
          classLabel: classLabel,
          brand: brand,
          photo: photo,
          fontBold: fontBold,
          fontRegular: fontRegular,
          style: style,
        );
    }
  }

  pw.Widget _buildStaffCard({
    required StaffData staff,
    required _SchoolBrand brand,
    required pw.ImageProvider? photo,
    required pw.Font fontBold,
    required pw.Font fontRegular,
    required IdCardStyle style,
  }) {
    switch (style.template) {
      case IdCardTemplate.modern:
        return _buildStaffCardModern(
          staff: staff,
          brand: brand,
          photo: photo,
          fontBold: fontBold,
          fontRegular: fontRegular,
          style: style,
        );
      case IdCardTemplate.minimal:
        return _buildStaffCardMinimal(
          staff: staff,
          brand: brand,
          photo: photo,
          fontBold: fontBold,
          fontRegular: fontRegular,
          style: style,
        );
      case IdCardTemplate.classic:
        return _buildStaffCardClassic(
          staff: staff,
          brand: brand,
          photo: photo,
          fontBold: fontBold,
          fontRegular: fontRegular,
          style: style,
        );
    }
  }

  pw.Widget _brandHeader({
    required String title,
    required _SchoolBrand brand,
    required pw.Font fontBold,
    required pw.Font fontRegular,
    required PdfColor titleColor,
    required PdfColor textColor,
    required PdfColor subTextColor,
    required bool compact,
  }) {
    final lines = <String>[];
    if (brand.email.trim().isNotEmpty) lines.add(brand.email.trim());
    final phone = brand.phone.trim();
    if (phone.isNotEmpty) {
      if (lines.isEmpty) {
        lines.add(phone);
      } else {
        lines[0] = '${lines[0]} • $phone';
      }
    }
    if (!compact && brand.address.trim().isNotEmpty) {
      lines.add(brand.address.trim());
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: 20,
          height: 20,
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(color: PdfColors.white, width: 0.5),
          ),
          child: brand.logo == null
              ? pw.Center(child: pw.Text('LOGO', style: pw.TextStyle(font: fontBold, fontSize: 6, color: subTextColor)))
              : pw.ClipRRect(
                  horizontalRadius: 4,
                  verticalRadius: 4,
                  child: pw.Image(brand.logo!, fit: pw.BoxFit.cover),
                ),
        ),
        pw.SizedBox(width: 6),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                brand.name.toUpperCase(),
                style: pw.TextStyle(font: fontBold, fontSize: 8, color: textColor),
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
              ),
              pw.Text(
                title,
                style: pw.TextStyle(font: fontBold, fontSize: 7, color: titleColor),
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
              ),
              for (final l in lines)
                pw.Text(
                  l,
                  style: pw.TextStyle(font: fontRegular, fontSize: 5.5, color: subTextColor),
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _mottoFooter({required _SchoolBrand brand, required pw.Font fontBold, required PdfColor bg, required PdfColor fg}) {
    final motto = brand.motto.trim();
    if (motto.isEmpty) return pw.SizedBox();
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        motto,
        style: pw.TextStyle(font: fontBold, fontSize: 6, color: fg),
        textAlign: pw.TextAlign.center,
        maxLines: 1,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  pw.Widget _buildStudentCardModern({
    required Student student,
    required String classLabel,
    required _SchoolBrand brand,
    required pw.ImageProvider? photo,
    required pw.Font fontBold,
    required pw.Font fontRegular,
    required IdCardStyle style,
  }) {
    final fullName = '${student.firstName} ${student.lastName}'.trim();
    final primary = style.primaryPdf;
    final accent = style.accentPdf;

    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        color: style.backgroundPdf,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: primary, width: 1.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              color: primary,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: _brandHeader(
              title: 'STUDENT ID CARD',
              brand: brand,
              fontBold: fontBold,
              fontRegular: fontRegular,
              titleColor: PdfColors.white,
              textColor: PdfColors.white,
              subTextColor: PdfColors.white,
              compact: true,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _photoBox(photo: photo, fallbackText: _initials(student.firstName, student.lastName), fontBold: fontBold),
                pw.SizedBox(width: 7),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(fullName, style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.black)),
                      pw.SizedBox(height: 1),
                      _kv('Student ID', student.studentId, fontBold, fontRegular),
                      _kv('Class', classLabel, fontBold, fontRegular),
                      _kv('Guardian', student.guardianName, fontBold, fontRegular),
                      _kv('Guardian No', student.guardianPhone, fontBold, fontRegular),
                      _kv('Canteen', student.eatsCanteen ? 'Yes' : 'No', fontBold, fontRegular),
                      _kv('Bus', student.takesSchoolBus ? 'Yes' : 'No', fontBold, fontRegular),
                      pw.Spacer(),
                      pw.BarcodeWidget(
                        data: student.studentId,
                        barcode: pw.Barcode.code128(),
                        height: 16,
                        drawText: false,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 4),
          _mottoFooter(brand: brand, fontBold: fontBold, bg: accent, fg: PdfColors.white),
        ],
      ),
    );
  }

  pw.Widget _buildStudentCardClassic({
    required Student student,
    required String classLabel,
    required _SchoolBrand brand,
    required pw.ImageProvider? photo,
    required pw.Font fontBold,
    required pw.Font fontRegular,
    required IdCardStyle style,
  }) {
    final fullName = '${student.firstName} ${student.lastName}'.trim();
    final issuedOn = DateFormat('dd MMM yyyy').format(DateTime.now());
    final primary = style.primaryPdf;

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: primary, width: 2),
        borderRadius: pw.BorderRadius.circular(10),
        color: style.backgroundPdf,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _brandHeader(
            title: 'STUDENT ID CARD',
            brand: brand,
            fontBold: fontBold,
            fontRegular: fontRegular,
            titleColor: primary,
            textColor: primary,
            subTextColor: PdfColors.grey700,
            compact: false,
          ),
          pw.SizedBox(height: 6),
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _photoBox(photo: photo, fallbackText: _initials(student.firstName, student.lastName), fontBold: fontBold),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(fullName, style: pw.TextStyle(font: fontBold, fontSize: 10)),
                      pw.SizedBox(height: 2),
                      _kv('Student ID', student.studentId, fontBold, fontRegular),
                      _kv('Class', classLabel, fontBold, fontRegular),
                      _kv('Guardian', student.guardianName, fontBold, fontRegular),
                      _kv('Guardian No', student.guardianPhone, fontBold, fontRegular),
                      _kv('Canteen', student.eatsCanteen ? 'Yes' : 'No', fontBold, fontRegular),
                      _kv('Bus', student.takesSchoolBus ? 'Yes' : 'No', fontBold, fontRegular),
                      pw.Spacer(),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Issued: $issuedOn', style: pw.TextStyle(font: fontRegular, fontSize: 6, color: PdfColors.grey700)),
                          pw.Text('Powered by OmniWeave', style: pw.TextStyle(font: fontRegular, fontSize: 6, color: PdfColors.grey700)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 5),
          pw.BarcodeWidget(
            data: student.studentId,
            barcode: pw.Barcode.code128(),
            height: 16,
            drawText: false,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildStudentCardMinimal({
    required Student student,
    required String classLabel,
    required _SchoolBrand brand,
    required pw.ImageProvider? photo,
    required pw.Font fontBold,
    required pw.Font fontRegular,
    required IdCardStyle style,
  }) {
    final primary = style.primaryPdf;
    final fullName = '${student.firstName} ${student.lastName}'.trim();

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: primary, width: 1.2),
        borderRadius: pw.BorderRadius.circular(10),
        color: style.backgroundPdf,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _brandHeader(
            title: 'STUDENT ID',
            brand: brand,
            fontBold: fontBold,
            fontRegular: fontRegular,
            titleColor: primary,
            textColor: PdfColors.black,
            subTextColor: PdfColors.grey700,
            compact: true,
          ),
          pw.SizedBox(height: 6),
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _photoBox(photo: photo, fallbackText: _initials(student.firstName, student.lastName), fontBold: fontBold),
                pw.SizedBox(width: 7),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(fullName, style: pw.TextStyle(font: fontBold, fontSize: 9)),
                      pw.SizedBox(height: 1),
                      _kv('ID', student.studentId, fontBold, fontRegular),
                      _kv('Class', classLabel, fontBold, fontRegular),
                      _kv('Guardian No', student.guardianPhone, fontBold, fontRegular),
                      _kv('Canteen', student.eatsCanteen ? 'Yes' : 'No', fontBold, fontRegular),
                      _kv('Bus', student.takesSchoolBus ? 'Yes' : 'No', fontBold, fontRegular),
                      pw.Spacer(),
                      _mottoFooter(brand: brand, fontBold: fontBold, bg: primary, fg: PdfColors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildStaffCardModern({
    required StaffData staff,
    required _SchoolBrand brand,
    required pw.ImageProvider? photo,
    required pw.Font fontBold,
    required pw.Font fontRegular,
    required IdCardStyle style,
  }) {
    final fullName = '${staff.firstName} ${staff.lastName}'.trim();
    final primary = style.primaryPdf;
    final accent = style.accentPdf;

    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        color: style.backgroundPdf,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: primary, width: 1.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              color: primary,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: _brandHeader(
              title: 'STAFF ID CARD',
              brand: brand,
              fontBold: fontBold,
              fontRegular: fontRegular,
              titleColor: PdfColors.white,
              textColor: PdfColors.white,
              subTextColor: PdfColors.white,
              compact: true,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _photoBox(photo: photo, fallbackText: _initials(staff.firstName, staff.lastName), fontBold: fontBold),
                pw.SizedBox(width: 7),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(fullName, style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.black)),
                      pw.SizedBox(height: 1),
                      _kv('Staff ID', staff.staffId, fontBold, fontRegular),
                      _kv('Position', staff.position, fontBold, fontRegular),
                      _kv('Department', staff.department ?? 'N/A', fontBold, fontRegular),
                      _kv('Phone', staff.phoneNumber, fontBold, fontRegular),
                      pw.Spacer(),
                      pw.BarcodeWidget(
                        data: staff.staffId,
                        barcode: pw.Barcode.code128(),
                        height: 16,
                        drawText: false,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 4),
          _mottoFooter(brand: brand, fontBold: fontBold, bg: accent, fg: PdfColors.white),
        ],
      ),
    );
  }

  pw.Widget _buildStaffCardClassic({
    required StaffData staff,
    required _SchoolBrand brand,
    required pw.ImageProvider? photo,
    required pw.Font fontBold,
    required pw.Font fontRegular,
    required IdCardStyle style,
  }) {
    final fullName = '${staff.firstName} ${staff.lastName}'.trim();
    final issuedOn = DateFormat('dd MMM yyyy').format(DateTime.now());
    final primary = style.primaryPdf;

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: primary, width: 2),
        borderRadius: pw.BorderRadius.circular(10),
        color: style.backgroundPdf,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _brandHeader(
            title: 'STAFF ID CARD',
            brand: brand,
            fontBold: fontBold,
            fontRegular: fontRegular,
            titleColor: primary,
            textColor: primary,
            subTextColor: PdfColors.grey700,
            compact: false,
          ),
          pw.SizedBox(height: 6),
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _photoBox(photo: photo, fallbackText: _initials(staff.firstName, staff.lastName), fontBold: fontBold),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(fullName, style: pw.TextStyle(font: fontBold, fontSize: 10)),
                      pw.SizedBox(height: 2),
                      _kv('Staff ID', staff.staffId, fontBold, fontRegular),
                      _kv('Position', staff.position, fontBold, fontRegular),
                      _kv('Department', staff.department ?? 'N/A', fontBold, fontRegular),
                      _kv('Phone', staff.phoneNumber, fontBold, fontRegular),
                      pw.Spacer(),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Issued: $issuedOn', style: pw.TextStyle(font: fontRegular, fontSize: 6, color: PdfColors.grey700)),
                          pw.Text('Powered by OmniWeave', style: pw.TextStyle(font: fontRegular, fontSize: 6, color: PdfColors.grey700)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 5),
          pw.BarcodeWidget(
            data: staff.staffId,
            barcode: pw.Barcode.code128(),
            height: 16,
            drawText: false,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildStaffCardMinimal({
    required StaffData staff,
    required _SchoolBrand brand,
    required pw.ImageProvider? photo,
    required pw.Font fontBold,
    required pw.Font fontRegular,
    required IdCardStyle style,
  }) {
    final primary = style.primaryPdf;
    final fullName = '${staff.firstName} ${staff.lastName}'.trim();

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: primary, width: 1.2),
        borderRadius: pw.BorderRadius.circular(10),
        color: style.backgroundPdf,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _brandHeader(
            title: 'STAFF ID',
            brand: brand,
            fontBold: fontBold,
            fontRegular: fontRegular,
            titleColor: primary,
            textColor: PdfColors.black,
            subTextColor: PdfColors.grey700,
            compact: true,
          ),
          pw.SizedBox(height: 6),
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _photoBox(photo: photo, fallbackText: _initials(staff.firstName, staff.lastName), fontBold: fontBold),
                pw.SizedBox(width: 7),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(fullName, style: pw.TextStyle(font: fontBold, fontSize: 9)),
                      pw.SizedBox(height: 1),
                      _kv('ID', staff.staffId, fontBold, fontRegular),
                      _kv('Position', staff.position, fontBold, fontRegular),
                      _kv('Phone', staff.phoneNumber, fontBold, fontRegular),
                      pw.Spacer(),
                      _mottoFooter(brand: brand, fontBold: fontBold, bg: primary, fg: PdfColors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  pw.Widget _photoBox({
    required pw.ImageProvider? photo,
    required String fallbackText,
    required pw.Font fontBold,
  }) {
    return pw.Container(
      width: 46,
      height: 56,
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: photo == null
          ? pw.Center(
              child: pw.Text(
                fallbackText,
                style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.indigo900),
              ),
            )
          : pw.ClipRRect(
              horizontalRadius: 6,
              verticalRadius: 6,
              child: pw.Image(photo, fit: pw.BoxFit.cover),
            ),
    );
  }

  pw.Widget _kv(String k, String v, pw.Font fontBold, pw.Font fontRegular) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 1.5),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(text: '$k: ', style: pw.TextStyle(font: fontBold, fontSize: 7, color: PdfColors.grey800)),
            pw.TextSpan(text: v, style: pw.TextStyle(font: fontRegular, fontSize: 7, color: PdfColors.black)),
          ],
        ),
        maxLines: 1,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  String _initials(String first, String last) {
    final a = first.trim().isNotEmpty ? first.trim()[0].toUpperCase() : '?';
    final b = last.trim().isNotEmpty ? last.trim()[0].toUpperCase() : '?';
    return '$a$b';
  }
}

class _SchoolBrand {
  final String name;
  final String email;
  final String address;
  final String phone;
  final String motto;
  final pw.ImageProvider? logo;

  const _SchoolBrand({
    required this.name,
    required this.email,
    required this.address,
    required this.phone,
    required this.motto,
    required this.logo,
  });
}
