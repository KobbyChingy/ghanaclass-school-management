import 'package:drift/drift.dart';
import 'academic_tables.dart';
import 'tables.dart';

class ShopCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80).unique()();
  TextColumn get description => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
}

class ShopSuppliers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
}

class ShopItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 140)();
  TextColumn get category => text().withDefault(const Constant('other'))();

  // Optional identifiers
  TextColumn get sku => text().nullable().unique()();
  TextColumn get barcode => text().nullable().unique()();

  IntColumn get categoryId => integer().nullable().references(ShopCategories, #id)();

  TextColumn get description => text().nullable()();

  // Uniform / bookstore variants
  TextColumn get size => text().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get variantGroup => text().nullable()();
  TextColumn get mandatoryForClassCodes => text().nullable()();

  // Pricing
  RealColumn get costPrice => real().withDefault(const Constant(0.0))();
  RealColumn get sellingPrice => real().withDefault(const Constant(0.0))();

  // Inventory
  RealColumn get quantityOnHand => real().withDefault(const Constant(0.0))();
  RealColumn get reorderLevel => real().withDefault(const Constant(0.0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  // Canteen-ish flags
  BoolColumn get isPerishable => boolean().withDefault(const Constant(false))();
  BoolColumn get isCanteenItem => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
}

class ShopStockMovements extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get itemId => integer().references(ShopItems, #id)();

  // purchase, sale, issue, return, adjust
  TextColumn get movementType => text().withDefault(const Constant('adjust'))();

  // Always positive; direction inferred from movementType
  RealColumn get quantity => real()();

  // Optional unit cost for purchases
  RealColumn get unitCost => real().nullable()();

  IntColumn get supplierId => integer().nullable().references(ShopSuppliers, #id)();

  TextColumn get reference => text().nullable()();
  TextColumn get notes => text().nullable()();

  IntColumn get createdBy => integer().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
}

class ShopSales extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get receiptNo => text().unique()();
  DateTimeColumn get soldAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get soldBy => integer().references(Users, #id)();

  // cash, momo, card, wallet
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();

  // student, staff, walkin, parent
  TextColumn get customerType => text().withDefault(const Constant('walkin'))();
  IntColumn get studentId => integer().nullable().references(Students, #id)();
  TextColumn get customerName => text().nullable()();

  RealColumn get totalAmount => real()();
  RealColumn get amountReceived => real().withDefault(const Constant(0.0))();
  RealColumn get changeGiven => real().withDefault(const Constant(0.0))();

  TextColumn get momoReference => text().nullable()();

  // completed, void
  TextColumn get status => text().withDefault(const Constant('completed'))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
}

class ShopSaleItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get saleId => integer().references(ShopSales, #id)();
  IntColumn get itemId => integer().references(ShopItems, #id)();

  RealColumn get quantity => real()();
  RealColumn get unitPrice => real()();
  RealColumn get lineTotal => real()();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
}

class StudentWallets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get studentId => integer().unique().references(Students, #id)();
  RealColumn get balance => real().withDefault(const Constant(0.0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
}

class WalletTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get studentId => integer().references(Students, #id)();

  // topup, purchase, refund, adjust
  TextColumn get type => text()();
  RealColumn get amount => real()();

  IntColumn get saleId => integer().nullable().references(ShopSales, #id)();
  TextColumn get reference => text().nullable()();

  IntColumn get createdBy => integer().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get remoteId => text().nullable().unique()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
}
