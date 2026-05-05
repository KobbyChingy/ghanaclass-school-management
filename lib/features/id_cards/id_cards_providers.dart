import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/features/id_cards/id_card_pdf_service.dart';

final idCardPdfServiceProvider = Provider<IdCardPdfService>((ref) {
  final db = ref.watch(databaseProvider);
  final authService = ref.watch(authServiceProvider);
  return IdCardPdfService(db, authService);
});
