import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/features/finance/finance_service.dart';

class PayrollPayslipPdfService {
  Future<Uint8List> buildPayslipPdf({
    required PayrollHistoryEntry entry,
    InstitutionalIdentityData? schoolInfo,
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

    final r = entry.record;
    final dfDate = DateFormat('dd MMM yyyy');
    final dfDateTime = DateFormat('dd MMM yyyy, HH:mm');

    String money(double v) => 'GH₵ ${v.toStringAsFixed(2)}';

    final schoolName = (schoolInfo?.schoolName.trim().isNotEmpty == true) ? schoolInfo!.schoolName.trim() : 'School';
    final officialEmail = (schoolInfo?.officialEmail.trim().isNotEmpty == true) ? schoolInfo!.officialEmail.trim() : null;
    final phone = (schoolInfo?.phoneNumber?.trim().isNotEmpty == true) ? schoolInfo!.phoneNumber!.trim() : null;
    final address = (schoolInfo?.address?.trim().isNotEmpty == true) ? schoolInfo!.address!.trim() : null;

    pw.ImageProvider? schoolLogo;
    final logoBytes = schoolInfo?.logoBytes;
    if (logoBytes != null && logoBytes.isNotEmpty) {
      schoolLogo = pw.MemoryImage(logoBytes);
    } else {
      final path = schoolInfo?.logoPath;
      if (path != null && path.trim().isNotEmpty) {
        try {
          final fileBytes = await File(path).readAsBytes();
          if (fileBytes.isNotEmpty) schoolLogo = pw.MemoryImage(fileBytes);
        } catch (_) {
          // Ignore logo read failures.
        }
      }
    }

    pw.Widget kv(String k, String v) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 3),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 110,
              child: pw.Text(
                k,
                style: pw.TextStyle(font: bold, fontSize: 9, color: PdfColors.grey700),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                v,
                style: pw.TextStyle(font: regular, fontSize: 10, color: PdfColors.black),
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget moneyRow(String label, String value, {bool emphasize = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(font: emphasize ? bold : regular, fontSize: 10, color: PdfColors.grey800),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(font: emphasize ? bold : regular, fontSize: 10, color: emphasize ? PdfColors.indigo900 : PdfColors.black),
            ),
          ],
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
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(12),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (schoolLogo != null)
                    pw.Container(
                      width: 44,
                      height: 44,
                      padding: const pw.EdgeInsets.all(4),
                      decoration: pw.BoxDecoration(
                        borderRadius: pw.BorderRadius.circular(10),
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.ClipRRect(
                        horizontalRadius: 8,
                        verticalRadius: 8,
                        child: pw.Image(schoolLogo, fit: pw.BoxFit.contain),
                      ),
                    ),
                  if (schoolLogo != null) pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          schoolName,
                          style: pw.TextStyle(font: bold, fontSize: 16, color: PdfColors.indigo900),
                        ),
                        if (address != null)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 2),
                            child: pw.Text(address, style: pw.TextStyle(font: regular, fontSize: 9, color: PdfColors.grey700)),
                          ),
                        if (phone != null || officialEmail != null)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 1),
                            child: pw.Text(
                              [
                                if (phone != null) phone,
                                if (officialEmail != null) officialEmail,
                              ].join(' • '),
                              style: pw.TextStyle(font: regular, fontSize: 9, color: PdfColors.grey700),
                            ),
                          ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.indigo900,
                      borderRadius: pw.BorderRadius.circular(999),
                    ),
                    child: pw.Text(
                      'PAYSLIP',
                      style: pw.TextStyle(font: bold, fontSize: 9, color: PdfColors.white),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Text(
              'Employee Payroll Payslip',
              style: pw.TextStyle(font: bold, fontSize: 14, color: PdfColors.black),
            ),
            pw.SizedBox(height: 6),
            pw.Container(height: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  kv('Staff', entry.staff.fullName),
                  kv('Email', entry.staff.email),
                  kv('Role', entry.staff.role),
                  kv('Period', '${DateFormat('MMMM').format(DateTime(r.year, r.month))} ${r.year}'),
                  kv('Paid At', dfDateTime.format(r.paidAt)),
                  kv('Processed By', entry.paidBy.fullName),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Text('Salary Breakdown', style: pw.TextStyle(font: bold, fontSize: 11, color: PdfColors.indigo900)),
                  pw.SizedBox(height: 8),
                  moneyRow('Gross Salary', money(r.grossSalary)),
                  moneyRow('Total Allowances', money(r.totalAllowances)),
                  moneyRow('Total Deductions', money(r.totalDeductions)),
                  pw.Container(height: 1, color: PdfColors.grey300),
                  moneyRow('Net Salary', money(r.netSalary), emphasize: true),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated on ${dfDate.format(DateTime.now())}',
                  style: pw.TextStyle(font: regular, fontSize: 8.5, color: PdfColors.grey700),
                ),
                pw.Text(
                  'Generated by GhanaClass',
                  style: pw.TextStyle(font: regular, fontSize: 8.5, color: PdfColors.grey700),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  Future<void> printPayslip({
    required PayrollHistoryEntry entry,
    InstitutionalIdentityData? schoolInfo,
  }) async {
    await Printing.layoutPdf(
      name: 'Payslip-${entry.staff.fullName}-${entry.record.year}-${entry.record.month}',
      onLayout: (format) async {
        return buildPayslipPdf(
          entry: entry,
          schoolInfo: schoolInfo,
          pageFormat: format,
        );
      },
    );
  }
}

class PayrollHistoryReportPdfService {
  Future<Uint8List> buildPayrollHistoryReportPdf({
    required List<PayrollHistoryEntry> entries,
    required int month,
    required int year,
    InstitutionalIdentityData? schoolInfo,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
    bool groupByStaff = false,
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

    final dfDate = DateFormat('dd MMM yyyy');
    final dfDateTime = DateFormat('dd MMM yyyy, HH:mm');

    String money(double v) => 'GH₵ ${v.toStringAsFixed(2)}';

    final schoolName = (schoolInfo?.schoolName.trim().isNotEmpty == true) ? schoolInfo!.schoolName.trim() : 'School';

    final periodLabel = '${DateFormat('MMMM').format(DateTime(year, month))} $year';
    final totalGross = entries.fold<double>(0, (sum, e) => sum + e.record.grossSalary);
    final totalNet = entries.fold<double>(0, (sum, e) => sum + e.record.netSalary);
    final totalAllowances = entries.fold<double>(0, (sum, e) => sum + e.record.totalAllowances);
    final totalDeductions = entries.fold<double>(0, (sum, e) => sum + e.record.totalDeductions);

    List<List<String>> buildTableRows() {
      final rows = <List<String>>[];
      rows.add(const ['Staff', 'Gross', 'Allow.', 'Deduct.', 'Net', 'Paid At', 'Processed By']);

      for (final e in entries) {
        rows.add([
          e.staff.fullName,
          money(e.record.grossSalary),
          money(e.record.totalAllowances),
          money(e.record.totalDeductions),
          money(e.record.netSalary),
          dfDateTime.format(e.record.paidAt),
          e.paidBy.fullName,
        ]);
      }

      return rows;
    }

    List<List<String>> buildGroupedRows() {
      final rows = <List<String>>[];
      rows.add(const ['Staff', 'Records', 'Total Gross', 'Total Allow.', 'Total Deduct.', 'Total Net']);

      final byStaff = <int, List<PayrollHistoryEntry>>{};
      for (final e in entries) {
        (byStaff[e.staff.id] ??= <PayrollHistoryEntry>[]).add(e);
      }

      final staffIds = byStaff.keys.toList()..sort();
      for (final id in staffIds) {
        final list = byStaff[id]!;
        list.sort((a, b) => b.record.paidAt.compareTo(a.record.paidAt));
        final staffName = list.first.staff.fullName;

        final gross = list.fold<double>(0, (s, e) => s + e.record.grossSalary);
        final net = list.fold<double>(0, (s, e) => s + e.record.netSalary);
        final allow = list.fold<double>(0, (s, e) => s + e.record.totalAllowances);
        final deduct = list.fold<double>(0, (s, e) => s + e.record.totalDeductions);
        rows.add([
          staffName,
          list.length.toString(),
          money(gross),
          money(allow),
          money(deduct),
          money(net),
        ]);
      }

      return rows;
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.fromLTRB(24, 22, 24, 28),
        build: (context) {
          return [
            pw.Text(
              schoolName,
              style: pw.TextStyle(font: bold, fontSize: 16, color: PdfColors.indigo900),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Payroll History Report',
              style: pw.TextStyle(font: bold, fontSize: 13, color: PdfColors.black),
            ),
            pw.Text(
              'Period: $periodLabel',
              style: pw.TextStyle(font: regular, fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _metric('Records', entries.length.toString(), bold, regular),
                  _metric('Total Gross', money(totalGross), bold, regular),
                  _metric('Total Net', money(totalNet), bold, regular),
                  _metric('Allow/Deduct', '${money(totalAllowances)} / ${money(totalDeductions)}', bold, regular),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            if (groupByStaff) ...[
              pw.Text('Grouped by Staff', style: pw.TextStyle(font: bold, fontSize: 11, color: PdfColors.indigo900)),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                data: buildGroupedRows(),
                headerStyle: pw.TextStyle(font: bold, fontSize: 8.5, color: PdfColors.black),
                cellStyle: pw.TextStyle(font: regular, fontSize: 8.0, color: PdfColors.black),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
                cellAlignment: pw.Alignment.topLeft,
                headerAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              ),
              pw.SizedBox(height: 12),
            ],
            pw.Text('Records', style: pw.TextStyle(font: bold, fontSize: 11, color: PdfColors.indigo900)),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              data: buildTableRows(),
              headerStyle: pw.TextStyle(font: bold, fontSize: 8.2, color: PdfColors.black),
              cellStyle: pw.TextStyle(font: regular, fontSize: 7.8, color: PdfColors.black),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
              cellAlignment: pw.Alignment.topLeft,
              headerAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              columnWidths: const {
                0: pw.FlexColumnWidth(1.5),
                1: pw.FixedColumnWidth(60),
                2: pw.FixedColumnWidth(60),
                3: pw.FixedColumnWidth(60),
                4: pw.FixedColumnWidth(60),
                5: pw.FixedColumnWidth(95),
                6: pw.FlexColumnWidth(1.2),
              },
            ),
            pw.SizedBox(height: 10),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Generated on ${dfDate.format(DateTime.now())}',
                style: pw.TextStyle(font: regular, fontSize: 8.5, color: PdfColors.grey700),
              ),
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _metric(String label, String value, pw.Font bold, pw.Font regular) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(font: regular, fontSize: 8.5, color: PdfColors.grey700)),
          pw.SizedBox(height: 1),
          pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 9.5, color: PdfColors.black)),
        ],
      ),
    );
  }
}
