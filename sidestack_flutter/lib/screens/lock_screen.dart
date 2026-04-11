import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LockScreen extends StatelessWidget {
  final VoidCallback onUnlock;
  final bool authenticating;
  const LockScreen(
      {super.key, required this.onUnlock, required this.authenticating});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.of(context).background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Lock icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.accentDim,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.lock_outline_rounded,
                        size: 36, color: AppTheme.accent),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'SideStacks is locked',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.of(context).textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Authenticate to access your stacks',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.of(context).textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                if (authenticating)
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      color: AppTheme.accent,
                      strokeWidth: 2.5,
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onUnlock,
                      icon: const Icon(Icons.fingerprint, size: 20),
                      label: const Text('Unlock',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
