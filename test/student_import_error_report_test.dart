import 'package:flutter_test/flutter_test.dart';

import 'package:ghanaclass_school_management/features/students/student_import_error_report.dart';

void main() {
  test('buildStudentImportErrorReport formats counts + errors', () {
    final report = buildStudentImportErrorReport(
      generatedAt: DateTime.parse('2026-02-03T10:00:00.000Z'),
      imported: 12,
      created: 10,
      updated: 2,
      errors: ['Row 2: Missing First Name', 'Row 5: Invalid DOB'],
    );

    expect(report, contains('Student Import Error Report'));
    expect(report, contains('Imported: 12'));
    expect(report, contains('Created: 10'));
    expect(report, contains('Updated: 2'));
    expect(report, contains('Failed: 2'));
    expect(report, contains('- Row 2: Missing First Name'));
    expect(report, contains('- Row 5: Invalid DOB'));
  });
}
