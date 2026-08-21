import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 12h / 24h time display preference, shared by the schedule page, the
/// reminders list and every alarm clock. Defaults to the DEVICE's own
/// format (captured in [setDevice24hFormat] from main); the user can
/// still override it with the in-app toggle, which persists.
class TimeFormatNotifier extends StateNotifier<bool> {
  TimeFormatNotifier() : super(_device24h ?? true) {
    _load();
  }

  static const _prefsKey = 'timeFormat24';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_prefsKey);
      if (saved != null) {
        state = saved;
      } else if (_device24h != null) {
        state = _device24h!;
      }
    } catch (_) {
      // keep default
    }
  }

  Future<void> set24(bool value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (_) {
      // ignore
    }
  }
}

/// The device's own 12h/24h preference, captured once at startup.
bool? _device24h;

/// Called from main() with the platform's clock setting. When the user
/// has not picked a format inside the app, this decides the display.
void setDevice24hFormat(bool use24h) => _device24h = use24h;

final timeFormatProvider =
    StateNotifierProvider<TimeFormatNotifier, bool>((_) => TimeFormatNotifier());

/// "HH:MM" in the user's chosen format ("14:05" or "02:05 PM").
String fmtClockTime(int hour, int minute, {required bool use24h}) {
  final hh = hour.toString().padLeft(2, '0');
  final mm = minute.toString().padLeft(2, '0');
  if (use24h) return '$hh:$mm';
  final suffix = hour < 12 ? 'AM' : 'PM';
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  return '${h12.toString().padLeft(2, '0')}:$mm $suffix';
}
