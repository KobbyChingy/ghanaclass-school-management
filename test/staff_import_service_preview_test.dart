import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghanaclass_school_management/features/staff/staff_import_service.dart';

void main() {
  test('StaffImportExportService CSV preview preserves strings and normalizes numeric-looking values', () async {
    final tempDir = await Directory.systemTemp.createTemp('staff_import_preview_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final csvFile = File('${tempDir.path}/sample.csv');
    await csvFile.writeAsString([
      // Duplicate headers + an empty header.
      ',Phone Number,Phone Number,Base Salary,Scientific',
      // Leading zero phone should remain intact; salary and scientific should normalize.
      ',0551234567,0249876543,1500.0,2.335E+11',
      '',
    ].join('\n'));

    final service = StaffImportExportService();
    final rows = await service.parseForPreview(csvFile.path);

    expect(rows, hasLength(1));

    final row = rows.single;
    expect(row.containsKey('Column 1'), isTrue);

    // Duplicate headers become unique.
    expect(row.containsKey('Phone Number'), isTrue);
    expect(row.containsKey('Phone Number (2)'), isTrue);

    // Leading zeros preserved (CSV numeric parsing is disabled).
    expect(row['Phone Number'], '0551234567');
    expect(row['Phone Number (2)'], '0249876543');

    // Numeric-looking values normalized.
    expect(row['Base Salary'], '1500');
    expect(row['Scientific'], '233500000000');
  });
}
