String buildStaffImportErrorReport({
  required DateTime generatedAt,
  required int imported,
  required List<String> errors,
}) {
  final buffer = StringBuffer();
  buffer.writeln('Staff Import Error Report');
  buffer.writeln('Generated: ${generatedAt.toIso8601String()}');
  buffer.writeln('Imported: $imported');
  buffer.writeln('Failed: ${errors.length}');
  buffer.writeln('');
  buffer.writeln('Errors:');
  for (final e in errors) {
    buffer.writeln('- $e');
  }
  return buffer.toString();
}
