import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'custom_sound.dart';

/// Persists the audio bytes as a real file in the app support directory
/// so Android system notifications can play it (file:// URI).
Future<CustomSound> persistSound(
    Uint8List bytes, String name, String ext) async {
  final dir = await getApplicationSupportDirectory();
  final file = File('${dir.path}${Platform.pathSeparator}custom_alarm.$ext');
  await file.writeAsBytes(bytes, flush: true);
  return CustomSound(name: name, ext: ext, path: file.path);
}

Future<Uint8List?> readBytes(CustomSound sound) async {
  final path = sound.path;
  if (path == null) return null;
  final file = File(path);
  if (!await file.exists()) return null;
  return file.readAsBytes();
}

Future<void> deleteSound(CustomSound? sound) async {
  final path = sound?.path;
  if (path == null) return;
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } catch (_) {
    // best effort
  }
}
