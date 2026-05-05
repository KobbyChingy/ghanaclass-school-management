import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:open_file/open_file.dart';

import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/core/providers/system_settings_providers.dart';
import 'package:ghanaclass_school_management/features/assessments/report_providers.dart';
import 'package:ghanaclass_school_management/features/assessments/report_service.dart';
import 'package:ghanaclass_school_management/features/assessments/report_card_style.dart';
import 'package:ghanaclass_school_management/features/assessments/report_pdf_service.dart';
import 'package:ghanaclass_school_management/shared/printing/pdf_preview_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class StudentReportScreen extends ConsumerStatefulWidget {
  final int studentId;

  const StudentReportScreen({super.key, required this.studentId});

  @override
  ConsumerState<StudentReportScreen> createState() => _StudentReportScreenState();
}

class _StudentReportScreenState extends ConsumerState<StudentReportScreen> {
  static const _prefTemplateKey = 'report_card_template';
  static const _prefColorKey = 'report_card_color';

  int? _term;
  int? _year;

  final _formKey = GlobalKey<FormState>();
  final _conductController = TextEditingController();
  final _teacherRemarksController = TextEditingController();
  final _headteacherRemarksController = TextEditingController();

  // Ghana National template extra fields
  final _interestController = TextEditingController();
  final _promotedToController = TextEditingController();
  DateTime? _nextTermBegins;
  final Map<String, String> _behavioralRatings = {};

  String? _controllersKey;
  bool _isSaving = false;
  int _reloadTick = 0;

  ReportCardTemplate _selectedTemplate = ReportCardTemplate.classic;
  ReportCardColorScheme _selectedColor = ReportCardColorScheme.indigo;
  Future<ReportData>? _reportFuture;

  @override
  void initState() {
    super.initState();
    _loadStylePrefs();
  }

  void _refreshReportFuture() {
    if (_term == null || _year == null) return;
    _reportFuture = ref
        .read(reportServiceProvider)
        .getStudentReportData(widget.studentId, _term!, _year!);
  }

  Future<void> _loadStylePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final style = ReportCardStyle.fromIds(
      templateId: prefs.getString(_prefTemplateKey),
      colorId: prefs.getString(_prefColorKey),
    );

    if (!mounted) return;
    setState(() {
      _selectedTemplate = style.template;
      _selectedColor = style.colorScheme;
    });
  }

  Future<void> _saveStylePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefTemplateKey, _selectedTemplate.name);
    await prefs.setString(_prefColorKey, _selectedColor.name);
  }

  ReportCardStyle get _reportStyle => ReportCardStyle(
        template: _selectedTemplate,
        colorScheme: _selectedColor,
      );

  @override
  void dispose() {
    _conductController.dispose();
    _teacherRemarksController.dispose();
    _headteacherRemarksController.dispose();
    _interestController.dispose();
    _promotedToController.dispose();
    super.dispose();
  }

    GhanaNationalData _ghanaNationalData(ReportData data) => GhanaNationalData(
        nextTermBegins: _nextTermBegins,
        interest: _interestController.text.trim().isEmpty
            ? null
            : _interestController.text.trim(),
        promotedTo: _promotedToController.text.trim().isEmpty
            ? null
            : _promotedToController.text.trim(),
      pupilAttendance: data.pupilAttendance,
      totalAttendanceDays: data.totalAttendanceDays,
        behavioralRatings: _behavioralRatings,
      );

  @override
  Widget build(BuildContext context) {
    final activeTerm = ref.watch(activeTermProvider);
    final activeYear = ref.watch(activeYearProvider);

    _term ??= activeTerm;
    _year ??= activeYear;

    _refreshReportFuture();

    final term = _term!;
    final year = _year!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Report'),
      ),
      body: FutureBuilder(
        key: ValueKey('student-report-${widget.studentId}-$term-$year-$_reloadTick'),
        future: _reportFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _ErrorBanner(message: 'Failed to load report: ${snapshot.error}'),
              ),
            );
          }

          final data = snapshot.requireData;

          final newControllersKey = '${data.student.id}-${data.term}-${data.academicYear}';
          if (_controllersKey != newControllersKey) {
            _controllersKey = newControllersKey;
            _conductController.text = data.conduct ?? 'Satisfactory';
            _teacherRemarksController.text = data.teacherRemarks ?? 'Good performance, keep it up.';
            _headteacherRemarksController.text = data.headteacherRemarks ?? 'Promising results.';
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _headerCard(data),
              const SizedBox(height: 16),
              _termYearRow(context, term: term, year: year),
              const SizedBox(height: 16),
              _styleSelectorCard(),
              const SizedBox(height: 16),
              _actionsRow(context, data),
              const SizedBox(height: 20),
              _resultsCard(data),
              const SizedBox(height: 20),
              if (_selectedTemplate == ReportCardTemplate.ghanaNational)
                _ghanaFieldsCard(data),
              if (_selectedTemplate == ReportCardTemplate.ghanaNational)
                const SizedBox(height: 20),
              _remarksCard(data),
            ],
          );
        },
      ),
    );
  }

  Widget _headerCard(ReportData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.actionIndigo.withValues(alpha: 0.1),
            child: const Icon(LucideIcons.user, color: AppTheme.actionIndigo),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data.student.firstName} ${data.student.lastName}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${data.student.studentId} • Class: ${data.schoolClass.className}',
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _termYearRow(BuildContext context, {required int term, required int year}) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            key: ValueKey('term-$term'),
            initialValue: term,
            decoration: const InputDecoration(
              labelText: 'Term',
              prefixIcon: Icon(LucideIcons.calendar),
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 1, child: Text('Term 1')),
              DropdownMenuItem(value: 2, child: Text('Term 2')),
              DropdownMenuItem(value: 3, child: Text('Term 3')),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _term = v;
                _controllersKey = null;
                _refreshReportFuture();
              });
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            key: ValueKey('year-$year'),
            initialValue: year.toString(),
            decoration: const InputDecoration(
              labelText: 'Academic Year',
              prefixIcon: Icon(LucideIcons.graduationCap),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onFieldSubmitted: (v) {
              final parsed = int.tryParse(v.trim());
              if (parsed == null) return;
              setState(() {
                _year = parsed;
                _controllersKey = null;
                _refreshReportFuture();
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _actionsRow(BuildContext context, ReportData data) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.start,
      children: [
        OutlinedButton.icon(
          icon: const Icon(LucideIcons.eye),
          label: const Text('Preview PDF'),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PdfPreviewScreen(
                  title: 'Terminal Report',
                  subtitle: '${data.student.firstName} ${data.student.lastName} • Term ${data.term}',
                  pdfFileName: 'report-${data.student.studentId}-term-${data.term}.pdf',
                  buildPdf: (format) => ref
                      .read(reportPdfServiceProvider)
                      .buildTerminalReportPdf(
                        data: data,
                        pageFormat: format,
                        style: _reportStyle,
                        ghanaNationalData: _selectedTemplate == ReportCardTemplate.ghanaNational
                          ? _ghanaNationalData(data)
                            : null,
                      ),
                ),
              ),
            );
          },
        ),
        OutlinedButton.icon(
          icon: const Icon(LucideIcons.download),
          label: const Text('Save PDF'),
          onPressed: () => _savePdf(data),
        ),
        ElevatedButton.icon(
          icon: const Icon(LucideIcons.printer),
          label: const Text('Print'),
          onPressed: () => ref
              .read(reportPdfServiceProvider)
              .generateAndPrintTerminalReport(
                data,
                style: _reportStyle,
                ghanaNationalData: _selectedTemplate == ReportCardTemplate.ghanaNational
                  ? _ghanaNationalData(data)
                    : null,
              ),
        ),
        TextButton.icon(
          icon: const Icon(LucideIcons.refreshCw),
          label: const Text('Refresh'),
          onPressed: () => setState(() {
            _reloadTick++;
            _refreshReportFuture();
          }),
        ),
      ],
    );
  }

  Future<void> _savePdf(ReportData data) async {
    try {
      final suggestedName = _suggestPdfFileName(data);
      final targetPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save terminal report as PDF',
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );

      if (targetPath == null) return;

      var normalizedPath = targetPath;
      if (!normalizedPath.toLowerCase().endsWith('.pdf')) {
        normalizedPath = '$normalizedPath.pdf';
      }

        final bytes = await ref
              .read(reportPdfServiceProvider)
              .buildTerminalReportPdf(
                data: data,
                style: _reportStyle,
                ghanaNationalData: _selectedTemplate == ReportCardTemplate.ghanaNational
                  ? _ghanaNationalData(data)
                    : null,
              );
      await File(normalizedPath).writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved PDF to $normalizedPath'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () {
              OpenFile.open(normalizedPath);
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save PDF: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _suggestPdfFileName(ReportData data) {
    final raw = '${data.student.lastName}_${data.student.firstName}_Terminal_Report_Term${data.term}_${data.academicYear}.pdf';
    // Windows disallows: \ / : * ? " < > |
    return raw.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
  }

  Widget _styleSelectorCard() {
    final previewColor = _selectedColor.flutterColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Report Card Style', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text(
            'Choose a template and accent color for the PDF.',
            style: TextStyle(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<ReportCardTemplate>(
                  initialValue: _selectedTemplate,
                  decoration: const InputDecoration(
                    labelText: 'Template',
                    border: OutlineInputBorder(),
                  ),
                  items: ReportCardTemplate.values
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.label),
                        ),
                      )
                      .toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() => _selectedTemplate = v);
                    await _saveStylePrefs();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<ReportCardColorScheme>(
                  initialValue: _selectedColor,
                  decoration: const InputDecoration(
                    labelText: 'Accent Color',
                    border: OutlineInputBorder(),
                  ),
                  items: ReportCardColorScheme.values
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: c.flutterColor,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(c.label),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() => _selectedColor = v);
                    await _saveStylePrefs();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 36,
                height: 8,
                decoration: BoxDecoration(
                  color: previewColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${_selectedTemplate.label} • ${_selectedColor.label}',
                style: const TextStyle(color: AppTheme.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultsCard(ReportData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Results', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _metricChip('Position', '${data.position}/${data.totalStudents}'),
              _metricChip('Average', data.averageScore.toStringAsFixed(2)),
              _metricChip('Attendance', data.attendanceRate),
            ],
          ),
          const SizedBox(height: 12),
          if (data.results.isEmpty)
            const Text('No subject results found for this term.', style: TextStyle(color: AppTheme.textMuted))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Subject')),
                  DataColumn(label: Text('CA')),
                  DataColumn(label: Text('Exam')),
                  DataColumn(label: Text('Total')),
                  DataColumn(label: Text('Grade')),
                  DataColumn(label: Text('Remarks')),
                ],
                rows: [
                  for (final r in data.results)
                    DataRow(
                      cells: [
                        DataCell(Text(r.subjectName)),
                        DataCell(Text(r.caScore.toStringAsFixed(1))),
                        DataCell(Text(r.examScore.toStringAsFixed(1))),
                        DataCell(Text(r.totalScore.toStringAsFixed(1))),
                        DataCell(Text(r.grade)),
                        DataCell(Text((r.remarks ?? '').trim())),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

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

  Widget _ghanaFieldsCard(ReportData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ghana National Report Fields',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'These fields appear only on the Ghana National (GES) template.',
            style: TextStyle(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),

          // ── Attendance (auto-generated from Attendance page records) ──
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _metricChip('Total Attendance Days', '${data.totalAttendanceDays}'),
              _metricChip('Pupil Attendance', '${data.pupilAttendance}'),
              _metricChip('Attendance Rate', data.attendanceRate),
            ],
          ),
          const SizedBox(height: 12),

          // ── Next Term Begins ──
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate:
                    _nextTermBegins ?? DateTime.now().add(const Duration(days: 60)),
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (picked != null) setState(() => _nextTermBegins = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Next Term Begins',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              child: Text(
                _nextTermBegins != null
                    ? DateFormat('dd MMM yyyy').format(_nextTermBegins!)
                    : 'Tap to select date',
                style: TextStyle(
                  color: _nextTermBegins != null ? null : AppTheme.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Promoted To ──
          TextField(
            controller: _promotedToController,
            decoration: const InputDecoration(
              labelText: 'Promoted To (e.g. Basic 6)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // ── Interest ──
          TextField(
            controller: _interestController,
            decoration: const InputDecoration(
              labelText: 'Interest',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // ── Behavioural Ratings ──
          const Text(
            'Behavioural Characteristics',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'A = Very High  •  B = High  •  C = Average  •  D = Low  •  E = Very Low',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          for (final trait in _behaviouralTraits) ...[
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(trait, style: const TextStyle(fontSize: 13)),
                ),
                Expanded(
                  flex: 4,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('$trait-${_behavioralRatings[trait]}'),
                    initialValue: _behavioralRatings[trait],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('—')),
                      DropdownMenuItem(value: 'A', child: Text('A – Very High')),
                      DropdownMenuItem(value: 'B', child: Text('B – High')),
                      DropdownMenuItem(value: 'C', child: Text('C – Average')),
                      DropdownMenuItem(value: 'D', child: Text('D – Low')),
                      DropdownMenuItem(value: 'E', child: Text('E – Very Low')),
                    ],
                    onChanged: (v) => setState(() {
                      if (v == null) {
                        _behavioralRatings.remove(trait);
                      } else {
                        _behavioralRatings[trait] = v;
                      }
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _remarksCard(ReportData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Remarks & Conduct', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _conductController,
              decoration: const InputDecoration(labelText: 'Conduct', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _teacherRemarksController,
              decoration: const InputDecoration(labelText: 'Teacher\'s Remarks', border: OutlineInputBorder()),
              minLines: 2,
              maxLines: 4,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _headteacherRemarksController,
              decoration: const InputDecoration(labelText: 'Headteacher\'s Remarks', border: OutlineInputBorder()),
              minLines: 2,
              maxLines: 4,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.save),
                  label: Text(_isSaving ? 'Saving...' : 'Save'),
                  onPressed: _isSaving ? null : () => _saveRemarks(data),
                ),
                const SizedBox(width: 12),
                Text(
                  'Saved for Term ${data.term}, ${data.academicYear}',
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveRemarks(ReportData data) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(reportServiceProvider).upsertReportSummary(
            ReportSummariesCompanion(
              studentId: drift.Value(widget.studentId),
              term: drift.Value(_term!),
              academicYear: drift.Value(_year!),
              conduct: drift.Value(_conductController.text.trim()),
              teacherRemarks: drift.Value(_teacherRemarksController.text.trim()),
              headteacherRemarks: drift.Value(_headteacherRemarksController.text.trim()),
            ),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report summary saved.')),
        );
        setState(() {
          _reloadTick++;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _metricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text('$label: $value', style: const TextStyle(color: AppTheme.textMuted)),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AppTheme.error.withValues(alpha: 0.08),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.alertTriangle, size: 18, color: AppTheme.error),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: AppTheme.textMuted))),
        ],
      ),
    );
  }
}
