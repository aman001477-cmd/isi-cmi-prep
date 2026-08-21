import 'package:flutter_test/flutter_test.dart';

import 'package:isi_cmi_prep/features/reminders/reminder_model.dart';
import 'package:isi_cmi_prep/features/reminders/reminder_notifications.dart';

void main() {
  test('notification init + schedule completes on VM', () async {
    await initReminderNotifications();
    await scheduleReminderNotification(
        Reminder(id: 'x', title: 't', at: DateTime.now().add(const Duration(hours: 1))));
    await cancelReminderNotification('x');
  }, timeout: const Timeout(Duration(seconds: 30)));
}
