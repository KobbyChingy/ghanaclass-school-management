import 'package:drift/drift.dart';

class Alarms extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Short title shown in lists (e.g. "Break Time").
  TextColumn get title => text().withLength(min: 1, max: 120)();

  /// Optional longer description.
  TextColumn get description => text().nullable()();

  /// Local device file path for the audio to play.
  TextColumn get soundPath => text()();

  /// Time-of-day in 24-hour format.
  IntColumn get hour => integer()();
  IntColumn get minute => integer()();

  /// Bitmask for days-of-week repetition.
  /// Bit 0 = Monday, ..., Bit 6 = Sunday.
  /// 0 means one-time (fires once then disables).
  IntColumn get repeatDaysMask => integer().withDefault(const Constant(0))();

  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();

  /// Last time this alarm fired (used to prevent repeats within the same minute).
  DateTimeColumn get lastFiredAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
