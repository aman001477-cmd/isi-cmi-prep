import 'package:flutter/material.dart';

import '../theme/app_design_system.dart';
import '../theme/app_logo.dart';

/// Cold-start intro — the logo pops in with a soft glow, holds briefly,
/// then fades out to reveal the app underneath. Wrapped around the whole
/// MaterialApp so a theme switch never replays it.
class IntroGate extends StatefulWidget {
  const IntroGate({super.key, required this.child});

  final Widget child;

  @override
  State<IntroGate> createState() => _IntroGateState();
}

class _IntroGateState extends State<IntroGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2500),
  );

  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _done = true);
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                // 0→1 pop-in, hold until 78%, then fade out by 100%.
                final pop = Curves.easeOutBack
                    .transform((t / 0.45).clamp(0.0, 1.0));
                final opacity =
                    t < 0.78 ? 1.0 : (1 - (t - 0.78) / 0.22).clamp(0.0, 1.0);

                return Container(
                  color: AppColors.canvas,
                  child: Center(
                    child: Transform.scale(
                      scale: 0.55 + 0.45 * pop,
                      child: Opacity(
                        opacity: opacity,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AppLogo(size: 148, glow: true),
                            const SizedBox(height: 32),
                            Text(
                              'PREP',
                              style: AppTypography.titleLarge.copyWith(
                                letterSpacing: 3,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'prepare · focus · succeed',
                              style: AppTypography.caption.copyWith(
                                fontSize: 12,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        ],
      ),
    );
  }
}
