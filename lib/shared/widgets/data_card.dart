import 'package:flutter/material.dart';

import '../../core/theme/app_design_system.dart';

/// Flat data-display card.
/// White surface + 1px border + crisp tiny shadow. NO neumorphism here.
class DataCard extends StatelessWidget {
  const DataCard({
    super.key,
    this.title,
    this.subtitle,
    required this.body,
    this.trailing,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadius.standard,
    this.actions,
  });

  final String? title;
  final String? subtitle;
  final Widget body;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final double radius;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: AppShadows.flatCard,
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null || trailing != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null)
                          Text(title!, style: AppTypography.titleMedium),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle!, style: AppTypography.small),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            body,
            if (actions != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm,
                  children: actions!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Thin horizontal internal divider — 1px #EBEFF3.
class DataDivider extends StatelessWidget {
  const DataDivider({super.key, this.verticalMargin = AppSpacing.md});

  final double verticalMargin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalMargin),
      child: Container(height: 1, color: AppColors.divider),
    );
  }
}

/// Micro metric row with a colored status dot.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, this.size = 8});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}