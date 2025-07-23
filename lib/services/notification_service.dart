import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _notifications.initialize(settings);
  }

  Future<void> requestPermissions() async {
    await _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    await _notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> scheduleMonthlyReminder(String provider) async {
    await _notifications.cancelAll(); // Clear existing reminders
    await requestPermissions();

    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate;

    if (provider == 'DUOS') {
      final lastDayOfMonth = tz.TZDateTime(tz.local, now.year, now.month + 1, 0);
      scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, lastDayOfMonth.day - 2, 10); // 10 AM on the 3rd to last day
    } else if (provider == 'Handicapformidlingen') {
      scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, 13, 10); // 10 AM on the 13th
    } else {
      return; // No provider selected
    }

    // If the scheduled date is in the past for the current month, schedule it for the next month
    if (scheduledDate.isBefore(now)) {
      scheduledDate = tz.TZDateTime(tz.local, now.year, now.month + 1, scheduledDate.day, 10);
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'monthly_reminder_channel',
      'Monthly Reminders',
      channelDescription: 'Channel for monthly SPS hour registration reminders',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.zonedSchedule(
      0,
      'SPS Timer Reminder',
      'Husk at registrere dine SPS-timer for denne måned.',
      scheduledDate,
      notificationDetails,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }

  Future<void> sendTestNotification() async {
    await requestPermissions();
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      channelDescription: 'Channel for test notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);
    await _notifications.show(
      1,
      'Test Notification',
      'This is a test notification.',
      notificationDetails,
    );
  }
}
