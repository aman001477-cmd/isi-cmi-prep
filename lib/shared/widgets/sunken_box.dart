import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_design_system.dart';

/// Paints soft inner (sunken) shadows — Flutter's BoxShadow has no inset
/// support, so the engraved look is faked via blur + erase compositing:
///   1. clip to the rounded rect
///   2. draw a blurred splat offset toward the shadow corner
///   3. erase the interior so only the rim remains
class InsetShadowPainter extends CustomPainter {
  const InsetShadowPainter({
    this.blur = 7,
    this.spread = 5,
    this.cornerRadius = AppRadius.standard,
    this.light,
    this.dark,
    this.insetFactor = 1.0,
  });

  final double blur;
  final double spread;
  final double cornerRadius;
  final Color? light;
  final Color? dark;
  final double insetFactor;

  @override
  void paint(Canvas canvas, Size size) {
    final light = this.light ?? AppColors.shadowLight;
    final dark = this.dark ?? AppColors.shadowDark;
    final bounds = Offset.zero & size;
    final clamp = math.min(size.width, size.height) * 0.5;
    final r = math.min(cornerRadius, math.max(0.0, clamp));
    final clip = RRect.fromRectAndRadius(bounds, Radius.circular(r));

    void corner({required Offset dir, required Color color}) {
      final delta = dir * (spread * insetFactor);
      final shifted = bounds.shift(delta);
      canvas.saveLayer(bounds, Paint());
      canvas.clipRRect(clip);
      canvas.drawRect(
        shifted,
        Paint()
          ..color = color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
      );
      final eraseDeflate = spread + blur;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          bounds.deflate(eraseDeflate),
          Radius.circular(math.max(0.0, r - eraseDeflate)),
        ),
        Paint()..blendMode = BlendMode.clear,
      );
      canvas.restore();
    }

    corner(dir: const Offset(1, 1), color: dark);
    corner(dir: const Offset(-1, -1), color: light);
  }

  @override
  bool shouldRepaint(covariant InsetShadowPainter old) =>
      old.blur != blur ||
      old.spread != spread ||
      old.cornerRadius != cornerRadius ||
      old.light != light ||
      old.dark != dark ||
      old.insetFactor != insetFactor;
}

/// Box that looks engraved into the canvas — permanent sunken state
/// (inputs, wells, active toggles).
class SunkenBox extends StatelessWidget {
  const SunkenBox({
    super.key,
    required this.child,
    this.radius = AppRadius.standard,
    this.color,
    this.padding,
    this.intensity = 1.0,
  });

  final Widget child;
  final double radius;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final darkMode = Theme.of(context).brightness == Brightness.dark;
    final light = darkMode ? const Color(0xFF22262B) : AppColors.shadowLight;
    final dark = darkMode ? const Color(0xFF121416) : AppColors.shadowDark;

    return Container(
      decoration: BoxDecoration(
        color: color ?? AppColors.canvas,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: CustomPaint(
        foregroundPainter: InsetShadowPainter(
          blur: 8,
          spread: 6,
          cornerRadius: radius,
          light: light,
          dark: dark,
          insetFactor: intensity,
        ),
        child: padding != null
            ? Padding(padding: padding!, child: child)
            : child,
      ),
    );
  }
}