import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/features/students/student_import_service.dart';
import 'package:ghanaclass_school_management/features/students/student_import_error_report.dart';
import 'package:ghanaclass_school_management/features/students/student_providers.dart';
import 'package:ghanaclass_school_management/core/providers/activity_providers.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

class StudentImportDialog extends ConsumerStatefulWidget {
  const StudentImportDialog({super.key});

  @override
  ConsumerState<StudentImportDialog> createState() => _StudentImportDialogState();
}

class _StudentImportDialogState extends ConsumerState<StudentImportDialog> {
  final _importService = StudentImportExportService();
  List<Map<String, String>>? _previewData;
  String? _selectedFilePath;
  bool _isProcessing = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
        _isProcessing = true;
      });

      try {
        final data = await _importService.parseForPreview(_selectedFilePath!);
        setState(() => _previewData = data);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error parsing file: $e')),
          );
        }
      } finally {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Bulk Student Import',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_selectedFilePath == null)
                _buildUploadPrompt()
              else if (_isProcessing)
                const Center(child: CircularProgressIndicator())
              else if (_previewData != null)
                Expanded(child: _buildPreviewDisplay())
              else
                const Text('No data found in file.'),
              
              if (_previewData != null) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => setState(() {
                        _selectedFilePath = null;
                        _previewData = null;
                      }),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _showConfirmationPrompt,
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.actionIndigo),
                      child: const Text('Upload Students'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadPrompt() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Icon(LucideIcons.uploadCloud, size: 80, color: AppTheme.actionIndigo.withValues(alpha: 0.5)),
        const SizedBox(height: 24),
        const Text(
          'Select a CSV or Excel file to begin',
          style: TextStyle(fontSize: 18, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _pickFile,
          icon: const Icon(LucideIcons.filePlus),
          label: const Text('Choose File'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            try {
              final path = await _importService.exportTemplateToExcel();
              if (!mounted || path == null) return;
              await OpenFile.open(path);
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not export template: $e'), backgroundColor: Colors.red),
              );
            }
          },
          icon: const Icon(LucideIcons.download, size: 18),
          label: const Text('Download Template'),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildPreviewDisplay() {
    if (_previewData!.isEmpty) return const Center(child: Text('Empty file.'));

    final headers = _previewData![0].keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preview: ${_previewData!.length} records found',
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.success),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columns: headers.map((h) => DataColumn(label: Text(h))).toList(),
                rows: _previewData!.take(10).map((row) {
                  return DataRow(
                    cells: headers.map((h) => DataCell(Text(row[h] ?? ''))).toList(),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        if (_previewData!.length > 10)
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text('... showing first 10 records only', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
          ),
      ],
    );
  }

  void _showConfirmationPrompt() {
    if (_previewData == null || _previewData!.isEmpty) return;

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    final headers = _previewData!.first.keys.toSet();
    final hasAnyClassColumn = headers.contains('Class Name') ||
        headers.contains('Class') ||
        headers.contains('ClassCode') ||
        headers.contains('Class Code');

    if (!hasAnyClassColumn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your file is missing class columns. Add “Class Name” or “Class Code” so classes can be created automatically.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Upload'),
        content: Text('Are you sure you want to upload ${_previewData?.length} student records? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final dialogNavigator = Navigator.of(dialogContext);
              final importDialogNavigator = Navigator.of(context);
              final rootContext = rootNavigator.context;

              setState(() => _isProcessing = true);
              dialogNavigator.pop(); // Close confirm dialog
              
              try {
                final studentService = ref.read(studentServiceProvider);
                final result = await studentService.bulkImportStudentsFromRowsWithResult(_previewData!);

                if (!mounted) return;

                // Log Activity
                final currentUser = ref.read(currentUserProvider);
                if (currentUser != null) {
                  await ref.read(activityServiceProvider).logActivity(
                        actorUserId: currentUser.id,
                        actorName: currentUser.fullName,
                        actorRole: UserRole.values.firstWhere((r) => r.name == currentUser.role, orElse: () => UserRole.admin),
                        module: 'students',
                        actionType: 'bulk_import',
                        description: 'Admin imported ${_previewData?.length} students via file.',
                        isImportant: true,
                      );
                }

                if (!mounted) return;

                // Close import dialog (this widget will be disposed after this).
                importDialogNavigator.pop();

                final message = result.errors.isEmpty
                    ? 'Imported ${result.imported} students successfully.'
                    : 'Imported ${result.imported} students. Failed: ${result.errors.length}.';

                messenger.showSnackBar(
                  SnackBar(content: Text(message), backgroundColor: result.errors.isEmpty ? Colors.green : Colors.orange),
                );

                if (result.errors.isNotEmpty) {
                  if (!mounted) return;
                  if (!rootContext.mounted) return;
                  await showDialog(
                    context: rootContext,
                    builder: (ctx) {
                      final shown = result.errors.take(10).toList();
                      return AlertDialog(
                        title: const Text('Import completed with errors'),
                        content: SizedBox(
                          width: 520,
                          child: SizedBox(
                            height: 360,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SelectableText('Imported: ${result.imported}'),
                                SelectableText('Created: ${result.created}'),
                                SelectableText('Updated: ${result.updated}'),
                                SelectableText('Failed: ${result.errors.length}'),
                                const SizedBox(height: 12),
                                const Text('First errors:'),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: Scrollbar(
                                    thumbVisibility: true,
                                    child: ListView.builder(
                                      itemCount: shown.length,
                                      itemBuilder: (context, index) {
                                        return SelectableText('• ${shown[index]}');
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () async {
                              try {
                                final path = await _exportErrorReport(
                                  imported: result.imported,
                                  created: result.created,
                                  updated: result.updated,
                                  errors: result.errors,
                                );
                                await OpenFile.open(path);
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('Error report exported.'), backgroundColor: Colors.green),
                                );
                              } catch (e) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text('Could not export error report: $e'), backgroundColor: Colors.red),
                                );
                              }
                            },
                            child: const Text('Download error report'),
                          ),
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                        ],
                      );
                    },
                  );
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _isProcessing = false);
                }
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
            child: const Text('Yes, Upload'),
          ),
        ],
      ),
    );
  }

  Future<String> _exportErrorReport({
    required int imported,
    required int created,
    required int updated,
    required List<String> errors,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${directory.path}/student_import_errors_$timestamp.txt';

    final report = buildStudentImportErrorReport(
      generatedAt: DateTime.now(),
      imported: imported,
      created: created,
      updated: updated,
      errors: errors,
    );

    await File(filePath).writeAsString(report);
    return filePath;
  }
}
