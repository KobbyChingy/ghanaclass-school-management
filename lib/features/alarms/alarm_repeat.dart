class AlarmRepeat {
  static const int monday = 1 << 0;
  static const int tuesday = 1 << 1;
  static const int wednesday = 1 << 2;
  static const int thursday = 1 << 3;
  static const int friday = 1 << 4;
  static const int saturday = 1 << 5;
  static const int sunday = 1 << 6;

  static const int weekdays = monday | tuesday | wednesday | thursday | friday;
  static const int weekend = saturday | sunday;
  static const int everyday = weekdays | weekend;

  static int bitForWeekday(int weekday) {
    // DateTime.weekday: Mon=1 .. Sun=7
    switch (weekday) {
      case 1:
        return monday;
      case 2:
        return tuesday;
      case 3:
        return wednesday;
      case 4:
        return thursday;
      case 5:
        return friday;
      case 6:
        return saturday;
      case 7:
        return sunday;
      default:
        return 0;
    }
  }

  static bool repeatsOnWeekday(int mask, int weekday) {
    if (mask == 0) return true; // one-time still valid for today
    final bit = bitForWeekday(weekday);
    return (mask & bit) != 0;
  }

  static String summary(int mask) {
    if (mask == 0) return 'One-time';
    if (mask == everyday) return 'Every day';
    if (mask == weekdays) return 'Weekdays';
    if (mask == weekend) return 'Weekend';

    final parts = <String>[];
    if ((mask & monday) != 0) parts.add('Mon');
    if ((mask & tuesday) != 0) parts.add('Tue');
    if ((mask & wednesday) != 0) parts.add('Wed');
    if ((mask & thursday) != 0) parts.add('Thu');
    if ((mask & friday) != 0) parts.add('Fri');
    if ((mask & saturday) != 0) parts.add('Sat');
    if ((mask & sunday) != 0) parts.add('Sun');
    return parts.join(', ');
  }
}
