import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─── Transaction confirmation — compact non-blocking toast ───────────────────
//
// Replaces the old full-screen backdrop overlay. A 48px pill slides up from
// the bottom of the screen, holds for 1.2 s, then fades out. The sheet
// dismisses immediately on submit; this toast appears over the dashboard
// without blocking any interaction.

Future<void> showTransactionConfirmation(
  BuildContext context, {
  required bool isIncome,
  required double amount,
  required String symbol,
}) async {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (ctx) => _TransactionToast(
      isIncome: isIncome,
      amount: amount,
      symbol: symbol,
      onDone: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );

  overlay.insert(entry);

  // Auto-remove after animation completes (300ms in + 1200ms hold + 250ms out)
  await Future.delayed(const Duration(milliseconds: 1750));
  if (entry.mounted) entry.remove();
}

class _TransactionToast extends StatefulWidget {
  final bool isIncome;
  final double amount;
  final String symbol;
  final VoidCallback onDone;

  const _TransactionToast({
    required this.isIncome,
    required this.amount,
    required this.symbol,
    required this.onDone,
  });

  @override
  State<_TransactionToast> createState() => _TransactionToastState();
}

class _TransactionToastState extends State<_TransactionToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    _ctrl.forward();

    // Hold, then fade out
    Future.delayed(const Duration(milliseconds: 1200), () async {
      if (mounted) {
        await _ctrl.reverse();
        widget.onDone();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isIncome ? AppTheme.green : AppTheme.expense;
    final sign = widget.isIncome ? '+' : '−';
    final label = widget.isIncome ? 'Income logged' : 'Expense recorded';

    return Positioned(
      bottom: 104, // above bottom nav
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Center(
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: AppTheme.of(context).card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.of(context).border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.of(context).textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$sign${widget.symbol}${widget.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
