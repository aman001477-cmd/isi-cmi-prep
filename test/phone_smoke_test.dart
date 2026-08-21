import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:isi_cmi_prep/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: ISICMIPrepApp()));
    await tester.pumpAndSettle();
  }

  Future<void> goTo(WidgetTester tester, IconData icon) async {
    await tester.tap(find.byIcon(icon).last);
    await tester.pumpAndSettle();
  }

  testWidgets('phone portrait: no overflow on any page', (tester) async {
    await pumpAt(tester, const Size(390, 780));
    expect(tester.takeException(), isNull, reason: 'home');

    await goTo(tester, Icons.fact_check_outlined); // Syllabus
    expect(tester.takeException(), isNull, reason: 'syllabus');
    await tester.drag(find.byType(SingleChildScrollView).first,
        const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'syllabus scroll');

    await goTo(tester, Icons.event_outlined); // Planner
    expect(tester.takeException(), isNull, reason: 'planner');

    await goTo(tester, Icons.event_repeat_outlined); // Schedule
    expect(tester.takeException(), isNull, reason: 'schedule');
    await tester.drag(find.byType(SingleChildScrollView).first,
        const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'schedule scroll');

    await tester.tap(find.byKey(const Key('profile-chip')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'profile sheet');
    await tester.drag(find.byType(SingleChildScrollView).last,
        const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'profile scroll');
  });

  testWidgets('small phone: top bar + pages fit', (tester) async {
    await pumpAt(tester, const Size(320, 568));
    expect(tester.takeException(), isNull, reason: 'small home');

    await goTo(tester, Icons.event_repeat_outlined); // Schedule
    expect(tester.takeException(), isNull, reason: 'small schedule');

    await goTo(tester, Icons.event_outlined); // Planner
    expect(tester.takeException(), isNull, reason: 'small planner');

    await tester.tap(find.byKey(const Key('profile-chip')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'small profile');
  });
}
