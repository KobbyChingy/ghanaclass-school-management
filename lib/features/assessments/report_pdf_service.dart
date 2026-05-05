import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'report_service.dart';
import 'report_card_style.dart';

typedef PdfFontLoader = Future<pw.Font> Function();

/// Extra data specific to the Ghana National (GES) terminal report template.
class GhanaNationalData {
  final DateTime? nextTermBegins;
  final int? pupilAttendance;
  final int? totalAttendanceDays;
  final String? promotedTo;
  final String? interest;

  /// Map of behavioural trait name → rating letter (A / B / C / D / E).
  final Map<String, String> behavioralRatings;

  const GhanaNationalData({
    this.nextTermBegins,
    this.pupilAttendance,
    this.totalAttendanceDays,
    this.promotedTo,
    this.interest,
    this.behavioralRatings = const {},
  });
}

class ReportPdfService {
  ReportPdfService({
    PdfFontLoader? regularFontLoader,
    PdfFontLoader? boldFontLoader,
  })  : _regularFontLoader = regularFontLoader ?? PdfGoogleFonts.openSansRegular,
        _boldFontLoader = boldFontLoader ?? PdfGoogleFonts.openSansBold;

  final PdfFontLoader _regularFontLoader;
  final PdfFontLoader _boldFontLoader;

  Future<Uint8List> buildTerminalReportPdf({
    required ReportData data,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
    ReportCardStyle style = const ReportCardStyle(),
    GhanaNationalData? ghanaNationalData,
  }) async {
    final doc = pw.Document();
    final font = await _regularFontLoader();
    final fontBold = await _boldFontLoader();

    if (style.template == ReportCardTemplate.ghanaNational) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 24),
          build: (pw.Context context) =>
              _buildGhanaNationalPage(data, font, fontBold, ghanaNationalData ?? const GhanaNationalData()),
        ),
      );
    } else {
      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildReportHeader(data, fontBold, style),
                pw.SizedBox(height: 20),
                _buildStudentInfoBanner(data, fontBold, style),
                pw.SizedBox(height: 24),
                _buildResultsTable(data.results, font, fontBold, style),
                pw.Spacer(),
                _buildFooter(data, fontBold),
              ],
            );
          },
        ),
      );
    }

    return doc.save();
  }

  Future<void> generateAndPrintTerminalReport(
    ReportData data, {
    ReportCardStyle style = const ReportCardStyle(),
    GhanaNationalData? ghanaNationalData,
  }) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => buildTerminalReportPdf(
        data: data,
        pageFormat: format,
        style: style,
        ghanaNationalData: ghanaNationalData,
      ),
      name: 'Report_${data.student.lastName}_Term${data.term}.pdf',
    );
  }

  pw.Widget _buildReportHeader(ReportData data, pw.Font fontBold, ReportCardStyle style) {
    final accent = style.colorScheme.pdfColor;
    final accentDark = style.colorScheme.pdfColorDark;

    switch (style.template) {
      case ReportCardTemplate.modern:
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: accentDark,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                data.schoolInfo.schoolName.toUpperCase(),
                style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.white),
              ),
              if ((data.schoolInfo.motto ?? '').trim().isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 3),
                  child: pw.Text(
                    (data.schoolInfo.motto ?? '').trim(),
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.white),
                  ),
                ),
              pw.SizedBox(height: 6),
              pw.Text(
                (data.schoolInfo.address ?? '').trim(),
                style: pw.TextStyle(fontSize: 9, color: PdfColors.white),
              ),
              pw.Text(
                'Tel: ${data.schoolInfo.phoneNumber} | Email: ${data.schoolInfo.officialEmail}',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.white),
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TERMINAL PROGRESS REPORT',
                    style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.white),
                  ),
                  pw.Text(
                    'Term ${data.term} • ${data.academicYear}',
                    style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.white),
                  ),
                ],
              ),
            ],
          ),
        );

      case ReportCardTemplate.minimal:
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              data.schoolInfo.schoolName.toUpperCase(),
              style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.black),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              '${(data.schoolInfo.address ?? '').trim()}  •  Tel: ${data.schoolInfo.phoneNumber}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 6),
            pw.Container(height: 2, color: accent),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Terminal Progress Report',
                  style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.black),
                ),
                pw.Text(
                  'Term ${data.term} • ${data.academicYear}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                ),
              ],
            ),
          ],
        );

      case ReportCardTemplate.classic:
        return pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  data.schoolInfo.schoolName.toUpperCase(),
                  style: pw.TextStyle(font: fontBold, fontSize: 22, color: accent),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              data.schoolInfo.motto ?? '',
              style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
            ),
            pw.SizedBox(height: 2),
            pw.Text(data.schoolInfo.address ?? '', style: const pw.TextStyle(fontSize: 10)),
            pw.Text(
              'Tel: ${data.schoolInfo.phoneNumber} | Email: ${data.schoolInfo.officialEmail}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 2, color: accent),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'TERMINAL PROGRESS REPORT',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 16,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Academic Year: ${data.academicYear}', style: pw.TextStyle(font: fontBold, fontSize: 11)),
                pw.Text('Term: ${data.term}', style: pw.TextStyle(font: fontBold, fontSize: 11)),
              ],
            ),
          ],
        );
      case ReportCardTemplate.ghanaNational:
        // Not used — ghanaNational routes through _buildGhanaNationalPage directly.
        return pw.SizedBox();
    }
  }

  pw.Widget _buildStudentInfoBanner(ReportData data, pw.Font fontBold, ReportCardStyle style) {
    final accent = style.colorScheme.pdfColor;

    return pw.Column(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(
              color: style.template == ReportCardTemplate.modern ? accent : PdfColors.grey400,
              width: style.template == ReportCardTemplate.modern ? 1.2 : 1,
            ),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _infoItem('NAME OF STUDENT:', '${data.student.firstName} ${data.student.lastName}'.toUpperCase(), fontBold),
                  _infoItem('CLASS:', data.schoolClass.className.toUpperCase(), fontBold),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _infoItem('STUDENT ID:', data.student.studentId, fontBold),
                  _infoItem('POSITION:', '${data.position} out of ${data.totalStudents}', fontBold),
                  _infoItem('AVERAGE SCORE:', data.averageScore.toStringAsFixed(2), fontBold),
                  _infoItem('ATTENDANCE:', data.attendanceRate, fontBold),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _infoItem(String label, String value, pw.Font fontBold) {
    return pw.Row(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.black)),
        pw.SizedBox(width: 5),
        pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 10)),
      ],
    );
  }

  pw.Widget _buildResultsTable(
    List<SubjectResult> results,
    pw.Font font,
    pw.Font fontBold,
    ReportCardStyle style,
  ) {
    final accent = style.colorScheme.pdfColor;
    final headerBg = switch (style.template) {
      ReportCardTemplate.minimal => PdfColors.grey200,
      _ => style.colorScheme.pdfColorDark,
    };
    final headerTextColor = style.template == ReportCardTemplate.minimal ? PdfColors.black : PdfColors.white;

    return pw.TableHelper.fromTextArray(
      context: null,
      headerStyle: pw.TextStyle(font: fontBold, color: headerTextColor, fontSize: 10),
      headerDecoration: pw.BoxDecoration(color: headerBg),
      cellStyle: pw.TextStyle(font: font, fontSize: 10),
      rowDecoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      border: pw.TableBorder.all(
        color: style.template == ReportCardTemplate.modern ? accent : PdfColors.grey400,
        width: 0.7,
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(1),
        5: const pw.FlexColumnWidth(2),
      },
      headers: ['SUBJECT', 'CA (30%)', 'EXAM (70%)', 'TOTAL', 'GRADE', 'REMARKS'],
      data: results.map((r) => [
        r.subjectName,
        r.caScore.toStringAsFixed(1),
        r.examScore.toStringAsFixed(1),
        r.totalScore.toStringAsFixed(1),
        r.grade,
        r.remarks ?? '',
      ]).toList(),
    );
  }

  pw.Widget _buildFooter(ReportData data, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 15),
        pw.Text('GENERAL REMARKS & CONDUCT', style: pw.TextStyle(font: fontBold, fontSize: 10)),
        pw.SizedBox(height: 5),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Conduct: ${data.conduct ?? "Satisfactory"}', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 4),
              pw.Text('Teacher\'s Remarks: ${data.teacherRemarks ?? "Good performance, keep it up."}', 
                style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 4),
              pw.Text('Headmaster\'s Remarks: ${data.headteacherRemarks ?? "Promising results."}', 
                style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ),
        pw.SizedBox(height: 30),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _signatureBox('CLASS TEACHER', fontBold),
            _signatureBox('HEADMASTER / PRINCIPAL', fontBold),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Center(
          child: pw.Text('Date Printed: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())}', 
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ),
      ],
    );
  }

  pw.Widget _signatureBox(String title, pw.Font fontBold) {
    return pw.Column(
      children: [
        pw.Container(
          width: 200,
          height: 60,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300, style: pw.BorderStyle.dashed),
          ),
          child: pw.Center(
            child: pw.Text('STAMP & SIGNATURE', 
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey400)),
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 9)),
      ],
    );
  }

  // ─── Ghana National (GES) Template ────────────────────────────────────────

  static const _behaviouralTraits = [
    'COURTESY',
    'NEATNESS',
    'EMOTIONAL CONTROL',
    'SOCIALITY',
    'INITIATIVE',
    'DEPENDABILITY',
    'COOPERATIVE SPIRIT',
    'VOLUNTEERISM',
    'HONESTY',
    'LEADERSHIP QUALITIES',
  ];

  List<pw.Widget> _buildGhanaNationalPage(
    ReportData data,
    pw.Font font,
    pw.Font fontBold,
    GhanaNationalData ghana,
  ) {
    const bc = PdfColors.black;
    const bw = 0.5;

    final studentName = [
      data.student.firstName,
      data.student.lastName,
      if ((data.student.otherNames ?? '').trim().isNotEmpty) data.student.otherNames!.trim(),
    ].join(' ');

    final totalScore = data.results.fold<double>(0, (s, r) => s + r.totalScore);

    pw.Widget infoRow(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: pw.Row(
            children: [
              pw.Text(label,
                  style: pw.TextStyle(font: fontBold, fontSize: 7, color: PdfColors.grey700)),
              pw.SizedBox(width: 4),
              pw.Expanded(
                child: pw.Text(value,
                    style: pw.TextStyle(font: fontBold, fontSize: 8)),
              ),
            ],
          ),
        );

    pw.Widget divider() =>
        pw.Container(height: bw, color: bc);

    return [
      // ── Header ──────────────────────────────────────────────────────────
      pw.Column(
        children: [
          pw.Text(
            'GHANA EDUCATION SERVICE',
            style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            data.schoolInfo.schoolName.toUpperCase(),
            style: pw.TextStyle(font: fontBold, fontSize: 16),
            textAlign: pw.TextAlign.center,
          ),
          if ((data.schoolInfo.address ?? '').trim().isNotEmpty)
            pw.Text(
              data.schoolInfo.address!.trim(),
              style: pw.TextStyle(font: font, fontSize: 8),
              textAlign: pw.TextAlign.center,
            ),
          pw.Text(
            'Tel: ${data.schoolInfo.phoneNumber ?? ""}',
            style: pw.TextStyle(font: font, fontSize: 8),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'TERMINAL REPORT',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 13,
              decoration: pw.TextDecoration.underline,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 8),
        ],
      ),

      // ── Student Info Block ───────────────────────────────────────────────
      pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(color: bc, width: bw)),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left column
            pw.Expanded(
              flex: 3,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  infoRow('PUPIL NAME:', studentName),
                  divider(),
                  infoRow('CLASS:', data.schoolClass.className),
                  divider(),
                  infoRow('NO. ON ROLL:', data.totalStudents.toString()),
                  divider(),
                  infoRow('TOTAL ATTENDANCE:', ghana.totalAttendanceDays?.toString() ?? ''),
                  divider(),
                  infoRow('PUPIL ATTENDANCE:', ghana.pupilAttendance?.toString() ?? ''),
                ],
              ),
            ),
            pw.Container(width: bw, color: bc),
            // Right column
            pw.Expanded(
              flex: 2,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  infoRow('TERM:', data.term.toString()),
                  divider(),
                  infoRow(
                    'NEXT TERM BEGINS:',
                    ghana.nextTermBegins != null
                        ? DateFormat('dd MMM yyyy').format(ghana.nextTermBegins!)
                        : '',
                  ),
                  divider(),
                  infoRow('TOTAL SCORE:', totalScore.toStringAsFixed(0)),
                  divider(),
                  infoRow('AVERAGE SCORE:', data.averageScore.toStringAsFixed(1)),
                  divider(),
                  infoRow('PROMOTED TO:', ghana.promotedTo ?? ''),
                ],
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 10),

      // ── Subjects Table ───────────────────────────────────────────────────
      pw.TableHelper.fromTextArray(
        headerStyle: pw.TextStyle(font: fontBold, fontSize: 8),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        cellStyle: pw.TextStyle(font: font, fontSize: 8),
        cellAlignment: pw.Alignment.center,
        columnWidths: {
          0: const pw.FlexColumnWidth(3.2),
          1: const pw.FlexColumnWidth(1.3),
          2: const pw.FlexColumnWidth(1.3),
          3: const pw.FlexColumnWidth(1.5),
          4: const pw.FlexColumnWidth(1.2),
          5: const pw.FlexColumnWidth(2),
        },
        border: pw.TableBorder.all(color: bc, width: bw),
        headers: ['SUBJECTS', 'Class\nScore\n50', 'Exam\nScore\n50', 'Total Score\n100%', 'Subject\nGrade', 'Remarks'],
        data: data.results.map((r) => [
          r.subjectName.toUpperCase(),
          r.caScore.toStringAsFixed(0),
          r.examScore.toStringAsFixed(0),
          r.totalScore.toStringAsFixed(0),
          r.grade,
          r.remarks?.isNotEmpty == true ? r.remarks! : _gradeRemark(r.grade),
        ]).toList(),
      ),
      pw.SizedBox(height: 10),

      // ── Personality Development ──────────────────────────────────────────
      pw.Text(
        'PERSONALITY DEVELOPMENT (Please tick the appropriate cell)',
        style: pw.TextStyle(font: fontBold, fontSize: 8),
      ),
      pw.SizedBox(height: 4),
      _buildPersonalitySection(data, font, fontBold, ghana, bc, bw),
      pw.SizedBox(height: 10),

      // ── Interest ────────────────────────────────────────────────────────
      _labelledLine('INTEREST:', ghana.interest ?? '', font, fontBold, bc),
      pw.SizedBox(height: 8),

      // ── Class Teacher's Remarks ──────────────────────────────────────────
      _labelledLine(
        "CLASS TEACHER'S REMARKS:",
        data.teacherRemarks ?? '',
        font,
        fontBold,
        bc,
      ),
      pw.SizedBox(height: 8),

      // ── Head Teacher's Remarks ───────────────────────────────────────────
      _labelledLine(
        "HEAD TEACHER'S REMARKS:",
        data.headteacherRemarks ?? '',
        font,
        fontBold,
        bc,
      ),
      pw.SizedBox(height: 28),

      // ── Signature / Stamp ────────────────────────────────────────────────
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Column(
            children: [
              pw.Container(
                width: 130,
                height: 50,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, style: pw.BorderStyle.dashed),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'STAMP & SIGNATURE',
                    style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey500),
                  ),
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text('HEADMASTER / PRINCIPAL',
                  style: pw.TextStyle(font: fontBold, fontSize: 8)),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 10),
      pw.Center(
        child: pw.Text(
          'Date Printed: ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
          style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey600),
        ),
      ),
    ];
  }

  pw.Widget _buildPersonalitySection(
    ReportData data,
    pw.Font font,
    pw.Font fontBold,
    GhanaNationalData ghana,
    PdfColor borderColor,
    double borderWidth,
  ) {
    final ratings = ghana.behavioralRatings;

    pw.Widget ratingDot(String trait, String rating) {
      final selected = ratings[trait] == rating;
      return pw.Container(
        alignment: pw.Alignment.center,
        child: selected
            ? pw.Container(
                width: 7,
                height: 7,
                decoration: const pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  color: PdfColors.black,
                ),
              )
            : pw.SizedBox(width: 7, height: 7),
      );
    }

    final traitRows = _behaviouralTraits.map((trait) {
      return pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            child: pw.Text(trait, style: pw.TextStyle(font: font, fontSize: 7)),
          ),
          for (final r in ['A', 'B', 'C', 'D', 'E'])
            pw.Container(
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.all(2),
              child: ratingDot(trait, r),
            ),
        ],
      );
    }).toList();

    final behaviourTable = pw.Table(
      border: pw.TableBorder.all(color: borderColor, width: borderWidth),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1),
        3: pw.FlexColumnWidth(1.3),
        4: pw.FlexColumnWidth(1),
        5: pw.FlexColumnWidth(1.3),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _thCell('BEHAVIORAL\nCHARACTERISTICS\n(CONDUCT)', fontBold),
            _thCell('A\n(VERY\nHIGH)', fontBold),
            _thCell('B\n(HIGH)', fontBold),
            _thCell('C\n(AVERAGE)', fontBold),
            _thCell('D\n(LOW)', fontBold),
            _thCell('E\n(VERY\nLOW)', fontBold),
          ],
        ),
        ...traitRows,
      ],
    );

    final gradingTable = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          color: PdfColors.grey200,
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: pw.Center(
            child: pw.Text('GRADING', style: pw.TextStyle(font: fontBold, fontSize: 8)),
          ),
        ),
        pw.Table(
          border: pw.TableBorder.all(color: borderColor, width: borderWidth),
          columnWidths: const {
            0: pw.FlexColumnWidth(1.2),
            1: pw.FlexColumnWidth(2),
          },
          children: [
            _gradingRow('80 – 100', 'A - EXCELLENT', font, fontBold),
            _gradingRow('70 – 79', 'B – VERY GOOD', font, fontBold),
            _gradingRow('60 – 69', 'C – GOOD', font, fontBold),
            _gradingRow('50 – 59', 'D – AVERAGE', font, fontBold),
            _gradingRow('40 – 49', 'E – BELOW AVERAGE', font, fontBold),
            _gradingRow('0 – 39', 'F – LOWEST', font, fontBold),
          ],
        ),
      ],
    );

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(flex: 3, child: behaviourTable),
        pw.SizedBox(width: 6),
        pw.Expanded(flex: 2, child: gradingTable),
      ],
    );
  }

  pw.Widget _thCell(String text, pw.Font fontBold) => pw.Container(
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.all(2),
        child: pw.Text(
          text,
          style: pw.TextStyle(font: fontBold, fontSize: 6.5),
          textAlign: pw.TextAlign.center,
        ),
      );

  pw.TableRow _gradingRow(
    String range,
    String grade,
    pw.Font font,
    pw.Font fontBold,
  ) =>
      pw.TableRow(children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: pw.Text(range, style: pw.TextStyle(font: fontBold, fontSize: 7)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: pw.Text(grade, style: pw.TextStyle(font: font, fontSize: 7)),
        ),
      ]);

  pw.Widget _labelledLine(
    String label,
    String value,
    pw.Font font,
    pw.Font fontBold,
    PdfColor borderColor,
  ) =>
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(label, style: pw.TextStyle(font: fontBold, fontSize: 8.5)),
          pw.SizedBox(width: 4),
          pw.Expanded(
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: borderColor, width: 0.5),
                ),
              ),
              padding: const pw.EdgeInsets.only(bottom: 1),
              child: pw.Text(value, style: pw.TextStyle(font: font, fontSize: 8.5)),
            ),
          ),
        ],
      );

  String _gradeRemark(String grade) {
    switch (grade.trim().toUpperCase()) {
      case 'A':
        return 'EXCELLENT';
      case 'B':
        return 'VERY GOOD';
      case 'C':
        return 'GOOD';
      case 'D':
        return 'AVERAGE';
      case 'E':
        return 'BELOW AVERAGE';
      case 'F':
        return 'LOWEST';
      default:
        return '';
    }
  }
}
