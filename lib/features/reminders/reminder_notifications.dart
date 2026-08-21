import 'reminder_notifications_android.dart'
    if (dart.library.html) 'reminder_notifications_web.dart' as impl;

import 'reminder_model.dart';

/// System notifications for reminders. On web these are no-ops — the
/// in-app popup (ReminderPopupHandler) covers the web path; on Android
/// they ring + pop up even when the app is closed.
Future<void> initReminderNotifications() => impl.initImpl();

Future<void> scheduleReminderNotification(Reminder r) =>
    impl.scheduleImpl(r);

Future<void> cancelReminderNotification(String id) => impl.cancelImpl(id);

/// Schedules the daily "tomorrow's plan" summary (Android only) at the
/// user-picked time (default 21:00).
Future<void> scheduleDailyPlanNotification(String body,
        {int hour = 21, int minute = 0}) =>
    impl.scheduleDailyPlanImpl(body, hour: hour, minute: minute);

/// Removes the daily plan notification (Android only).
Future<void> cancelDailyPlanNotification() => impl.cancelDailyPlanImpl();

/// Switches the Android notification alarm sound to the user's picked
/// audio file (null = bundled chime).
void setCustomNotificationSoundPath(String? path) =>
    impl.setCustomNotificationSoundPathImpl(path);
