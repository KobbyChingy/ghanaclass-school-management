import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';

class ExamPdfService {
  Future<void> generateAndPrintExam({
    required String title,
    required String subjectName,
    required String className,
    required DateTime examDate,
    required String teacherName,
    required List<QuestionBankData> questions,
    required InstitutionalIdentityData schoolInfo,
  }) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            _buildHeader(schoolInfo, fontBold),
            pw.SizedBox(height: 10),
            _buildExamMetadata(title, subjectName, className, examDate, teacherName, fontBold),
            pw.SizedBox(height: 20),
            _buildStudentInfoBox(fontBold),
            pw.SizedBox(height: 24),
            ..._buildQuestions(questions, font, fontBold),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: '${title}_$subjectName.pdf',
    );
  }

  pw.Widget _buildHeader(InstitutionalIdentityData school, pw.Font fontBold) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(school.schoolName.toUpperCase(), 
              style: pw.TextStyle(font: fontBold, fontSize: 20, color: PdfColors.blue800)),
          ],
        ),
        pw.SizedBox(height: 4),
        if (school.motto != null) 
          pw.Text(school.motto!, style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
        pw.Text(school.address ?? '', style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Tel: ${school.phoneNumber ?? ""} | Email: ${school.officialEmail}', 
          style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 5),
        pw.Divider(thickness: 1, color: PdfColors.grey700),
      ],
    );
  }

  pw.Widget _buildExamMetadata(String title, String subject, String className, DateTime date, String teacher, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
          child: pw.Text(title.toUpperCase(), 
            style: pw.TextStyle(font: fontBold, fontSize: 16, decoration: pw.TextDecoration.underline)),
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _metaItem('SUBJECT:', subject, fontBold),
            _metaItem('CLASS:', className, fontBold),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _metaItem('DATE:', DateFormat('dd MMM yyyy').format(date), fontBold),
            _metaItem('TEACHER:', teacher, fontBold),
          ],
        ),
      ],
    );
  }

  pw.Widget _metaItem(String label, String value, pw.Font fontBold) {
    return pw.Row(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(width: 5),
        pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 10)),
      ],
    );
  }

  pw.Widget _buildStudentInfoBox(pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('NAME OF STUDENT: ________________________________________________', 
            style: const pw.TextStyle(fontSize: 10)),
          pw.Text('ID: ____________', style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  List<pw.Widget> _buildQuestions(List<QuestionBankData> questions, pw.Font font, pw.Font fontBold) {
    // Separate Objectives and Theory
    final objectives = questions.where((q) => q.questionType == 'objective').toList();
    final theories = questions.where((q) => q.questionType == 'theory').toList();

    List<pw.Widget> widgets = [];

    if (objectives.isNotEmpty) {
      widgets.add(pw.Text('SECTION A: OBJECTIVES', style: pw.TextStyle(font: fontBold, fontSize: 12)));
      widgets.add(pw.SizedBox(height: 10));
      for (var i = 0; i < objectives.length; i++) {
        widgets.add(_buildObjectiveQuestion(i + 1, objectives[i], font, fontBold));
        widgets.add(pw.SizedBox(height: 12));
      }
      widgets.add(pw.SizedBox(height: 20));
    }

    if (theories.isNotEmpty) {
      widgets.add(pw.Text('SECTION B: THEORY', style: pw.TextStyle(font: fontBold, fontSize: 12)));
      widgets.add(pw.SizedBox(height: 10));
      for (var i = 0; i < theories.length; i++) {
        widgets.add(_buildTheoryQuestion(objectives.length + i + 1, theories[i], font, fontBold));
        widgets.add(pw.SizedBox(height: 24));
      }
    }

    return widgets;
  }

  pw.Widget _buildObjectiveQuestion(int number, QuestionBankData q, pw.Font font, pw.Font fontBold) {
    final List<dynamic> options = q.options != null ? jsonDecode(q.options!) : [];
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('$number. ', style: pw.TextStyle(font: fontBold)),
            pw.Expanded(child: pw.Text(q.questionText)),
            pw.SizedBox(width: 10),
            pw.Text('[${q.marks} mks]', style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 20),
          child: pw.Column(
            children: options.asMap().entries.map((entry) {
              final char = String.fromCharCode(65 + entry.key);
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 2),
                child: pw.Row(
                  children: [
                    pw.Text('($char) ${entry.value}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTheoryQuestion(int number, QuestionBankData q, pw.Font font, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('$number. ', style: pw.TextStyle(font: fontBold)),
            pw.Expanded(child: pw.Text(q.questionText)),
            pw.SizedBox(width: 10),
            pw.Text('[${q.marks} mks]', style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
        pw.SizedBox(height: 12),
        // Add lines for answering
        ...List.generate(3, (_) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8, left: 20),
          child: pw.Container(height: 1, color: PdfColors.grey300),
        )),
      ],
    );
  }
}
