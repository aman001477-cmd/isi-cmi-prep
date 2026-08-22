import 'package:flutter/material.dart';

import '../../core/theme/app_design_system.dart';

/// Small reusable prompt/confirm dialogs used across feature pages.
Future<String?> promptText(
  BuildContext context,
  String title,
  String hint, {
  String? initial,
  Key? fieldKey,
}) async {
  final ctrl = TextEditingController(text: initial ?? '');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.standard)),
      title: Text(title, style: TextStyle(color: AppColors.textPrimary)),
      content: TextField(
        key: fieldKey,
        controller: ctrl,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('OK')),
      ],
    ),
  );
  return ok == true ? ctrl.text.trim() : null;
}

Future<bool?> confirm(BuildContext context, String title, String body) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.standard)),
      title: Text(title, style: TextStyle(color: AppColors.textPrimary)),
      content:
          Text(body, style: TextStyle(color: AppColors.textSecondary)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.dangerDeep),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete')),
      ],
    ),
  );
}
