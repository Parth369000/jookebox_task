import 'package:timezone/timezone.dart' as tz;

String pad2(int n) => n.toString().padLeft(2, '0');

tz.TZDateTime nextWeeklyInstance(int weekday, int hour, int minute) {
  final now = DateTime.now();
  DateTime scheduled = DateTime(now.year, now.month, now.day, hour, minute);
  final addDays = (weekday - scheduled.weekday) % 7;
  scheduled = scheduled.add(Duration(days: addDays));
  if (!scheduled.isAfter(now))
    scheduled = scheduled.add(const Duration(days: 7));
  return tz.TZDateTime.from(scheduled, tz.local);
}

DateTime nextWeeklyLocalDateTime(int weekday, int hour, int minute) {
  final now = DateTime.now();
  DateTime scheduled = DateTime(now.year, now.month, now.day, hour, minute);
  final addDays = (weekday - scheduled.weekday) % 7;
  scheduled = scheduled.add(Duration(days: addDays));
  if (!scheduled.isAfter(now))
    scheduled = scheduled.add(const Duration(days: 7));
  return scheduled;
}

String formatDate(DateTime d) =>
    '${pad2(d.day)}/${pad2(d.month)}/${d.year} ${pad2(d.hour)}:${pad2(d.minute)}';
