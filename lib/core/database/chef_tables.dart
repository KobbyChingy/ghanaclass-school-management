import 'package:drift/drift.dart';

import 'tables.dart';
import 'academic_tables.dart';
import 'shop_tables.dart';

// Extra metadata for canteen/shop items (nutrition + allergens)
class CanteenItemDetails extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopItemId => integer().unique().references(ShopItems, #id)();

  // Comma-separated tags, e.g. "nuts,fish,gluten"
  TextColumn get allergenTags => text().nullable()();

  // Free-form nutrition info (kcal, macros, etc)
  TextColumn get nutritionInfo => text().nullable()();

  BoolColumn get isVegetarian => boolean().withDefault(const Constant(false))();
  BoolColumn get isHalal => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Student-specific dietary notes (typically supplied by parent/medical notes)
class StudentDietaryNotes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get studentId => integer().unique().references(Students, #id)();

  TextColumn get allergies => text().nullable()();
  TextColumn get preferences => text().nullable()();
  TextColumn get medicalNotes => text().nullable()();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// Portion planning by class/level for a given menu day
class CanteenPortionPlans extends Table {
  IntColumn get id => integer().autoIncrement()();

  DateTimeColumn get menuDate => dateTime()();
  IntColumn get classId => integer().references(SchoolClasses, #id)();

  // Estimated portions for the class (e.g. smaller for creche)
  IntColumn get plannedPortions => integer().withDefault(const Constant(0))();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {menuDate, classId},
      ];
}

// Recipes enable ingredient deduction + costing
class CanteenRecipes extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 140)();
  TextColumn get description => text().nullable()();

  // Optional link to a menu item (ShopItem) representing the meal
  IntColumn get outputShopItemId => integer().nullable().references(ShopItems, #id)();

  // Defaults for scaling
  IntColumn get defaultPortions => integer().withDefault(const Constant(50))();

  IntColumn get createdBy => integer().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class CanteenRecipeIngredients extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get recipeId => integer().references(CanteenRecipes, #id)();
  IntColumn get ingredientShopItemId => integer().references(ShopItems, #id)();

  // Quantity used per portion (in unit below)
  RealColumn get quantityPerPortion => real()();
  TextColumn get unit => text().withDefault(const Constant('unit'))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {recipeId, ingredientShopItemId},
      ];
}

// Production records (prepared vs served) and optional stock deduction
class CanteenProductionRecords extends Table {
  IntColumn get id => integer().autoIncrement()();

  DateTimeColumn get productionDate => dateTime()();
  IntColumn get recipeId => integer().references(CanteenRecipes, #id)();

  IntColumn get portionsPrepared => integer().withDefault(const Constant(0))();
  IntColumn get portionsServed => integer().withDefault(const Constant(0))();

  // If stock was deducted, store a reference receipt-like token.
  TextColumn get stockReference => text().nullable()();

  TextColumn get notes => text().nullable()();

  IntColumn get createdBy => integer().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Temperature logs (fridge/freezer/surface) for basic HACCP-like compliance
class CanteenTemperatureLogs extends Table {
  IntColumn get id => integer().autoIncrement()();

  DateTimeColumn get loggedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get location => text().withDefault(const Constant('kitchen'))();
  RealColumn get temperatureC => real()();

  TextColumn get notes => text().nullable()();

  IntColumn get createdBy => integer().references(Users, #id)();
}

// Hygiene & safety checklists (simple: store fields as JSON)
class CanteenHygieneChecks extends Table {
  IntColumn get id => integer().autoIncrement()();

  DateTimeColumn get checkDate => dateTime()();
  TextColumn get checklistType => text().withDefault(const Constant('daily'))();

  // JSON string with booleans/notes
  TextColumn get payloadJson => text()();

  TextColumn get notes => text().nullable()();

  IntColumn get createdBy => integer().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Incident reporting (allergy reaction etc.)
class CanteenIncidents extends Table {
  IntColumn get id => integer().autoIncrement()();

  DateTimeColumn get occurredAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get studentId => integer().nullable().references(Students, #id)();

  TextColumn get severity => text().withDefault(const Constant('low'))();
  TextColumn get description => text()();
  TextColumn get actionsTaken => text().nullable()();

  BoolColumn get resolved => boolean().withDefault(const Constant(false))();

  IntColumn get createdBy => integer().references(Users, #id)();
}

// Waste tracking (leftovers / spoilage)
class CanteenWasteLogs extends Table {
  IntColumn get id => integer().autoIncrement()();

  DateTimeColumn get wasteDate => dateTime()();
  TextColumn get wasteType => text().withDefault(const Constant('leftover'))();
  RealColumn get quantity => real().withDefault(const Constant(0.0))();
  TextColumn get unit => text().withDefault(const Constant('portion'))();

  TextColumn get notes => text().nullable()();

  IntColumn get createdBy => integer().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Incoming orders (pre-orders from parent portal later; currently supports manual entries)
class CanteenOrders extends Table {
  IntColumn get id => integer().autoIncrement()();

  DateTimeColumn get orderDate => dateTime()();

  IntColumn get studentId => integer().nullable().references(Students, #id)();
  IntColumn get menuItemId => integer().references(ShopItems, #id)();

  IntColumn get quantity => integer().withDefault(const Constant(1))();

  // parent, student, walkin, admin
  TextColumn get source => text().withDefault(const Constant('walkin'))();

  // pending, preparing, served, cancelled
  TextColumn get status => text().withDefault(const Constant('pending'))();

  TextColumn get notes => text().nullable()();

  IntColumn get createdBy => integer().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Menu templates / rotation
class CanteenMenuTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120).unique()();
  TextColumn get description => text().nullable()();
  IntColumn get createdBy => integer().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class CanteenMenuTemplateItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get templateId => integer().references(CanteenMenuTemplates, #id)();

  // 1=Mon ... 7=Sun
  IntColumn get dayOfWeek => integer().withDefault(const Constant(1))();
  IntColumn get menuItemId => integer().references(ShopItems, #id)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {templateId, dayOfWeek, menuItemId},
      ];
}
