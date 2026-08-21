import 'package:flutter/material.dart';

import '../../core/theme/app_design_system.dart';
import 'sunken_box.dart';

/// Engraved text field — permanently sunken, typing cursor in accent.
class NeuInput extends StatelessWidget {
  const NeuInput({
    super.key,
    required this.controller,
    this.hint,
    this.label,
    this.keyboardType,
    this.obscure = false,
    this.maxLines = 1,
    this.onChanged,
    this.prefixIcon,
    this.suffix,
  });

  final TextEditingController controller;
  final String? hint;
  final String? label;
  final TextInputType? keyboardType;
  final bool obscure;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final IconData? prefixIcon;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final field = SunkenBox(
      radius: AppRadius.standard,
      color: AppColors.surfaceFaint,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        maxLines: maxLines,
        onChanged: onChanged,
        cursorColor: AppColors.accent,
        cursorWidth: 2,
        style: AppTypography.body,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTypography.small.copyWith(color: AppColors.textSecondary),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, size: 18, color: AppColors.textSecondary)
              : null,
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
        ),
      ),
    );

    if (label == null) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.xs),
          child: Text(label!, style: AppTypography.caption),
        ),
        field,
      ],
    );
  }
}