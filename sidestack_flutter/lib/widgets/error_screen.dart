import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Full-screen error widget — used for unexpected Flutter errors and
/// as an inline fallback when a screen fails to load data.
class ErrorScreen extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;
  final bool fullScreen;

  const ErrorScreen({
    super.key,
    this.message,
    this.onRetry,
    this.fullScreen = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppTheme.red.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.error_outline_rounded,
            color: AppTheme.red,
            size: 32,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Something went wrong',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: theme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message ?? 'An unexpected error occurred.\nPlease try again.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: theme.textSecondary,
            height: 1.5,
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 24),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.accent.withOpacity(0.12),
              foregroundColor: AppTheme.accent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Try again',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );

    if (!fullScreen) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: content,
          ),
        ),
      ),
    );
  }
}
