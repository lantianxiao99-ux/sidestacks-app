import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// UsernameSetupScreen
//
// Shown once to Google/Apple users after their first sign-in, before they
// reach the main app. Lets them choose a username and optionally edit the
// name pulled from their OAuth profile.
// ─────────────────────────────────────────────────────────────────────────────

class UsernameSetupScreen extends StatefulWidget {
  const UsernameSetupScreen({super.key});

  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final _usernameCtrl = TextEditingController();
  String? _usernameError;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameCtrl.text.trim();
    final auth = context.read<AuthProvider>();

    // Local format check first (avoids a Firestore round-trip for obvious errors)
    final localError = await auth.checkUsername(username);
    if (localError != null) {
      setState(() => _usernameError = localError);
      return;
    }

    setState(() { _isSubmitting = true; _usernameError = null; });

    final success = await auth.completeOAuthSetup(username);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      // Store username as their in-app display preference
      context.read<AppProvider>().setUsername(username);
    } else {
      setState(() => _usernameError = auth.error ?? 'Something went wrong.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final colors = AppTheme.of(context);

    // Name from OAuth profile
    final displayName = auth.userName ?? '';
    final firstName = displayName.split(' ').first;

    // Provider-specific copy
    final providerName = auth.signInProvider; // 'Google' or 'Apple'
    final providerIcon = providerName == 'Apple'
        ? Icons.apple
        : Icons.g_mobiledata;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),

              // ── Header ────────────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    // Provider badge
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: colors.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.border, width: 1.5),
                      ),
                      child: Icon(providerIcon, size: 32, color: colors.textPrimary),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      firstName.isNotEmpty
                          ? 'Hey $firstName 👋'
                          : 'One last step 👋',
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You\'re signed in with $providerName.\nJust pick a username and you\'re in.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14,
                          color: colors.textSecondary,
                          height: 1.5),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // ── Name display (read-only) ───────────────────────────────────
              if (displayName.isNotEmpty) ...[
                _Label('Your name'),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: colors.cardAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        displayName,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: colors.textPrimary),
                      ),
                    ),
                    Icon(Icons.lock_outline, size: 14, color: colors.textMuted),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 2),
                  child: Text(
                    'Taken from your $providerName account',
                    style: TextStyle(fontSize: 10, color: colors.textMuted),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Username field ────────────────────────────────────────────
              _Label('Choose a username'),
              TextField(
                controller: _usernameCtrl,
                autofocus: true,
                autocorrect: false,
                keyboardType: TextInputType.visiblePassword,
                style: TextStyle(fontSize: 14, color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g. jordandawes',
                  prefixText: '@',
                  errorText: _usernameError,
                  helperText: '3–20 characters · letters, numbers, underscores',
                  helperStyle: TextStyle(fontSize: 10, color: colors.textMuted),
                ),
                onChanged: (_) {
                  if (_usernameError != null) setState(() => _usernameError = null);
                },
                onSubmitted: (_) => _isSubmitting ? null : _submit(),
              ),
              const SizedBox(height: 32),

              // ── CTA ───────────────────────────────────────────────────────
              PrimaryButton(
                label: _isSubmitting ? 'Setting up…' : 'Get started',
                onPressed: _isSubmitting ? null : _submit,
              ),

              const SizedBox(height: 16),

              // ── Sign out escape hatch ─────────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: () => context.read<AuthProvider>().signOut(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Sign out',
                      style: TextStyle(
                          fontSize: 13,
                          color: colors.textMuted,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: AppTheme.of(context).textMuted,
          letterSpacing: 0.8),
    ),
  );
}
