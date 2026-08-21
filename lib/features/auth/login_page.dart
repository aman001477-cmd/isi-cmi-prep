import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_provider.dart';
import '../../core/auth/user_store.dart';
import '../../core/theme/app_design_system.dart';
import '../../core/theme/app_logo.dart';

/// First screen — every user signs in with their id + password.
/// Accounts can be created two ways: the admin panel (admin creates
/// users) or right here — "New user? Create account" (self signup).
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _passController = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  bool _signupMode = false;
  String? _error;
  String _hint = '';

  @override
  void initState() {
    super.initState();
    _loadHint();
  }

  Future<void> _loadHint() async {
    final users = await UserStore.loadUsers();
    if (!mounted) return;
    final hasUsers = users.where((u) => !u.isAdmin).isNotEmpty;
    setState(() {
      _hint = hasUsers
          ? 'Admin ya user id + password se login karo'
          : 'Default admin login: admin / admin123';
    });
  }

  Future<void> _login() async {
    final id = _idController.text.trim();
    final pass = _passController.text;
    if (id.isEmpty || pass.isEmpty) {
      setState(() => _error = 'User id aur password dono bharo');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await ref.read(sessionProvider.notifier).login(id, pass);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  Future<void> _signup() async {
    final name = _nameController.text.trim();
    final pass = _passController.text;
    if (name.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Naam aur password dono bharo');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await ref.read(sessionProvider.notifier).signup(name, pass);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    final acc = ref.read(sessionProvider).account;
    if (acc != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Account ready — aapki user id: ${acc.id}. Isi se aage login karo.'),
        duration: const Duration(seconds: 5),
      ));
    }
  }

  Future<void> _submit() => _signupMode ? _signup() : _login();

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < 700;

    final card = Container(
      width: narrow ? width * 0.92 : 380,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 30,
              offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.standard),
              ),
              child: AppLogoGlyph(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Text(
              'PREP',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Sign in to your study space',
              style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!_signupMode) ...[
            TextField(
              key: const Key('login-id'),
              controller: _idController,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'User ID',
                hintText: 'admin / u1001 / name',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ] else ...[
            TextField(
              key: const Key('signup-name'),
              controller: _nameController,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Your name',
                hintText: 'Jaise: Priya Sharma',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('login-password'),
            controller: _passController,
            enabled: !_busy,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              key: const Key('login-error'),
              style: AppTypography.caption.copyWith(
                  color: AppColors.danger, fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 48,
            child: FilledButton(
              key: const Key('login-submit'),
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_signupMode ? 'Create account' : 'Login',
                      style:
                          const TextStyle(fontSize: 15, letterSpacing: 0.8)),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            key: const Key('signup-toggle'),
            onPressed: _busy
                ? null
                : () => setState(() {
                      _signupMode = !_signupMode;
                      _error = null;
                    }),
            child: Text(
              _signupMode
                  ? 'Already have an account? Login'
                  : 'New user? Create your own account',
              style: AppTypography.caption.copyWith(
                  color: AppColors.accent, fontWeight: FontWeight.w700),
            ),
          ),
          if (_hint.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _hint,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );

    return Scaffold(
      key: const Key('login-page'),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.canvas,
              AppColors.accent.withValues(alpha: 0.07),
              AppColors.canvas,
            ],
          ),
        ),
        child: Center(child: SingleChildScrollView(child: card)),
      ),
    );
  }
}
