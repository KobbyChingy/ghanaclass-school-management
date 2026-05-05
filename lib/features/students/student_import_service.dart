import 'dart:io';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';

class StudentImportExportService {
  String _cellValueToString(Object? value) {
    if (value == null) return '';
    if (value is DateTime) {
      return value.toIso8601String().split('T').first;
    }
    if (value is num) {
      final asInt = value.toInt();
      if (value == asInt.toDouble()) return asInt.toString();
      return value.toString();
    }

    var s = value.toString();
    if (RegExp(r'^\d+\.0$').hasMatch(s)) {
      s = s.substring(0, s.length - 2);
    }
    if (RegExp(r'^\d+(?:\.\d+)?[eE][+\-]?\d+$').hasMatch(s)) {
      final d = double.tryParse(s);
      if (d != null) {
        s = d.toStringAsFixed(0);
      }
    }
    return s;
  }

  List<String> _makeUniqueHeaders(List<String> rawHeaders) {
    final seen = <String, int>{};
    final result = <String>[];
    for (var i = 0; i < rawHeaders.length; i++) {
      var h = rawHeaders[i].trim();
      if (h.isEmpty) h = 'Column ${i + 1}';
      final key = h;
      final count = (seen[key] ?? 0) + 1;
      seen[key] = count;
      result.add(count == 1 ? h : '$h ($count)');
    }
    return result;
  }

  /// Export a blank import template to Excel.
  Future<String?> exportTemplateToExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel['Students'];

    sheet.appendRow([
      TextCellValue('Class Name'),
      TextCellValue('Class Code'),
      TextCellValue('Academic Year'),
      TextCellValue('Student ID'),
      TextCellValue('Admission Number'),
      TextCellValue('First Name'),
      TextCellValue('Last Name'),
      TextCellValue('Other Names'),
      TextCellValue('Gender'),
      TextCellValue('DOB'),
      TextCellValue('Address'),
      TextCellValue('Phone Number'),
      TextCellValue('Email'),
      TextCellValue('Guardian Name'),
      TextCellValue('Guardian Phone'),
      TextCellValue('Guardian Email'),
      TextCellValue('Guardian Occupation'),
      TextCellValue('Guardian Relationship'),
      TextCellValue('Guardian Address'),
      TextCellValue('Enrolled Fees'),
      TextCellValue('Status'),
      TextCellValue('Admission Date'),
    ]);

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${directory.path}/student_import_template_$timestamp.xlsx';
    final fileBytes = excel.save();
    if (fileBytes == null) return null;
    await File(filePath).writeAsBytes(fileBytes);
    return filePath;
  }

  /// Export students to Excel
  Future<String?> exportToExcel(List<Student> students) async {
    final excel = Excel.createExcel();
    final sheet = excel['Students'];
    
    // Add Headers (this is also the recommended import template)
    sheet.appendRow([
      TextCellValue('Class Name'),
      TextCellValue('Class Code'),
      TextCellValue('Academic Year'),
      TextCellValue('Student ID'),
      TextCellValue('Admission Number'),
      TextCellValue('First Name'),
      TextCellValue('Last Name'),
      TextCellValue('Other Names'),
      TextCellValue('Gender'),
      TextCellValue('DOB'),
      TextCellValue('Address'),
      TextCellValue('Phone Number'),
      TextCellValue('Email'),
      TextCellValue('Guardian Name'),
      TextCellValue('Guardian Phone'),
      TextCellValue('Guardian Email'),
      TextCellValue('Guardian Occupation'),
      TextCellValue('Guardian Relationship'),
      TextCellValue('Guardian Address'),
      TextCellValue('Enrolled Fees'),
      TextCellValue('Status'),
      TextCellValue('Admission Date'),
    ]);
    
    // Add Data
    for (final s in students) {
      sheet.appendRow([
        // Class columns are intentionally left blank on export because we don't join here.
        // They should be filled when using this file as an import template.
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(DateTime.now().year.toString()),
        TextCellValue(s.studentId),
        TextCellValue(s.admissionNumber),
        TextCellValue(s.firstName),
        TextCellValue(s.lastName),
        TextCellValue(s.otherNames ?? ''),
        TextCellValue(s.gender),
        TextCellValue(s.dateOfBirth.toIso8601String().split('T')[0]),
        TextCellValue(s.address ?? ''),
        TextCellValue(s.phoneNumber ?? ''),
        TextCellValue(s.email ?? ''),
        TextCellValue(s.guardianName),
        TextCellValue(s.guardianPhone),
        TextCellValue(s.guardianEmail ?? ''),
        TextCellValue(s.guardianOccupation ?? ''),
        TextCellValue(s.guardianRelationship),
        TextCellValue(s.guardianAddress ?? ''),
        TextCellValue(s.enrolledFees.toString()),
        TextCellValue(s.status),
        TextCellValue(s.admissionDate.toIso8601String().split('T')[0]),
      ]);
    }
    
    // Save file
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${directory.path}/students_export_$timestamp.xlsx';
    final fileBytes = excel.save();
    
    if (fileBytes != null) {
      await File(filePath).writeAsBytes(fileBytes);
      return filePath;
    }
    return null;
  }

  /// Parse CSV/Excel for preview
  Future<List<Map<String, String>>> parseForPreview(String filePath) async {
    final extension = filePath.split('.').last.toLowerCase();
    
    if (extension == 'csv') {
      var input = File(filePath).readAsStringSync();
      input = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      final rows = const CsvToListConverter(shouldParseNumbers: false, eol: '\n').convert(input);
      if (rows.isEmpty) return [];
      
      final headers = _makeUniqueHeaders(rows[0].map((e) => _cellValueToString(e)).toList());
      final List<Map<String, String>> data = [];
      
      for (var i = 1; i < rows.length; i++) {
        final Map<String, String> map = {};
        var hasAnyValue = false;
        for (var j = 0; j < headers.length; j++) {
          final value = j < rows[i].length ? _cellValueToString(rows[i][j]) : '';
          if (value.trim().isNotEmpty) hasAnyValue = true;
          map[headers[j]] = value;
        }
        if (hasAnyValue) data.add(map);
      }
      return data;
    } else if (extension == 'xlsx' || extension == 'xls') {
      final bytes = File(filePath).readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables['Students'] ?? excel.tables.values.first;
      
      if (sheet.rows.isEmpty) return [];
      
      final headers = _makeUniqueHeaders(sheet.rows[0].map((e) => _cellValueToString(e?.value)).toList());
      final List<Map<String, String>> data = [];
      
      for (var i = 1; i < sheet.rows.length; i++) {
        final Map<String, String> map = {};
        var hasAnyValue = false;
        for (var j = 0; j < headers.length; j++) {
          final value = j < sheet.rows[i].length ? _cellValueToString(sheet.rows[i][j]?.value) : '';
          if (value.trim().isNotEmpty) hasAnyValue = true;
          map[headers[j]] = value;
        }
        if (hasAnyValue) data.add(map);
      }
      return data;
    }
    
    return [];
  }
}
