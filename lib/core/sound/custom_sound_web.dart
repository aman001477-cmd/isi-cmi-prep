import 'dart:convert';
import 'dart:typed_data';

import 'custom_sound.dart';

/// Web keeps the audio as base64 inside SharedPreferences (localStorage).
Future<CustomSound> persistSound(
    Uint8List bytes, String name, String ext) async {
  return CustomSound(name: name, ext: ext, base64: base64Encode(bytes));
}

Future<Uint8List?> readBytes(CustomSound sound) async {
  final b64 = sound.base64;
  if (b64 == null) return null;
  try {
    return base64Decode(b64);
  } catch (_) {
    return null;
  }
}

Future<void> deleteSound(CustomSound? sound) async {}
