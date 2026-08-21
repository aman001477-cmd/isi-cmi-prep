import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:isi_cmi_prep/features/planner/planner_provider.dart';
import 'package:isi_cmi_prep/features/syllabus/models.dart';
import 'package:isi_cmi_prep/features/syllabus/syllabus_provider.dart';
import 'package:isi_cmi_prep/main.dart';

void setWide(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget buildApp() => const ProviderScope(child: ISICMIPrepApp());

PlannerTask seedTask(String id, String title, DateTime date, {bool done = false}) =>
    PlannerTask(id: id, title: title, date: date, done: done);

Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Streak: consecutive goal days + today progress',
      (tester) async {
    setWide(tester);
    final today = PlannerTask.day(DateTime.now());
    SharedPreferences.setMockInitialValues({
      'streak_goal_v1': 2,
      'planner_v1': jsonEncode([
        seedTask('a', 'yesterday 1', today.subtract(const Duration(days: 1)),
            done: true).toJson(),
        seedTask('b', 'yesterday 2', today.subtract(const Duration(days: 1)),
            done: true).toJson(),
        seedTask('c', 'today 1', today, done: true).toJson(),
        seedTask('d', 'today 2', today, done: true).toJson(),
      ]),
    });
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();

    expect(find.text('🔥 2-day streak'), findsOneWidget);
    expect(find.text('Today: 2/2 tasks'), findsOneWidget);

    // per-day history rows
    expect(find.text('Daily history'), findsOneWidget);
    expect(find.text('2/2 tasks'), findsNWidgets(2)); // yesterday + today
  });

  testWidgets('Streak goal is selectable on the Stats card',
      (tester) async {
    setWide(tester);
    SharedPreferences.setMockInitialValues({'streak_goal_v1': 2});
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('streak-goal-up-card')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<Text>(find.byKey(const Key('streak-goal-value-card')))
            .data,
        '2');

    await tester.tap(find.byKey(const Key('streak-goal-up-card')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<Text>(find.byKey(const Key('streak-goal-value-card')))
            .data,
        '3');
    expect((await prefs()).getInt('streak_goal_v1'), 3);

    await tester.ensureVisible(find.byKey(const Key('streak-goal-down-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('streak-goal-down-card')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<Text>(find.byKey(const Key('streak-goal-value-card')))
            .data,
        '2');
    expect((await prefs()).getInt('streak_goal_v1'), 2);
  });

  testWidgets('Weekly stats card renders bars and delta text',
      (tester) async {
    setWide(tester);
    final today = PlannerTask.day(DateTime.now());
    SharedPreferences.setMockInitialValues({
      'planner_v1': jsonEncode([
        seedTask('a', 'today done', today, done: true).toJson(),
        seedTask('b', 'yesterday done',
            today.subtract(const Duration(days: 1)),
            done: true).toJson(),
      ]),
    });
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();

    expect(find.text('Weekly stats'), findsOneWidget);
    expect(find.text('2 tasks this week — first week tracked'),
        findsOneWidget);
  });

  testWidgets('Mock result: log score on a mock day, trend card appears',
      (tester) async {
    setWide(tester);
    final today = DateTime.now();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(
        'cal-${today.year}-${today.month}-${today.day}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('day-status-close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mock-toggle')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mock-result')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('mock-result-marks')), '42');
    await tester.enterText(find.byKey(const Key('mock-result-max')), '60');
    await tester.tap(find.byKey(const Key('mock-result-save')));
    await tester.pumpAndSettle();

    expect(find.text('42/60'), findsOneWidget);

    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();
    expect(find.text('Mock test trend'), findsOneWidget);
    expect(find.text('Avg 70% across 1 attempt'), findsOneWidget);
    expect(find.text('Mock test results'), findsOneWidget);
    expect(find.text('42/60 · 70%'), findsOneWidget);
  });

  testWidgets('Exam hero: set name + date, live countdown starts',
      (tester) async {
    setWide(tester);
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // empty state → set-up button
    expect(find.text('Exam countdown'), findsOneWidget);
    expect(find.byKey(const Key('exam-set')), findsOneWidget);

    await tester.tap(find.byKey(const Key('exam-set')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('exam-name')), 'ISI B.Math 2027');
    await tester.tap(find.byKey(const Key('exam-date-pick')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // date picker default = today+60
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('exam-save')));
    await tester.pumpAndSettle();

    // hero shows the name, the date and a ticking countdown
    expect(find.text('ISI B.Math 2027'), findsOneWidget);
    expect(find.byKey(const Key('exam-countdown')), findsOneWidget);
    expect(find.byKey(const Key('exam-clear')), findsOneWidget);

    final p = await prefs();
    final saved = jsonDecode(p.getString('pinned_exam_v1') ?? '{}');
    expect(saved['name'], 'ISI B.Math 2027');

    // clearing removes the countdown
    await tester.tap(find.byKey(const Key('exam-clear')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exam-set')), findsOneWidget);
    expect((await prefs()).getString('pinned_exam_v1'),
        isNot(contains('ISI B.Math')));
  });

  test('Spaced revision: DONE schedules 3 reminders, un-done cancels them',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    ExamNode? firstLeaf;
    void walk(ExamNode n) {
      if (firstLeaf != null) return;
      if (n.children.isEmpty) {
        firstLeaf = n;
        return;
      }
      for (final c in n.children) {
        walk(c);
      }
    }

    for (final r in container.read(syllabusProvider)) {
      walk(r);
    }
    final leaf = firstLeaf!;
    final notifier = container.read(syllabusProvider.notifier);

    await notifier.cycleStatus(leaf.id);
    await notifier.cycleStatus(leaf.id);
    await notifier.cycleStatus(leaf.id);
    await pumpEventQueue();

    var raw = (await prefs()).getString('reminders_v1') ?? '';
    var list = jsonDecode(raw) as List<dynamic>;
    expect(list.length, 3);
    for (final r in list) {
      expect((r as Map<String, Object?>)['title'],
          startsWith('Revision: '));
    }

    await notifier.cycleStatus(leaf.id); // done → notDone cancels
    await pumpEventQueue();
    raw = (await prefs()).getString('reminders_v1') ?? '';
    list = jsonDecode(raw) as List<dynamic>;
    expect(list, isEmpty);
  });

  testWidgets('Profile: daily goal stepper + daily plan notification toggle',
      (tester) async {
    setWide(tester);
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profile-chip')));
    await tester.pumpAndSettle();

    expect(find.text('Progress & goals'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('streak-goal-up')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('streak-goal-up')));
    await tester.pumpAndSettle();
    expect(
        tester.widget<Text>(find.byKey(const Key('streak-goal-value'))).data,
        '4');

    await tester.ensureVisible(find.byKey(const Key('plan-notif-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-notif-toggle')));
    await tester.pumpAndSettle();

    final p = await prefs();
    expect(p.getInt('streak_goal_v1'), 4);
    expect(p.getBool('plan_notif_v1'), true);
  });
}
