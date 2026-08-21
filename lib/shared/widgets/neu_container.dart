import 'package:flutter/material.dart';

import '../../core/theme/app_design_system.dart';
import 'sunken_box.dart';

/// Neumorphic container — the ONLY component used for tactile zones.
/// [raised] — extruded default. [sunken] — pressed/inset. [flat] — no chamfer.
class NeuContainer extends StatelessWidget {
  const NeuContainer.raised({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadius.standard,
    this.color,
    this.onTap,
  }) : surface = NeuSurface.raised;

  const NeuContainer.sunken({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadius.standard,
    this.color,
  })  : surface = NeuSurface.sunken,
        onTap = null;

  const NeuContainer.flat({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadius.standard,
    this.color,
    this.onTap,
  }) : surface = NeuSurface.flat;

  final NeuSurface surface;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);

    if (surface == NeuSurface.sunken) {
      return SunkenBox(
          radius: radius, color: color ?? AppColors.canvas, child: content);
    }

    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? AppColors.canvas,
        borderRadius: BorderRadius.circular(radius),
        border: surface == NeuSurface.flat
            ? Border.all(color: AppColors.border, width: 1)
            : null,
        boxShadow: surface == NeuSurface.raised ? AppShadows.raised : null,
      ),
      child: content,
    );

    if (surface == NeuSurface.flat) return box;

    if (onTap == null) return box;

    return _Pressable(
      onTap: onTap!,
      radius: radius,
      color: color ?? AppColors.canvas,
      pill: radius == AppRadius.pill,
      child: box,
    );
  }
}

enum NeuSurface { raised, sunken, flat }

/// Adds tactile press: raised -> sunken while the finger is down.
class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.onTap,
    required this.radius,
    required this.color,
    required this.child,
    this.pill = false,
  });

  final VoidCallback onTap;
  final double radius;
  final Color color;
  final Widget child;
  final bool pill;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    if (_pressed) {
      return GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: SunkenBox(
          radius: widget.radius,
          color: widget.color ?? AppColors.canvas,
          child: widget.child,
        ),
      );
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: widget.color ?? AppColors.canvas,
          borderRadius: BorderRadius.circular(widget.radius),
          border: widget.pill
              ? Border.all(color: AppColors.accent, width: 2)
              : null,
          boxShadow: AppShadows.raised,
        ),
        child: widget.child,
      ),
    );
  }
}