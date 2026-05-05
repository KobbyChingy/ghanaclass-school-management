import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghanaclass_school_management/core/providers/activity_providers.dart';
import 'package:ghanaclass_school_management/core/providers/database_provider.dart';
import 'package:ghanaclass_school_management/features/shop/shop_service.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';

final shopServiceProvider = Provider<ShopService>((ref) {
  final db = ref.watch(databaseProvider);
  final activity = ref.watch(activityServiceProvider);
  return ShopService(db, activityService: activity);
});

final shopCategoriesProvider = FutureProvider<List<ShopCategory>>((ref) async {
  final service = ref.watch(shopServiceProvider);
  return service.getCategories();
});

final shopSuppliersProvider = FutureProvider<List<ShopSupplier>>((ref) async {
  final service = ref.watch(shopServiceProvider);
  return service.getSuppliers();
});

final shopItemsProvider = FutureProvider.family<List<ShopItem>, String?>((ref, query) async {
  final service = ref.watch(shopServiceProvider);
  return service.getItems(query: query);
});

final shopLowStockItemsProvider = FutureProvider<List<ShopItem>>((ref) async {
  final service = ref.watch(shopServiceProvider);
  return service.getLowStockItems();
});

final shopRecentSalesProvider = FutureProvider<List<ShopSale>>((ref) async {
  final service = ref.watch(shopServiceProvider);
  return service.getRecentSales();
});

final shopSalesHistoryProvider = FutureProvider.family<List<ShopSale>, String?>((ref, query) async {
  final service = ref.watch(shopServiceProvider);
  return service.getRecentSales(limit: 120, query: query);
});

final shopRecentMovementsProvider = FutureProvider<List<ShopStockMovement>>((ref) async {
  final service = ref.watch(shopServiceProvider);
  return service.getRecentMovements();
});

final studentWalletProvider = FutureProvider.family<StudentWallet?, int>((ref, studentId) async {
  final service = ref.watch(shopServiceProvider);
  return service.getWallet(studentId);
});

final walletTransactionsProvider = FutureProvider.family<List<WalletTransaction>, int>((ref, studentId) async {
  final service = ref.watch(shopServiceProvider);
  return service.getWalletTransactions(studentId);
});
