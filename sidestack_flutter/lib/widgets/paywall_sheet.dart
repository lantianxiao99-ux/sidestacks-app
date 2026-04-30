import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../providers/app_provider.dart';
import '../services/purchase_service.dart';
import '../theme/app_theme.dart';
import 'shared_widgets.dart';

Future<void> showPaywallSheet(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _PaywallSheet(),
  );
}

class _PaywallSheet extends StatefulWidget {
  const _PaywallSheet();

  @override
  State<_PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<_PaywallSheet> {
  Package? _monthlyPackage;
  Package? _annualPackage;
  bool _loadingPackage = true;
  bool _purchasing = false;
  bool _restoring = false;
  bool _isAnnual = true; // Default to annual — better value, lower churn

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    final monthly = await PurchaseService.instance.getMonthlyPackage();
    final annual = await PurchaseService.instance.getAnnualPackage();
    if (mounted) {
      setState(() {
        _monthlyPackage = monthly;
        _annualPackage = annual;
        _loadingPackage = false;
        // If no annual package available, fall back to monthly
        if (annual == null && monthly != null) _isAnnual = false;
      });
    }
  }

  Package? get _selectedPackage =>
      _isAnnual ? (_annualPackage ?? _monthlyPackage) : _monthlyPackage;

  // ── Purchase ────────────────────────────────────────────────────────────────

  Future<void> _purchase(BuildContext context) async {
    final pkg = _selectedPackage;
    if (pkg == null) return;

    setState(() => _purchasing = true);
    try {
      await PurchaseService.instance.purchase(pkg);
      if (!mounted) return;
      await context.read<AppProvider>().upgradeToPremium();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pro unlocked. Let\'s get to work!'),
          backgroundColor: AppTheme.green,
        ),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Something went wrong with the purchase. No charge was made. Try again when you\'re ready.',
            style: TextStyle(color: AppTheme.of(context).textPrimary),
          ),
          backgroundColor: AppTheme.of(context).card,
        ),
      );
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  // ── Restore ─────────────────────────────────────────────────────────────────

  Future<void> _restore(BuildContext context) async {
    setState(() => _restoring = true);
    final restored = await context.read<AppProvider>().restorePremium();
    if (!mounted) return;
    setState(() => _restoring = false);
    if (restored) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pro subscription restored!'),
          backgroundColor: AppTheme.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'We couldn\'t find an active subscription. If you\'ve subscribed before, try again or contact support.',
            style: TextStyle(color: AppTheme.of(context).textPrimary),
          ),
          backgroundColor: AppTheme.of(context).card,
        ),
      );
    }
  }

  // ── Savings badge label ─────────────────────────────────────────────────────

  String _savingsLabel() {
    if (_monthlyPackage == null || _annualPackage == null) return 'Save 35%';
    final monthlyAnnualized = _monthlyPackage!.storeProduct.price * 12;
    final annualPrice = _annualPackage!.storeProduct.price;
    if (monthlyAnnualized <= 0) return 'Save 17%';
    final pct = ((1 - annualPrice / monthlyAnnualized) * 100).round();
    return 'Save $pct%';
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final busy = _purchasing || _restoring;

    final monthlyPrice =
        _monthlyPackage?.storeProduct.priceString ?? '\$6.00';
    final annualPrice =
        _annualPackage?.storeProduct.priceString ?? '\$60.00';

    // Per-month equivalent shown under annual
    final annualMonthly = _annualPackage != null
        ? '\$${(_annualPackage!.storeProduct.price / 12).toStringAsFixed(2)}'
        : '\$5.00';

    final displayPrice = _isAnnual ? annualMonthly : monthlyPrice;
    final billingNote = _isAnnual
        ? 'Billed $annualPrice annually · cancel anytime'
        : 'Billed monthly · cancel anytime';

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        color: AppTheme.of(context).surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.of(context).borderLight),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppTheme.of(context).borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Logo + trial chip row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  Theme.of(context).brightness == Brightness.dark
                      ? 'assets/logo_white.png'
                      : 'assets/logo_navy.png',
                  width: 100,
                  fit: BoxFit.contain,
                ),
                const Spacer(),
                Consumer<AppProvider>(
                  builder: (context, provider, _) {
                    if (provider.trialExpired) {
                      return _StatusChip('Trial ended', AppTheme.red);
                    } else if (provider.isInTrial) {
                      return _StatusChip('${provider.trialDaysRemaining}d left in trial', AppTheme.accent);
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Headline + subtitle
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Unlock Pro',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4),
              ),
            ),
            const SizedBox(height: 3),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Everything you need to run your side hustles like a business.',
                style: TextStyle(fontSize: 13, color: AppTheme.of(context).textSecondary, height: 1.4),
              ),
            ),
            const SizedBox(height: 14),

            // ── Plan toggle ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppTheme.of(context).card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.of(context).border),
              ),
              child: Row(
                children: [
                  _PlanToggle(
                    label: 'Annual',
                    badge: null,
                    selected: _isAnnual,
                    onTap: () => setState(() => _isAnnual = true),
                  ),
                  _PlanToggle(
                    label: 'Monthly',
                    badge: null,
                    selected: !_isAnnual,
                    onTap: () => setState(() => _isAnnual = false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Feature list ───────────────────────────────────────────────
            const _ProFeatureList(),
            const SizedBox(height: 14),

            // ── Price row ──────────────────────────────────────────────────
            _loadingPackage
                ? const SizedBox(height: 32, child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2))
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        displayPrice,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accent,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Text(' / mo', style: TextStyle(fontSize: 13, color: AppTheme.accent)),
                      const Spacer(),
                      Text(
                        billingNote,
                        style: TextStyle(fontSize: 10, color: AppTheme.of(context).textMuted),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
            const SizedBox(height: 12),

            // ── CTA ────────────────────────────────────────────────────────
            PrimaryButton(
              label: busy ? (_purchasing ? 'Processing…' : 'Restoring…') : 'Get Pro Access',
              onPressed: (busy || _loadingPackage || _selectedPackage == null)
                  ? null
                  : () => _purchase(context),
            ),
            const SizedBox(height: 6),

            // Restore · Maybe later
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: busy ? null : () => _restore(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: _restoring
                        ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent))
                        : Text('Restore', style: TextStyle(fontSize: 12, color: AppTheme.accent, fontWeight: FontWeight.w500)),
                  ),
                ),
                Text('·', style: TextStyle(color: AppTheme.of(context).textMuted)),
                GestureDetector(
                  onTap: busy ? null : () => Navigator.pop(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text('Maybe later',
                        style: TextStyle(fontSize: 12, color: AppTheme.of(context).textMuted, fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Plan toggle pill ─────────────────────────────────────────────────────────

class _PlanToggle extends StatelessWidget {
  final String label;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  const _PlanToggle({
    required this.label,
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : AppTheme.of(context).textSecondary,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withOpacity(0.22)
                        : AppTheme.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppTheme.green,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Status chip ──────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ─── Pro feature list ─────────────────────────────────────────────────────────

class _ProFeatureList extends StatelessWidget {
  const _ProFeatureList();

  static const _items = [
    _FItem(Icons.layers_outlined,        'Unlimited Stacks',             'Free: up to 2'),
    _FItem(Icons.history,                'Full transaction history',      'Free: last 3 months'),
    _FItem(Icons.receipt_long_outlined,  'PDF invoices & payment links',  null),
    _FItem(Icons.bar_chart,              'Analytics & projections',       null),
    _FItem(Icons.download_outlined,      'CSV & PDF export',              null),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.of(context).card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.of(context).border),
      ),
      child: Column(
        children: _items.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          final isLast = i == _items.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: isLast ? null : BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.of(context).border, width: 0.5)),
            ),
            child: Row(
              children: [
                Icon(item.icon, size: 16, color: AppTheme.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(item.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ),
                if (item.freeNote != null)
                  Text(item.freeNote!, style: TextStyle(fontSize: 10, color: AppTheme.of(context).textMuted)),
                const SizedBox(width: 8),
                const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.green),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FItem {
  final IconData icon;
  final String label;
  final String? freeNote;
  const _FItem(this.icon, this.label, this.freeNote);
}
