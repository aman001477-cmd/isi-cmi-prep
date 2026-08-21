import 'package:flutter/material.dart';

import '../../core/theme/app_design_system.dart';
import 'sunken_box.dart';

/// Interactive pill button. Raised by default, sunken on press.
/// Focus state: 2px solid accent border (no harsh outlines).
class NeuButton extends StatefulWidget {
  const NeuButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.textColor,
    this.height = 52,
    this.filled = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color? color;
  final Color? textColor;
  final double height;
  final bool filled;

  @override
  State<NeuButton> createState() => _NeuButtonState();
}

class _NeuButtonState extends State<NeuButton> {
  bool _down = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final ink = widget.filled
        ? Colors.white
        : (widget.textColor ?? AppColors.textPrimary);

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 18, color: ink),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            widget.label,
            style: AppTypography.label.copyWith(color: ink),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    final bg = widget.filled
        ? AppColors.accent
        : (widget.color ?? AppColors.canvas);

    // NOTE: the GestureDetector must STAY MOUNTED while pressed. Swapping
    // it for a SunkenBox mid-gesture disposes the tap recognizer, so
    // onTapUp never fires, _down stays true and the button freezes dead.
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: _focused
                ? Border.all(color: AppColors.accent, width: 2)
                : null,
            boxShadow: _down ? null : AppShadows.raised,
          ),
          child: _down
              ? CustomPaint(
                  foregroundPainter: const InsetShadowPainter(
                    blur: 8,
                    spread: 6,
                    cornerRadius: AppRadius.pill,
                  ),
                  child: content,
                )
              : content,
        ),
      ),
    );
  }
}