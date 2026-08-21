import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:isi_cmi_prep/main.dart';

/// Regression guard for the Midnight theme: after switching to the dark
/// palette every visible text must resolve to a light (white-ish) colour.
/// Goes dark-brown > light text and catches const-cached stale styles.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('midnight: every visible Text is white-ish', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: ISICMIPrepApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('theme-toggle')));
    await tester.pumpAndSettle();

    final dark = <String>[];
    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      final context = tester.element(find.byWidget(t));
      final color =
          t.style?.color ?? DefaultTextStyle.of(context).style.color;
      if (color != null && color.computeLuminance() < 0.35) {
        dark.add('${t.data ?? '?'} -> $color');
      }
    }
    expect(dark, isEmpty, reason: 'non-white texts in midnight: $dark');
  });
}