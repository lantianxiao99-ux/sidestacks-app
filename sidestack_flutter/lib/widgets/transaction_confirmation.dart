import 'package:flutter/material.dart';

Future<void> showTransactionConfirmation(
  BuildContext context, {
  required bool isIncome,
  required double amount,
  required String symbol,
}) async {
  final overlay = Overlay.of(context);
  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (ctx) => _TransactionConfirmationOverlay(
      isIncome: isIncome,
      amount: amount,
      symbol: symbol,
      onDismissed: () => overlayEntry.remove(),
    ),
  );

  overlay.insert(overlayEntry);

  // Auto-dismiss after 1.5 seconds
  await Future.delayed(const Duration(milliseconds: 1500));
  if (overlayEntry.mounted) {
    overlayEntry.remove();
  }
}

class _TransactionConfirmationOverlay extends StatefulWidget {
  final bool isIncome;
  final double amount;
  final String symbol;
  final VoidCallback onDismissed;

  const _TransactionConfirmationOverlay({
    required this.isIncome,
    required this.amount,
    required this.symbol,
    required this.onDismissed,
  });

  @override
  State<_TransactionConfirmationOverlay> createState() =>
      _TransactionConfirmationOverlayState();
}

class _TransactionConfirmationOverlayState
    extends State<_TransactionConfirmationOverlay> with TickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Bounce curve: scales from 0 to 1.2, then settles to 1.0
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut),
    );

    _scaleCtrl.forward();
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  String get _formattedAmount {
    final sign = widget.isIncome ? '+' : '−';
    return '$sign${widget.symbol}${widget.amount.toStringAsFixed(2)}';
  }

  String get _message {
    return widget.isIncome ? 'Income logged' : 'Expense tracked';
  }

  Color get _accentColor {
    return widget.isIncome
        ? const Color(0xFF22C55E) // green
        : const Color(0xFFEF4444); // red
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Large checkmark icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accentColor.withOpacity(0.15),
                ),
                child: Center(
                  child: Icon(
                    Icons.check_circle,
                    size: 64,
                    color: _accentColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Amount
              Text(
                _formattedAmount,
                style: TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: _accentColor,
                ),
              ),
              const SizedBox(height: 8),

              // Message
              Text(
                _message,
                style: const TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
