import 'package:drift/drift.dart' as drift;
import 'package:ghanaclass_school_management/core/database/app_database.dart';

class DirectorNotificationsSettings {
  final double attendanceBelowPercent;
  final double feesCollectionBelowPercent;
  final String summaryEmailFrequency;
  final String summaryEmailTo;

  const DirectorNotificationsSettings({
    required this.attendanceBelowPercent,
    required this.feesCollectionBelowPercent,
    required this.summaryEmailFrequency,
    required this.summaryEmailTo,
  });
}

class DirectorNotificationsSettingsService {
  DirectorNotificationsSettingsService(this._db);

  final AppDatabase _db;

  static const _kAttendanceBelow = 'director_alert_threshold_attendance_below_percent';
  static const _kFeesBelow = 'director_alert_threshold_fees_collection_below_percent';
  static const _kSummaryFreq = 'director_summary_email_frequency';
  static const _kSummaryTo = 'director_summary_email_to';

  Future<DirectorNotificationsSettings> getSettings() async {
    final attendance = await _getDouble(_kAttendanceBelow) ?? 75.0;
    final fees = await _getDouble(_kFeesBelow) ?? 70.0;
    final freq = await _getString(_kSummaryFreq) ?? 'weekly';
    final to = await _getString(_kSummaryTo) ?? '';

    return DirectorNotificationsSettings(
      attendanceBelowPercent: attendance,
      feesCollectionBelowPercent: fees,
      summaryEmailFrequency: freq,
      summaryEmailTo: to,
    );
  }

  Future<void> setThresholds({
    required double attendanceBelowPercent,
    required double feesCollectionBelowPercent,
  }) async {
    _validatePercent(attendanceBelowPercent);
    _validatePercent(feesCollectionBelowPercent);

    await _setDouble(_kAttendanceBelow, attendanceBelowPercent);
    await _setDouble(_kFeesBelow, feesCollectionBelowPercent);
  }

  Future<void> setSummaryEmail({required String frequency, required String to}) async {
    final f = frequency.trim().toLowerCase();
    if (f != 'daily' && f != 'weekly' && f != 'monthly') {
      throw const FormatException('Frequency must be daily, weekly, or monthly');
    }

    await _setString(_kSummaryFreq, f);
    await _setString(_kSummaryTo, to.trim());
  }

  void _validatePercent(double v) {
    if (v.isNaN || v.isInfinite || v < 0 || v > 100) {
      throw const FormatException('Enter a percent between 0 and 100');
    }
  }

  Future<String?> _getString(String key) async {
    final row = await (_db.select(_db.syncMetadata)..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<double?> _getDouble(String key) async {
    final v = await _getString(key);
    if (v == null) return null;
    return double.tryParse(v);
  }

  Future<void> _setString(String key, String value) async {
    await _db.into(_db.syncMetadata).insertOnConflictUpdate(
          SyncMetadataCompanion(
            key: drift.Value(key),
            value: drift.Value(value),
            updatedAt: drift.Value(DateTime.now()),
          ),
        );
  }

  Future<void> _setDouble(String key, double value) => _setString(key, value.toStringAsFixed(2));
}
