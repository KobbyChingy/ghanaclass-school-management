import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/features/finance/finance_service.dart';

class FinancePdfService {
  Future<Uint8List> buildReceiptPdf({
    required Payment payment,
    required Student student,
    required FeeStructure feeStructure,
    InstitutionalIdentityData? schoolInfo,
    double? feeTotal,
    double? paidToDate,
    double? balanceRemaining,
    String? receivedByName,
    PdfPageFormat? pageFormat,
  }) async {
    final doc = pw.Document();
    final fontBold = await PdfGoogleFonts.openSansBold();
    final fontRegular = await PdfGoogleFonts.openSansRegular();

    final schoolName = (schoolInfo?.schoolName.trim().isNotEmpty == true) ? schoolInfo!.schoolName.trim() : 'School';
    final officialEmail = (schoolInfo?.officialEmail.trim().isNotEmpty == true) ? schoolInfo!.officialEmail.trim() : null;
    final phone = (schoolInfo?.phoneNumber?.trim().isNotEmpty == true) ? schoolInfo!.phoneNumber!.trim() : null;
    final address = (schoolInfo?.address?.trim().isNotEmpty == true) ? schoolInfo!.address!.trim() : null;
    final motto = (schoolInfo?.motto?.trim().isNotEmpty == true) ? schoolInfo!.motto!.trim() : null;

    final receiptFeeTotal = feeTotal ?? feeStructure.amount;
    final receiptPaidToDate = paidToDate ?? payment.amountPaid;
    final receiptBalanceRemaining =
        balanceRemaining ?? (receiptFeeTotal - receiptPaidToDate).clamp(0.0, double.infinity);
    final isPartPayment = receiptBalanceRemaining > 0.0001;

    String money(double v) => 'GHS ${v.toStringAsFixed(2)}';

    final dfDate = DateFormat('dd MMM yyyy');
    final dfDateTime = DateFormat('dd MMM yyyy, HH:mm');

    pw.ImageProvider? schoolLogo;
    final logoBytes = schoolInfo?.logoBytes;
    if (logoBytes != null && logoBytes.isNotEmpty) {
      schoolLogo = pw.MemoryImage(logoBytes);
    } else {
      final path = schoolInfo?.logoPath;
      if (path != null && path.trim().isNotEmpty) {
        try {
          final fileBytes = await File(path).readAsBytes();
          if (fileBytes.isNotEmpty) {
            schoolLogo = pw.MemoryImage(fileBytes);
          }
        } catch (_) {
          // Ignore logo read failures; PDF should still generate.
        }
      }
    }

    final format = pageFormat ?? PdfPageFormat.a5;

    pw.Widget infoLine(String? text) {
      final t = (text ?? '').trim();
      if (t.isEmpty) return pw.SizedBox();
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 1.5),
        child: pw.Text(
          t,
          style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: PdfColors.grey700),
        ),
      );
    }

    pw.Widget sectionTitle(String text) {
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(width: 3, height: 12, color: PdfColors.indigo900),
          pw.SizedBox(width: 6),
          pw.Text(
            text,
            style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: PdfColors.indigo900),
          ),
        ],
      );
    }

    pw.Widget kv(String label, String value, {PdfColor? valueColor}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 3,
              child: pw.Text(
                label,
                style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.grey700),
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              flex: 5,
              child: pw.Text(
                value,
                style: pw.TextStyle(font: fontRegular, fontSize: 9.5, color: valueColor ?? PdfColors.black),
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget card({required pw.Widget child}) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 10),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(10),
          border: pw.Border.all(color: PdfColors.grey300),
        ),
        child: child,
      );
    }

    pw.TableRow amountRow({
      required String label,
      required String value,
      bool emphasize = false,
      PdfColor? valueColor,
      PdfColor? bg,
    }) {
      final labelStyle = pw.TextStyle(
        font: emphasize ? fontBold : fontRegular,
        fontSize: 9,
        color: PdfColors.grey800,
      );
      final valueStyle = pw.TextStyle(
        font: emphasize ? fontBold : fontRegular,
        fontSize: 9,
        color: valueColor ?? (emphasize ? PdfColors.indigo900 : PdfColors.black),
      );

      return pw.TableRow(
        decoration: pw.BoxDecoration(color: bg ?? PdfColors.white),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            child: pw.Text(label, style: labelStyle),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(value, style: valueStyle),
            ),
          ),
        ],
      );
    }

    doc.addPage(
      pw.Page(
        pageFormat: format,
        build: (pw.Context context) {
          final studentName = '${student.firstName} ${student.lastName}'.trim();
          final guardianName = student.guardianName.trim();
          final guardianPhone = student.guardianPhone.trim();
          final notes = (payment.notes ?? '').trim();

          final statusText = isPartPayment ? 'PART PAYMENT' : 'PAID IN FULL';
          final statusBg = isPartPayment ? PdfColors.amber100 : PdfColors.green100;
          final statusFg = isPartPayment ? PdfColors.amber900 : PdfColors.green900;

          return pw.Container(
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(14),
              border: pw.Border.all(color: PdfColors.grey300, width: 1.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Header
                pw.Container(
                  padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.indigo900,
                    borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(14)),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      if (schoolLogo != null)
                        pw.Container(
                          width: 40,
                          height: 40,
                          margin: const pw.EdgeInsets.only(right: 10),
                          padding: const pw.EdgeInsets.all(4),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: pw.BorderRadius.circular(10),
                          ),
                          child: pw.ClipRRect(
                            horizontalRadius: 8,
                            verticalRadius: 8,
                            child: pw.Image(schoolLogo, fit: pw.BoxFit.contain),
                          ),
                        ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              schoolName,
                              style: pw.TextStyle(font: fontBold, fontSize: 15, color: PdfColors.white),
                            ),
                            if (motto != null)
                              pw.Padding(
                                padding: const pw.EdgeInsets.only(top: 2),
                                child: pw.Text(
                                  motto,
                                  style: pw.TextStyle(
                                    font: fontRegular,
                                    fontSize: 8.5,
                                    color: PdfColors.white,
                                  ),
                                ),
                              ),
                            if (address != null) infoLine(address),
                            if (phone != null || officialEmail != null)
                              infoLine(
                                [
                                  if (phone != null) 'Tel: $phone',
                                  if (officialEmail != null) 'Email: $officialEmail',
                                ].join('   •   '),
                              ),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 10),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'FEE RECEIPT',
                            style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.white),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Receipt #: ${payment.receiptNumber}',
                            style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: PdfColors.white),
                          ),
                          pw.Text(
                            dfDateTime.format(payment.paymentDate),
                            style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: PdfColors.white),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 8),
                            decoration: pw.BoxDecoration(
                              color: statusBg,
                              borderRadius: pw.BorderRadius.circular(50),
                            ),
                            child: pw.Text(
                              statusText,
                              style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: statusFg),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Body
                pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      card(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            sectionTitle('Student Details'),
                            kv('Student Name', studentName.isEmpty ? '-' : studentName),
                            kv('Student ID', student.studentId),
                            if (guardianName.isNotEmpty) kv('Guardian', guardianName),
                            if (guardianPhone.isNotEmpty) kv('Guardian Phone', guardianPhone),
                          ],
                        ),
                      ),

                      card(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            sectionTitle('Payment Details'),
                            kv('Fee Structure', feeStructure.feeName),
                            kv('Payment Method', payment.paymentMethod.toUpperCase()),
                            kv('Payment Type', isPartPayment ? 'Part Payment' : 'Full Payment'),
                            kv('Payment Date', dfDate.format(payment.paymentDate)),
                            if (receivedByName != null && receivedByName.trim().isNotEmpty)
                              kv('Received By', receivedByName.trim()),
                            if (notes.isNotEmpty) kv('Notes', notes),
                          ],
                        ),
                      ),

                      card(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: [
                            sectionTitle('Amounts'),
                            pw.SizedBox(height: 8),
                            pw.Table(
                              columnWidths: const {
                                0: pw.FlexColumnWidth(3),
                                1: pw.FlexColumnWidth(2),
                              },
                              border: pw.TableBorder(
                                horizontalInside: pw.BorderSide(color: PdfColors.grey300),
                              ),
                              children: [
                                amountRow(
                                  label: 'Fee Total',
                                  value: money(receiptFeeTotal),
                                  bg: PdfColors.grey50,
                                ),
                                amountRow(
                                  label: 'Amount Paid (Now)',
                                  value: money(payment.amountPaid),
                                  emphasize: true,
                                ),
                                amountRow(
                                  label: 'Total Paid (To Date)',
                                  value: money(receiptPaidToDate),
                                  bg: PdfColors.grey50,
                                ),
                                amountRow(
                                  label: 'Balance Remaining',
                                  value: money(receiptBalanceRemaining),
                                  emphasize: true,
                                  valueColor: receiptBalanceRemaining > 0.0001 ? PdfColors.red900 : PdfColors.green900,
                                ),
                              ],
                            ),
                            if (isPartPayment)
                              pw.Padding(
                                padding: const pw.EdgeInsets.only(top: 6),
                                child: pw.Text(
                                  'Outstanding balance after this payment: ${money(receiptBalanceRemaining)}',
                                  style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: PdfColors.grey700),
                                ),
                              ),
                          ],
                        ),
                      ),

                      pw.SizedBox(height: 10),

                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Received By', style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey800)),
                                pw.SizedBox(height: 16),
                                pw.Container(height: 1, color: PdfColors.grey600),
                              ],
                            ),
                          ),
                          pw.SizedBox(width: 18),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Student/Guardian', style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey800)),
                                pw.SizedBox(height: 16),
                                pw.Container(height: 1, color: PdfColors.grey600),
                              ],
                            ),
                          ),
                        ],
                      ),

                      pw.SizedBox(height: 10),
                      pw.Container(height: 1, color: PdfColors.grey300),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Thank you for your payment.',
                            style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: PdfColors.indigo900),
                          ),
                          pw.Text(
                            'Generated by GhanaClass',
                            style: pw.TextStyle(font: fontRegular, fontSize: 8.2, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'This is a computer-generated receipt. Please keep it for your records.',
                        style: pw.TextStyle(font: fontRegular, fontSize: 8.0, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return doc.save();
  }

  Future<void> generateAndPrintReceipt({
    required Payment payment,
    required Student student,
    required FeeStructure feeStructure,
    InstitutionalIdentityData? schoolInfo,
    double? feeTotal,
    double? paidToDate,
    double? balanceRemaining,
    String? receivedByName,
  }) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        return buildReceiptPdf(
          payment: payment,
          student: student,
          feeStructure: feeStructure,
          schoolInfo: schoolInfo,
          feeTotal: feeTotal,
          paidToDate: paidToDate,
          balanceRemaining: balanceRemaining,
          receivedByName: receivedByName,
          pageFormat: format,
        );
      },
      name: 'Receipt-${payment.receiptNumber}',
    );
  }

  Future<Uint8List> buildOwingLedgerPdf({
    required List<StudentFeesLedgerRow> rows,
    InstitutionalIdentityData? schoolInfo,
    String? classFilterLabel,
    String? feeFilterLabel,
    String? searchQuery,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) async {
    final doc = pw.Document();

    late final pw.Font regular;
    late final pw.Font bold;
    try {
      regular = await PdfGoogleFonts.openSansRegular();
      bold = await PdfGoogleFonts.openSansBold();
    } catch (_) {
      regular = pw.Font.helvetica();
      bold = pw.Font.helveticaBold();
    }

    final dfDateTime = DateFormat('dd MMM yyyy, HH:mm');
    final schoolName = (schoolInfo?.schoolName.trim().isNotEmpty == true)
        ? schoolInfo!.schoolName.trim()
        : 'School';
    final address = schoolInfo?.address?.trim();
    final phone = schoolInfo?.phoneNumber?.trim();
    final email = schoolInfo?.officialEmail.trim();

    String money(double value) => 'GHS ${value.toStringAsFixed(2)}';

    final totalOutstanding = rows.fold<double>(0, (sum, row) => sum + row.balance);
    final uniqueStudents = rows.map((row) => row.studentId).toSet().length;

    pw.Widget filterLine(String label, String? value) {
      final text = (value ?? '').trim();
      if (text.isEmpty) return pw.SizedBox.shrink();
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 2),
        child: pw.Text(
          '$label: $text',
          style: pw.TextStyle(font: regular, fontSize: 9, color: PdfColors.grey700),
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 28),
        build: (context) {
          return [
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColors.indigo900,
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    schoolName,
                    style: pw.TextStyle(font: bold, fontSize: 18, color: PdfColors.white),
                  ),
                  if (address != null && address.isNotEmpty)
                    pw.Text(address, style: pw.TextStyle(font: regular, fontSize: 9, color: PdfColors.white)),
                  if ((phone != null && phone.isNotEmpty) || (email != null && email.isNotEmpty))
                    pw.Text(
                      [if (phone != null && phone.isNotEmpty) phone, if (email != null && email.isNotEmpty) email]
                          .join('  •  '),
                      style: pw.TextStyle(font: regular, fontSize: 9, color: PdfColors.white),
                    ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'OWING REPORT',
                    style: pw.TextStyle(font: bold, fontSize: 14, color: PdfColors.white),
                  ),
                  pw.Text(
                    'Generated ${dfDateTime.format(DateTime.now())}',
                    style: pw.TextStyle(font: regular, fontSize: 8.5, color: PdfColors.white),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            filterLine('Class Filter', classFilterLabel),
            filterLine('Fee Structure Filter', feeFilterLabel),
            filterLine('Search', searchQuery),
            pw.SizedBox(height: 10),
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      borderRadius: pw.BorderRadius.circular(10),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Students Owing', style: pw.TextStyle(font: regular, fontSize: 9, color: PdfColors.grey700)),
                        pw.SizedBox(height: 4),
                        pw.Text('$uniqueStudents', style: pw.TextStyle(font: bold, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      borderRadius: pw.BorderRadius.circular(10),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Total Outstanding', style: pw.TextStyle(font: regular, fontSize: 9, color: PdfColors.grey700)),
                        pw.SizedBox(height: 4),
                        pw.Text(money(totalOutstanding), style: pw.TextStyle(font: bold, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.TableHelper.fromTextArray(
              context: context,
              headerStyle: pw.TextStyle(font: bold, color: PdfColors.white, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
              cellStyle: pw.TextStyle(font: regular, fontSize: 8.5),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: const {
                0: pw.FlexColumnWidth(1.3),
                1: pw.FlexColumnWidth(2.2),
                2: pw.FlexColumnWidth(1.6),
                3: pw.FlexColumnWidth(2.1),
                4: pw.FlexColumnWidth(1.1),
                5: pw.FlexColumnWidth(1.1),
                6: pw.FlexColumnWidth(1.1),
              },
              headers: const ['ID', 'Student', 'Class', 'Fee Structure', 'Fees', 'Paid', 'Balance'],
              data: rows
                  .map(
                    (row) => [
                      row.studentCode,
                      '${row.firstName} ${row.lastName}',
                      row.className ?? '-',
                      row.feeName,
                      money(row.totalFees),
                      money(row.totalPaid),
                      money(row.balance),
                    ],
                  )
                  .toList(growable: false),
            ),
          ];
        },
      ),
    );

    return doc.save();
  }
}
