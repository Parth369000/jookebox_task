import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (status.isDenied || status.isRestricted) {
        await Permission.notification.request();
      }
      final android =
          _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      if (android != null) {
        try {
          await android.deleteNotificationChannel('reminders_channel_loud_v2');
        } catch (_) {}
        await android.createNotificationChannel(
          AndroidNotificationChannel(
            'reminders_channel_loud_v2',
            'Reminders (Loud)',
            description: 'Reminders with sound & vibration - HIGH PRIORITY',
            importance: Importance.max,
            playSound: true,
            sound: const RawResourceAndroidNotificationSound('chime'),
            vibrationPattern: Int64List.fromList([0, 400, 200, 400, 200, 400]),
            enableVibration: true,
            showBadge: true,
            enableLights: true,
            ledColor: const ui.Color.fromARGB(255, 255, 0, 0),
          ),
        );
      }
    }
  }

  NotificationDetails get details => NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders_channel_loud_v2',
      'Reminders (Loud)',
      channelDescription: 'Reminders with sound & vibration',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      audioAttributesUsage: AudioAttributesUsage.notification,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([
        0,
        400,
        200,
        400,
        200,
        400,
        200,
        400,
      ]),
      sound: RawResourceAndroidNotificationSound('chime'),
      category: AndroidNotificationCategory.reminder,
      showWhen: true,
      fullScreenIntent: false,
      timeoutAfter: 10000,
      autoCancel: true,
      ongoing: false,
      onlyAlertOnce: true,
      visibility: NotificationVisibility.public,
    ),
    iOS: const DarwinNotificationDetails(
      presentSound: true,
      sound: 'default',
      presentAlert: true,
      presentBadge: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    ),
  );

  FlutterLocalNotificationsPlugin get plugin => _plugin;
}
