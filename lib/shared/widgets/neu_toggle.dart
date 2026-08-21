import 'package:flutter/material.dart';

import '../../core/theme/app_design_system.dart';
import 'sunken_box.dart';

/// Tactile pill toggle — raised off, sunken+accent on.
class NeuToggle extends StatelessWidget {
  const NeuToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.iconOn = Icons.check,
    this.iconOff = Icons.close,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData iconOn;
  final IconData iconOff;

  @override
  Widget build(BuildContext context) {
    final on = value;

    return GestureDetector(
      onTap: () => onChanged(!on),
      child: _Toggle(on: on, icon: on ? iconOn : iconOff),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.on, required this.icon});

  final bool on;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      width: 52,
      height: 28,
      padding: const EdgeInsets.all(3),
      child: Align(
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: on ? AppColors.accent : AppColors.surface,
            shape: BoxShape.circle,
            boxShadow: AppShadows.raised,
          ),
          child: Icon(
            icon,
            size: 12,
            color: on ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );

    return on
        ? SunkenBox(
            radius: AppRadius.pill,
            color: AppColors.accentSoft,
            child: body,
          )
        : Container(
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              boxShadow: AppShadows.raised,
            ),
            child: body,
          );
  }
}