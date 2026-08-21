// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import '../../core/sound/custom_sound.dart' show audioMimeFor;

html.AudioElement? _looping;
String? _loopingUrl;
Timer? _boundedStop;

/// Do-Not-Disturb lock — while true, looping alarm rings are muted.
bool _focusLock = false;

void setFocusLockImpl(bool on) => _focusLock = on;

/// User-picked audio bytes (null = not set).
Uint8List? _customBytes;
String _customExt = 'mp3';

void setCustomAudioImpl(Uint8List? bytes, String ext) {
  _customBytes = bytes;
  _customExt = ext.isEmpty ? 'mp3' : ext;
  _disposeLoop();
}

void _disposeLoop() {
  if (_looping != null) {
    try {
      _looping!.pause();
      _looping!.remove();
    } catch (_) {
      // ignore — element may already be gone
    }
    _looping = null;
  }
  if (_loopingUrl != null) {
    html.Url.revokeObjectUrl(_loopingUrl!);
    _loopingUrl = null;
  }
}

/// Loads the bundled WAV (or the user's picked audio) and plays it from
/// a Blob URL so the exact served asset path never has to be guessed.
Future<void> _spawn(String id, {required bool loop}) async {
  if (id.isEmpty || id == 'none') return;
  try {
    final Uint8List bytes;
    String mime;
    if (id == 'custom') {
      if (_customBytes == null) return;
      bytes = _customBytes!;
      mime = audioMimeFor(_customExt);
    } else {
      final ByteData data = await rootBundle.load('assets/sounds/$id.wav');
      bytes = data.buffer
          .asUint8List(data.offsetInBytes, data.lengthInBytes);
      mime = 'audio/wav';
    }
    final blob = html.Blob([bytes], mime);
    final url = html.Url.createObjectUrlFromBlob(blob);
    _disposeLoop();
    final a = html.AudioElement(url)..loop = loop;
    a.play();
    if (loop) {
      _looping = a;
      _loopingUrl = url;
    }
  } catch (_) {
    // never throw from the UI for a media hiccup
  }
}

/// Web implementation: plays the bundled WAV asset once.
void playSoundImpl(String id) => _spawn(id, loop: false);

/// Keeps the sound looping until [stopSoundImpl] is called. Muted
/// entirely while focus mode (DND) is on.
void playLoopImpl(String id) {
  if (_focusLock) return;
  _spawn(id, loop: true);
}

/// Completion alarm for the timer: loops for [seconds] then stops on
/// its own — always plays, even in focus mode.
void playBoundedImpl(String id, int seconds) {
  if (id.isEmpty || id == 'none') return;
  _boundedStop?.cancel();
  _spawn(id, loop: true);
  _boundedStop = Timer(Duration(seconds: seconds), _disposeLoop);
}

void stopSoundImpl() {
  _boundedStop?.cancel();
  _boundedStop = null;
  _disposeLoop();
}