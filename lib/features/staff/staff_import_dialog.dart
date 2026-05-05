import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/config/app_mode.dart';
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/core/providers/activity_providers.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/features/staff/staff_import_service.dart';
import 'package:ghanaclass_school_management/features/staff/staff_import_error_report.dart';
import 'package:ghanaclass_school_management/features/staff/staff_providers.dart';
import 'package:ghanaclass_school_management/features/staff/staff_service.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StaffImportDialog extends ConsumerStatefulWidget {
  const StaffImportDialog({super.key});

  @override
  ConsumerState<StaffImportDialog> createState() => _StaffImportDialogState();
}

class _StaffImportDialogState extends ConsumerState<StaffImportDialog> {
  final _importService = StaffImportExportService();

  List<Map<String, String>>? _previewData;
  String? _selectedFilePath;
  bool _isProcessing = false;

  Future<void> _downloadTemplate() async {
    try {
      final path = await _importService.exportTemplateToExcel();
      if (path == null) {
        throw Exception('Failed to create template file');
      }

      await OpenFile.open(path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Template exported. Fill it and import it here.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not export template: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
    );

    if (result == null || result.files.single.path == null) return;

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
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Bulk Staff Import', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(LucideIcons.x), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Upload a CSV/Excel file to create staff profiles and portal accounts in bulk.',
                style: TextStyle(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),

              if (_selectedFilePath == null)
                _buildUploadPrompt()
              else if (_isProcessing)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (_previewData != null)
                Expanded(child: _buildPreviewDisplay())
              else
                const Expanded(child: Center(child: Text('No data found in file.'))),

              if (_previewData != null) ...[
                const SizedBox(height: 16),
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
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _showConfirmationPrompt,
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.actionIndigo),
                      child: const Text('Upload Staff'),
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
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.uploadCloud, size: 74, color: AppTheme.actionIndigo.withValues(alpha: 0.55)),
            const SizedBox(height: 18),
            const Text('Select a CSV or Excel file to begin', style: TextStyle(fontSize: 16, color: AppTheme.textMuted)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(LucideIcons.filePlus),
              label: const Text('Choose File'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _downloadTemplate,
              icon: const Icon(LucideIcons.download),
              label: const Text('Download Template'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewDisplay() {
    if (_previewData == null || _previewData!.isEmpty) {
      return const Center(child: Text('Empty file.'));
    }

    final headers = _previewData!.first.keys.toList();

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
            padding: EdgeInsets.only(top: 8),
            child: Text('... showing first 10 records only', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
          ),
      ],
    );
  }

  void _showConfirmationPrompt() {
    if (_previewData == null || _previewData!.isEmpty) return;

    final headers = _previewData!.first.keys.toSet();
    final hasLogin = _hasAny(headers, ['Portal Email', 'Email', 'Username / Email', 'Login Email']);
    final hasPassword = _hasAny(headers, ['Password', 'Portal Password']);
    final hasFirst = _hasAny(headers, ['First Name', 'Firstname', 'FirstName']);
    final hasLast = _hasAny(headers, ['Last Name', 'Lastname', 'LastName']);
    final hasPhone = _hasAny(headers, ['Phone Number', 'Phone', 'Mobile', 'PhoneNumber']);

    if (!hasLogin || !hasPassword || !hasFirst || !hasLast || !hasPhone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Missing required columns. Required: First Name, Last Name, Phone Number, Portal Email, Password.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirm Upload'),
          content: Text(
            'Import ${_previewData!.length} staff records? This will create/update portal accounts and staff profiles.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
              onPressed: () async {
                Navigator.pop(ctx);
                await _runImport();
              },
              child: const Text('Yes, Upload'),
            ),
          ],
        );
      },
    );
  }

  bool _hasAny(Set<String> headers, List<String> candidates) {
    final normalized = headers.map(_normKey).toSet();
    return candidates.map(_normKey).any(normalized.contains);
  }

  String _normKey(String v) {
    return v.trim().toLowerCase().replaceAll(RegExp(r'[_\s\-]+'), '');
  }

  String? _getAny(Map<String, String> row, List<String> candidates) {
    final normalizedRow = <String, String>{};
    for (final e in row.entries) {
      normalizedRow[_normKey(e.key)] = e.value;
    }
    for (final c in candidates) {
      final v = normalizedRow[_normKey(c)];
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  DateTime? _tryParseDate(String? raw) {
    if (raw == null) return null;
    final v = raw.trim();
    if (v.isEmpty) return null;

    // Excel sometimes stores dates as a serial number (days since 1899-12-30).
    // Accept integer-like values for robustness.
    final serial = double.tryParse(v);
    if (serial != null && RegExp(r'^\d+(?:\.0+)?$').hasMatch(v)) {
      final days = serial.round();
      if (days > 0 && days < 600000) {
        return DateTime(1899, 12, 30).add(Duration(days: days));
      }
    }

    final iso = DateTime.tryParse(v);
    if (iso != null) return iso;

    final m = RegExp(r'^(\d{1,2})[\-/](\d{1,2})[\-/](\d{4})$').firstMatch(v);
    if (m != null) {
      final a = int.parse(m.group(1)!);
      final b = int.parse(m.group(2)!);
      final y = int.parse(m.group(3)!);

      // Prefer dd/mm/yyyy when day > 12
      final dayFirst = a > 12;
      final day = dayFirst ? a : b;
      final month = dayFirst ? b : a;
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(y, month, day);
      }
    }

    return null;
  }

  bool _parseBoolLoose(String? raw, {required bool defaultValue}) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v.isEmpty) return defaultValue;

    if (['1', 'true', 'yes', 'y', 'active', 'enabled', 'enable'].contains(v)) return true;
    if (['0', 'false', 'no', 'n', 'inactive', 'disabled', 'disable'].contains(v)) return false;

    return defaultValue;
  }

  String _normalizePhoneNumber(String input) {
    var v = input.trim();
    if (v.isEmpty) return '';

    // Remove common separators.
    v = v.replaceAll(RegExp(r'[\s\-\(\)\u2013\u2014]'), '');

    // Excel numeric phones often become 233555123456.0
    if (RegExp(r'^\d+\.0+$').hasMatch(v)) {
      v = v.split('.').first;
    } else if (v.endsWith('.0') && RegExp(r'^\d+\.0$').hasMatch(v)) {
      v = v.substring(0, v.length - 2);
    }

    // Excel may stringify big numbers as scientific notation.
    if (RegExp(r'^\d+(?:\.\d+)?[eE][+\-]?\d+$').hasMatch(v)) {
      final d = double.tryParse(v);
      if (d != null) {
        v = d.toStringAsFixed(0);
      }
    }

    return v;
  }

  String _normalizeStaffId(String input) {
    return input.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();
  }

  double _parseMoney(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return 0.0;
    final cleaned = v.replaceAll(RegExp(r'[^0-9.\-]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  Future<String> _generateUniqueStaffId({
    required int rowNumber,
    required StaffService staffService,
    required Set<String> alreadyUsed,
  }) async {
    final year = DateTime.now().year;
    final base = _normalizeStaffId('STAFF$year${rowNumber.toString().padLeft(4, '0')}');

    var candidate = base;
    var suffix = 1;
    while (alreadyUsed.contains(candidate) || await staffService.getStaffByStaffId(candidate) != null) {
      candidate = '$base-$suffix';
      suffix++;
      if (suffix > 5000) {
        throw Exception('Could not generate a unique Staff ID');
      }
    }
    return candidate;
  }

  UserRole _parseRole(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v.isEmpty) return UserRole.teacher;

    for (final r in UserRole.values) {
      if (r.name == v) return r;
      if (r.displayName.toLowerCase() == v) return r;
    }

    if (v.contains('account')) return UserRole.accountant;
    if (v.contains('sec')) return UserRole.secretary;
    if (v.contains('security')) return UserRole.security;
    if (v.contains('ict') && v.contains('lab')) return UserRole.ictlab;
    if (v.contains('science') && v.contains('lab')) return UserRole.sciencelab;
    if (v.contains('shop')) return UserRole.shop;
    if (v.contains('chef') || v.contains('canteen')) return UserRole.chef;
    if (v.contains('infirm')) return UserRole.infirmary;
    if (v.contains('libr')) return UserRole.library;

    return UserRole.teacher;
  }

  String _normalizeGender(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v.startsWith('f')) return 'female';
    return 'male';
  }

  Future<void> _runImport() async {
    if (_previewData == null || _previewData!.isEmpty) return;

    setState(() => _isProcessing = true);

    final prefs = await SharedPreferences.getInstance();
    final serverEnabled = AppMode.resolveServerEnabled(prefs.getBool('server_enabled'));
    if (serverEnabled) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bulk staff import is not supported in cloud mode yet.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    var imported = 0;
    final errors = <String>[];

    final seenEmails = <String>{};
    final seenStaffIds = <String>{};

    final authService = ref.read(authServiceProvider);
    final staffService = ref.read(staffServiceProvider);

    try {
      for (var i = 0; i < _previewData!.length; i++) {
        final row = _previewData![i];
        final rowNumber = i + 2; // header row is 1

        try {
          final firstName = _getAny(row, ['First Name', 'Firstname', 'FirstName']);
          final lastName = _getAny(row, ['Last Name', 'Lastname', 'LastName']);
          if (firstName == null || lastName == null) {
            throw Exception('Missing first/last name');
          }

          final loginId = _getAny(row, ['Portal Email', 'Email', 'Username / Email', 'Login Email']);
          final password = _getAny(row, ['Password', 'Portal Password']);
          if (loginId == null || password == null) {
            throw Exception('Missing portal email/password');
          }

          final normalizedLogin = loginId.toLowerCase().trim();
          if (!seenEmails.add(normalizedLogin)) {
            throw Exception('Duplicate portal email in file: $normalizedLogin');
          }

          final role = _parseRole(_getAny(row, ['Portal Role', 'Role', 'Portal']));

          final phoneRaw = _getAny(row, ['Phone Number', 'Phone', 'Mobile']);
          if (phoneRaw == null) {
            throw Exception('Missing phone number');
          }

          final phone = _normalizePhoneNumber(phoneRaw);
          if (phone.isEmpty) {
            throw Exception('Missing phone number');
          }

          final staffIdRaw = _getAny(row, ['Staff ID', 'StaffId', 'Staff ID Code', 'Staff Code']);
          final staffId = (staffIdRaw == null || staffIdRaw.trim().isEmpty)
              ? await _generateUniqueStaffId(rowNumber: rowNumber, staffService: staffService, alreadyUsed: seenStaffIds)
              : _normalizeStaffId(staffIdRaw);

          if (!seenStaffIds.add(staffId)) {
            throw Exception('Duplicate Staff ID in file: $staffId');
          }

          final gender = _normalizeGender(_getAny(row, ['Gender', 'Sex']));
          final dob = _tryParseDate(_getAny(row, ['DOB', 'Date of Birth'])) ?? DateTime.now().subtract(const Duration(days: 365 * 25));
          final hireDate = _tryParseDate(_getAny(row, ['Hire Date', 'Employment Date'])) ?? DateTime.now();

          final position = _getAny(row, ['Position', 'Job Title']) ?? role.displayName;
          final department = _getAny(row, ['Department']);
          final address = _getAny(row, ['Address']);
          final emergency = _getAny(row, ['Emergency Contact', 'Emergency']);

          final salaryRaw = _getAny(row, ['Base Salary', 'Salary']);
          final salary = _parseMoney(salaryRaw);

          final activeRaw = _getAny(row, ['Is Active', 'Active', 'Status']);
          final isActive = _parseBoolLoose(activeRaw, defaultValue: true);

          final userId = await authService.createOrUpdateStaffUser(
            fullName: '$firstName $lastName',
            email: normalizedLogin,
            password: password,
            role: role,
            phoneNumber: phone,
          );

          final existingByUser = await staffService.getStaffByUserId(userId);
          final existingByStaffId = await staffService.getStaffByStaffId(staffId);

          if (existingByUser != null && existingByStaffId != null && existingByUser.id != existingByStaffId.id) {
            throw Exception('Staff ID "$staffId" is already assigned to another portal account');
          }

          final existing = existingByUser ?? existingByStaffId;

          if (existing == null) {
            await staffService.createStaff(
              StaffCompanion.insert(
                userId: userId,
                staffId: staffId,
                firstName: firstName,
                lastName: lastName,
                gender: gender,
                dateOfBirth: dob,
                phoneNumber: phone,
                address: drift.Value(address),
                emergencyContact: drift.Value(emergency),
                position: position.trim().isEmpty ? role.displayName : position.trim(),
                department: drift.Value(department),
                hireDate: hireDate,
                baseSalary: salary,
                isActive: drift.Value(isActive),
              ),
            );
          } else {
            await staffService.updateStaff(
              StaffCompanion(
                id: drift.Value(existing.id),
                userId: drift.Value(userId),
                staffId: drift.Value(staffId),
                firstName: drift.Value(firstName),
                lastName: drift.Value(lastName),
                gender: drift.Value(gender),
                dateOfBirth: drift.Value(dob),
                phoneNumber: drift.Value(phone),
                address: drift.Value(address),
                emergencyContact: drift.Value(emergency),
                position: drift.Value(position.trim().isEmpty ? role.displayName : position.trim()),
                department: drift.Value(department),
                hireDate: drift.Value(hireDate),
                baseSalary: drift.Value(salary),
                isActive: drift.Value(isActive),
                updatedAt: drift.Value(DateTime.now()),
              ),
            );
          }

          imported++;
        } catch (e) {
          errors.add('Row $rowNumber: $e');
        }
      }

      // Activity log
      final currentUser = ref.read(currentUserProvider);
      if (currentUser != null) {
        await ref.read(activityServiceProvider).logActivity(
              actorUserId: currentUser.id,
              actorName: currentUser.fullName,
              actorRole: UserRole.values.firstWhere((r) => r.name == currentUser.role, orElse: () => UserRole.admin),
              module: 'staff',
              actionType: 'bulk_import',
              description: 'Admin imported $imported staff via file. Failed: ${errors.length}.',
              isImportant: true,
            );
      }

      ref.invalidate(staffListProvider);

      if (!mounted) return;

      Navigator.pop(context);

      final message = errors.isEmpty
          ? 'Imported $imported staff successfully.'
          : 'Imported $imported staff. Failed: ${errors.length}.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: errors.isEmpty ? Colors.green : Colors.orange),
      );

      if (errors.isNotEmpty) {
        await showDialog(
          context: context,
          builder: (ctx) {
            final shown = errors.take(10).toList();
            return AlertDialog(
              title: const Text('Import completed with errors'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Imported: $imported'),
                    Text('Failed: ${errors.length}'),
                    const SizedBox(height: 12),
                    const Text('First errors:'),
                    const SizedBox(height: 8),
                    ...shown.map((e) => Text('• $e')),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    try {
                      final path = await _exportErrorReport(imported: imported, errors: errors);
                      // Best effort open; ignore result.
                      await OpenFile.open(path);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Error report exported.'), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not export error report: $e'), backgroundColor: Colors.red),
                        );
                      }
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
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<String> _exportErrorReport({required int imported, required List<String> errors}) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${directory.path}/staff_import_errors_$timestamp.txt';

    final now = DateTime.now();
    final report = buildStaffImportErrorReport(
      generatedAt: now,
      imported: imported,
      errors: errors,
    );

    await File(filePath).writeAsString(report);
    return filePath;
  }
}
