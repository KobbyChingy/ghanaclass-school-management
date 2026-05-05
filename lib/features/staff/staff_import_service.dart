import 'dart:io';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

class StaffImportExportService {
  // XLSX fallback parsing
  //
  // Some valid .xlsx files can trigger a null-crash in the `excel` package
  // decoder ("Null check operator used on a null value" from
  // `package:excel/src/parser/parse.dart`). When that happens, the import UI
  // ends up showing an empty preview.
  //
  // To make Staff imports resilient, we fall back to a lightweight parser that
  // reads the sheet XML directly from the XLSX zip.

  String? _archiveTextFile(Archive archive, String path) {
    for (final f in archive.files) {
      if (f.name == path) {
        final content = f.content;
        if (content is List<int>) return String.fromCharCodes(content);
      }
    }
    return null;
  }

  String _xmlUnescape(String s) {
    return s
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }

  List<String> _parseSharedStrings(Archive archive) {
    final xml = _archiveTextFile(archive, 'xl/sharedStrings.xml');
    if (xml == null || xml.isEmpty) return const [];

    final strings = <String>[];
    for (final m in RegExp(r'<si\\b[\\s\\S]*?</si>').allMatches(xml)) {
      final si = m.group(0) ?? '';
      final buffer = StringBuffer();
      for (final tm in RegExp(r'<t[^>]*>([\\s\\S]*?)</t>').allMatches(si)) {
        buffer.write(tm.group(1) ?? '');
      }
      strings.add(_xmlUnescape(buffer.toString()));
    }
    return strings;
  }

  int _colLettersToIndex(String letters) {
    var n = 0;
    for (var i = 0; i < letters.length; i++) {
      final c = letters.codeUnitAt(i);
      if (c >= 65 && c <= 90) {
        n = n * 26 + (c - 64);
      } else if (c >= 97 && c <= 122) {
        n = n * 26 + (c - 96);
      }
    }
    return n - 1;
  }

  ({int maxCols, int maxRows}) _dimensionFromSheetXml(String sheetXml) {
    final m = RegExp(r'<dimension[^>]*ref="([A-Z]+)(\\d+):([A-Z]+)(\\d+)"').firstMatch(sheetXml);
    if (m == null) return (maxCols: 0, maxRows: 0);
    final endCol = _colLettersToIndex(m.group(3) ?? 'A') + 1;
    final endRow = int.tryParse(m.group(4) ?? '') ?? 0;
    return (maxCols: endCol, maxRows: endRow);
  }

  List<Map<String, String>> _parseXlsxPreviewFallback(
    List<int> bytes, {
    String preferredSheetName = 'Staff',
  }) {
    final archive = ZipDecoder().decodeBytes(bytes);

    final workbookXml = _archiveTextFile(archive, 'xl/workbook.xml');
    final relsXml = _archiveTextFile(archive, 'xl/_rels/workbook.xml.rels');
    if (workbookXml == null || relsXml == null) return [];

    final sheets = <({String name, String rid})>[];
    for (final m in RegExp(r'<sheet[^>]*name="([^"]+)"[^>]*r:id="([^"]+)"[^>]*/?>').allMatches(workbookXml)) {
      final name = _xmlUnescape(m.group(1) ?? '');
      final rid = m.group(2) ?? '';
      if (name.isNotEmpty && rid.isNotEmpty) {
        sheets.add((name: name, rid: rid));
      }
    }
    if (sheets.isEmpty) return [];

    String? targetForRid(String rid) {
      final m = RegExp('<Relationship[^>]*Id="${RegExp.escape(rid)}"[^>]*Target="([^"]+)"').firstMatch(relsXml);
      if (m == null) return null;
      var t = m.group(1) ?? '';
      if (t.isEmpty) return null;
      if (t.startsWith('/')) t = t.substring(1);
      if (!t.startsWith('xl/')) t = 'xl/$t';
      return t;
    }

    final picked = sheets.firstWhere(
      (s) => s.name.trim().toLowerCase() == preferredSheetName.trim().toLowerCase(),
      orElse: () => sheets.first,
    );
    final target = targetForRid(picked.rid);
    if (target == null) return [];

    final sheetXml = _archiveTextFile(archive, target);
    if (sheetXml == null || sheetXml.isEmpty) return [];

    final sharedStrings = _parseSharedStrings(archive);
    final dims = _dimensionFromSheetXml(sheetXml);
    final maxCols = dims.maxCols;
    final maxRows = dims.maxRows;

    final cellMap = <int, Map<int, String>>{};

    // Parse cells: <c r="A1" ...>...</c>
    final cellRe = RegExp(r'<c\\b[^>]*r="([A-Z]+)(\\d+)"[^>]*>([\\s\\S]*?)</c>');
    for (final m in cellRe.allMatches(sheetXml)) {
      final colLetters = m.group(1) ?? '';
      final rowIndex = int.tryParse(m.group(2) ?? '');
      final body = m.group(3) ?? '';
      if (rowIndex == null || colLetters.isEmpty) continue;
      final colIndex = _colLettersToIndex(colLetters);

      final fullCell = m.group(0) ?? '';
      final tMatch = RegExp(r'\\bt="([^"]+)"').firstMatch(fullCell);
      final t = tMatch?.group(1);

      String value = '';
      if (t == 'inlineStr') {
        final buffer = StringBuffer();
        for (final tm in RegExp(r'<t[^>]*>([\\s\\S]*?)</t>').allMatches(body)) {
          buffer.write(tm.group(1) ?? '');
        }
        value = _xmlUnescape(buffer.toString());
      } else {
        final vMatch = RegExp(r'<v>([\\s\\S]*?)</v>').firstMatch(body);
        final vRaw = vMatch?.group(1) ?? '';
        if (t == 's') {
          final idx = int.tryParse(vRaw);
          if (idx != null && idx >= 0 && idx < sharedStrings.length) {
            value = sharedStrings[idx];
          } else {
            value = '';
          }
        } else if (t == 'b') {
          value = vRaw == '1' ? 'true' : (vRaw == '0' ? 'false' : vRaw);
        } else {
          value = _xmlUnescape(vRaw);
        }
      }

      final row = cellMap.putIfAbsent(rowIndex, () => <int, String>{});
      row[colIndex] = value;
    }

    if (cellMap.isEmpty) return [];

    final headerRow = cellMap[1] ?? const <int, String>{};
    final headerCount = maxCols > 0
        ? maxCols
        : (headerRow.keys.isEmpty ? 0 : (headerRow.keys.reduce((a, b) => a > b ? a : b) + 1));
    if (headerCount <= 0) return [];

    final rawHeaders = List<String>.generate(headerCount, (i) => _cellValueToString(headerRow[i] ?? ''));
    final headers = _makeUniqueHeaders(rawHeaders);

    final data = <Map<String, String>>[];
    final lastRow = maxRows > 0 ? maxRows : cellMap.keys.reduce((a, b) => a > b ? a : b);

    for (var r = 2; r <= lastRow; r++) {
      final row = cellMap[r] ?? const <int, String>{};
      final map = <String, String>{};
      var hasAnyValue = false;
      for (var c = 0; c < headers.length; c++) {
        final value = _cellValueToString(row[c] ?? '');
        if (value.trim().isNotEmpty) hasAnyValue = true;
        map[headers[c]] = value;
      }
      if (hasAnyValue) data.add(map);
    }

    return data;
  }

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
    // Common “123.0” case when Excel/CSV coerces numbers to doubles.
    if (RegExp(r'^\d+\.0$').hasMatch(s)) {
      s = s.substring(0, s.length - 2);
    }
    // Scientific notation (e.g., 2.335E+11) -> integer string where possible.
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

  Future<String?> exportTemplateToExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel['Staff'];

    sheet.appendRow([
      TextCellValue('Staff ID'),
      TextCellValue('First Name'),
      TextCellValue('Last Name'),
      TextCellValue('Gender'),
      TextCellValue('DOB'),
      TextCellValue('Phone Number'),
      TextCellValue('Address'),
      TextCellValue('Emergency Contact'),
      TextCellValue('Position'),
      TextCellValue('Department'),
      TextCellValue('Hire Date'),
      TextCellValue('Base Salary'),
      TextCellValue('Portal Email'),
      TextCellValue('Portal Role'),
      TextCellValue('Password'),
      TextCellValue('Is Active'),
    ]);

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${directory.path}/staff_import_template_$timestamp.xlsx';

    final bytes = excel.save();
    if (bytes == null) return null;

    await File(filePath).writeAsBytes(bytes);
    return filePath;
  }

  Future<List<Map<String, String>>> parseForPreview(String filePath) async {
    final extension = filePath.split('.').last.toLowerCase();

    if (extension == 'csv') {
      var input = File(filePath).readAsStringSync();
      // Normalize newlines so the CSV parser behaves consistently across platforms.
      // Some Windows-generated CSVs use CRLF; the converter is most reliable with LF.
      input = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      // Treat CSV values as raw strings to avoid losing leading zeros
      // (e.g. phone numbers like 0551234567) due to numeric parsing.
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
    }

    if (extension == 'xlsx' || extension == 'xls') {
      final bytes = File(filePath).readAsBytesSync();

      try {
        final excel = Excel.decodeBytes(bytes);
        final sheet = excel.tables['Staff'] ?? excel.tables.values.first;

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
      } catch (_) {
        // Only XLSX can be parsed safely via the ZIP+XML fallback.
        if (extension == 'xlsx') {
          return _parseXlsxPreviewFallback(bytes, preferredSheetName: 'Staff');
        }
        rethrow;
      }
    }

    return [];
  }
}
