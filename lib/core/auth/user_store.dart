import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Identity + permissions of one account in the app.
///
/// - Admin: can manage every user, view/edit their data, change their
///   permissions and per-user backups.
/// - Users: log in with the id+password the admin gave them. Each user's
///   data lives in its own slot and can be backed up / restored anywhere.
class UserAccount {
  const UserAccount({
    required this.id,
    required this.name,
    required this.password,
    required this.isAdmin,
    this.canEdit = true,
    this.canDelete = true,
    this.canRemove = true,
    this.canReenter = true,
    this.createdAt,
  });

  /// Stable login id (admin = `admin`, users = `u1001`...).
  final String id;

  /// Display name shown in the admin panel.
  final String name;

  /// Plain-text password (local app; the optional cloud layer verifies
  /// with Firebase Auth when configured).
  final String password;

  final bool isAdmin;

  /// "edit" — change names/dates/details of existing entries.
  final bool canEdit;

  /// "delete" — delete entries.
  final bool canDelete;

  /// "remove" — bulk cleanup / clear actions.
  final bool canRemove;

  /// "reenter" — bring backlog entries back / reschedule.
  final bool canReenter;

  final DateTime? createdAt;

  UserAccount copyWith({
    String? name,
    String? password,
    bool? canEdit,
    bool? canDelete,
    bool? canRemove,
    bool? canReenter,
  }) =>
      UserAccount(
        id: id,
        name: name ?? this.name,
        password: password ?? this.password,
        isAdmin: isAdmin,
        canEdit: canEdit ?? this.canEdit,
        canDelete: canDelete ?? this.canDelete,
        canRemove: canRemove ?? this.canRemove,
        canReenter: canReenter ?? this.canReenter,
        createdAt: createdAt,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'password': password,
        'isAdmin': isAdmin,
        'canEdit': canEdit,
        'canDelete': canDelete,
        'canRemove': canRemove,
        'canReenter': canReenter,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };

  static UserAccount fromJson(Map<String, dynamic> j) => UserAccount(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? j['id'] as String,
        password: (j['password'] as String?) ?? '',
        isAdmin: j['isAdmin'] as bool? ?? false,
        canEdit: j['canEdit'] as bool? ?? true,
        canDelete: j['canDelete'] as bool? ?? true,
        canRemove: j['canRemove'] as bool? ?? true,
        canReenter: j['canReenter'] as bool? ?? true,
        createdAt: j['createdAt'] == null
            ? null
            : DateTime.parse(j['createdAt'] as String),
      );
}

/// Per-user data slots + the active session.
///
/// The whole app keeps working on top of SharedPreferences; a "user slot"
/// is a snapshot of every app key EXCEPT the auth/meta keys. Logging in as
/// a user captures the current session's data into its slot, wipes the
/// app keys and loads the target user's slot — then the UI providers are
/// invalidated so the whole app rebuilds around that user's data.
class UserStore {
  static const usersPrefsKey = 'users_v1';
  static const activeUserIdKey = 'active_user_id';
  static const adminPasswordKey = 'admin_pass_v1';
  static const loggedOutKey = 'logged_out_v1';
  static const defaultAdminPassword = 'admin123';

  /// The app keys that are NOT part of a user's data slot (device/app
  /// owned).
  static const _metaKeys = {
    usersPrefsKey,
    activeUserIdKey,
    adminPasswordKey,
    loggedOutKey,
    'themeId',
    'lightThemeId',
    'timeFormat24',
    'custom_sound_v1',
  };

  static Future<List<UserAccount>> loadUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(usersPrefsKey);
    if (raw == null) {
      // First run — seed the default admin account.
      final admin = UserAccount(
        id: 'admin',
        name: 'Admin',
        password: defaultAdminPassword,
        isAdmin: true,
      );
      await saveUsers([admin]);
      return [admin];
    }
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => UserAccount.fromJson(e as Map<String, dynamic>))
          .toList();
      if (list.isEmpty) {
        final admin = UserAccount(
          id: 'admin',
          name: 'Admin',
          password: defaultAdminPassword,
          isAdmin: true,
        );
        await saveUsers([admin]);
        return [admin];
      }
      return list;
    } catch (_) {
      final admin = UserAccount(
        id: 'admin',
        name: 'Admin',
        password: defaultAdminPassword,
        isAdmin: true,
      );
      await saveUsers([admin]);
      return [admin];
    }
  }

  static Future<void> saveUsers(List<UserAccount> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        usersPrefsKey, jsonEncode([for (final u in users) u.toJson()]));
  }

  static Future<String> adminPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(adminPasswordKey) ?? defaultAdminPassword;
  }

  static Future<void> setAdminPassword(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(adminPasswordKey, value);
  }

  /// Account the device is currently signed into ('' when signed out).
  static Future<String> activeUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(activeUserIdKey) ?? '';
  }

  static Future<void> setActiveUserId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(activeUserIdKey, id);
  }

  /// True after the user explicitly logged out (so the app stops
  /// auto-signing back in on the next launch).
  static Future<bool> wasLoggedOut() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(loggedOutKey) ?? false;
  }

  static Future<void> setLoggedOut(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(loggedOutKey, value);
  }

  static String slotKey(String userId) => 'slot_$userId';

  /// Looks the account up by id or name (case-insensitive).
  static UserAccount? findAccount(
      List<UserAccount> users, String idOrName) {
    final q = idOrName.trim().toLowerCase();
    for (final u in users) {
      if (u.id.toLowerCase() == q || u.name.toLowerCase() == q) {
        return u;
      }
    }
    const adminId = 'admin';
    if (adminId == q) return null; // admin is always in the list
    return null;
  }

  /// Validates credentials against the local account list.
  static UserAccount? authenticate(
      List<UserAccount> users, String idOrName, String password) {
    final account = findAccount(users, idOrName);
    if (account != null && account.password == password) return account;
    return null;
  }

  /// Capture the CURRENT app data (all non-meta keys) into [userId]'s slot.
  static Future<void> captureSlot(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final snapshot = <String, Object?>{};
    for (final key in prefs.getKeys()) {
      if (_metaKeys.contains(key)) continue;
      snapshot[key] = prefs.get(key);
    }
    snapshot['_savedAt'] = DateTime.now().toIso8601String();
    await prefs.setString(slotKey(userId), jsonEncode(snapshot));
  }

  /// Full snapshot map of a user's slot (empty map = fresh user).
  static Future<Map<String, Object?>> slotOf(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(slotKey(userId));
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map<String, dynamic>).cast<String, Object?>();
    } catch (_) {
      return {};
    }
  }

  /// Wipe every non-meta app key (fresh empty storage).
  static Future<void> wipeAppData() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().toList()) {
      if (_metaKeys.contains(key) || key.startsWith('slot_')) continue;
      await prefs.remove(key);
    }
  }

  /// Write a slot snapshot into the live app keys.
  static Future<void> applySlot(Map<String, Object?> slot) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in slot.entries) {
      if (_metaKeys.contains(entry.key) || entry.key == '_savedAt') continue;
      final v = entry.value;
      if (v is String) {
        await prefs.setString(entry.key, v);
      } else if (v is bool) {
        await prefs.setBool(entry.key, v);
      } else if (v is int) {
        await prefs.setInt(entry.key, v);
      } else if (v is double) {
        await prefs.setDouble(entry.key, v);
      } else if (v is List) {
        await prefs.setStringList(
            entry.key, v.map((e) => e.toString()).toList());
      }
    }
  }

  /// The full device-level sign-in switch:
  /// 1. save current session's data into its own slot
  /// 2. clear app data
  /// 3. load the target user's slot
  /// 4. persist the new active session
  static Future<void> switchTo(String userId) async {
    final current = await activeUserId();
    if (current.isNotEmpty && current != userId) {
      await captureSlot(current);
    }
    await wipeAppData();
    final target = await slotOf(userId);
    await applySlot(target);
    await setActiveUserId(userId);
  }

  /// New user: fresh id + EMPTY slot (their defaults seed on first load).
  static Future<UserAccount> createUser(
      List<UserAccount> users, String name, String password) async {
    var next = 1001;
    while (users.any((u) => u.id == 'u$next')) {
      next++;
    }
    final account = UserAccount(
      id: 'u$next',
      name: name.trim().isEmpty ? 'User $next' : name.trim(),
      password: password,
      isAdmin: false,
      createdAt: DateTime.now(),
    );
    users.add(account);
    // keep the current session's data (e.g. the admin's) safe first, then
    // clear the live app keys — the new user's slot is EMPTY on purpose.
    final active = await activeUserId();
    if (active.isNotEmpty) await captureSlot(active);
    await wipeAppData();
    await saveUsers(users);
    return account;
  }

  /// Remove an account + its slot (cannot remove the admin or self).
  static Future<void> removeUser(
      List<UserAccount> users, String userId, String activeId) async {
    if (userId == 'admin' || userId == activeId) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(slotKey(userId));
    users.removeWhere((u) => u.id == userId);
    await saveUsers(users);
  }

  /// A standalone backup JSON (same shape as the app-wide backup) for one
  /// user only — "user ka data backup pe save".
  static String encodeUserBackup(String userId, Map<String, Object?> slot) =>
      jsonEncode({
        'app': 'isi-cmi-prep',
        'kind': 'user-backup',
        'version': 1,
        'userId': userId,
        'savedAt': DateTime.now().toIso8601String(),
        'account': null,
        'data': slot,
      });

  /// Parse a per-user backup back into a slot (null = not valid).
  static Map<String, Object?>? decodeUserBackup(String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (j['app'] != 'isi-cmi-prep' || j['kind'] != 'user-backup') {
        return null;
      }
      return (j['data'] as Map<String, dynamic>).cast<String, Object?>();
    } catch (_) {
      return null;
    }
  }

  /// Replace a user's whole slot with a backup snapshot ("restore without
  /// data loss").
  static Future<void> restoreSlot(
      String userId, Map<String, Object?> slot) async {
    final prefs = await SharedPreferences.getInstance();
    // snapshot minus the meta keys survives
    slot.removeWhere((k, _) => _metaKeys.contains(k));
    slot['_savedAt'] = DateTime.now().toIso8601String();
    await prefs.setString(slotKey(userId), jsonEncode(slot));
  }
}