import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isi_cmi_prep/core/theme/app_logo.dart';

/// Renders the brand mark to PNG assets (launcher icons, in-app logo).
/// Run: flutter test test/render_logo_test.dart
void main() {
  Future<void> capture(
    WidgetTester tester,
    Widget child,
    String path,
  ) async {
    await tester.pumpWidget(RepaintBoundary(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: child,
      ),
    ));
    await tester.pump();
    final image =
        await captureImage(tester.element(find.byType(RepaintBoundary).first));
    await tester.runAsync(() async {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  testWidgets('render logo PNGs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await capture(
      tester,
      const AppLogo(size: 1024),
      'assets/logo/logo.png',
    );
    await capture(
      tester,
      const AppLogoGlyph(size: 1024),
      'assets/logo/logo_glyph.png',
    );
  });
}
