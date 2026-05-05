import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:ghanaclass_school_management/features/teachers/lesson_notes_service.dart';

class LessonNotesPdfService {
  Future<Uint8List> buildLessonNotesPdf({
    required String title,
    required int term,
    required int academicYear,
    String? className,
    String? subjectName,
    required List<LessonNoteRowDraft> rows,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) async {
    final doc = pw.Document();

    late final pw.Font regular;
    late final pw.Font bold;
    try {
      regular = await PdfGoogleFonts.openSansRegular();
      bold = await PdfGoogleFonts.openSansBold();
    } catch (_) {
      // Font download can fail offline; fall back to built-ins.
      regular = pw.Font.helvetica();
      bold = pw.Font.helveticaBold();
    }

    String clean(String? v) {
      final s = (v ?? '').trim();
      return s;
    }

    String displayOrBlank(String? v) {
      final s = clean(v);
      return s.isEmpty ? '—' : s;
    }

    final effectiveTitle = clean(title).isEmpty ? 'Lesson Notes' : clean(title);
    final effectiveClass = clean(className);
    final effectiveSubject = clean(subjectName);

    final headerStyle = pw.TextStyle(font: bold, fontSize: 9, color: PdfColors.black);
    final cellStyle = pw.TextStyle(font: regular, fontSize: 8, color: PdfColors.black);

    List<List<String>> tableData() {
      final out = <List<String>>[];
      out.add(const [
        'Week',
        'Strand',
        'Sub-Strand',
        'Content Standards',
        'Indicator(s)',
        'Resources',
      ]);

      for (final r in rows) {
        out.add([
          r.week?.toString() ?? '',
          clean(r.strand),
          clean(r.subStrand),
          clean(r.contentStandards),
          clean(r.indicators),
          clean(r.resources),
        ]);
      }

      return out;
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 28),
        build: (context) {
          return [
            pw.Text(
              'TERMLY SCHEME OF LEARNING',
              style: pw.TextStyle(font: bold, fontSize: 14, color: PdfColors.blue800),
            ),
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _kvRow('Title', effectiveTitle, bold, regular),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    children: [
                      pw.Expanded(child: _kvRow('Term', 'Term $term', bold, regular)),
                      pw.SizedBox(width: 12),
                      pw.Expanded(child: _kvRow('Academic Year', academicYear.toString(), bold, regular)),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    children: [
                      pw.Expanded(child: _kvRow('Class', displayOrBlank(effectiveClass), bold, regular)),
                      pw.SizedBox(width: 12),
                      pw.Expanded(child: _kvRow('Subject', displayOrBlank(effectiveSubject), bold, regular)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              data: tableData(),
              headerStyle: headerStyle,
              cellStyle: cellStyle,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
              cellAlignment: pw.Alignment.topLeft,
              headerAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                0: const pw.FixedColumnWidth(34),
                1: const pw.FlexColumnWidth(1.0),
                2: const pw.FlexColumnWidth(1.0),
                3: const pw.FlexColumnWidth(1.2),
                4: const pw.FlexColumnWidth(1.2),
                5: const pw.FlexColumnWidth(0.9),
              },
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            ),
            pw.SizedBox(height: 10),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Generated on ${DateTime.now().toIso8601String().split("T").first}',
                style: pw.TextStyle(font: regular, fontSize: 8, color: PdfColors.grey700),
              ),
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  pw.Widget _kvRow(String k, String v, pw.Font fontBold, pw.Font font) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 90,
          child: pw.Text(
            '$k:',
            style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey800),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            v,
            style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.black),
          ),
        ),
      ],
    );
  }
}
