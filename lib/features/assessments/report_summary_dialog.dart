import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/features/assessments/report_card_style.dart';
import 'package:ghanaclass_school_management/features/assessments/report_providers.dart';
import 'package:ghanaclass_school_management/core/providers/system_settings_providers.dart';
import 'package:ghanaclass_school_management/shared/printing/pdf_preview_screen.dart';
import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';

class ReportSummaryDialog extends ConsumerStatefulWidget {
  final Student student;

  const ReportSummaryDialog({super.key, required this.student});

  @override
  ConsumerState<ReportSummaryDialog> createState() => _ReportSummaryDialogState();
}

class _ReportSummaryDialogState extends ConsumerState<ReportSummaryDialog> {
  static const _prefTemplateKey = 'report_card_template';
  static const _prefColorKey = 'report_card_color';

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _conductController;
  late TextEditingController _teacherRemarksController;
  late TextEditingController _headteacherRemarksController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _conductController = TextEditingController(text: 'Satisfactory');
    _teacherRemarksController = TextEditingController(text: 'Good performance, keep it up.');
    _headteacherRemarksController = TextEditingController(text: 'Promising results.');
    _loadExistingData();
  }

  Future<void> _loadExistingData() async {
    final term = ref.read(activeTermProvider);
    final year = ref.read(activeYearProvider);
    
    // We can't easily watch the DB here without a provider, but we can fetch once
    final reportData = await ref.read(reportServiceProvider).getStudentReportData(widget.student.id, term, year);
    
    if (mounted) {
      setState(() {
        _conductController.text = reportData.conduct ?? 'Satisfactory';
        _teacherRemarksController.text = reportData.teacherRemarks ?? 'Good performance, keep it up.';
        _headteacherRemarksController.text = reportData.headteacherRemarks ?? 'Promising results.';
      });
    }
  }

  @override
  void dispose() {
    _conductController.dispose();
    _teacherRemarksController.dispose();
    _headteacherRemarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Report Summary - ${widget.student.firstName}'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _conductController,
                decoration: const InputDecoration(labelText: 'Conduct'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _teacherRemarksController,
                decoration: const InputDecoration(labelText: 'Teacher\'s Remarks'),
                maxLines: 3,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _headteacherRemarksController,
                decoration: const InputDecoration(labelText: 'Headmaster\'s Remarks'),
                maxLines: 2,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveAndGenerate,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save & Preview PDF'),
        ),
      ],
    );
  }

  Future<void> _saveAndGenerate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    final term = ref.read(activeTermProvider);
    final year = ref.read(activeYearProvider);

    try {
      await ref.read(reportServiceProvider).upsertReportSummary(
        ReportSummariesCompanion(
          studentId: drift.Value(widget.student.id),
          term: drift.Value(term),
          academicYear: drift.Value(year),
          conduct: drift.Value(_conductController.text),
          teacherRemarks: drift.Value(_teacherRemarksController.text),
          headteacherRemarks: drift.Value(_headteacherRemarksController.text),
        ),
      );

      final reportData = await ref.read(reportServiceProvider).getStudentReportData(widget.student.id, term, year);

      final prefs = await SharedPreferences.getInstance();
      final style = ReportCardStyle.fromIds(
        templateId: prefs.getString(_prefTemplateKey),
        colorId: prefs.getString(_prefColorKey),
      );

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfPreviewScreen(
            title: 'Terminal Report',
            subtitle: '${widget.student.firstName} ${widget.student.lastName} • Term $term',
            pdfFileName: 'report-${widget.student.studentId}-term-$term.pdf',
            buildPdf: (format) => ref
                .read(reportPdfServiceProvider)
                .buildTerminalReportPdf(data: reportData, pageFormat: format, style: style),
          ),
        ),
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
