import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';
import '../auth/user_store.dart';

/// OPTIONAL cloud layer — dead-simple to turn on and off again:
///
/// 1. `dart pub global activate flutterfire_cli`
/// 2. `dart run flutterfire configure`  (creates your Firebase project +
///    writes google-services.json / web config into this app)
/// 3. Rebuild. `cloudReady` flips to true automatically and every login/
///    create-user/backup action starts syncing that user's slot with
///    Cloud Firestore — "jahan chahe login, bina data loss ke".
///
/// Without any Firebase config the app runs fully local (no errors, no
/// network) — CloudSync just no-ops.
class CloudSync {
  static bool _ready = false;

  static bool get cloudReady => _ready;

  /// Call once from main(). Safe when Firebase is not configured.
  static Future<void> init() async {
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  static String _email(String id) => '$id@prep.local';

  static const accountsCol = 'isi_accounts';

  /// Every account gets a Firebase Auth identity (id@prep.local) so the
  /// same id+password works from any device. Best effort — never throws
  /// on the local-first path.
  static Future<void> ensureAuthUser(String id, String password) async {
    if (!_ready) return;
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email(id), password: password);
    } catch (_) {
      // already exists / offline — fine
    }
  }

  /// The account registry lives in Firestore too: sign up on one device,
  /// log in from any device. After a successful remote lookup the account
  /// is cached locally (same shape as [UserStore.usersPrefsKey]).
  static Future<void> pushAccount(UserAccount account) async {
    if (!_ready) return;
    try {
      await FirebaseFirestore.instance
          .collection(accountsCol)
          .doc(account.id)
          .set(account.toJson());
    } catch (_) {}
  }

  static Future<UserAccount?> pullAccount(String idOrName) async {
    if (!_ready) return null;
    final q = idOrName.trim().toLowerCase();
    try {
      // exact id first, then display-name match
      final byId = await FirebaseFirestore.instance
          .collection(accountsCol)
          .doc(q)
          .get();
      if (byId.exists) {
        final account = UserAccount.fromJson(
            (byId.data() as Map).cast<String, dynamic>());
        if (account.id.toLowerCase() == q ||
            account.name.toLowerCase() == q) return account;
      }
      final query = await FirebaseFirestore.instance
          .collection(accountsCol)
          .where('name', isEqualTo: idOrName.trim())
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return UserAccount.fromJson(
            (query.docs.first.data() as Map).cast<String, dynamic>());
      }
    } catch (_) {}
    return null;
  }

  static Future<List<UserAccount>> listAccounts() async {
    if (!_ready) return [];
    try {
      final snap = await FirebaseFirestore.instance
          .collection(accountsCol)
          .get();
      return snap.docs
          .map((d) =>
              UserAccount.fromJson((d.data() as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> removeAccount(String userId) async {
    if (!_ready) return;
    try {
      await FirebaseFirestore.instance
          .collection(accountsCol)
          .doc(userId)
          .delete();
    } catch (_) {}
  }

  static Future<void> changeAuthPassword(
      String id, String oldPassword, String newPassword) async {
    if (!_ready) return;
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(
              email: _email(id), password: oldPassword)
          .then((cred) => cred.user?.updatePassword(newPassword));
    } catch (_) {}
  }

  /// Called on login (after the local switch succeeded).
  static Future<void> syncAfterLogin(String userId) async {
    if (!_ready) return;
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: _email(userId), password: '');
    } catch (_) {}
  }

  static Future<void> pushSlot(String userId, Map<String, Object?> slot) async {
    if (!_ready) return;
    try {
      await FirebaseFirestore.instance
          .collection('isi_users')
          .doc(userId)
          .set({
        'data': slot,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Latest cloud copy of a user slot (null when missing/offline).
  static Future<Map<String, Object?>?> pullSlot(String userId) async {
    if (!_ready) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('isi_users')
          .doc(userId)
          .get();
      final data = doc.data();
      if (data == null || data['data'] is! Map) return null;
      return (data['data'] as Map).cast<String, Object?>();
    } catch (_) {
      return null;
    }
  }

  /// Remove the cloud copy (admin deleting a user).
  static Future<void> removeSlot(String userId) async {
    if (!_ready) return;
    try {
      await FirebaseFirestore.instance
          .collection('isi_users')
          .doc(userId)
          .delete();
    } catch (_) {}
  }
}