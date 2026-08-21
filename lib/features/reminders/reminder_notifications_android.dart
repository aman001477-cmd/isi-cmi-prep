import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_model.dart';

/// Android implementation — exact-alarm scheduled notifications with
/// full-screen intent (popup + alarm sound), so a reminder rings even
/// when the app is closed. On desktop/VM every call silently no-ops.
final FlutterLocalNotificationsPlugin _plugin =
    FlutterLocalNotificationsPlugin();

bool _initialized = false;

/// User-picked alarm sound file (null = bundled chime).
String? _customSoundPath;

void setCustomNotificationSoundPathImpl(String? path) =>
    _customSoundPath = path;

int _idFor(String id) => id.hashCode & 0x7fffffff;

Future<void> initImpl() async {
  if (_initialized) return;
  // Widget tests have no plugin host — the platform channels would hang
  // the test run, so notifications stay dormant there.
  if (Platform.environment.containsKey('FLUTTER_TEST')) return;
  try {
    tz_data.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (_) {
      // keep the default (UTC) — only affects the schedule instant
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _initialized = true;
  } catch (_) {
    // plugin unavailable (widget tests / unsupported platform)
  }
}

AndroidFlutterLocalNotificationsPlugin? _android() =>
    _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

Future<void> scheduleImpl(Reminder r) async {
  await initImpl();
  if (!_initialized) return;
  try {
    await _android()?.requestNotificationsPermission();
    await _android()?.requestExactAlarmsPermission();
    await _android()?.requestFullScreenIntentPermission();
    final sound = _customSoundPath != null
        ? UriAndroidNotificationSound(_customSoundPath!)
        : const RawResourceAndroidNotificationSound('chime');
    final details = r.silent
        ? AndroidNotificationDetails(
            'reminders-silent',
            'Reminders (notification only)',
            channelDescription: 'Silent reminders — notify without sound',
            importance: Importance.defaultImportance,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
            playSound: false,
          )
        : AndroidNotificationDetails(
            'reminders',
            'Reminders',
            channelDescription: 'Scheduled reminders & alarms',
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            playSound: true,
            fullScreenIntent: true,
            sound: sound,
          );
    await _plugin.zonedSchedule(
      id: _idFor(r.id),
      title: r.silent ? 'Notification — Prep' : 'Reminder — Prep',
      body: r.title,
      scheduledDate: tz.TZDateTime.from(r.at, tz.local),
      notificationDetails: NotificationDetails(android: details),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  } catch (_) {
    // ignore — in-app popup still works
  }
}

Future<void> cancelImpl(String id) async {
  await initImpl();
  if (!_initialized) return;
  try {
    await _plugin.cancel(id: _idFor(id));
  } catch (_) {
    // ignore
  }
}

/// Daily-repeating summary of tomorrow's plan at the user-picked time
/// (default 21:00, silent, no alarm sound — it's an info preview, not
/// an alarm).
Future<void> scheduleDailyPlanImpl(String body,
    {int hour = 21, int minute = 0}) async {
  await initImpl();
  if (!_initialized) return;
  try {
    await _android()?.requestNotificationsPermission();
    await _android()?.requestExactAlarmsPermission();
    var at = tz.TZDateTime(tz.local, DateTime.now().year,
        DateTime.now().month, DateTime.now().day, hour, minute);
    if (at.isBefore(tz.TZDateTime.now(tz.local))) {
      at = at.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      id: _idFor('daily-plan'),
      title: 'Prep — Kal ka plan',
      body: body,
      scheduledDate: at,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'daily-plan',
          'Daily plan',
          channelDescription: 'Daily plan summary at 9 PM',
          importance: Importance.defaultImportance,
          priority: Priority.high,
          playSound: false,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  } catch (_) {
    // ignore — toggle keeps its state, nothing crashes
  }
}

Future<void> cancelDailyPlanImpl() async {
  await initImpl();
  if (!_initialized) return;
  try {
    await _plugin.cancel(id: _idFor('daily-plan'));
  } catch (_) {
    // ignore
  }
}
