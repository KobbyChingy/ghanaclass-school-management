import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'promotion_service.dart';

final promotionServiceProvider = Provider<PromotionService>((ref) {
  final db = ref.watch(databaseProvider);
  return PromotionService(db);
});
