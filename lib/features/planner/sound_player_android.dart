import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// Android implementation of the sound facade — uses the audioplayers
/// package to play the bundled WAV assets. On desktop/VM (widget tests)
/// the plugin is missing and every call silently no-ops.
final AudioPlayer _player = AudioPlayer();
Timer? _boundedStop;

/// Do-Not-Disturb lock — while true, looping alarm rings are muted.
bool _focusLock = false;

void setFocusLockImpl(bool on) => _focusLock = on;

/// User-picked audio bytes (null = not set) — played via BytesSource.
Uint8List? _customBytes;

void setCustomAudioImpl(Uint8List? bytes, String ext) {
  _customBytes = bytes;
}

Future<void> _play(String id, {required bool loop}) async {
  if (id.isEmpty || id == 'none') return;
  try {
    await _player.stop();
    await _player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
    if (id == 'custom') {
      final bytes = _customBytes;
      if (bytes == null) return;
      await _player.play(BytesSource(bytes));
    } else {
      await _player.play(AssetSource('sounds/$id.wav'));
    }
  } catch (_) {
    // never throw from the UI for a media hiccup
  }
}

/// Plays the bundled WAV asset once.
void playSoundImpl(String id) => _play(id, loop: false);

/// Keeps the sound looping until [stopSoundImpl] is called. Muted
/// entirely while focus mode (DND) is on.
void playLoopImpl(String id) {
  if (_focusLock) return;
  _play(id, loop: true);
}

/// Completion alarm for the timer: loops for [seconds] then stops on
/// its own — always plays, even in focus mode.
void playBoundedImpl(String id, int seconds) {
  if (id.isEmpty || id == 'none') return;
  _boundedStop?.cancel();
  _play(id, loop: true);
  _boundedStop = Timer(Duration(seconds: seconds), () {
    try {
      _player.stop();
    } catch (_) {
      // ignore
    }
  });
}

void stopSoundImpl() {
  _boundedStop?.cancel();
  _boundedStop = null;
  try {
    _player.stop();
  } catch (_) {
    // ignore
  }
}
