import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// ---------------------------------------------------------------------------
/// Backup / restore — the whole app's data lives in SharedPreferences, so a
/// backup is a JSON snapshot of every persisted key. Export writes it to a
/// file, import reads such a file back and rewrites storage.
/// ---------------------------------------------------------------------------

const String backupAppTag = 'isi-cmi-prep';
const int backupVersion = 1;

class BackupDocument {
  const BackupDocument({required this.data, required this.savedAt});

  final Map<String, Object?> data;
  final DateTime savedAt;
}

/// Snapshot of every currently persisted key.
Future<BackupDocument> collectBackup() async {
  final prefs = await SharedPreferences.getInstance();
  final data = <String, Object?>{};
  for (final key in prefs.getKeys()) {
    data[key] = prefs.get(key);
  }
  return BackupDocument(data: data, savedAt: DateTime.now());
}

/// Human-readable filename for the exported file.
String defaultBackupFileName(DateTime now) {
  String pad(int n) => n.toString().padLeft(2, '0');
  return 'isi_cmi_prep_backup_${now.year}-${pad(now.month)}-${pad(now.day)}.json';
}

String encodeBackup(BackupDocument doc) => jsonEncode({
      'app': backupAppTag,
      'version': backupVersion,
      'savedAt': doc.savedAt.toIso8601String(),
      'data': doc.data,
    });

/// Parses an exported file. Returns null when the content is not a valid
/// backup (wrong app tag, malformed JSON, missing data).
BackupDocument? decodeBackup(String raw) {
  try {
    final root = jsonDecode(raw);
    if (root is! Map<String, dynamic>) return null;
    if (root['app'] != backupAppTag) return null;
    final data = root['data'];
    if (data is! Map<String, dynamic>) return null;
    final cleaned = <String, Object?>{};
    data.forEach((key, value) {
      if (value != null) cleaned[key] = value;
    });
    return BackupDocument(
      data: cleaned,
      savedAt: DateTime.tryParse(root['savedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  } catch (_) {
    return null;
  }
}

/// Writes every entry back to storage. Returns how many keys were written.
Future<int> applyBackup(BackupDocument doc) async {
  final prefs = await SharedPreferences.getInstance();
  var written = 0;
  for (final entry in doc.data.entries) {
    final value = entry.value;
    var ok = false;
    if (value is String) {
      ok = await prefs.setString(entry.key, value);
    } else if (value is bool) {
      ok = await prefs.setBool(entry.key, value);
    } else if (value is int) {
      ok = await prefs.setInt(entry.key, value);
    } else if (value is double) {
      ok = await prefs.setDouble(entry.key, value);
    } else if (value is List && value.every((e) => e is String)) {
      ok = await prefs.setStringList(entry.key, value.cast<String>());
    }
    if (ok) written++;
  }
  return written;
}
