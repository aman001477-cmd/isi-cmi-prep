import 'dart:convert';

import 'package:file_selector/file_selector.dart';

/// ---------------------------------------------------------------------------
/// File dialogs for backup export/import (via the first-party file_selector
/// plugin — browser download / upload on web).
/// ---------------------------------------------------------------------------

const XTypeGroup _backupType = XTypeGroup(
  label: 'ISI CMI Prep backup',
  extensions: ['json'],
);

/// Opens a save dialog and writes [content]. Returns false when the user
/// cancels or the platform has no file support.
Future<bool> saveBackupFile(String content, String suggestedName) async {
  try {
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: const [_backupType],
    );
    if (location == null) return false;
    final file = XFile.fromData(
      utf8.encode(content),
      mimeType: 'application/json',
      name: suggestedName,
    );
    await file.saveTo(location.path);
    return true;
  } catch (_) {
    return false;
  }
}

/// Opens a file picker for a backup file. Returns the file's text content,
/// or null when cancelled / unsupported.
Future<String?> pickBackupFile() async {
  try {
    final file = await openFile(acceptedTypeGroups: const [_backupType]);
    if (file == null) return null;
    return file.readAsString();
  } catch (_) {
    return null;
  }
}
