String buildStudentImportErrorReport({
  required DateTime generatedAt,
  required int imported,
  required int created,
  required int updated,
  required List<String> errors,
}) {
  final buffer = StringBuffer();
  buffer.writeln('Student Import Error Report');
  buffer.writeln('Generated: ${generatedAt.toIso8601String()}');
  buffer.writeln('Imported: $imported');
  buffer.writeln('Created: $created');
  buffer.writeln('Updated: $updated');
  buffer.writeln('Failed: ${errors.length}');
  buffer.writeln('');
  buffer.writeln('Errors:');
  for (final e in errors) {
    buffer.writeln('- $e');
  }
  return buffer.toString();
}
