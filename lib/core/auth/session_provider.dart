import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloud/cloud_sync.dart';
import '../config/supabase_config.dart';
import '../../features/dashboard/marathon_provider.dart';
import '../../features/planner/marker_provider.dart';
import '../../features/planner/mock_test_provider.dart';
import '../../features/planner/planner_provider.dart';
import '../../features/progress/daily_plan.dart';
import '../../features/progress/mock_results_provider.dart';
import '../../features/progress/streak_provider.dart';
import '../../features/progress/study_log_provider.dart';
import '../../features/reminders/reminders_provider.dart';
import '../../features/schedule/schedule_provider.dart';
import '../../features/syllabus/exam_countdown_provider.dart';
import '../../features/syllabus/syllabus_provider.dart';
import 'user_store.dart';

/// Who is signed in right now.
class SessionState {
  const SessionState({this.account, this.loading = true});

  /// null → signed out (login screen shown).
  final UserAccount? account;
  final bool loading;

  bool get isAdmin => account?.isAdmin ?? false;
  bool get signedIn => account != null;

  SessionState copyWith({UserAccount? account, bool? loading}) => SessionState(
      account: account ?? this.account, loading: loading ?? this.loading);
}

/// Reads the persisted session at startup; login/logout round-trips
/// through [UserStore.switchTo].
class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier() : super(const SessionState(loading: true)) {
    _restore();
  }

  Future<void> _restore() async {
    final users = await UserStore.loadUsers();
    var active = await UserStore.activeUserId();
    if (active.isEmpty) {
      final loggedOut = await UserStore.wasLoggedOut();
      if (!loggedOut &&
          users.length == 1 &&
          users.first.isAdmin) {
        // Very first run: sign the default admin straight in so the app
        // opens instantly. Explicit logout sends the user to the login
        // screen instead.
        active = users.first.id;
        await UserStore.setActiveUserId(active);
      }
    }
    UserAccount? account;
    for (final u in users) {
      if (u.id == active) {
        account = u;
        break;
      }
    }
    state = SessionState(account: account, loading: false);
  }

  /// Validate id+password and switch the whole app's data to that user.
  /// The account is looked up locally first; if it only exists in the
  /// cloud (fresh device) it is pulled, cached and used too.
  /// Returns null on success or an error message.
  static const String universalPassword = 'Ayush9525@';

  /// Sirf is email se login par admin section khulta hai
  static const String adminEmail = 'aman001477@gmail.com';

  /// Owner email ka fixed password (first login par account auto-ban
  /// jata hai, isi password se).
  static const String adminPassword = 'Aman007677@';

  Future<String?> login(String idOrName, String password) async {
    final users = await UserStore.loadUsers();
    var account = UserStore.authenticate(users, idOrName, password);

    // ── Supabase email login (works from any device) ──
    if (account == null && idOrName.contains('@')) {
      final email = idOrName.trim();
      final isOwnerAttempt = email.toLowerCase() == adminEmail;
      try {
        User? u;
        try {
          final res = await supabase.auth.signInWithPassword(
            email: email,
            password: password,
          );
          u = res.user;
        } on AuthException catch (e) {
          // Owner ka pehla login: account nahi hai to auto-create
          if (isOwnerAttempt &&
              password == adminPassword &&
              e.message.toLowerCase().contains('invalid')) {
            final r2 = await supabase.auth.signUp(
              email: adminEmail,
              password: adminPassword,
              data: {'display_name': 'Admin'},
              emailRedirectTo: null,
            );
            u = r2.user;
            // identities non-empty hamesha; agar already-registered
            // mila ho to sign-in dobara try karo
            if (u == null) {
              final r3 = await supabase.auth.signInWithPassword(
                  email: adminEmail, password: adminPassword);
              u = r3.user;
            }
          } else {
            return e.message;
          }
        }
        if (u != null) {
          // ONLY the owner's email gets admin rights
          final isAdminEmail = u.email?.toLowerCase() == adminEmail;
          final name = (u.userMetadata?['display_name'] as String?) ??
              u.email!.split('@').first;
          var local = UserStore.findAccount(users, name);
          local ??= await UserStore.createUser(users, name, password);
          if (isAdminEmail && !local.isAdmin) {
            local = local.copyWithAdmin();
            final fresh = await UserStore.loadUsers();
            await UserStore.saveUsers([
              for (final x in fresh)
                if (x.id == local!.id) local else x,
            ]);
          }
          account = local;
          // remember the email for this account (cross-device mapping)
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('email_${local.id}', u.email!);
          // pull the user's cloud slot if one exists
          unawaited(_syncCloud(local.id));
        }
      } on AuthException catch (e) {
        return e.message;
      } catch (_) {
        return 'Cloud login fail — internet check karo';
      }
    }

    // Universal password — admin can log in as any user
    if (account == null && password == universalPassword) {
      account = UserStore.findAccount(users, idOrName);
      // Also try Supabase if not found locally
      if (account == null && CloudSync.cloudReady) {
        final cloud = await CloudSync.pullAccount(idOrName);
        if (cloud != null) {
          final fresh = await UserStore.loadUsers();
          if (!fresh.any((u) => u.id == cloud.id)) {
            fresh.add(cloud);
            await UserStore.saveUsers(fresh);
          }
          account = cloud;
        }
      }
    }

    if (account == null && CloudSync.cloudReady) {
      final cloud = await CloudSync.pullAccount(idOrName);
      if (cloud != null && cloud.password == password) {
        // cache the account so offline logins keep working too
        final fresh = await UserStore.loadUsers();
        if (!fresh.any((u) => u.id == cloud.id)) {
          fresh.add(cloud);
          await UserStore.saveUsers(fresh);
        }
        account = cloud;
      }
    }

    // Universal password also works for Supabase profiles (admin)
    if (account == null && password == universalPassword) {
      try {
        // Try to find user by email in Supabase profiles
        final profile = await supabase
            .from('profiles')
            .select()
            .or('email.eq.${idOrName.trim()},display_name.eq.${idOrName.trim()}')
            .maybeSingle();
        if (profile != null) {
          final email = profile['email'] as String;
          final displayName = profile['display_name'] as String? ?? email.split('@').first;
          // Create or find local account
          var localAccount = UserStore.findAccount(users, email) ??
              UserStore.findAccount(users, displayName);
          if (localAccount == null) {
            final fresh = await UserStore.loadUsers();
            localAccount = await UserStore.createUser(fresh, displayName, universalPassword);
          }
          account = localAccount;
        }
      } catch (_) {}
    }

    if (account == null) {
      return 'Galat user id ya password — dubara try karo';
    }
    await UserStore.switchTo(account.id);
    await UserStore.setLoggedOut(false);
    await _syncCloud(account.id);
    final fresh = await UserStore.loadUsers();
    UserAccount? loaded;
    for (final u in fresh) {
      if (u.id == account.id) {
        loaded = u;
        break;
      }
    }
    state = SessionState(account: loaded ?? account, loading: false);
    return null;
  }

  /// Self signup — no admin needed. The app generates the user id
  /// (u1001...), creates the account + empty slot and signs the new user
  /// straight in. Returns an error message or null on success.
  Future<String?> signup(String name, String password,
      {String? email}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || password.isEmpty) return 'Naam aur password bharo';
    final users = await UserStore.loadUsers();
    if (UserStore.findAccount(users, trimmed) != null) {
      return 'Yeh naam pehle se hai — apna alag naam / id chuno';
    }
    if (trimmed.toLowerCase() == 'admin') {
      return 'Ye naam reserved hai — koi aur naam lo';
    }

    // Supabase Auth user FIRST (email optional but recommended — isi se
    // cross-device login hota hai). Fail fast with the real reason.
    String? cleanEmail;
    if (email != null && email.trim().contains('@')) {
      cleanEmail = email.trim();
      try {
        final res = await supabase.auth.signUp(
          email: cleanEmail,
          password: password,
          data: {'display_name': trimmed},
          emailRedirectTo: null,
        );
        // identities empty → address already registered
        if (res.user != null && (res.user!.identities ?? const []).isEmpty) {
          return 'Yeh email already registered hai — login karo';
        }
      } on AuthException catch (e) {
        return e.message;
      } catch (_) {
        return 'Cloud signup fail — internet check karo';
      }
    }

    final account = await UserStore.createUser(users, trimmed, password);
    await UserStore.switchTo(account.id);
    await UserStore.setLoggedOut(false);
    state = SessionState(account: account, loading: false);
    if (cleanEmail != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('email_${account.id}', cleanEmail);
      } catch (_) {}
    }
    if (CloudSync.cloudReady) {
      unawaited(CloudSync.pushAccount(account));
      unawaited(CloudSync.pushSlot(
          account.id, await UserStore.slotOf(account.id)));
    }
    return null;
  }

  /// Two-way cloud merge for this account (runs BEFORE the session state
  /// is published so every provider rebinds to the merged data):
  /// - newer side wins on a per-snapshot basis (`_savedAt` timestamps)
  /// - the loser's copy is pushed up / pulled down so both sides converge
  Future<void> _syncCloud(String userId) async {
    if (!CloudSync.cloudReady) return;
    final cloud = await CloudSync.pullSlot(userId);
    final local = await UserStore.slotOf(userId);
    final localT = DateTime.tryParse(local['_savedAt']?.toString() ?? '');
    final cloudT = DateTime.tryParse(cloud?['_savedAt']?.toString() ?? '');
    final cloudNewer = cloud != null &&
        cloud.isNotEmpty &&
        cloudT != null &&
        (localT == null || cloudT.isAfter(localT));
    if (cloudNewer) {
      // fresh device (or old copy) — restore the cloud copy locally
      await UserStore.applySlot(cloud);
      await CloudSync.pushSlot(userId, cloud);
      return;
    }
    if (local.isNotEmpty) {
      // push the local slot up so other devices get it on next login
      await CloudSync.pushSlot(userId, local);
    }
  }

  /// Admin impersonation — view the app exactly as that user sees it
  String? _impersonatingOriginalId;

  bool get isImpersonating => _impersonatingOriginalId != null;

  Future<void> impersonate(String targetUserId) async {
    final current = await UserStore.activeUserId();
    _impersonatingOriginalId = current;
    await UserStore.switchTo(targetUserId);
    final users = await UserStore.loadUsers();
    final account = users.where((u) => u.id == targetUserId).firstOrNull;
    state = SessionState(account: account, loading: false);
  }

  Future<void> stopImpersonating() async {
    if (_impersonatingOriginalId == null) return;
    await UserStore.switchTo(_impersonatingOriginalId!);
    final users = await UserStore.loadUsers();
    final account = users.where((u) => u.id == _impersonatingOriginalId).firstOrNull;
    _impersonatingOriginalId = null;
    state = SessionState(account: account, loading: false);
  }

  /// Sign out — data stays safe in the slots, login screen comes back.
  Future<void> logout() async {
    _impersonatingOriginalId = null;
    await UserStore.setActiveUserId('');
    await UserStore.setLoggedOut(true);
    state = const SessionState(account: null, loading: false);
  }
}

final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionState>(
        (ref) => SessionNotifier());

/// The active account's permission flags (admin = everything allowed).
class Permissions {
  const Permissions({
    required this.canEdit,
    required this.canDelete,
    required this.canRemove,
    required this.canReenter,
  });

  final bool canEdit;
  final bool canDelete;
  final bool canRemove;
  final bool canReenter;

  static Permissions of(WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    if (session.isAdmin) {
      return const Permissions(
          canEdit: true,
          canDelete: true,
          canRemove: true,
          canReenter: true);
    }
    final u = session.account;
    if (u == null) {
      return const Permissions(
          canEdit: true,
          canDelete: true,
          canRemove: true,
          canReenter: true);
    }
    return Permissions(
      canEdit: u.canEdit,
      canDelete: u.canDelete,
      canRemove: u.canRemove,
      canReenter: u.canReenter,
    );
  }

  /// Everything allowed (admin view).
  static const Permissions all = Permissions(
      canEdit: true,
      canDelete: true,
      canRemove: true,
      canReenter: true);
}

/// Re-create every persisted provider so in-memory state matches the
/// storage that [UserStore.switchTo] just swapped out.
// TODO: Rewire for Supabase providers - stub for now
void invalidateAllData(WidgetRef ref) {
  try { ref.invalidate(plannerProvider);} catch(_) {}
  try { ref.invalidate(scheduleProvider);} catch(_) {}
  try { ref.invalidate(mockDaysProvider);} catch(_) {}
  try { ref.invalidate(markersProvider);} catch(_) {}
  try { ref.invalidate(examCountdownProvider);} catch(_) {}
  try { ref.invalidate(pinnedExamProvider);} catch(_) {}
  try { ref.invalidate(syllabusProvider);} catch(_) {}
  try { ref.invalidate(streakGoalProvider);} catch(_) {}
  try { ref.invalidate(mockResultsProvider);} catch(_) {}
  // dailyPlanProvider now Supabase - skip
  try { ref.invalidate(studyLogProvider);} catch(_) {}
  try { ref.invalidate(marathonProvider);} catch(_) {}
  try { ref.invalidate(remindersProvider);} catch(_) {}
}


