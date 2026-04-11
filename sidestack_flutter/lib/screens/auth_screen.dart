import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

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
  final _nameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;

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
    _nameController.dispose();
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
        _nameController.text.trim(),
      );
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
    setState(() => _isSubmitting = false);
    if (!success && mounted && auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error!), backgroundColor: AppTheme.red),
      );
    }
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email first')),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    final success = await auth.resetPassword(_emailController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Reset email sent! Check your inbox.' : (auth.error ?? 'Failed')),
          backgroundColor: success ? AppTheme.green : AppTheme.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                            'assets/icon.png',
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
                    _FieldLabel('Your name'),
                    TextField(
                      controller: _nameController,
                      style: TextStyle(fontSize: 14, color: AppTheme.of(context).textPrimary),
                      decoration: const InputDecoration(hintText: 'Jordan Dawes'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 14),
                  ],

                  _FieldLabel('Email'),
                  TextField(
                    controller: _emailController,
                    style: TextStyle(fontSize: 14, color: AppTheme.of(context).textPrimary),
                    decoration: const InputDecoration(hintText: 'you@example.com'),
                    keyboardType: TextInputType.emailAddress,
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
                        onTap: _resetPassword,
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

                  const SizedBox(height: 32),
                  Center(
                    child: Text(
                      'By continuing you agree to our Terms & Privacy Policy',
                      style: TextStyle(fontSize: 11, color: AppTheme.of(context).textMuted),
                      textAlign: TextAlign.center,
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
