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

  static const _features = [
    _Feature(
      icon: Icons.history,
      label: 'Full transaction history',
      sub: 'Free shows last 3 months. Pro unlocks everything',
      highlight: true,
    ),
    _Feature(
      icon: Icons.receipt_long_outlined,
      label: 'PDF invoice generator',
      sub: 'Professional invoices with your payment link. Share in seconds',
    ),
    _Feature(
      icon: Icons.bar_chart,
      label: 'Full analytics suite',
      sub: '14 charts: trends, projections, comparisons, YoY',
    ),
    _Feature(
      icon: Icons.download_outlined,
      label: 'CSV & PDF export',
      sub: 'Export anytime in CSV or PDF, accountant-ready',
    ),
    _Feature(
      icon: Icons.calculate_outlined,
      label: 'Tax estimates',
      sub: 'Quarterly tax estimates based on your real profit',
    ),
    _Feature(
      icon: Icons.camera_alt_outlined,
      label: 'Receipt scanner',
      sub: 'Attach photos to any expense instantly',
    ),
  ];

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
          content: Text('🎉 Pro unlocked. Let\'s get to work!'),
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
          content: Text('✅ Pro restored!'),
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
    if (monthlyAnnualized <= 0) return 'Save 35%';
    final pct = ((1 - annualPrice / monthlyAnnualized) * 100).round();
    return 'Save $pct%';
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final busy = _purchasing || _restoring;

    final monthlyPrice =
        _monthlyPackage?.storeProduct.priceString ?? '\$9.99';
    final annualPrice =
        _annualPackage?.storeProduct.priceString ?? '\$79.99';

    // Per-month equivalent shown under annual
    final annualMonthly = _annualPackage != null
        ? '\$${(_annualPackage!.storeProduct.price / 12).toStringAsFixed(2)}'
        : '\$6.67';

    final displayPrice = _isAnnual ? '$annualMonthly / mo' : '$monthlyPrice / mo';
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
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppTheme.of(context).borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Icon
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset('assets/icon.png', width: 56, height: 56),
            ),
            const SizedBox(height: 16),

            const Text(
              'Your side hustles deserve real tools',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Consumer<AppProvider>(
              builder: (context, provider, _) {
                final totalProfit = provider.stacks.fold<double>(0.0, (sum, stack) => sum + stack.netProfit);
                final currencySymbol = provider.currencySymbol;
                final subtitle = totalProfit > 0
                    ? 'You\'ve earned $currencySymbol${totalProfit.toStringAsFixed(2)} so far. Pro helps you keep more of it.'
                    : 'Track every pound, invoice clients, and see where your money really goes.';
                return Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.of(context).textSecondary,
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // ── Plan toggle ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.of(context).card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.of(context).border),
              ),
              child: Row(
                children: [
                  _PlanToggle(
                    label: 'Annual',
                    badge: _savingsLabel(),
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
            const SizedBox(height: 20),

            // ── Comparison table ───────────────────────────────────────────
            _ComparisonTable(),
            const SizedBox(height: 20),

            // ── Testimonials ────────────────────────────────────────────────
            Column(
              children: const [
                _Testimonial(
                  quote: 'Finally know which of my three hustles is actually worth my time.',
                  name: 'Jamie, 23',
                  role: 'Reseller + freelancer',
                  emoji: '😎',
                ),
                SizedBox(height: 8),
                _Testimonial(
                  quote: 'Sent my first proper invoice in under 2 minutes. Client paid same day.',
                  name: 'Priya, 26',
                  role: 'Freelance designer',
                  emoji: '✨',
                ),
                SizedBox(height: 8),
                _Testimonial(
                  quote: 'The tax estimate card alone saved me a nasty surprise at year end.',
                  name: 'Marcus, 29',
                  role: 'Content creator',
                  emoji: '🙌',
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Price ──────────────────────────────────────────────────────
            _loadingPackage
                ? const SizedBox(
                    height: 36,
                    child: CircularProgressIndicator(
                        color: AppTheme.accent, strokeWidth: 2),
                  )
                : Column(
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: displayPrice.split(' / ')[0],
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.accent,
                                letterSpacing: -0.5,
                                fontFamily: 'Sora',
                              ),
                            ),
                            TextSpan(
                              text: ' / mo',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: AppTheme.of(context).textSecondary,
                                fontFamily: 'Sora',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        billingNote,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.of(context).textMuted,
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: 20),

            // ── CTA ────────────────────────────────────────────────────────
            PrimaryButton(
              label: busy
                  ? (_purchasing ? 'Processing…' : 'Restoring…')
                  : 'Get Pro Access',
              onPressed:
                  (busy || _loadingPackage || _selectedPackage == null)
                      ? null
                      : () => _purchase(context),
            ),
            const SizedBox(height: 10),

            // Restore
            GestureDetector(
              onTap: busy ? null : () => _restore(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _restoring
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.accent),
                      )
                    : Text(
                        'Restore Purchase',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.accent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 2),

            // Dismiss
            GestureDetector(
              onTap: busy ? null : () => Navigator.pop(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Maybe later',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.of(context).textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
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

// ─── Feature row ──────────────────────────────────────────────────────────────

class _Feature {
  final IconData icon;
  final String label;
  final String sub;
  final bool highlight;
  const _Feature(
      {required this.icon, required this.label, required this.sub,
       this.highlight = false});
}

class _FeatureRow extends StatelessWidget {
  final _Feature feature;
  const _FeatureRow({required this.feature});

  @override
  Widget build(BuildContext context) {
    final color = feature.highlight ? AppTheme.green : AppTheme.accent;
    final bgColor = feature.highlight ? AppTheme.greenDim : AppTheme.accentDim;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(feature.icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(feature.label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: feature.highlight ? color : AppTheme.of(context).textPrimary)),
                Text(feature.sub,
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.of(context).textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.check_circle, size: 18, color: AppTheme.green),
        ],
      ),
    );
  }
}

// ─── Comparison table ─────────────────────────────────────────────────────────

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable();

  static const _rows = [
    _CompRow('Transaction history', 'Last 3 months', 'Unlimited'),
    _CompRow('SideStacks', 'Up to 2', 'Unlimited'),
    _CompRow('PDF invoice generator', null, 'Professional + payment link'),
    _CompRow('Full analytics suite', null, '14 charts + projections'),
    _CompRow('CSV & PDF export', null, 'Accountant-ready, anytime'),
    _CompRow('Tax estimates', null, 'Quarterly, auto-calculated'),
    _CompRow('Receipt scanner', null, 'Attach photos to expenses'),
    _CompRow('Cash flow view', null, 'Recurring + invoice forecast'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.of(context).card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.of(context).border),
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.of(context).cardAlt,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(children: [
              const Expanded(child: SizedBox()),
              SizedBox(
                width: 70,
                child: Text(
                  'FREE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.of(context).textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              SizedBox(
                width: 70,
                child: Text(
                  'PRO ⚡',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accent,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ]),
          ),
          // Feature rows
          ..._rows.asMap().entries.map((entry) {
            final i = entry.key;
            final row = entry.value;
            final isLast = i == _rows.length - 1;
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : Border(
                        bottom: BorderSide(
                            color: AppTheme.of(context).border, width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.feature,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: Center(
                      child: row.freeLabel != null
                          ? Text(
                              row.freeLabel!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.of(context).textSecondary),
                            )
                          : const Icon(Icons.close,
                              size: 14, color: AppTheme.red),
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: Center(
                      child: row.proLabel != null
                          ? Text(
                              row.proLabel!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.green),
                            )
                          : const Icon(Icons.check,
                              size: 14, color: AppTheme.green),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _CompRow {
  final String feature;
  final String? freeLabel;
  final String? proLabel;
  const _CompRow(this.feature, this.freeLabel, this.proLabel);
}

// ─── Testimonial card ─────────────────────────────────────────────────────────

class _Testimonial extends StatelessWidget {
  final String quote;
  final String name;
  final String role;
  final String emoji;
  const _Testimonial({
    required this.quote,
    required this.name,
    required this.role,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.of(context).card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.of(context).border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.accentDim,
              shape: BoxShape.circle,
            ),
            child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stars
                Row(
                  children: List.generate(
                    5,
                    (_) => const Icon(Icons.star,
                        size: 11, color: AppTheme.amber),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '"$quote"',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.of(context).textPrimary,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$name · $role',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.of(context).textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Value pillar card ────────────────────────────────────────────────────────

class _ValuePillar extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _ValuePillar({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.of(context).card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.of(context).border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.of(context).textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
