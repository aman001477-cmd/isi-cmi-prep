import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Floating countdown overlay — a tiny window that stays on top of other
/// apps while the focus timer runs. Live data (phase / total / remaining /
/// started-at epoch) is pushed from the main app with [shareData] every
/// tick; this widget only renders it and ticks locally in between.
///
/// Two visual states:
///  · expanded — big clock + "minimize" (collapse to a dot) and "×"
///    (close the overlay completely)
///  · collapsed — a small bubble with the remaining time; tap to expand
class OverlayApp extends StatefulWidget {
  const OverlayApp({super.key});

  @override
  State<OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<OverlayApp> {
  static const _expandedSize = Size(250, 170);
  static const _collapsedSize = Size(70, 70);

  Timer? _tick;
  String _phase = 'idle';
  int _remaining = 0;
  int? _startedAtEpoch;
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen(_onEvent);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _onEvent(dynamic event) {
    try {
      final raw = event is Map
          ? event['data']
          : event is List && event.isNotEmpty
              ? event.first
              : null;
      if (raw == null) return;
      final j = jsonDecode(raw as String) as Map<String, dynamic>;
      setState(() {
        _phase = j['phase'] as String? ?? 'idle';
        _remaining = (j['remaining'] as num?)?.toInt() ?? 0;
        _startedAtEpoch = (j['startedAtEpoch'] as num?)?.toInt();
      });
    } catch (_) {
      // ignore malformed events
    }
  }

  int get _liveRemaining {
    if (_phase != 'running' || _startedAtEpoch == null) return _remaining;
    final elapsedMs = DateTime.now().millisecondsSinceEpoch - _startedAtEpoch!;
    final r = _remaining - elapsedMs ~/ 1000;
    return r < 0 ? 0 : r;
  }

  String _mmss(int s) {
    final h = (s ~/ 3600).toString().padLeft(2, '0');
    final m = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$h:$m:$sec';
  }

  Future<void> _collapse() async {
    await FlutterOverlayWindow.resizeOverlay(
        _collapsedSize.width.toInt(), _collapsedSize.height.toInt(), false);
    if (!mounted) return;
    setState(() => _collapsed = true);
  }

  Future<void> _expand() async {
    await FlutterOverlayWindow.resizeOverlay(
        _expandedSize.width.toInt(), _expandedSize.height.toInt(), false);
    if (!mounted) return;
    setState(() => _collapsed = false);
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _liveRemaining;
    if (_collapsed) {
      return Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: _expand,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xF21B1E2E),
              borderRadius: BorderRadius.circular(35),
              border: Border.all(color: const Color(0xFF8E94F2), width: 1.5),
              boxShadow: const [BoxShadow(blurRadius: 12, color: Color(0x66000000))],
            ),
            alignment: Alignment.center,
            child: Text(
              _mmss(remaining),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      );
    }

    final running = _phase == 'running';
    final done = _phase == 'done';
    final label = done
        ? 'Time’s up!'
        : running
            ? 'FOCUS · running'
            : _phase == 'paused'
                ? 'Paused'
                : 'Ready';

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xF21B1E2E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: running ? const Color(0xFF8E94F2) : const Color(0xFF3A3F52),
              width: 1.5),
          boxShadow: const [BoxShadow(blurRadius: 14, color: Color(0x66000000))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined,
                    size: 13, color: Color(0xFF8E94F2)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                _IconButton(
                  key: const Key('ov-min'),
                  icon: Icons.remove,
                  tooltip: 'Minimize',
                  onTap: _collapse,
                ),
                _IconButton(
                  key: const Key('ov-close'),
                  icon: Icons.close,
                  tooltip: 'Close overlay',
                  onTap: () => FlutterOverlayWindow.closeOverlay(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _mmss(remaining),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: done ? const Color(0xFF4CAF8C) : Colors.white,
                fontSize: 34,
                height: 1,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Icon(icon, size: 15, color: Colors.white70),
        ),
      ),
    );
  }
}

/// App-side controller for the floating overlay. All plugin calls are
/// Android-only, so everywhere else these are harmless no-ops. State is
/// published to the overlay window every time the timer changes.
class TimerOverlayController extends StateNotifier<bool> {
  TimerOverlayController() : super(false);

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get shown => state;
  bool permissionGranted = false;

  Future<bool> isPermissionGranted() async {
    if (!_supported) return false;
    permissionGranted = await FlutterOverlayWindow.isPermissionGranted();
    return permissionGranted;
  }

  /// Rules out the "display over other apps" permission and opens the
  /// system settings page to grant it; returns true once granted.
  Future<bool> ensurePermission() async {
    if (!_supported) return false;
    permissionGranted = await FlutterOverlayWindow.isPermissionGranted();
    if (!permissionGranted) {
      await FlutterOverlayWindow.requestPermission();
      permissionGranted = await FlutterOverlayWindow.isPermissionGranted();
    }
    return permissionGranted;
  }

  Future<bool> show() async {
    if (!_supported || state) return state;
    try {
      await FlutterOverlayWindow.showOverlay(
        overlayTitle: 'Prep — focus timer',
        overlayContent: 'Floating countdown',
        enableDrag: true,
        positionGravity: PositionGravity.right,
        height: 170,
        width: 250,
      );
      state = true;
    } catch (_) {
      state = false;
    }
    return state;
  }

  Future<void> close() async {
    if (!_supported) return;
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (_) {
      // ignore
    }
    state = false;
  }

  /// Pushes the latest timer state to the overlay window (Android only).
  Future<void> publish(Map<String, Object?> payload) async {
    if (!_supported || !state) return;
    try {
      await FlutterOverlayWindow.shareData(jsonEncode(payload));
    } catch (_) {
      // ignore — the overlay may not be up yet
    }
  }
}