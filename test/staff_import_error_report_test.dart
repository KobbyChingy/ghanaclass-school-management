import 'package:flutter_test/flutter_test.dart';

import 'package:ghanaclass_school_management/features/staff/staff_import_error_report.dart';

void main() {
  test('buildStaffImportErrorReport formats counts + errors', () {
    final generatedAt = DateTime.utc(2026, 2, 3, 12, 34, 56);
    final errors = <String>[
      'Row 2: Missing portal email/password',
      'Row 3: Duplicate Staff ID in file: STAFF-DUP-001',
    ];

    final report = buildStaffImportErrorReport(
      generatedAt: generatedAt,
      imported: 5,
      errors: errors,
    );

    expect(report, contains('Staff Import Error Report'));
    expect(report, contains('Generated: 2026-02-03T12:34:56.000Z'));
    expect(report, contains('Imported: 5'));
    expect(report, contains('Failed: 2'));
    expect(report, contains('Errors:'));

    for (final e in errors) {
      expect(report, contains('- $e'));
    }
  });
}
