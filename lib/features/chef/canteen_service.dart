import 'package:drift/drift.dart';
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/core/services/activity_service.dart';

class CanteenPosItem {
  final ShopItem item;
  final double effectivePrice;
  final bool isAvailable;

  const CanteenPosItem({
    required this.item,
    required this.effectivePrice,
    required this.isAvailable,
  });
}

class CanteenMenuEntryView {
  final ShopItem item;
  final CanteenMenuItem entry;

  const CanteenMenuEntryView({required this.item, required this.entry});
}

class CanteenService {
  final AppDatabase _db;
  final ActivityService _activity;

  CanteenService(this._db, {required ActivityService activityService}) : _activity = activityService;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<int> _getOrCreateMenuId({
    required DateTime date,
    required int actorUserId,
  }) async {
    final normalized = _dateOnly(date);
    final existing = await (_db.select(_db.canteenMenus)..where((t) => t.menuDate.equals(normalized))).getSingleOrNull();
    if (existing != null) return existing.id;

    return _db.into(_db.canteenMenus).insert(
          CanteenMenusCompanion.insert(
            menuDate: normalized,
            createdBy: actorUserId,
          ),
        );
  }

  Future<int> upsertCanteenItem({
    int? id,
    required String name,
    double costPrice = 0,
    double sellingPrice = 0,
    bool isPerishable = false,
    bool isActive = true,
  }) {
    final companion = ShopItemsCompanion(
      id: id == null ? const Value.absent() : Value(id),
      name: Value(name.trim()),
      category: const Value('canteen'),
      costPrice: Value(costPrice),
      sellingPrice: Value(sellingPrice),
      isPerishable: Value(isPerishable),
      isCanteenItem: const Value(true),
      isActive: Value(isActive),
      isDirty: const Value(true),
    );
    return _db.into(_db.shopItems).insertOnConflictUpdate(companion);
  }

  Future<List<ShopItem>> getCanteenItems({String? query, bool activeOnly = true}) {
    final q = _db.select(_db.shopItems)
      ..where((t) => t.isCanteenItem.equals(true));

    if (activeOnly) {
      q.where((t) => t.isActive.equals(true));
    }

    final trimmed = query?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      q.where((t) => t.name.like('%$trimmed%') | t.sku.like('%$trimmed%') | t.barcode.like('%$trimmed%'));
    }

    q.orderBy([(t) => OrderingTerm.asc(t.name)]);
    return q.get();
  }

  Future<List<CanteenMenuEntryView>> getMenuEntriesForDate(DateTime date) async {
    final normalized = _dateOnly(date);

    final q = _db.select(_db.canteenMenuItems).join([
      innerJoin(_db.canteenMenus, _db.canteenMenus.id.equalsExp(_db.canteenMenuItems.menuId)),
      innerJoin(_db.shopItems, _db.shopItems.id.equalsExp(_db.canteenMenuItems.itemId)),
    ])
      ..where(_db.canteenMenus.menuDate.equals(normalized));

    final rows = await q.get();
    final entries = rows
        .map(
          (r) => CanteenMenuEntryView(
            entry: r.readTable(_db.canteenMenuItems),
            item: r.readTable(_db.shopItems),
          ),
        )
        .toList(growable: false);

    entries.sort((a, b) => a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase()));
    return entries;
  }

  Future<void> setItemOnMenu({
    required DateTime date,
    required int shopItemId,
    required int actorUserId,
    required String actorName,
    required UserRole actorRole,
    bool isAvailable = true,
    double? overridePrice,
  }) async {
    final menuId = await _getOrCreateMenuId(date: date, actorUserId: actorUserId);

    await _db.into(_db.canteenMenuItems).insertOnConflictUpdate(
          CanteenMenuItemsCompanion(
            menuId: Value(menuId),
            itemId: Value(shopItemId),
            isAvailable: Value(isAvailable),
            overridePrice: Value(overridePrice),
          ),
        );

    await _activity.logActivity(
      actorUserId: actorUserId,
      actorName: actorName,
      actorRole: actorRole,
      module: 'canteen',
      actionType: 'menu_update',
      description: 'Updated canteen menu for ${_dateOnly(date).toIso8601String().split('T').first}.',
      isImportant: false,
    );
  }

  Future<void> removeItemFromMenu({
    required DateTime date,
    required int shopItemId,
    required int actorUserId,
    required String actorName,
    required UserRole actorRole,
  }) async {
    final normalized = _dateOnly(date);
    final menu = await (_db.select(_db.canteenMenus)..where((t) => t.menuDate.equals(normalized))).getSingleOrNull();
    if (menu == null) return;

    await (_db.delete(_db.canteenMenuItems)
          ..where((t) => t.menuId.equals(menu.id) & t.itemId.equals(shopItemId)))
        .go();

    await _activity.logActivity(
      actorUserId: actorUserId,
      actorName: actorName,
      actorRole: actorRole,
      module: 'canteen',
      actionType: 'menu_update',
      description: 'Removed an item from canteen menu for ${normalized.toIso8601String().split('T').first}.',
      isImportant: false,
    );
  }

  Future<List<CanteenPosItem>> getPosItemsForDate(DateTime date, {String? query}) async {
    final normalized = _dateOnly(date);

    final joinQ = _db.select(_db.canteenMenuItems).join([
      innerJoin(_db.canteenMenus, _db.canteenMenus.id.equalsExp(_db.canteenMenuItems.menuId)),
      innerJoin(_db.shopItems, _db.shopItems.id.equalsExp(_db.canteenMenuItems.itemId)),
    ])
      ..where(_db.canteenMenus.menuDate.equals(normalized) & _db.canteenMenuItems.isAvailable.equals(true))
      ..where(_db.shopItems.isActive.equals(true));

    final trimmed = query?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      joinQ.where(_db.shopItems.name.like('%$trimmed%') | _db.shopItems.sku.like('%$trimmed%') | _db.shopItems.barcode.like('%$trimmed%'));
    }

    final rows = await joinQ.get();
    final items = <CanteenPosItem>[];
    for (final row in rows) {
      final entry = row.readTable(_db.canteenMenuItems);
      final item = row.readTable(_db.shopItems);
      final effective = entry.overridePrice ?? item.sellingPrice;
      items.add(
        CanteenPosItem(
          item: item,
          effectivePrice: effective,
          isAvailable: entry.isAvailable,
        ),
      );
    }

    items.sort((a, b) => a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase()));
    return items;
  }
}
