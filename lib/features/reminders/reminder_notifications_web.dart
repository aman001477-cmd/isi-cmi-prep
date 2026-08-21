import 'reminder_model.dart';

/// Web has no system notifications — the in-app popup is the mechanism.
Future<void> initImpl() async {}

Future<void> scheduleImpl(Reminder r) async {}

Future<void> cancelImpl(String id) async {}

Future<void> scheduleDailyPlanImpl(String body,
    {int hour = 21, int minute = 0}) async {}

Future<void> cancelDailyPlanImpl() async {}

void setCustomNotificationSoundPathImpl(String? path) {}
