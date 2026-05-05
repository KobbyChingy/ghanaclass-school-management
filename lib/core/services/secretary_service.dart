import 'package:drift/drift.dart' as drift;

import 'package:ghanaclass_school_management/core/database/app_database.dart';

class SecretaryService {
  final AppDatabase _db;

  SecretaryService(this._db);

  Stream<List<SecretaryCorrespondenceTemplate>> watchTemplates() {
    return (_db.select(_db.secretaryCorrespondenceTemplates)
          ..orderBy([(t) => drift.OrderingTerm.asc(t.title)]))
        .watch();
  }

  Future<int> upsertTemplate({
    int? id,
    required String title,
    String? category,
    required String body,
    required int createdByUserId,
  }) async {
    final now = DateTime.now();

    if (id == null) {
      return _db.into(_db.secretaryCorrespondenceTemplates).insert(
            SecretaryCorrespondenceTemplatesCompanion.insert(
              title: title.trim(),
              category: drift.Value(category?.trim().isEmpty ?? true ? null : category?.trim()),
              body: body,
              createdByUserId: createdByUserId,
              updatedAt: drift.Value(now),
            ),
          );
    }

    await (_db.update(_db.secretaryCorrespondenceTemplates)..where((t) => t.id.equals(id))).write(
      SecretaryCorrespondenceTemplatesCompanion(
        title: drift.Value(title.trim()),
        category: drift.Value(category?.trim().isEmpty ?? true ? null : category?.trim()),
        body: drift.Value(body),
        updatedAt: drift.Value(now),
      ),
    );

    return id;
  }

  Future<void> deleteTemplate(int id) {
    return (_db.delete(_db.secretaryCorrespondenceTemplates)..where((t) => t.id.equals(id))).go();
  }
}
