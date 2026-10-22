import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class DailyNotificationService {
  DailyNotificationService._();

  static final instance = DailyNotificationService._();
  static const _notificationId = 800;

  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone));

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
  }

  Future<bool> scheduleDailyAtEight() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final notificationsGranted =
        await android?.requestNotificationsPermission();
    final exactAlarmsGranted = await android?.requestExactAlarmsPermission();

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final iosGranted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    if (notificationsGranted == false ||
        exactAlarmsGranted == false ||
        iosGranted == false) {
      return false;
    }

    final now = tz.TZDateTime.now(tz.local);
    var firstAlarm = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      8,
    );
    if (!firstAlarm.isAfter(now)) {
      firstAlarm = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + 1,
        8,
      );
    }

    await _plugin.zonedSchedule(
      _notificationId,
      'Barbería YASSER',
      '💈 Barbería YASSER está en servicio',
      firstAlarm,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'yasser_opening',
          'Horario de servicio',
          channelDescription: 'Aviso diario de apertura de YASSER',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    return true;
  }
}
