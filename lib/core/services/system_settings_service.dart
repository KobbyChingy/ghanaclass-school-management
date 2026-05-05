import 'package:drift/drift.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';

class SystemSettingsService {
  final AppDatabase _database;

  SystemSettingsService(this._database);

  Future<SystemSetting> getSettings() async {
    final existing = await _database.select(_database.systemSettings).getSingleOrNull();
    if (existing != null) return existing;

    // Create default settings if not exists
    final id = await _database.into(_database.systemSettings).insert(
      SystemSettingsCompanion.insert(
        activeAcademicYear: Value(DateTime.now().year),
        activeTerm: const Value(1),
      ),
    );
    return await (_database.select(_database.systemSettings)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<void> updateSettings(SystemSettingsCompanion entry) async {
    final settings = await getSettings();
    await (_database.update(_database.systemSettings)..where((t) => t.id.equals(settings.id))).write(entry);
  }

  Stream<SystemSetting> watchSettings() async* {
    final settings = await getSettings();
    yield settings;
    yield* ((_database.select(_database.systemSettings)
          ..where((t) => t.id.equals(settings.id)))
        .watchSingle());
  }
}
