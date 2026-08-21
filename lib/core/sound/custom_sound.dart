import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'custom_sound_io.dart'
    if (dart.library.html) 'custom_sound_web.dart' as store;
import '../../features/planner/sound_player.dart';
import '../../features/reminders/reminder_notifications.dart';

/// A user-picked alarm sound. Persisted per platform:
///  - Android/desktop: written to the app support directory (`path`),
///  - web: kept as base64 in SharedPreferences (`base64`).
class CustomSound {
  CustomSound({
    required this.name,
    required this.ext,
    this.path,
    this.base64,
  });

  final String name;
  final String ext;
  final String? path;
  final String? base64;

  Uint8List? _bytes;

  Uint8List? get bytes => _bytes;

  void cacheBytes(Uint8List value) => _bytes = value;

  factory CustomSound.fromJson(Map<String, Object?> json) => CustomSound(
        name: json['name'] as String,
        ext: json['ext'] as String,
        path: json['path'] as String?,
        base64: json['base64'] as String?,
      );

  Map<String, Object?> toJson() => {
        'name': name,
        'ext': ext,
        'path': path,
        'base64': base64,
      };
}

/// Notified whenever the stored custom sound changes — the Reminders
/// card listens to it to re-render the ringtone row.
final ValueNotifier<CustomSound?> customSoundNotifier =
    ValueNotifier<CustomSound?>(null);

/// Max audio size we persist (web localStorage is ~5-10 MB).
const int kMaxCustomSoundBytes = 6 * 1024 * 1024;

/// Single-user custom alarm sound: load once, then pick/replace/clear.
/// Wires the bytes into the sound player and the Android notification
/// sound automatically.
class CustomSoundStore {
  CustomSoundStore._();

  static final CustomSoundStore instance = CustomSoundStore._();

  static const _prefsKey = 'custom_sound_v1';

  bool _loaded = false;

  CustomSound? get current => customSoundNotifier.value;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final sound = CustomSound.fromJson(
          jsonDecode(raw) as Map<String, Object?>);
      await _apply(sound);
    } catch (_) {
      // storage unavailable (incognito) — keep default chime
    }
  }

  Future<void> _apply(CustomSound sound) async {
    try {
      final bytes = await store.readBytes(sound);
      if (bytes != null) sound.cacheBytes(bytes);
    } catch (_) {}
    customSoundNotifier.value = sound;
    setCustomAudio(sound.bytes, sound.ext);
    setCustomNotificationSoundPath(sound.path);
  }

  /// Persists [bytes] (the picked audio file) and activates it.
  /// Returns false when the file is too large or storage fails.
  Future<bool> save(Uint8List bytes, String name) async {
    if (bytes.length > kMaxCustomSoundBytes) return false;
    try {
      final ext = _extOf(name);
      final record = await store.persistSound(bytes, name, ext);
      record.cacheBytes(bytes);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(record.toJson()));
      await _apply(record);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Removes the custom sound — alarms fall back to the bundled chime.
  Future<void> clear() async {
    try {
      await store.deleteSound(current);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
    customSoundNotifier.value = null;
    setCustomAudio(null, '');
    setCustomNotificationSoundPath(null);
  }

  static String _extOf(String name) {
    final i = name.lastIndexOf('.');
    final ext = i >= 0 ? name.substring(i + 1).toLowerCase() : 'mp3';
    if (ext.isEmpty || ext.length > 5) return 'mp3';
    return ext;
  }
}

/// Media MIME for an audio extension (used for web blob playback).
String audioMimeFor(String ext) {
  switch (ext.toLowerCase()) {
    case 'mp3':
      return 'audio/mpeg';
    case 'wav':
      return 'audio/wav';
    case 'ogg':
    case 'oga':
      return 'audio/ogg';
    case 'm4a':
      return 'audio/mp4';
    case 'aac':
      return 'audio/aac';
    case 'flac':
      return 'audio/flac';
    default:
      return 'audio/*';
  }
}
