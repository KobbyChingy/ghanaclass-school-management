import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'report_service.dart';
import 'report_pdf_service.dart';

final reportServiceProvider = Provider<ReportService>((ref) {
  final db = ref.watch(databaseProvider);
  return ReportService(db);
});

final reportPdfServiceProvider = Provider<ReportPdfService>((ref) {
  return ReportPdfService();
});
