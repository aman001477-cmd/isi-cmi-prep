import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_design_system.dart';
import '../../core/utils/time_format.dart';

/// Hour/minute picker with up/down arrows AND tap-to-type keyboard
/// input. Displays in the user's 12h/24h preference.
///
/// Tracks its own copy of [value] so rapid arrow taps (without a
/// rebuild in between) still step correctly; parent-driven changes are
/// picked up in [didUpdateWidget].
class ClockInput extends ConsumerStatefulWidget {
  const ClockInput({
    super.key,
    required this.value,
    required this.isHour,
    required this.onChanged,
    this.keyPrefix,
    this.compact = false,
  });

  /// Current value — hour (0–23) or minute (0–59) depending on [isHour].
  final int value;

  /// True → hours field, false → minutes field.
  final bool isHour;
  final ValueChanged<int> onChanged;

  /// Prefix for widget keys (`<prefix>-up`, `-value`, `-down`).
  final String? keyPrefix;
  final bool compact;

  @override
  ConsumerState<ClockInput> createState() => _ClockInputState();
}

class _ClockInputState extends ConsumerState<ClockInput> {
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.value;
  }

  @override
  void didUpdateWidget(ClockInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _current) _current = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    final use24h = ref.watch(timeFormatProvider);
    final mod = widget.isHour ? 24 : 60;
    final prefix = widget.keyPrefix ?? (widget.isHour ? 'clk-h' : 'clk-m');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          key: Key('$prefix-up'),
          onTap: () => _emit((_current + 1) % mod),
          child: const _StepperIcon(Icons.arrow_drop_up),
        ),
        const SizedBox(width: 2),
        GestureDetector(
          key: Key('$prefix-value'),
          onTap: () => _openTypeDialog(context, ref),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceFaint,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Text(
              widget.isHour
                  ? fmtClockTime(_current, 0, use24h: use24h).split(':').first
                  : _current.toString().padLeft(2, '0'),
              style: AppTypography.titleMedium.copyWith(
                  fontSize: widget.compact ? 13 : 15),
            ),
          ),
        ),
        const SizedBox(width: 2),
        GestureDetector(
          key: Key('$prefix-down'),
          onTap: () => _emit((_current - 1 + mod) % mod),
          child: const _StepperIcon(Icons.arrow_drop_down),
        ),
        if (widget.isHour && !use24h)
          Padding(
            padding: const EdgeInsets.only(left: 3),
            child: GestureDetector(
              key: Key('$prefix-ampm'),
              onTap: () => _emit((_current + 12) % 24),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _current < 12 ? 'AM' : 'PM',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _emit(int v) {
    _current = v;
    widget.onChanged(v);
  }

  Future<void> _openTypeDialog(BuildContext context, WidgetRef ref) async {
    final use24h = ref.read(timeFormatProvider);

    final result = await showDialog<int>(
      context: context,
      builder: (_) => ClockTypeDialog(
        title: widget.isHour ? 'Type the hour' : 'Type the minutes',
        max: widget.isHour ? (use24h ? 23 : 12) : 59,
        initial: _current,
        use24h: use24h,
        isHour: widget.isHour,
      ),
    );
    if (result != null) _emit(result);
  }
}

class _StepperIcon extends StatelessWidget {
  const _StepperIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceFaint,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Icon(icon, size: 16, color: AppColors.textSecondary),
    );
  }
}

/// Small dialog with a number keyboard for the hour/minute value.
class ClockTypeDialog extends StatefulWidget {
  const ClockTypeDialog({
    required this.title,
    required this.max,
    required this.initial,
    required this.use24h,
    required this.isHour,
  });

  final String title;
  final int max;
  final int initial;
  final bool use24h;
  final bool isHour;

  @override
  State<ClockTypeDialog> createState() => _ClockTypeDialogState();
}

class _ClockTypeDialogState extends State<ClockTypeDialog> {
  late final TextEditingController _ctrl;
  bool _pm = false;

  @override
  void initState() {
    super.initState();
    final display = widget.isHour && !widget.use24h
        ? (widget.initial % 12 == 0 ? 12 : widget.initial % 12)
        : widget.initial;
    _pm = widget.initial >= 12;
    _ctrl = TextEditingController(text: display.toString());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.standard),
      ),
      title: Text(widget.title,
          style: TextStyle(color: AppColors.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('clock-type-field'),
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 2,
            textAlign: TextAlign.center,
            style: AppTypography.titleMedium.copyWith(fontSize: 22),
            cursorColor: AppColors.accent,
            decoration: InputDecoration(
              counterText: '',
              hintText: '0 – ${widget.max}',
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _ok(),
          ),
          if (widget.isHour && !widget.use24h) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _AmPmPill(
                  label: 'AM',
                  active: !_pm,
                  onTap: () => setState(() => _pm = false),
                ),
                const SizedBox(width: 8),
                _AmPmPill(
                  label: 'PM',
                  active: _pm,
                  onTap: () => setState(() => _pm = true),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        FilledButton(
          onPressed: _ok,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
          ),
          child: const Text('Set'),
        ),
      ],
    );
  }

  void _ok() {
    final parsed = int.tryParse(_ctrl.text.trim());
    if (parsed == null) {
      Navigator.of(context).pop();
      return;
    }
    var v = parsed;
    if (widget.isHour && !widget.use24h) {
      v = (v % 12) + (_pm ? 12 : 0);
    }
    Navigator.of(context).pop(v > widget.max ? widget.max : v);
  }
}

class _AmPmPill extends StatelessWidget {
  const _AmPmPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.accent : AppColors.surfaceFaint,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: active ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.label.copyWith(
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
