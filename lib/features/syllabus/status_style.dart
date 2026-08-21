import 'package:flutter/material.dart';

import '../../core/theme/app_design_system.dart';
import 'models.dart';

/// Single source of truth for status look & feel.
extension NodeStatusStyle on NodeStatus {
  String get label => switch (this) {
        NodeStatus.notDone => 'NOT DONE',
        NodeStatus.doing => 'DOING',
        NodeStatus.partial => 'PART DONE',
        NodeStatus.done => 'DONE',
      };

  String get short => switch (this) {
        NodeStatus.notDone => 'ND',
        NodeStatus.doing => 'IN',
        NodeStatus.partial => 'PD',
        NodeStatus.done => 'DN',
      };

  Color get background => switch (this) {
        NodeStatus.notDone => AppColors.surfaceFaint,
        NodeStatus.doing => AppColors.accentSoft,
        NodeStatus.partial => AppColors.warning.withValues(alpha: 0.4),
        NodeStatus.done => AppColors.success.withValues(alpha: 0.45),
      };

  Color get foreground => switch (this) {
        NodeStatus.notDone => AppColors.textSecondary,
        NodeStatus.doing => AppColors.accent,
        NodeStatus.partial => AppColors.warningDeep,
        NodeStatus.done => AppColors.successDeep,
      };
}