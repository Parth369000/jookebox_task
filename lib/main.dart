import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'reminders/models/reminder.dart';
import 'reminders/services/notification_service.dart';
import 'reminders/utils/time_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  // Ensure tz.local matches device timezone
  try {
    final String localTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTz));
  } catch (_) {
    // Fallback to UTC if timezone lookup fails
    tz.setLocalLocation(tz.getLocation('UTC'));
  }
  runApp(const ReminderApp());
}

class ReminderApp extends StatelessWidget {
  const ReminderApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reminder',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const ReminderHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ReminderHome extends StatefulWidget {
  const ReminderHome({super.key});
  @override
  State<ReminderHome> createState() => _ReminderHomeState();
}

class _ReminderHomeState extends State<ReminderHome> {
  final _notifications = NotificationService.instance;

  final _days = const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  final _activities = const [
    'Wake up',
    'Go to gym',
    'Breakfast',
    'Meetings',
    'Lunch',
    'Quick nap',
    'Go to library',
    'Dinner',
    'Go to sleep',
  ];

  String _day = 'Monday';
  TimeOfDay _selectedTime = const TimeOfDay(hour: 7, minute: 0);
  String _activity = 'Wake up';

  final List<Reminder> _reminders = [];
  final List<CompletedReminder> _completed = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Skip plugin initialization in test environment to avoid platform interface errors
    final bool isTestEnvironment =
        Platform.environment['FLUTTER_TEST'] == 'true';
    if (!isTestEnvironment) {
      _notifications.init();
    }
    // Periodically refresh to move items from upcoming to completed
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _rolloverDueReminders();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  NotificationDetails get _details => _notifications.details;

  String _pad(int n) => pad2(n);

  tz.TZDateTime _nextWeeklyInstance(int weekday, int hour, int minute) =>
      nextWeeklyInstance(weekday, hour, minute);

  // Also expose a pure local DateTime for UI bookkeeping
  DateTime _nextWeeklyLocalDateTime(int weekday, int hour, int minute) =>
      nextWeeklyLocalDateTime(weekday, hour, minute);

  Future<void> _scheduleReminder(Reminder r) async {
    final weekdayIndex = _days.indexOf(r.day) + 1; // Mon=1..Sun=7
    final first = _nextWeeklyInstance(weekdayIndex, r.hour, r.minute);

    // Cancel any existing notification with the same ID
    await _notifications.plugin.cancel(r.id);

    // Schedule a single notification at the exact local time
    await _notifications.plugin.zonedSchedule(
      r.id,
      r.activity,
      '${r.day} • ${_pad(r.hour)}:${_pad(r.minute)}',
      first,
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      // one-shot (non-repeating)
    );
  }

  List<Reminder> _upcomingReminders() {
    final now = DateTime.now();
    return _reminders.where((r) => r.scheduledAt.isAfter(now)).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  List<CompletedReminder> _completedReminders() {
    return _completed.toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  }

  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _cancel(int id) async {
    await _notifications.plugin.cancel(id);
    setState(() => _reminders.removeWhere((e) => e.id == id));
  }

  void _rolloverDueReminders() {
    final DateTime now = DateTime.now();
    bool changed = false;
    // Walk a copy to allow removals while iterating
    for (final r in List<Reminder>.from(_reminders)) {
      if (!r.scheduledAt.isAfter(now)) {
        _completed.add(
          CompletedReminder(
            activity: r.activity,
            day: r.day,
            hour: r.hour,
            minute: r.minute,
            occurredAt: r.scheduledAt,
          ),
        );
        _reminders.remove(r); // remove from upcoming once completed
        changed = true;
      }
    }
    if (changed && _completed.length > 200) {
      _completed.removeRange(0, _completed.length - 200);
    }
  }

  Future<void> _add() async {
    try {
      final r = Reminder(
        id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        day: _day,
        hour: _selectedTime.hour,
        minute: _selectedTime.minute,
        activity: _activity,
        scheduledAt: _nextWeeklyLocalDateTime(
          _days.indexOf(_day) + 1,
          _selectedTime.hour,
          _selectedTime.minute,
        ),
      );
      await _scheduleReminder(r);
      setState(() {
        _reminders.add(r);
        _rolloverDueReminders();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Scheduled: ${r.activity} on ${r.day} at ${_pad(_selectedTime.hour)}:${_pad(_selectedTime.minute)}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error scheduling reminder: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reminder App')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _box(
                'Day of the week',
                DropdownButton<String>(
                  value: _day,
                  isExpanded: true,
                  items:
                      _days
                          .map(
                            (d) => DropdownMenuItem(value: d, child: Text(d)),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => _day = v!),
                ),
              ),
              _box(
                'Time',
                InkWell(
                  onTap: () async {
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: _selectedTime,
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            timePickerTheme: TimePickerThemeData(
                              backgroundColor:
                                  Theme.of(context).colorScheme.surface,
                              hourMinuteTextColor:
                                  Theme.of(context).colorScheme.onSurface,
                              hourMinuteColor:
                                  Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                              dialBackgroundColor:
                                  Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                              dialHandColor:
                                  Theme.of(context).colorScheme.primary,
                              dialTextColor:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null && picked != _selectedTime) {
                      setState(() {
                        _selectedTime = picked;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        Icon(
                          Icons.access_time,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _box(
                'Activity',
                DropdownButton<String>(
                  value: _activity,
                  isExpanded: true,
                  items:
                      _activities
                          .map(
                            (a) => DropdownMenuItem(value: a, child: Text(a)),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => _activity = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.schedule),
            label: const Text('Schedule'),
          ),
          const SizedBox(height: 16),
          Text('Upcoming', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._upcomingReminders().map(
            (r) => Card(
              child: ListTile(
                title: Text(r.activity),
                subtitle: Text('${r.day} • ${_formatDate(r.scheduledAt)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _cancel(r.id),
                ),
              ),
            ),
          ),
          if (_upcomingReminders().isEmpty)
            const Text('No upcoming reminders.'),
          const SizedBox(height: 16),
          Text('Completed', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._completedReminders().map(
            (r) => Card(
              child: ListTile(
                title: Text(r.activity),
                subtitle: Text('${r.day} : ${_formatDate(r.occurredAt)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() => _completed.remove(r)),
                ),
              ),
            ),
          ),
          if (_completedReminders().isEmpty)
            const Text('No completed reminders yet.'),
        ],
      ),
    );
  }

  Widget _box(String label, Widget child) {
    return SizedBox(
      width: 260,
      child: InputDecorator(
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
        ).copyWith(labelText: label),
        child: child,
      ),
    );
  }
}

