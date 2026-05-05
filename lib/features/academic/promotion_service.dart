import 'package:drift/drift.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';

class PromotionService {
  final AppDatabase _database;

  PromotionService(this._database);

  Future<int> promoteStudents({
    required int fromClassId,
    required int toClassId,
    required List<int> studentIds,
  }) async {
    return await _database.transaction(() async {
      int count = 0;
      for (var id in studentIds) {
        final updated = await (_database.update(_database.students)
          ..where((s) => s.id.equals(id) & s.classId.equals(fromClassId)))
          .write(StudentsCompanion(
            classId: Value(toClassId),
            updatedAt: Value(DateTime.now()),
          ));
        count += updated;
      }
      return count;
    });
  }

  Future<List<Student>> getPromotableStudents(int classId) async {
    return await (_database.select(_database.students)
      ..where((s) => s.classId.equals(classId) & s.status.equals('active'))).get();
  }
}
