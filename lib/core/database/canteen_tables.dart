import 'package:drift/drift.dart';

import 'tables.dart';
import 'shop_tables.dart';

class CanteenMenus extends Table {
  IntColumn get id => integer().autoIncrement()();

  // Store as full DateTime, but the app treats it as a "day" (midnight-normalized).
  DateTimeColumn get menuDate => dateTime()();

  IntColumn get createdBy => integer().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {menuDate},
      ];
}

class CanteenMenuItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get menuId => integer().references(CanteenMenus, #id)();
  IntColumn get itemId => integer().references(ShopItems, #id)();

  // Optional override price for a specific day/menu.
  RealColumn get overridePrice => real().nullable()();

  BoolColumn get isAvailable => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {menuId, itemId},
      ];
}
