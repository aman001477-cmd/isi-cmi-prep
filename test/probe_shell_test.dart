import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:isi_cmi_prep/main.dart';

void main() {
  testWidgets('probe what renders after settle', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: ISICMIPrepApp()));
    await tester.pumpAndSettle();

    final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '');
    // ignore: avoid_print
    print('on screen: ${texts.where((s) => s.isNotEmpty).take(25).join(' | ')}');
    // ignore: avoid_print
    print('login page: ${find.byKey(const Key('login-page')).evaluate().length}');
    // ignore: avoid_print
    print('shell: ${find.text('Dashboard').evaluate().length}');
  });
}