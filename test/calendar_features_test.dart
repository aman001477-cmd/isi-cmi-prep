import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:isi_cmi_prep/features/planner/marker_provider.dart';
import 'package:isi_cmi_prep/features/planner/mock_test_provider.dart';
import 'package:isi_cmi_prep/features/planner/planner_provider.dart';
import 'package:isi_cmi_prep/main.dart';

void setWide(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget buildApp() => const ProviderScope(child: ISICMIPrepApp());

Future<void> openCalendar(WidgetTester tester) async {
  // let the app settle past the auth gate/launch before navigating
  await tester.pumpAndSettle();
  await tester.tap(find.text('Calendar'));
  await tester.pumpAndSettle();
}

Future<void> selectToday(WidgetTester tester) async {
  final today = DateTime.now();
  await tester.tap(find.byKey(
      Key('cal-${today.year}-${today.month}-${today.day}')));
  await tester.pumpAndSettle();
  await closeDayStatus(tester);
}

Future<void> closeDayStatus(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('day-status-close')));
  await tester.pumpAndSettle();
}

Map<String, Object?> taskJson(
        String id, String title, DateTime date,
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

Future<String> storedReminders() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('reminders_v1') ?? '';
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('MockTestNotifier stores and clears an alarm per day', () async {
    final notifier = MockTestNotifier();
    final d = DateTime(2026, 8, 5);
    final d2 = DateTime(2026, 8, 12);

    await notifier.toggle(d);
    await notifier.setAlarm(d, const MockAlarm(hour: 14, minute: 30));
    expect(notifier.alarmFor(d)!.hour, 14);
    expect(notifier.alarmFor(d)!.minute, 30);
    expect(notifier.alarmFor(d2), isNull);

    await notifier.clearAlarm(d);
    expect(notifier.alarmFor(d), isNull);
  });

  test('MarkersNotifier creates, stamps and removes markers', () async {
    final notifier = MarkersNotifier();
    final d = DateTime(2026, 8, 5);

    final id = notifier.addMarker('Revision', appMarkerColors[2]);
    expect(notifier.markerById(id)!.name, 'Revision');
    expect(notifier.markerAt(d), isNull);

    await notifier.assign(
        d, MarkerAssignment(markerId: id, alarmHour: 10, alarmMinute: 0));
    expect(notifier.markerAt(d)!.name, 'Revision');
    expect(notifier.assignmentAt(d)!.hasAlarm, isTrue);

    final removed = notifier.removeMarker(id);
    expect(removed.length, 1);
    expect(notifier.markerAt(d), isNull);
    expect(notifier.markerById(id), isNull);
  });

  testWidgets('Mock test day gets an alarm which fires a reminder',
      (tester) async {
    setWide(tester);
    await tester.pumpWidget(buildApp());
    await openCalendar(tester);
    await selectToday(tester);

    // mark the day
    await tester.tap(find.byKey(const Key('mock-toggle')));
    await tester.pumpAndSettle();

    // set an alarm through the dialog
    await tester.tap(find.byKey(const Key('mock-alarm')));
    await tester.pumpAndSettle();
    expect(find.text('Mock test alarm'), findsOneWidget);
    await tester.tap(find.byKey(const Key('mock-time-h-up')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mock-alarm-save')));
    await tester.pumpAndSettle();

    // the chip shows the picked time (10:00 after one up-tap from 9)
    expect(find.text('10:00'), findsOneWidget);
    expect(await storedReminders(), contains('Mock test'));

    // removing the alarm removes the reminder too
    await tester.tap(find.byKey(const Key('mock-alarm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mock-alarm-remove')));
    await tester.pumpAndSettle();
    expect(await storedReminders(), isNot(contains('Mock test')));
  });

  testWidgets('Dashboard: reminders + today mock alarm show live countdowns',
      (tester) async {
    setWide(tester);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    SharedPreferences.setMockInitialValues({
      'reminders_v1': jsonEncode([
        {
          'id': 'r1',
          'title': 'Solve DSA paper',
          'at': tomorrow.add(const Duration(hours: 10)).toIso8601String(),
        }
      ]),
      'mock_days_v1': [mockDayKey(today)],
      'mock_alarms_v1': jsonEncode({
        mockDayKey(today): {'hour': 23, 'minute': 30, 'reminderId': null},
      }),
    });

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // the reminder row ticks down with days/hours/min/sec
    expect(find.text('Solve DSA paper'), findsOneWidget);
    expect(find.text('event in'), findsOneWidget);

    // today's mock shows its alarm time and a countdown to it
    expect(find.textContaining('TODAY ·'), findsOneWidget);
    expect(find.text('Mock test'), findsWidgets);
    expect(find.byKey(const Key('ticking')), findsWidgets);
  });

  testWidgets('Day status: date with pending tasks shows what is left to '
      'complete for green', (tester) async {
    setWide(tester);
    final today = PlannerTask.day(DateTime.now());
    SharedPreferences.setMockInitialValues({
      'planner_v1': jsonEncode([
        taskJson('g1', 'Revise maths', today, done: true),
        taskJson('g2', 'Read physics', today, done: true),
        taskJson('g3', 'Mock paper', today, done: false),
      ]),
    });

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await openCalendar(tester);

    // date cell is NOT green yet (2 of 3 done) — no check badge
    final cell = find.byKey(Key(
        'cal-${today.year}-${today.month}-${today.day}'));
    expect(find.descendant(of: cell, matching: find.byIcon(Icons.check)),
        findsNothing);

    // tapping opens the day-status window with the remaining task
    await tester.tap(cell);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('day-status')), findsOneWidget);
    expect(find.byKey(const Key('day-status-pending-head')), findsOneWidget);
    expect(find.text('2 of 3 tasks done today'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('day-status')),
        matching: find.text('Mock paper'),
      ),
      findsOneWidget,
    );
    await closeDayStatus(tester);
  });

  testWidgets('Day status: complete day turns green with a check badge',
      (tester) async {
    setWide(tester);
    final today = PlannerTask.day(DateTime.now());
    SharedPreferences.setMockInitialValues({
      'planner_v1': jsonEncode([
        taskJson('g1', 'Revise maths', today, done: true),
        taskJson('g2', 'Read physics', today, done: true),
        taskJson('g3', 'Mock paper', today, done: true),
      ]),
    });

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await openCalendar(tester);

    final cell = find.byKey(Key(
        'cal-${today.year}-${today.month}-${today.day}'));
    expect(find.descendant(of: cell, matching: find.byIcon(Icons.check)),
        findsOneWidget);

    await tester.tap(cell);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('day-status')), findsOneWidget);
    expect(find.byKey(const Key('day-status-green')), findsOneWidget);
    expect(find.text('3 of 3 tasks done today'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('day-status')),
        matching: find.text('Revise maths'),
      ),
      findsOneWidget,
    );
    await closeDayStatus(tester);
  });

  testWidgets('Markers: create an option, mark a day, alarm, unmark',
      (tester) async {
    setWide(tester);
    await tester.pumpWidget(buildApp());
    await openCalendar(tester);

    // create the option via settings
    await tester.ensureVisible(find.byKey(const Key('marker-settings')));
    await tester.tap(find.byKey(const Key('marker-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('marker-manager-new')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('marker-name')), 'Exam prep');
    await tester.tap(find.byKey(const Key('marker-color-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('marker-save')));
    await tester.pumpAndSettle();

    // the "Mark <day> as Exam prep" row appears — tap it to stamp today
    await selectToday(tester);
    final row = find.textContaining('as Exam prep');
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.textContaining('Marked'), findsOneWidget);
    expect(await storedReminders(), isNot(contains('Exam prep')));

    // add an alarm through the chip → dialog
    await tester.tap(find.byIcon(Icons.alarm_add));
    await tester.pumpAndSettle();
    expect(find.textContaining('Apply marker'), findsOneWidget);
    await tester.tap(find.byKey(const Key('marker-alarm-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('marker-apply')));
    await tester.pumpAndSettle();

    expect(await storedReminders(), contains('Exam prep'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('calendar_markers_v1'), contains('Exam prep'));

    // cell highlights with the marker's first letter
    final today = DateTime.now();
    final cell = find.descendant(
      of: find.byKey(
          Key('cal-${today.year}-${today.month}-${today.day}')),
      matching: find.text('E'),
    );
    expect(cell, findsOneWidget);

    // tapping the row again unmarks — assignment + reminder gone
    await tester.tap(find.textContaining('Marked'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Marked'), findsNothing);
    expect(await storedReminders(), isNot(contains('Exam prep')));
  });
}