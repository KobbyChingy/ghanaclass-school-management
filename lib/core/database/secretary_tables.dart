import 'package:drift/drift.dart';

import 'tables.dart';

class SecretaryCorrespondenceTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text().withLength(min: 1, max: 160)();
  TextColumn get category => text().nullable().withLength(min: 0, max: 80)();
  TextColumn get body => text().withLength(min: 1, max: 8000)();

  @ReferenceName('secretaryCorrespondenceTemplatesCreatedBy')
  IntColumn get createdByUserId => integer().references(Users, #id)();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {title}
      ];
}
