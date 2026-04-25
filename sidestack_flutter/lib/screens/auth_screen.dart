import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

const _kPrivacyUrl = 'https://lantianxiao99-ux.github.io/sidestacks-legal/privacy.html';
const _kTermsUrl   = 'https://lantianxiao99-ux.github.io/sidestacks-legal/terms.html';

Future<void> _openUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _usernameError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    final auth = context.read<AuthProvider>();
    setState(() => _isSubmitting = true);
    bool success;
    if (_tabController.index == 0) {
      success = await auth.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } else {
      // Validate name fields
      if (_firstNameController.text.trim().isEmpty ||
          _lastNameController.text.trim().isEmpty) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your first and last name')),
        );
        return;
      }
      // Validate username
      final username = _usernameController.text.trim();
      if (username.isEmpty) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please choose a username')),
        );
        return;
      }
      final usernameErr = await auth.checkUsername(username);
      if (usernameErr != null) {
        setState(() { _usernameError = usernameErr; _isSubmitting = false; });
        return;
      }
      // Validate passwords
      if (_passwordController.text != _confirmPasswordController.text) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match')),
        );
        return;
      }
      success = await auth.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
        _firstNameController.text.trim(),
        _lastNameController.text.trim(),
        username,
      );
      if (success && mounted) {
        // Immediately set username as their display preference
        context.read<AppProvider>().setUsername(username);
      }
    }
    setState(() => _isSubmitting = false);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Something went wrong'),
          backgroundColor: AppTheme.red,
        ),
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isSubmitting = true);
    final auth = context.read<AuthProvider>();
    final success = await auth.signInWithGoogle();
    if (!mounted) return; // widget may have unmounted if sign-in navigated away
    setState(() => _isSubmitting = false);
    if (!success && auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error!), backgroundColor: AppTheme.red),
      );
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isSubmitting = true);
    final auth = context.read<AuthProvider>();
    final success = await auth.signInWithApple();
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (!success && auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error!), backgroundColor: AppTheme.red),
      );
    }
  }

  void _showForgotPasswordSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.of(context).surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => _ForgotPasswordSheet(
        prefillValue: _emailController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // ── Account linking UI ─────────────────────────────────────────────────
    // Shown when Apple/Google sign-in detects an existing account with the
    // same email. The user enters their password to merge both into one account.
    if (auth.needsAccountLink) {
      return _AccountLinkScreen(email: auth.pendingLinkEmail ?? '');
    }

    return Scaffold(
      backgroundColor: AppTheme.of(context).background,
      body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),
                  Center(
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(
                            'assets/logo_white.png',
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('SideStacks',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                        const SizedBox(height: 6),
                        Text('Track your hustles. Know your profit.',
                            style: TextStyle(fontSize: 14, color: AppTheme.of(context).textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppTheme.of(context).card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.of(context).border),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      onTap: (_) => setState(() {}),
                      indicator: BoxDecoration(color: AppTheme.of(context).cardAlt, borderRadius: BorderRadius.circular(9)),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelStyle: TextStyle(fontFamily: 'Sora', fontSize: 12, fontWeight: FontWeight.w600),
                      labelColor: AppTheme.of(context).textPrimary,
                      unselectedLabelColor: AppTheme.of(context).textSecondary,
                      tabs: const [Tab(text: 'Sign In'), Tab(text: 'Create Account')],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_tabController.index == 1) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel('First name'),
                              TextField(
                                controller: _firstNameController,
                                style: TextStyle(fontSize: 14, color: AppTheme.of(context).textPrimary),
                                decoration: const InputDecoration(hintText: 'Jordan'),
                                textCapitalization: TextCapitalization.words,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel('Last name'),
                              TextField(
                                controller: _lastNameController,
                                style: TextStyle(fontSize: 14, color: AppTheme.of(context).textPrimary),
                                decoration: const InputDecoration(hintText: 'Dawes'),
                                textCapitalization: TextCapitalization.words,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel('Username'),
                    TextField(
                      controller: _usernameController,
                      style: TextStyle(fontSize: 14, color: AppTheme.of(context).textPrimary),
                      decoration: InputDecoration(
                        hintText: 'jordandawes',
                        prefixText: '@',
                        errorText: _usernameError,
                        helperText: 'Letters, numbers and underscores only',
                        helperStyle: TextStyle(fontSize: 10, color: AppTheme.of(context).textMuted),
                      ),
                      keyboardType: TextInputType.visiblePassword,
                      autocorrect: false,
                      onChanged: (_) { if (_usernameError != null) setState(() => _usernameError = null); },
                    ),
                    const SizedBox(height: 14),
                  ],

                  _FieldLabel(_tabController.index == 0 ? 'Email or username' : 'Email'),
                  TextField(
                    controller: _emailController,
                    style: TextStyle(fontSize: 14, color: AppTheme.of(context).textPrimary),
                    decoration: InputDecoration(hintText: _tabController.index == 0 ? 'you@example.com or @username' : 'you@example.com'),
                    keyboardType: _tabController.index == 0 ? TextInputType.text : TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),

                  _FieldLabel('Password'),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: TextStyle(fontSize: 14, color: AppTheme.of(context).textPrimary),
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 18, color: AppTheme.of(context).textMuted,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (_tabController.index == 1) ...[
                    _FieldLabel('Confirm password'),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscurePassword,
                      style: TextStyle(fontSize: 14, color: AppTheme.of(context).textPrimary),
                      decoration: const InputDecoration(hintText: '••••••••'),
                    ),
                    const SizedBox(height: 24),
                  ] else ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: _showForgotPasswordSheet,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('Forgot password?',
                              style: TextStyle(fontSize: 12, color: AppTheme.accent, fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  PrimaryButton(
                    label: _isSubmitting ? 'Please wait...' : (_tabController.index == 0 ? 'Sign In' : 'Create Account'),
                    onPressed: _isSubmitting ? null : _submitEmail,
                  ),
                  const SizedBox(height: 16),

                  Row(children: [
                    Expanded(child: Divider(color: AppTheme.of(context).border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or', style: TextStyle(fontSize: 12, color: AppTheme.of(context).textMuted)),
                    ),
                    Expanded(child: Divider(color: AppTheme.of(context).border)),
                  ]),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : _signInWithGoogle,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppTheme.of(context).border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 18, height: 18,
                            decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(4)),
                            child: const Center(child: Text('G', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white))),
                          ),
                          const SizedBox(width: 10),
                          Text('Continue with Google',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.of(context).textPrimary)),
                        ],
                      ),
                    ),
                  ),
                  if (Platform.isIOS) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : _signInWithApple,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppTheme.of(context).border),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.apple, size: 20, color: AppTheme.of(context).textPrimary),
                            const SizedBox(width: 8),
                            Text('Continue with Apple',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.of(context).textPrimary)),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),
                  Center(
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.of(context).textMuted),
                        children: [
                          const TextSpan(text: 'By continuing you agree to our '),
                          TextSpan(
                            text: 'Terms of Service',
                            style: const TextStyle(
                                color: AppTheme.accent,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.underline),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => _openUrl(_kTermsUrl),
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: const TextStyle(
                                color: AppTheme.accent,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.underline),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => _openUrl(_kPrivacyUrl),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Forgot password / forgot username bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ForgotPasswordSheet extends StatefulWidget {
  final String prefillValue;
  const _ForgotPasswordSheet({this.prefillValue = ''});

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  late final TextEditingController _ctrl;
  final TextEditingController _emailForUsernameCtrl = TextEditingController();

  bool _loading = false;
  bool _sent = false;
  String? _error;

  // Forgot-username sub-flow
  bool _showUsernameRecovery = false;
  bool _lookingUpUsername = false;
  String? _foundUsername;
  String? _usernameError;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.prefillValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _emailForUsernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final value = _ctrl.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Please enter your email or username.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final auth = context.read<AuthProvider>();
    final success = await auth.resetPassword(value);
    if (!mounted) return;
    if (success) {
      setState(() { _loading = false; _sent = true; });
    } else {
      setState(() { _loading = false; _error = auth.error ?? 'Something went wrong.'; });
    }
  }

  Future<void> _lookUpUsername() async {
    final email = _emailForUsernameCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _usernameError = 'Enter a valid email address.');
      return;
    }
    setState(() { _lookingUpUsername = true; _usernameError = null; _foundUsername = null; });
    final auth = context.read<AuthProvider>();
    final username = await auth.lookupUsernameByEmail(email);
    if (!mounted) return;
    if (username != null) {
      setState(() { _lookingUpUsername = false; _foundUsername = username; });
    } else {
      setState(() {
        _lookingUpUsername = false;
        _usernameError = 'No account found with that email.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),

            // ── Password reset ─────────────────────────────────────────────
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.accentDim,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lock_reset_outlined,
                    size: 18, color: AppTheme.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reset your password',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary)),
                    Text('We\'ll email you a reset link',
                        style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 20),

            if (_sent) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.greenDim,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.green.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.mark_email_read_outlined,
                      size: 22, color: AppTheme.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Check your inbox!',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.green)),
                        Text('We\'ve sent a password reset link. It may take a minute to arrive.',
                            style: TextStyle(
                                fontSize: 12, color: colors.textSecondary, height: 1.4)),
                      ],
                    ),
                  ),
                ]),
              ),
            ] else ...[
              TextField(
                controller: _ctrl,
                autofocus: true,
                keyboardType: TextInputType.text,
                style: TextStyle(fontSize: 14, color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'you@example.com or @username',
                  hintStyle: TextStyle(color: colors.textMuted, fontSize: 13),
                  errorText: _error,
                ),
                onSubmitted: (_) => _sendResetEmail(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onPressed: _loading ? null : _sendResetEmail,
                  child: _loading
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Send reset email',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],

            const SizedBox(height: 28),
            Divider(color: colors.border),
            const SizedBox(height: 16),

            // ── Forgot username sub-flow ───────────────────────────────────
            GestureDetector(
              onTap: () => setState(() {
                _showUsernameRecovery = !_showUsernameRecovery;
                _foundUsername = null;
                _usernameError = null;
              }),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: colors.cardAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.alternate_email,
                      size: 18, color: colors.textSecondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Forgot your username?',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary)),
                      Text('Look it up using your email address',
                          style: TextStyle(
                              fontSize: 12, color: colors.textSecondary)),
                    ],
                  ),
                ),
                Icon(
                  _showUsernameRecovery
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 20, color: colors.textMuted,
                ),
              ]),
            ),

            if (_showUsernameRecovery) ...[
              const SizedBox(height: 16),
              if (_foundUsername != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.accentDim,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your username is:',
                          style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                      const SizedBox(height: 4),
                      Text('@$_foundUsername',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accent,
                              letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _emailForUsernameCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(fontSize: 14, color: colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Email address on your account',
                    hintStyle: TextStyle(color: colors.textMuted, fontSize: 13),
                    errorText: _usernameError,
                  ),
                  onSubmitted: (_) => _lookUpUsername(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.border),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    onPressed: _lookingUpUsername ? null : _lookUpUsername,
                    child: _lookingUpUsername
                        ? SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                color: colors.textMuted, strokeWidth: 2))
                        : Text('Find my username',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary)),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.of(context).textMuted, letterSpacing: 0.8),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Account linking screen
//
// Shown when Apple/Google sign-in detects an existing email/password account
// with the same email. The user enters their password once to merge both
// sign-in methods into a single account — after that, Apple, Google, and
// email/password all reach the same data.
// ─────────────────────────────────────────────────────────────────────────────

class _AccountLinkScreen extends StatefulWidget {
  final String email;
  const _AccountLinkScreen({required this.email});

  @override
  State<_AccountLinkScreen> createState() => _AccountLinkScreenState();
}

class _AccountLinkScreenState extends State<_AccountLinkScreen> {
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    final password = _passwordCtrl.text;
    if (password.isEmpty) {
      setState(() => _error = 'Please enter your password.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final auth = context.read<AuthProvider>();
    final err = await auth.linkAccountWithEmailPassword(password);
    if (!mounted) return;
    if (err != null) {
      setState(() { _loading = false; _error = err; });
    }
    // On success, authStateChanges fires → RootScreen navigates to main app.
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: AppTheme.accentDim,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.link, size: 30, color: AppTheme.accent),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'One account found',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'An existing SideStacks account is linked to\n${widget.email}\n\nEnter your password to connect your sign-in method and keep all your data in one place.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: colors.textSecondary, height: 1.5),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Email display (read-only)
              _FieldLabel('Email'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: colors.cardAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Text(widget.email,
                    style: TextStyle(fontSize: 14, color: colors.textPrimary)),
              ),
              const SizedBox(height: 16),

              // Password field
              _FieldLabel('Password'),
              StatefulBuilder(
                builder: (ctx, setO) => TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  autofocus: true,
                  style: TextStyle(fontSize: 14, color: colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Your SideStacks password',
                    hintStyle: TextStyle(color: colors.textMuted, fontSize: 13),
                    errorText: _error,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 18, color: colors.textMuted,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  onSubmitted: (_) => _loading ? null : _link(),
                ),
              ),
              const SizedBox(height: 28),

              // Link button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _loading ? null : _link,
                  child: _loading
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Link accounts & continue',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 14),

              // Cancel — goes back to the normal auth screen
              Center(
                child: GestureDetector(
                  onTap: () => context.read<AuthProvider>().cancelAccountLink(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Cancel',
                        style: TextStyle(fontSize: 13, color: colors.textMuted, fontWeight: FontWeight.w500)),
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
