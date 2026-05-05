import 'dart:async';
import 'dart:io';

import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/features/alarms/alarm_repeat.dart';
import 'package:ghanaclass_school_management/features/alarms/alarm_service.dart';

class AlarmScheduler {
  AlarmScheduler({
    required AlarmService service,
  }) : _service = service;

  final AlarmService _service;

  StreamSubscription<List<Alarm>>? _sub;
  Timer? _timer;

  List<Alarm> _alarms = const [];

  void start() {
    _sub ??= _service.watchAlarms().listen((alarms) {
      _alarms = alarms;
    });

    _timer ??= Timer.periodic(const Duration(seconds: 5), (_) {
      _tick(DateTime.now());
    });
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;

    _timer?.cancel();
    _timer = null;
  }

  static DateTime _truncateToMinute(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute);
  }

  Future<void> _tick(DateTime now) async {
    if (_alarms.isEmpty) return;

    final nowMinute = _truncateToMinute(now);

    for (final alarm in _alarms) {
      if (!alarm.isEnabled) continue;
      if (alarm.hour != now.hour || alarm.minute != now.minute) continue;
      if (!AlarmRepeat.repeatsOnWeekday(alarm.repeatDaysMask, now.weekday)) continue;

      if (alarm.lastFiredAt != null) {
        final last = _truncateToMinute(alarm.lastFiredAt!);
        if (last == nowMinute) continue; // already fired this minute
      }

      if (alarm.repeatDaysMask == 0) {
        await _fireOneShot(alarm, now);
      } else {
        await _fireRepeating(alarm, now);
      }
    }
  }

  Future<void> _fireRepeating(Alarm alarm, DateTime now) async {
    await _play(alarm.soundPath);
    await _service.updateLastFired(alarm.id, now);
  }

  Future<void> _fireOneShot(Alarm alarm, DateTime now) async {
    await _play(alarm.soundPath);
    await _service.disableAfterOneShot(alarm.id, now);
  }

  Future<void> _play(String soundPath) async {
    final file = File(soundPath);
    if (!await file.exists()) return;

    // Alarm playback is temporarily disabled on desktop until a stable
    // cross-platform audio implementation is introduced.
  }

  Future<void> testPlay(String soundPath) => _play(soundPath);
}
