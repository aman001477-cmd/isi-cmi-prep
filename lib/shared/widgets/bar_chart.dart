import 'package:flutter/material.dart';

import '../../core/theme/app_design_system.dart';

/// One bar of a [BarChart].
class BarDatum {
  const BarDatum(this.label, this.value, {this.valueLabel});

  final String label;
  /// 0..1 scale; the chart normalizes to its own maximum.
  final double value;
  /// Optional text shown above the bar (e.g. the raw count).
  final String? valueLabel;
}

/// Minimal bar chart — bars sized relative to the largest value, value
/// labels above, labels below. Highlighted bar = today / newest.
class BarChart extends StatelessWidget {
  const BarChart({
    super.key,
    required this.data,
    this.color,
    this.highlightIndex,
    this.height = 110,
  });

  final List<BarDatum> data;
  final Color? color;
  final int? highlightIndex;
  final double height;

  @override
  Widget build(BuildContext context) {
    var max = 0.0;
    for (final d in data) {
      if (d.value > max) max = d.value;
    }
    final barColor = (color ?? AppColors.accent).withValues(alpha: 0.55);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < data.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _BarColumn(
                    fraction: max <= 0 ? 0 : (data[i].value / max).clamp(0.0, 1.0),
                    valueLabel: data[i].valueLabel,
                    color: i == highlightIndex ? AppColors.accent : barColor,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < data.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  data[i].label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    fontSize: 9,
                    color: i == highlightIndex
                        ? AppColors.accent
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _BarColumn extends StatelessWidget {
  const _BarColumn({
    required this.fraction,
    required this.valueLabel,
    required this.color,
  });

  final double fraction;
  final String? valueLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (valueLabel != null)
          Text(
            valueLabel!,
            style: AppTypography.caption.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        const SizedBox(height: 3),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: fraction,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
