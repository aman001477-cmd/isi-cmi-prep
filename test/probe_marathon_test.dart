import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:isi_cmi_prep/main.dart';

void main() {
  testWidgets('probe marathon keys', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: ISICMIPrepApp()));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1100));

    debugPrint('clock: ${find.byKey(const Key('marathon-clock')).evaluate().length}');
    debugPrint('complete: ${find.byKey(const Key('marathon-complete')).evaluate().length}');
    debugPrint('left: ${find.byKey(const Key('marathon-left')).evaluate().length}');
    debugPrint('target: ${find.byKey(const Key('marathon-target')).evaluate().length}');
    debugPrint('preset480: ${find.byKey(const Key('marathon-preset-480')).evaluate().length}');
    debugPrint('presets360: ${find.byKey(const Key('marathon-preset-360')).evaluate().length}');
    debugPrint('plus: ${find.byKey(const Key('marathon-plus')).evaluate().length}');
  });
}
