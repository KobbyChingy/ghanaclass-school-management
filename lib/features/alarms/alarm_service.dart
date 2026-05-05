import 'dart:io';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:ghanaclass_school_management/core/database/app_database.dart';

class AlarmService {
  AlarmService(this._db);

  final AppDatabase _db;

  Stream<List<Alarm>> watchAlarms() {
    return (_db.select(_db.alarms)..orderBy([(t) => OrderingTerm.asc(t.hour), (t) => OrderingTerm.asc(t.minute)]))
        .watch();
  }

  Future<List<Alarm>> getAlarmsOnce() {
    return (_db.select(_db.alarms)..orderBy([(t) => OrderingTerm.asc(t.hour), (t) => OrderingTerm.asc(t.minute)]))
        .get();
  }

  Future<int> createAlarm({
    required String title,
    String? description,
    required String soundPath,
    required int hour,
    required int minute,
    required int repeatDaysMask,
    bool isEnabled = true,
  }) {
    return _db.into(_db.alarms).insert(
          AlarmsCompanion.insert(
            title: title.trim(),
            description: Value(description?.trim().isNotEmpty == true ? description!.trim() : null),
            soundPath: soundPath,
            hour: hour,
            minute: minute,
            repeatDaysMask: Value(repeatDaysMask),
            isEnabled: Value(isEnabled),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  Future<void> updateAlarm(
    Alarm alarm, {
    String? title,
    String? description,
    String? soundPath,
    int? hour,
    int? minute,
    int? repeatDaysMask,
    bool? isEnabled,
  }) {
    return (_db.update(_db.alarms)..where((t) => t.id.equals(alarm.id))).write(
      AlarmsCompanion(
        title: title != null ? Value(title.trim()) : const Value.absent(),
        description: description != null
            ? Value(description.trim().isNotEmpty ? description.trim() : null)
            : const Value.absent(),
        soundPath: soundPath != null ? Value(soundPath) : const Value.absent(),
        hour: hour != null ? Value(hour) : const Value.absent(),
        minute: minute != null ? Value(minute) : const Value.absent(),
        repeatDaysMask: repeatDaysMask != null ? Value(repeatDaysMask) : const Value.absent(),
        isEnabled: isEnabled != null ? Value(isEnabled) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setEnabled(int alarmId, bool enabled) {
    return (_db.update(_db.alarms)..where((t) => t.id.equals(alarmId))).write(
      AlarmsCompanion(
        isEnabled: Value(enabled),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateLastFired(int alarmId, DateTime firedAt) {
    return (_db.update(_db.alarms)..where((t) => t.id.equals(alarmId))).write(
      AlarmsCompanion(
        lastFiredAt: Value(firedAt),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> disableAfterOneShot(int alarmId, DateTime firedAt) {
    return (_db.update(_db.alarms)..where((t) => t.id.equals(alarmId))).write(
      AlarmsCompanion(
        isEnabled: const Value(false),
        lastFiredAt: Value(firedAt),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteAlarm(int alarmId) {
    return (_db.delete(_db.alarms)..where((t) => t.id.equals(alarmId))).go();
  }

  /// Picks an audio file and copies it into app storage so it remains available.
  /// Returns the saved absolute path or null if cancelled.
  Future<String?> pickAndSaveAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
      withData: false,
    );

    if (result == null || result.files.isEmpty) return null;
    final path = result.files.single.path;
    if (path == null || path.trim().isEmpty) return null;

    final source = File(path);
    if (!await source.exists()) return null;

    final supportDir = await getApplicationSupportDirectory();
    final alarmsDir = Directory(p.join(supportDir.path, 'alarms', 'sounds'));
    if (!await alarmsDir.exists()) {
      await alarmsDir.create(recursive: true);
    }

    final ext = p.extension(path);
    final fileName = 'alarm-${const Uuid().v4()}${ext.isNotEmpty ? ext : ''}';
    final destPath = p.join(alarmsDir.path, fileName);
    await source.copy(destPath);

    return destPath;
  }
}
