class Reminder {
  final int id;
  final String day;
  final int hour;
  final int minute;
  final String activity;
  final DateTime scheduledAt;
  const Reminder({
    required this.id,
    required this.day,
    required this.hour,
    required this.minute,
    required this.activity,
    required this.scheduledAt,
  });
}

class CompletedReminder {
  final String activity;
  final String day;
  final int hour;
  final int minute;
  final DateTime occurredAt;
  const CompletedReminder({
    required this.activity,
    required this.day,
    required this.hour,
    required this.minute,
    required this.occurredAt,
  });
}
