import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/intro/intro_gate.dart';
import 'core/cloud/cloud_sync.dart';
import 'core/router/app_router.dart';
import 'core/sound/custom_sound.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_palettes.dart';
import 'core/theme/theme_provider.dart';
import 'core/utils/time_format.dart';
import 'features/dashboard/timer_overlay.dart';
import 'features/progress/daily_plan.dart';
import 'features/reminders/reminder_notifications.dart';

/// Separate entry point for the floating overlay window (Android only).
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OverlayApp(),
  ));
}

final ValueNotifier<String?> lastError = ValueNotifier<String?>(null);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final media = MediaQueryData.fromView(
      WidgetsBinding.instance.platformDispatcher.views.first);
  setDevice24hFormat(media.alwaysUse24HourFormat);
  initReminderNotifications();
  unawaited(CustomSoundStore.instance.load());
  unawaited(CloudSync.init());

  final originalError = FlutterError.onError;
  FlutterError.onError = (details) {
    lastError.value = details.exceptionAsString();
    originalError?.call(details);
  };

  runZonedGuarded(
    () => runApp(const ProviderScope(child: ISICMIPrepApp())),
    (error, stack) {
      lastError.value = error.toString();
    },
  );
}

class ISICMIPrepApp extends ConsumerWidget {
  const ISICMIPrepApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeId = ref.watch(themeProvider);
    final isDark =
        (themeOptionFor(themeId)?.palette.canvas.computeLuminance() ?? 0.9) <
            0.5;
    ref.watch(dailyPlanProvider);

    return IntroGate(
      child: MaterialApp.router(
        key: ValueKey('theme-$themeId-${ThemeNotifier.epoch}'),
        title: 'Prep',
        theme: isDark ? AppTheme.dark : AppTheme.light,
        debugShowCheckedModeBanner: false,
        routerConfig: AppRouter.router,
        builder: (context, child) => Stack(
          children: [
            child ?? const SizedBox.shrink(),
            ValueListenableBuilder<String?>(
              valueListenable: lastError,
              builder: (context, message, _) {
                if (message == null || message.isEmpty) {
                  return const SizedBox.shrink();
                }
                return SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => lastError.value = null,
                      child: Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB42318),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(
                                blurRadius: 12, color: Color(0x66000000)),
                          ],
                        ),
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
