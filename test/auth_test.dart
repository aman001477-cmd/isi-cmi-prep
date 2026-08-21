import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:isi_cmi_prep/core/auth/user_store.dart';
import 'package:isi_cmi_prep/features/admin/admin_page.dart';
import 'package:isi_cmi_prep/features/planner/planner_widgets.dart';
import 'package:isi_cmi_prep/main.dart';

void setWide(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

const adminJson = {
  'id': 'admin',
  'name': 'Admin',
  'password': 'admin123',
  'isAdmin': true,
};

const rahulJson = {
  'id': 'u1001',
  'name': 'Rahul',
  'password': 'pass1',
  'isAdmin': false,
  'canEdit': true,
  'canDelete': true,
  'canRemove': true,
  'canReenter': true,
};

void seedUsers({bool loggedOut = true, bool rahul = true}) {
  SharedPreferences.setMockInitialValues({
    'users_v1': jsonEncode([
      adminJson,
      if (rahul) rahulJson,
    ]),
    'active_user_id': '',
    'logged_out_v1': loggedOut,
  });
}

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: ISICMIPrepApp()));
  await tester.pumpAndSettle();
}

Future<void> login(
    WidgetTester tester, String id, String password) async {
  await tester.enterText(find.byKey(const Key('login-id')), id);
  await tester.enterText(find.byKey(const Key('login-password')), password);
  await tester.tap(find.byKey(const Key('login-submit')));
  await tester.pumpAndSettle();
}

void main() {
  group('auth — login gate', () {
    testWidgets('first run opens straight into the admin dashboard',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      setWide(tester);
      await pumpApp(tester);
      expect(find.byKey(const Key('login-page')), findsNothing);
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Admin'), findsWidgets); // admin tab visible
    });

    testWidgets('explicit logout returns to the login screen', (tester) async {
      SharedPreferences.setMockInitialValues({
        'users_v1': jsonEncode([adminJson]),
        'active_user_id': 'admin',
      });
      setWide(tester);
      await pumpApp(tester);
      expect(find.text('Dashboard'), findsWidgets);

      await tester.tap(find.byKey(const Key('profile-chip')));
      await tester.pumpAndSettle();
      expect(find.text('Signed in as'), findsOneWidget);
      await tester.tap(find.byKey(const Key('profile-logout')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login-page')), findsOneWidget);
    });

    testWidgets('user can sign in with their id + password', (tester) async {
      seedUsers();
      setWide(tester);
      await pumpApp(tester);
      expect(find.byKey(const Key('login-page')), findsOneWidget);

      await login(tester, 'u1001', 'pass1');
      expect(find.byKey(const Key('login-page')), findsNothing);
      expect(find.text('Dashboard'), findsWidgets);
      // a normal user never sees the Admin tab
      expect(find.text('Admin'), findsNothing);
    });

    testWidgets('wrong password shows an error and stays on login',
        (tester) async {
      seedUsers();
      setWide(tester);
      await pumpApp(tester);

      await login(tester, 'u1001', 'nope');
      expect(find.byKey(const Key('login-page')), findsOneWidget);
      expect(find.byKey(const Key('login-error')), findsOneWidget);
    });

    testWidgets('a new user can create their own account and gets signed in',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'users_v1': jsonEncode([adminJson]),
        'logged_out_v1': true,
      });
      setWide(tester);
      await pumpApp(tester);
      expect(find.byKey(const Key('login-page')), findsOneWidget);

      await tester.tap(find.byKey(const Key('signup-toggle')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('signup-name')), 'Priya Sharma');
      await tester.enterText(
          find.byKey(const Key('login-password')), 'priya123');
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login-page')), findsNothing);
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Admin'), findsNothing); // normal user

      final prefs = await SharedPreferences.getInstance();
      final users =
          (jsonDecode(prefs.getString('users_v1')!) as List)
              .cast<Map<String, dynamic>>();
      final priya = users.firstWhere((u) => u['name'] == 'Priya Sharma');
      expect(priya['id'], startsWith('u'));
      expect(priya['isAdmin'], isFalse);
      // the device is now signed in as her
      expect(prefs.getString('active_user_id'), priya['id']);
      expect(prefs.getBool('logged_out_v1'), isFalse);
    });

    testWidgets('signup rejects an already-used name', (tester) async {
      seedUsers(); // Rahul already exists
      setWide(tester);
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('signup-toggle')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('signup-name')), 'Rahul');
      await tester.enterText(
          find.byKey(const Key('login-password')), 'x123');
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('login-page')), findsOneWidget);
      expect(find.textContaining('pehle se hai'), findsOneWidget);
    });
  });

  group('admin panel', () {
    testWidgets('admin creates a user, opens their details and edits '
        'permissions', (tester) async {
      SharedPreferences.setMockInitialValues({
        'users_v1': jsonEncode([adminJson, rahulJson]),
        'active_user_id': 'admin',
      });
      setWide(tester);
      await pumpApp(tester);

      await tester.tap(find.text('Admin'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('user-card-admin')), findsOneWidget);
      expect(find.byKey(const Key('user-card-u1001')), findsOneWidget);

      // open Rahul and flip his Delete permission off
      await tester.tap(find.byKey(const Key('user-card-u1001')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('user-detail-u1001')), findsOneWidget);
      expect(find.byKey(const Key('perm-edit-u1001')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('perm-delete-u1001')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('perm-delete-u1001')));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      final users =
          (jsonDecode(prefs.getString('users_v1')!) as List)
              .cast<Map<String, dynamic>>();
      final saved = users.firstWhere((u) => u['id'] == 'u1001');
      expect(saved['canDelete'], isFalse);

      // create a brand new user
      await tester.ensureVisible(find.byKey(const Key('admin-add-user')));
      await tester.tap(find.byKey(const Key('admin-add-user')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('admin-user-name')), 'Sneha');
      await tester.enterText(
          find.byKey(const Key('admin-user-password')), 'sneha123');
      await tester.tap(find.byKey(const Key('admin-create-user')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('user-card-u1002')), findsOneWidget);
      final users2 =
          (jsonDecode(prefs.getString('users_v1')!) as List)
              .cast<Map<String, dynamic>>();
      expect(users2.any((u) => u['id'] == 'u1002'), isTrue);
    });
  });

  group('permissions gating', () {
    testWidgets('user without delete permission is blocked with a snackbar',
        (tester) async {
      final today = DateTime.now().toIso8601String().split('T').first;
      SharedPreferences.setMockInitialValues({
        'users_v1': jsonEncode(
            [adminJson, {...rahulJson, 'canDelete': false}]),
        'logged_out_v1': true,
        'slot_u1001': jsonEncode({
          'planner_v1': jsonEncode([
            {'id': 't1', 'title': 'Gate task', 'date': today, 'done': false},
          ]),
        }),
      });
      setWide(tester);
      await pumpApp(tester);
      await login(tester, 'u1001', 'pass1');

      await tester.tap(find.text('To Do List'));
      await tester.pumpAndSettle();
      expect(find.text('Gate task'), findsOneWidget);

      final deleteIcon = find.descendant(
        of: find.byType(PlannerTaskCard).first,
        matching: find.byIcon(Icons.delete_outline),
      );
      await tester.tap(deleteIcon);
      await tester.pump();
      expect(find.textContaining('Delete band hai'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Gate task'), findsOneWidget); // still there
    });

    testWidgets('admin can delete a task from the user editor', (tester) async {
      final today = DateTime.now().toIso8601String().split('T').first;
      SharedPreferences.setMockInitialValues({
        'users_v1': jsonEncode([adminJson, {...rahulJson, 'canDelete': false}]),
        'active_user_id': 'admin',
        'slot_u1001': jsonEncode({
          'planner_v1': jsonEncode([
            {'id': 't1', 'title': 'Gate task', 'date': today, 'done': false},
          ]),
        }),
      });
      setWide(tester);
      await pumpApp(tester);
      await tester.tap(find.text('Admin'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('user-card-u1001')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('task-edit-0')), findsOneWidget);
      await tester.tap(find.byKey(const Key('task-delete-0')));
      await tester.pumpAndSettle();
      final slot = await UserStore.slotOf('u1001');
      expect(parseTasks(slot['planner_v1']), isEmpty);
    });
  });

  group('UserStore slots', () {
    test('switchTo keeps each user data in its own slot', () async {
      SharedPreferences.setMockInitialValues({});
      final users = await UserStore.loadUsers();
      await UserStore.createUser(users, 'Rahul', 'pass1');
      await UserStore.switchTo('u1001');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('planner_v1', jsonEncode([{'id': 't1'}]));

      await UserStore.switchTo('admin');
      // Rahul's data is untouched inside his slot
      final rahulSlot = await UserStore.slotOf('u1001');
      expect(rahulSlot['planner_v1'], jsonEncode([{'id': 't1'}]));
      // admin's live area is empty now (fresh default)
      expect(prefs.getString('planner_v1'), isNull);
    });

    test('per-user backup round-trips', () async {
      final slot = {'planner_v1': jsonEncode([{'id': 't1'}])};
      final raw = UserStore.encodeUserBackup('u1001', slot);
      final decoded = UserStore.decodeUserBackup(raw);
      expect(decoded, isNotNull);
      expect(decoded!['planner_v1'], slot['planner_v1']);

      expect(UserStore.decodeUserBackup('{"bad": true}'), isNull);
      expect(UserStore.decodeUserBackup('not json'), isNull);
    });
  });
}