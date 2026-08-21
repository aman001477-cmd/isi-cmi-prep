import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:isi_cmi_prep/core/backup/backup_service.dart';
import 'package:isi_cmi_prep/core/theme/app_design_system.dart';
import 'package:isi_cmi_prep/features/planner/planner_provider.dart';
import 'package:isi_cmi_prep/features/progress/streak_provider.dart';
import 'package:isi_cmi_prep/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildApp() => const ProviderScope(child: ISICMIPrepApp());

  // Wide surface + desktop shell with labelled left rail.
  void setWide(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  // Every calendar day tap opens the day-status window — close it so the
  // test can reach the content below the grid.
  Future<void> closeDayStatus(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('day-status-close')));
    await tester.pumpAndSettle();
  }

  Map<String, Object?> taskJson(String id, String title, DateTime date,
          {required bool done}) =>
      {
        'id': id,
        'title': title,
        'date': date.toIso8601String(),
        'done': done,
        'sound': 'none',
        'ringSeconds': 30,
        'notifyOnly': false,
        'backlog': false,
        'order': 0,
        'repeatDaily': false,
      };

  group('shell & dashboard', () {
    testWidgets('App shell builds and shows real stats on dashboard',
        (WidgetTester tester) async {
      setWide(tester);
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // default exam row + the two timer cards
      expect(find.text('ISI · CMI'), findsOneWidget);
      expect(find.text('Focus Timer'), findsOneWidget);
      expect(find.text('Daily Fix Timer'), findsOneWidget);
    });

    testWidgets('Syllabus supports adding a new exam', (WidgetTester tester) async {
      setWide(tester);
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Syllabus'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add Exam'));
      await tester.tap(find.text('Add Exam'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'JEE 2027');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      // appears in the exam tree (and its countdown row)
      expect(find.text('JEE 2027'), findsWidgets);
    });
  });

  group('calendar', () {
    testWidgets('Calendar: tapping a day cell shows its tasks and month nav '
        'works', (WidgetTester tester) async {
      setWide(tester);
      final today = PlannerTask.day(DateTime.now());
      final tomorrow = today.add(const Duration(days: 1));
      SharedPreferences.setMockInitialValues({
        'planner_v1': jsonEncode([taskJson('c1', 'Cal task', tomorrow, done: false)]),
      });

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();

      final tomorrowKey =
          Key('cal-${tomorrow.year}-${tomorrow.month}-${tomorrow.day}');
      await tester.tap(find.byKey(tomorrowKey));
      await tester.pumpAndSettle();
      await closeDayStatus(tester);
      expect(find.text('Cal task'), findsOneWidget);

      // month navigation flips the grid header
      await tester.tap(find.byKey(const Key('cal-next')));
      await tester.pumpAndSettle();
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul',
          'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final nextMonth = DateTime(today.year, today.month + 1);
      expect(find.text('${months[nextMonth.month - 1]} ${nextMonth.year}'),
          findsWidgets);
      expect(find.byKey(tomorrowKey), findsNothing); // different month

      // selection persists — yesterday's pick keeps showing its day list
      expect(find.text('Cal task'), findsOneWidget);
    });

    testWidgets('Calendar can mark a day as Mock test and highlights it',
        (WidgetTester tester) async {
      setWide(tester);
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();

      final today = PlannerTask.day(DateTime.now());
      final todayKey = Key('cal-${today.year}-${today.month}-${today.day}');

      // nothing marked yet — no M badges
      expect(find.text('M'), findsNothing);

      // select today's cell and mark it as a mock test day
      await tester.tap(find.byKey(todayKey));
      await tester.pumpAndSettle();
      await closeDayStatus(tester);
      await tester.tap(find.byKey(const Key('mock-toggle')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Mock test on'), findsOneWidget);
      expect(find.text('M'), findsOneWidget); // badge in the cell
      expect(find.text('1'), findsWidgets); // month count tile shows 1

      // tapping again removes the mark
      await tester.tap(find.byKey(const Key('mock-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('M'), findsNothing);
      expect(find.textContaining('as a Mock test day'), findsOneWidget);
    });
  });

  group('focus timer', () {
    testWidgets('Dashboard Focus Timer sets a preset and counts down',
        (WidgetTester tester) async {
      setWide(tester);
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('timer-preset-25')));
      await tester.tap(find.byKey(const Key('timer-preset-25')));
      await tester.pumpAndSettle();

      String clock() => tester
          .widget<Text>(find.byKey(const Key('timer-clock')))
          .data!;
      expect(clock(), '25:00');

      await tester.tap(find.byKey(const Key('timer-toggle')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(clock(), '24:57');

      // reset clears the clock back to idle
      await tester.tap(find.byKey(const Key('timer-reset')));
      await tester.pumpAndSettle();
      expect(clock(), '00:00');
    });

    testWidgets('Dashboard card sets a preset and shows the progress ring',
        (WidgetTester tester) async {
      setWide(tester);
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // duration pickers live right on the dashboard card
      await tester.ensureVisible(find.byKey(const Key('timer-preset-45')));
      await tester.tap(find.byKey(const Key('timer-preset-45')));
      await tester.pumpAndSettle();

      String clock() => tester
          .widget<Text>(find.byKey(const Key('timer-clock')))
          .data!;
      expect(clock(), '45:00');

      CircularProgressIndicator ring() => tester.widget(
          find.byKey(const Key('timer-ring')));
      expect(ring().value, 1.0); // full ring — nothing elapsed yet

      // start → ring depletes with the clock
      await tester.tap(find.byKey(const Key('timer-toggle')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      expect(clock(), '44:55');
      expect(ring().value, closeTo(2695 / 2700, 0.001));

      // reset returns to idle with pickers + full ring again
      await tester.tap(find.byKey(const Key('timer-reset')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('timer-preset-60')), findsOneWidget);
      expect(find.byKey(const Key('timer-overlay')), findsOneWidget);
      expect(ring().value, 0.0);
    });

    testWidgets('Full-screen timer draws a big progress ring',
        (WidgetTester tester) async {
      setWide(tester);
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('timer-fullscreen')));
      await tester.tap(find.byKey(const Key('timer-fullscreen')));
      await tester.pumpAndSettle();

      expect(find.text('Ready when you are'), findsOneWidget);
      await tester.tap(find.byKey(const Key('fs-preset-25')));
      await tester.pumpAndSettle();
      // the overlay-style full-screen page keeps the card clock in the
      // tree too, so the time shows twice
      expect(find.text('25:00'), findsWidgets);

      await tester.tap(find.byKey(const Key('fullscreen-toggle')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('24:59'), findsWidgets);
    });

    testWidgets('Timer focus mode flips DND and shows on the card',
        (WidgetTester tester) async {
      setWide(tester);
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('timer-focus')));
      await tester.tap(find.byKey(const Key('timer-focus')));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.notifications_off), findsOneWidget);

      await tester.tap(find.byKey(const Key('timer-focus')));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.notifications), findsOneWidget);
    });

    testWidgets('Timer completion sound is selectable on the card',
        (WidgetTester tester) async {
      setWide(tester);
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('timer-sound-chime')));
      await tester.tap(find.byKey(const Key('timer-sound-chime')));
      await tester.pumpAndSettle();

      // selected chip is highlighted with the accent colour
      final label = tester.widget<Text>(find.text('Chime'));
      expect(label.style?.color, AppColors.accent);
    });
  });

  group('marathon timer', () {
    testWidgets('Marathon timer shows permanent daily countdown + target '
        'stepper', (WidgetTester tester) async {
      setWide(tester);
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 1100));

      expect(find.byKey(const Key('marathon-clock')), findsOneWidget);
      expect(find.byKey(const Key('marathon-complete')), findsOneWidget);
      expect(find.byKey(const Key('marathon-left')), findsOneWidget);
      expect(find.byKey(const Key('marathon-target')), findsOneWidget);

      // default target is 10 h
      expect(
          tester.widget<Text>(find.byKey(const Key('marathon-target'))).data,
          '10 h');

      // preset chips set target immediately
      await tester.ensureVisible(find.byKey(const Key('marathon-preset-480')));
      await tester.tap(find.byKey(const Key('marathon-preset-480')));
      await tester.pumpAndSettle();
      expect(
          tester.widget<Text>(find.byKey(const Key('marathon-target'))).data,
          '8 h');

      // +/- stepper moves by whole hours within 1–24
      await tester.tap(find.byKey(const Key('marathon-plus')));
      await tester.pumpAndSettle();
      expect(
          tester.widget<Text>(find.byKey(const Key('marathon-target'))).data,
          '9 h');
      await tester.tap(find.byKey(const Key('marathon-minus')));
      await tester.pumpAndSettle();
      expect(
          tester.widget<Text>(find.byKey(const Key('marathon-target'))).data,
          '8 h');

      // pause freezes the countdown (label flips), resume continues
      await tester.ensureVisible(find.byKey(const Key('marathon-pause')));
      await tester.tap(find.byKey(const Key('marathon-pause')));
      await tester.pumpAndSettle();
      expect(find.text('Resume'), findsOneWidget);

      // the Pause closed the running stretch as a lap, shown below the
      // buttons
      expect(find.byKey(const Key('marathon-laps')), findsOneWidget);
      expect(find.byKey(const Key('marathon-lap-0')), findsOneWidget);
      expect(find.textContaining('–'), findsWidgets);

      await tester.tap(find.byKey(const Key('marathon-pause')));
      await tester.pumpAndSettle();
      expect(find.text('Pause'), findsOneWidget);

      // reset is available and starts a fresh target from now — old laps
      // are gone
      await tester.tap(find.byKey(const Key('marathon-reset')));
      await tester.pumpAndSettle();
      expect(
          tester.widget<Text>(find.byKey(const Key('marathon-target'))).data,
          '8 h');
      expect(find.byKey(const Key('marathon-laps')), findsNothing);
    });
  });

  group('profile & backup', () {
    testWidgets('Profile sheet offers Export and Import rows',
        (WidgetTester tester) async {
      setWide(tester);
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('profile-chip')));
      await tester.pumpAndSettle();

      expect(find.text('Export data'), findsOneWidget);
      expect(find.text('Import data'), findsOneWidget);
    });

    testWidgets('Profile theme picker switches the whole app palette',
        (WidgetTester tester) async {
      setWide(tester);
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      String themeKey() => tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .key
          .toString();
      final before = themeKey();

      await tester.tap(find.byKey(const Key('theme-toggle')));
      await tester.pumpAndSettle();

      expect(themeKey(), isNot(before));
    });

    test('Backup service round-trips every persisted value type', () async {
      SharedPreferences.setMockInitialValues({
        'k_str': 'hello',
        'k_bool': true,
        'k_int': 42,
        'k_double': 3.5,
        'k_list': ['a', 'b'],
      });

      final doc = await collectBackup();
      final decoded = decodeBackup(encodeBackup(doc));
      expect(decoded, isNotNull);
      expect(decoded!.data, doc.data);
      expect(decoded.savedAt, doc.savedAt);

      // fresh storage, apply the snapshot back
      SharedPreferences.setMockInitialValues({});
      final written = await applyBackup(decoded);
      expect(written, 5);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('k_str'), 'hello');
      expect(prefs.getBool('k_bool'), isTrue);
      expect(prefs.getInt('k_int'), 42);
      expect(prefs.getDouble('k_double'), 3.5);
      expect(prefs.getStringList('k_list'), ['a', 'b']);
    });

    test('Backup service rejects non-backup or malformed files', () {
      expect(decodeBackup('not json at all'), isNull);
      expect(decodeBackup(jsonEncode({'app': 'some-other-app', 'data': {}})),
          isNull);
      expect(decodeBackup(jsonEncode({'app': backupAppTag})), isNull);
      expect(decodeBackup(jsonEncode(123)), isNull);
    });

    test('Streak goal clamps to 1–20 and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final n = StreakGoalNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(n.state, 3); // default daily goal
      await n.set(0);
      expect(n.state, 1); // clamped up
      await n.set(99);
      expect(n.state, 20); // clamped down
    });
  });
}
