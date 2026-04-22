import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../providers/mileage_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import 'mileage_screen.dart';
import '../services/tax_pdf_service.dart';

// ─── Tax-year helpers ─────────────────────────────────────────────────────────
//
// Australian tax year: 1 July → 30 June of the following year.
// e.g.  1 Jul 2025 → 30 Jun 2026  ⟶  label "FY2025-26"

DateTime _auTaxYearStart(DateTime ref) {
  // If before July 1, the FY started in the prior calendar year
  return ref.month < 7
      ? DateTime(ref.year - 1, 7, 1)
      : DateTime(ref.year, 7, 1);
}

DateTime _auTaxYearEnd(DateTime ref) {
  final start = _auTaxYearStart(ref);
  return DateTime(start.year + 1, 6, 30, 23, 59, 59);
}

/// Returns a label like "FY2025-26" for the Australian tax year containing [ref].
String taxYearLabel(DateTime ref) {
  final start = _auTaxYearStart(ref);
  final endShort = (start.year + 1) % 100;
  return 'FY${start.year}-${endShort.toString().padLeft(2, '0')}';
}

// GST threshold in AUD — once annual turnover exceeds this, registration is required.
const double kGstThreshold = 75000.0;
// Australian GST rate
const double kGstRate = 0.10;

// Known deductible categories (mirrors analytics_screen constant list)
const _kDeductibleCategories = {
  'Software',
  'Tools & Equipment',
  'Marketing',
  'Professional Services',
  'Travel',
  'Home Office',
  'Training',
  'Subscriptions',
  'Phone & Internet',
  'Office Supplies',
};

// ATO cents-per-km rate for 2024-25 (85c/km, no log required up to 5,000 km)
const double _kRatePerKm = 0.85;

// ─── Screen ───────────────────────────────────────────────────────────────────

class TaxScreen extends StatefulWidget {
  const TaxScreen({super.key});

  @override
  State<TaxScreen> createState() => _TaxScreenState();
}

class _TaxScreenState extends State<TaxScreen> {
  // 0 = current tax year, -1 = one year back, etc.
  int _yearOffset = 0;
  bool _generating = false;

  // ── AU financial year helpers ──────────────────────────────────────────────
  // The "reference" date used to compute the active tax year window.
  DateTime get _ref {
    final now = DateTime.now();
    if (_yearOffset == 0) return now;
    final start = _auTaxYearStart(now);
    return DateTime(start.year + _yearOffset, start.month, start.day);
  }

  Future<void> _generateSummary(
      BuildContext ctx, AppProvider provider, bool isAU) async {
    setState(() => _generating = true);
    try {
      await shareTaxReportPdf(
        context: ctx,
        allTransactions: provider.allTransactions,
        year: isAU ? _auYearStart.year : _calYear,
        taxRate: provider.taxRate,
        currencySymbol: provider.currencySymbol,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text('Could not generate summary: $e'),
          backgroundColor: AppTheme.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  DateTime get _auYearStart => _auTaxYearStart(_ref);
  DateTime get _auYearEnd   => _auTaxYearEnd(_ref);
  String   get _auYearLabel => taxYearLabel(_ref);

  // ── Calendar year helpers (non-AU) ────────────────────────────────────────
  int get _calYear => DateTime.now().year + _yearOffset;
  DateTime get _calYearStart => DateTime(_calYear, 1, 1);
  DateTime get _calYearEnd   => DateTime(_calYear, 12, 31, 23, 59, 59);
  String   get _calYearLabel => '$_calYear';

  // ── Resolved helpers (pick AU vs calendar based on mode) ─────────────────
  DateTime _resolvedYearStart(bool isAU) =>
      isAU ? _auYearStart : _calYearStart;
  DateTime _resolvedYearEnd(bool isAU) =>
      isAU ? _auYearEnd : _calYearEnd;
  String _resolvedYearLabel(bool isAU) =>
      isAU ? _auYearLabel : _calYearLabel;

  bool _inYear(DateTime d, bool isAU) {
    final start = _resolvedYearStart(isAU);
    final end   = _resolvedYearEnd(isAU);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final mileage  = context.watch<MileageProvider>();
    final sym      = provider.currencySymbol;
    final isAU     = provider.isAustraliaMode;

    // ── Transactions for the active tax year ─────────────────────────────────
    final txs      = provider.allTransactions.where((t) => _inYear(t.date, isAU)).toList();
    final income   = txs.where((t) => t.type == TransactionType.income)
                       .fold(0.0, (s, t) => s + t.amount);
    final expenses = txs.where((t) => t.type == TransactionType.expense)
                       .fold(0.0, (s, t) => s + t.amount);
    final profit   = income - expenses;

    // ── Deductible expenses ───────────────────────────────────────────────────
    final deductible = txs.where((t) =>
        t.type == TransactionType.expense &&
        _kDeductibleCategories.contains(t.category)).toList();
    final totalDeductible = deductible.fold(0.0, (s, t) => s + t.amount);

    // ── Mileage for this year ─────────────────────────────────────────────────
    final mileTrips = mileage.trips.where((t) => _inYear(t.date, isAU)).toList();
    final mileageKm = mileTrips.fold(0.0, (s, t) => s + t.distanceKm);
    // AU: ATO caps at 5,000 km/year and uses fixed rate; non-AU: no cap, configurable rate
    final mileageRate   = isAU ? _kRatePerKm : provider.customMileageRate;
    final mileageCapKm  = isAU ? 5000.0 : double.infinity;
    final clampedKm     = mileageCapKm.isInfinite
        ? mileageKm
        : mileageKm.clamp(0, mileageCapKm).toDouble();
    final mileageDeduction = clampedKm * mileageRate;
    final mileRateLabel    = isAU
        ? '\$0.85/km'
        : '${provider.mileageUseKm ? 'km' : 'mi'} @ \$${mileageRate.toStringAsFixed(2)}';

    // ── Tax estimate ──────────────────────────────────────────────────────────
    final totalAllowances  = totalDeductible + mileageDeduction;
    final taxableProfit    = (profit - mileageDeduction).clamp(0, double.infinity).toDouble();
    final estimatedTax     = taxableProfit * provider.taxRate;

    // ── GST (BAS) calculations — AU only ─────────────────────────────────────
    final double gstCollected, gstCredits, gstPayable;
    final bool hasGstData;
    if (isAU) {
      final gstIncomeTxs = txs.where(
          (t) => t.type == TransactionType.income && t.includesGst).toList();
      gstCollected = gstIncomeTxs.fold(0.0, (s, t) => s + (t.amount / 11));
      final gstExpenseTxs = txs.where(
          (t) => t.type == TransactionType.expense && t.includesGst).toList();
      gstCredits = gstExpenseTxs.fold(0.0, (s, t) => s + (t.amount / 11));
      gstPayable = gstCollected - gstCredits;
      hasGstData = gstCollected > 0 || gstCredits > 0;
    } else {
      gstCollected = 0;
      gstCredits   = 0;
      gstPayable   = 0;
      hasGstData   = false;
    }

    // ── Outstanding invoices ──────────────────────────────────────────────────
    final outstanding = provider.allInvoices
        .where((inv) =>
            inv.status == InvoiceStatus.sent ||
            inv.status == InvoiceStatus.viewed)
        .toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── App bar with fiscal year picker ──────────────────────────────
          SliverAppBar(
            floating: true,
            pinned: false,
            titleSpacing: 20,
            title: Text(
              'Estimates',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: AppTheme.of(context).textPrimary),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _TaxYearPicker(
                  label: _resolvedYearLabel(isAU),
                  canGoBack:    true,
                  canGoForward: _yearOffset < 0,
                  onBack:    () => setState(() => _yearOffset--),
                  onForward: () => setState(() => _yearOffset++),
                ),
              ),
            ],
          ),

          // ── No stacks yet — helpful empty state ───────────────────────────
          if (provider.stacks.isEmpty)
            const SliverFillRemaining(
              child: _TaxEmptyState(),
            )
          else ...[

            // ── Year summary band ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: _YearSummaryBand(
                  income: income, expenses: expenses, profit: profit, sym: sym),
              ),
            ),

            // ── Estimated tax card ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: _EstimatedTaxCard(
                  taxableProfit: taxableProfit,
                  estimatedTax: estimatedTax,
                  taxRate: provider.taxRate,
                  totalAllowances: totalAllowances,
                  sym: sym,
                ),
              ),
            ),

            // ── Deductible expenses ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: _DeductibleExpensesCard(
                  deductible: deductible,
                  totalDeductible: totalDeductible,
                  taxRate: provider.taxRate,
                  sym: sym,
                ),
              ),
            ),

            // ── Mileage deduction ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: _MileageDeductionCard(
                  tripCount: mileTrips.length,
                  km: mileageKm,
                  cappedKm: clampedKm,
                  deduction: mileageDeduction,
                  taxRate: provider.taxRate,
                  sym: sym,
                  isAuMode: isAU,
                  capKm: mileageCapKm,
                  rateLabel: mileRateLabel,
                  onAddTrip: () => showMileageScreen(context),
                ),
              ),
            ),

            // ── BAS / GST summary — AU only ───────────────────────────────
            if (isAU)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: _BasSummaryCard(
                    gstCollected: gstCollected,
                    gstCredits: gstCredits,
                    gstPayable: gstPayable,
                    hasData: hasGstData,
                    totalIncome: income,
                    sym: sym,
                  ),
                ),
              ),

            // ── Outstanding invoices callout ───────────────────────────────
            if (outstanding.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: _OutstandingInvoicesCard(
                      invoices: outstanding, sym: sym),
                ),
              ),

            // ── Monthly set-aside tip ──────────────────────────────────────
            if (estimatedTax > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: _SetAsideTip(
                      estimatedTax: estimatedTax,
                      taxRate: provider.taxRate,
                      sym: sym),
                ),
              ),

            // ── Estimate settings (tax rate, mileage rate) ────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: _TaxSettingsCard(isAU: isAU),
              ),
            ),

            // ── Generate Summary ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: _GenerateSummaryCard(
                  generating: _generating,
                  yearLabel: _resolvedYearLabel(isAU),
                  hasData: !provider.stacks.isEmpty,
                  onGenerate: provider.stacks.isEmpty
                      ? null
                      : () => _generateSummary(context, provider, isAU),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ],
      ),
    );
  }
}

// ─── Fiscal year picker ───────────────────────────────────────────────────────

class _TaxYearPicker extends StatelessWidget {
  final String label;
  final bool canGoBack, canGoForward;
  final VoidCallback onBack, onForward;

  const _TaxYearPicker({
    required this.label,
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.of(context).card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.of(context).border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ArrowBtn(
              icon: Icons.chevron_left,
              enabled: canGoBack,
              onTap: onBack),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.of(context).textPrimary),
            ),
          ),
          _ArrowBtn(
              icon: Icons.chevron_right,
              enabled: canGoForward,
              onTap: onForward),
        ],
      ),
    );
  }
}

class _ArrowBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _ArrowBtn(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon,
            size: 16,
            color: enabled
                ? AppTheme.of(context).textSecondary
                : AppTheme.of(context).textMuted.withOpacity(0.25)),
      ),
    );
  }
}

// ─── Year summary band (3 pills) ─────────────────────────────────────────────

class _YearSummaryBand extends StatelessWidget {
  final double income, expenses, profit;
  final String sym;
  const _YearSummaryBand({
    required this.income,
    required this.expenses,
    required this.profit,
    required this.sym,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
          child: _SummaryPill(
              label: 'Income', value: income, sym: sym, color: AppTheme.green)),
      const SizedBox(width: 8),
      Expanded(
          child: _SummaryPill(
              label: 'Expenses',
              value: expenses,
              sym: sym,
              color: AppTheme.red)),
      const SizedBox(width: 8),
      Expanded(
          child: _SummaryPill(
              label: 'Profit',
              value: profit,
              sym: sym,
              color: profit >= 0 ? AppTheme.green : AppTheme.red)),
    ]);
  }
}

class _SummaryPill extends StatelessWidget {
  final String label, sym;
  final double value;
  final Color color;
  const _SummaryPill(
      {required this.label,
      required this.value,
      required this.sym,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: color.withOpacity(0.7))),
          const SizedBox(height: 3),
          Text(
            formatCurrency(value.abs(), sym),
            style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color),
          ),
        ],
      ),
    );
  }
}

// ─── Estimated tax card ───────────────────────────────────────────────────────

class _EstimatedTaxCard extends StatelessWidget {
  final double taxableProfit, estimatedTax, taxRate, totalAllowances;
  final String sym;
  const _EstimatedTaxCard({
    required this.taxableProfit,
    required this.estimatedTax,
    required this.taxRate,
    required this.totalAllowances,
    required this.sym,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (taxRate * 100).round();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.of(context).card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.of(context).border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: AppTheme.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: const Center(
                  child: Icon(Icons.receipt_long_outlined, size: 17, color: AppTheme.amber)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ESTIMATED TAX',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppTheme.of(context).textMuted)),
                  Text(
                    formatCurrency(estimatedTax, sym),
                    style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: estimatedTax > 0
                            ? AppTheme.amber
                            : AppTheme.green),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$pct% rate',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.amber),
              ),
            ),
          ]),
          if (estimatedTax > 0) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: AppTheme.of(context).border),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _TaxMetric(
                    label: 'Taxable profit',
                    value: formatCurrency(taxableProfit, sym),
                    color: AppTheme.of(context).textPrimary),
              ),
              Expanded(
                child: _TaxMetric(
                    label: 'Total allowances',
                    value: formatCurrency(totalAllowances, sym),
                    color: AppTheme.green),
              ),
              Expanded(
                child: _TaxMetric(
                    label: 'Set aside / mo',
                    value: formatCurrency(estimatedTax / 12, sym),
                    color: AppTheme.accent),
              ),
            ]),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              taxableProfit <= 0
                  ? 'No tax estimated — profit is zero or below for this tax year.'
                  : 'Log income to see your estimated tax liability.',
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.of(context).textSecondary,
                  height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _TaxMetric extends StatelessWidget {
  final String label, value;
  final Color color;
  const _TaxMetric(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: AppTheme.of(context).textMuted)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color)),
      ],
    );
  }
}

// ─── Deductible expenses card ─────────────────────────────────────────────────

class _DeductibleExpensesCard extends StatefulWidget {
  final List<Transaction> deductible;
  final double totalDeductible, taxRate;
  final String sym;
  const _DeductibleExpensesCard({
    required this.deductible,
    required this.totalDeductible,
    required this.taxRate,
    required this.sym,
  });

  @override
  State<_DeductibleExpensesCard> createState() =>
      _DeductibleExpensesCardState();
}

class _DeductibleExpensesCardState extends State<_DeductibleExpensesCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // Group by category, sorted largest first
    final byCategory = <String, double>{};
    for (final tx in widget.deductible) {
      final cat = tx.category.isEmpty ? 'Other' : tx.category;
      byCategory[cat] = (byCategory[cat] ?? 0) + tx.amount;
    }
    final sorted = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.of(context).card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.of(context).border),
        ),
        child: Column(
          children: [
            // ── Header row ──────────────────────────────────────────────────
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: AppTheme.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Center(
                    child: Icon(Icons.receipt_long_outlined, size: 17, color: AppTheme.green)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DEDUCTIBLE EXPENSES',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppTheme.of(context).textMuted)),
                    Row(children: [
                      Text(
                        formatCurrency(widget.totalDeductible, widget.sym),
                        style: const TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.green),
                      ),
                      const SizedBox(width: 8),
                      if (widget.totalDeductible > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.green.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'saves ${formatCurrency(widget.totalDeductible * widget.taxRate, widget.sym)}',
                            style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.green),
                          ),
                        ),
                    ]),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.expand_more,
                    size: 18, color: AppTheme.of(context).textMuted),
              ),
            ]),

            // ── Expanded category breakdown ──────────────────────────────────
            if (_expanded) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: AppTheme.of(context).border),
              const SizedBox(height: 10),
              if (sorted.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Text(
                    'No deductible expenses logged for this tax year.\nCategories like Software, Travel, and Home Office qualify.',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.of(context).textSecondary,
                        height: 1.5),
                  ),
                )
              else
                ...sorted.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Expanded(
                          child: Text(e.key,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.of(context).textPrimary)),
                        ),
                        Text(
                          formatCurrency(e.value, widget.sym),
                          style: const TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.green),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '-${formatCurrency(e.value * widget.taxRate, widget.sym)} tax',
                            style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.green),
                          ),
                        ),
                      ]),
                    )),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Mileage deduction card ───────────────────────────────────────────────────

class _MileageDeductionCard extends StatelessWidget {
  final int tripCount;
  final double km, cappedKm, deduction, taxRate, capKm;
  final String sym, rateLabel;
  final bool isAuMode;
  final VoidCallback onAddTrip;

  const _MileageDeductionCard({
    required this.tripCount,
    required this.km,
    required this.cappedKm,
    required this.deduction,
    required this.taxRate,
    required this.sym,
    required this.isAuMode,
    required this.capKm,
    required this.rateLabel,
    required this.onAddTrip,
  });

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF8B5CF6);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.of(context).card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.of(context).border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: purple.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: const Center(
                  child: Icon(Icons.directions_car_outlined, size: 17, color: purple)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MILEAGE DEDUCTION',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppTheme.of(context).textMuted)),
                  Row(children: [
                    Text(
                      formatCurrency(deduction, sym),
                      style: const TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: purple),
                    ),
                    const SizedBox(width: 8),
                    if (deduction > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: purple.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'saves ${formatCurrency(deduction * taxRate, sym)}',
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: purple),
                        ),
                      ),
                  ]),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: onAddTrip,
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Log trip'),
              style: TextButton.styleFrom(
                foregroundColor: purple,
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                textStyle: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ]),

          // ── Stats pills ─────────────────────────────────────────────────────
          if (tripCount > 0) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: AppTheme.of(context).border),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _MileagePill(
                      label: 'Trips',
                      value: '$tripCount',
                      color: purple)),
              const SizedBox(width: 8),
              Expanded(
                  child: _MileagePill(
                      label: isAuMode ? 'km logged' : 'dist logged',
                      value: km.toStringAsFixed(1),
                      color: purple)),
              const SizedBox(width: 8),
              if (isAuMode) ...[
                Expanded(
                    child: _MileagePill(
                        label: 'km claimed',
                        value: '${cappedKm.toStringAsFixed(0)}/5000',
                        color: cappedKm >= 5000
                            ? const Color(0xFFEF4444)
                            : AppTheme.of(context).textMuted)),
                const SizedBox(width: 8),
              ],
              Expanded(
                  child: _MileagePill(
                      label: isAuMode ? 'ATO rate' : 'rate',
                      value: rateLabel,
                      color: AppTheme.of(context).textMuted)),
            ]),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              isAuMode
                  ? 'Log business trips to claim the ATO \$0.85/km deduction (capped at 5,000 km/year) and reduce your tax bill.'
                  : 'Log business trips to claim a mileage deduction at your configured rate and reduce your tax bill.',
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.of(context).textSecondary,
                  height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _MileagePill extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MileagePill(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: color.withOpacity(0.7))),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}

// ─── BAS / GST summary card ───────────────────────────────────────────────────

class _BasSummaryCard extends StatelessWidget {
  final double gstCollected, gstCredits, gstPayable, totalIncome;
  final bool hasData;
  final String sym;

  const _BasSummaryCard({
    required this.gstCollected,
    required this.gstCredits,
    required this.gstPayable,
    required this.hasData,
    required this.totalIncome,
    required this.sym,
  });

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0F766E);
    const kGstThreshold = 75000.0;
    final nearThreshold = totalIncome > 0 &&
        totalIncome >= kGstThreshold * 0.80 &&
        totalIncome < kGstThreshold;
    final overThreshold = totalIncome >= kGstThreshold;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.of(context).card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.of(context).border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: teal.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                  child: Text('🇦🇺', style: TextStyle(fontSize: 17))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('GST / BAS SUMMARY',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppTheme.of(context).textMuted)),
                  Text(
                    hasData
                        ? '${sym}${gstPayable.abs().toStringAsFixed(2)} ${gstPayable >= 0 ? 'to pay' : 'refund'}'
                        : 'No GST transactions yet',
                    style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: hasData
                            ? (gstPayable >= 0 ? teal : AppTheme.green)
                            : AppTheme.of(context).textMuted),
                  ),
                ],
              ),
            ),
          ]),

          // GST threshold warning
          if (overThreshold || nearThreshold) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: (overThreshold ? AppTheme.red : const Color(0xFFF59E0B))
                    .withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: overThreshold
                        ? AppTheme.red
                        : const Color(0xFFF59E0B)),
              ),
              child: Row(children: [
                Icon(
                  overThreshold ? Icons.warning_amber_outlined : Icons.bar_chart_outlined,
                  size: 16,
                  color: overThreshold ? AppTheme.red : const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    overThreshold
                        ? 'Your income has exceeded the \$75,000 GST threshold — you must register for GST with the ATO.'
                        : 'You\'re approaching the \$75,000 GST registration threshold (${sym}${(kGstThreshold - totalIncome).toStringAsFixed(0)} away).',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: overThreshold
                            ? AppTheme.red
                            : const Color(0xFFB45309),
                        height: 1.4),
                  ),
                ),
              ]),
            ),
          ],

          if (hasData) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: AppTheme.of(context).border),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _MileagePill(
                      label: 'GST collected',
                      value: '$sym${gstCollected.toStringAsFixed(2)}',
                      color: teal)),
              const SizedBox(width: 8),
              Expanded(
                  child: _MileagePill(
                      label: 'GST credits',
                      value: '$sym${gstCredits.toStringAsFixed(2)}',
                      color: AppTheme.green)),
              const SizedBox(width: 8),
              Expanded(
                  child: _MileagePill(
                      label: 'Net GST',
                      value: '$sym${gstPayable.abs().toStringAsFixed(2)}',
                      color: gstPayable >= 0 ? teal : AppTheme.green)),
            ]),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              'Mark transactions as "Includes GST" when adding them to track your BAS obligations here.',
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.of(context).textSecondary,
                  height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Outstanding invoices callout ─────────────────────────────────────────────

class _OutstandingInvoicesCard extends StatelessWidget {
  final List<Invoice> invoices;
  final String sym;
  const _OutstandingInvoicesCard(
      {required this.invoices, required this.sym});

  @override
  Widget build(BuildContext context) {
    final total = invoices.fold(0.0, (s, inv) => s + inv.amount);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.amber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.amber.withOpacity(0.25)),
      ),
      child: Row(children: [
        const Icon(Icons.mark_email_unread_outlined, size: 18, color: AppTheme.amber),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${invoices.length} unpaid invoice${invoices.length == 1 ? '' : 's'}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.amber),
              ),
              Text(
                '${formatCurrency(total, sym)} not yet counted as income',
                style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.amber.withOpacity(0.8)),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right,
            size: 16, color: AppTheme.amber.withOpacity(0.6)),
      ]),
    );
  }
}

// ─── Monthly set-aside tip ────────────────────────────────────────────────────

class _SetAsideTip extends StatelessWidget {
  final double estimatedTax, taxRate;
  final String sym;
  const _SetAsideTip(
      {required this.estimatedTax,
      required this.taxRate,
      required this.sym});

  @override
  Widget build(BuildContext context) {
    final monthly = estimatedTax / 12;
    final pct = (taxRate * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.accentDim,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
      ),
      child: Row(children: [
        const Icon(Icons.lightbulb_outline, size: 16, color: AppTheme.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Set aside ${formatCurrency(monthly, sym)}/month to avoid a surprise bill at year end. '
            "That's $pct% of your taxable profit spread monthly.",
            style: const TextStyle(
                fontSize: 11,
                color: AppTheme.accent,
                fontWeight: FontWeight.w500,
                height: 1.5),
          ),
        ),
      ]),
    );
  }
}

// ─── Generate Summary card ────────────────────────────────────────────────────

class _GenerateSummaryCard extends StatelessWidget {
  final bool generating;
  final bool hasData;
  final String yearLabel;
  final VoidCallback? onGenerate;

  const _GenerateSummaryCard({
    required this.generating,
    required this.hasData,
    required this.yearLabel,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: generating ? null : onGenerate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: AppTheme.accentDim,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.accent.withOpacity(0.25)),
        ),
        child: Row(children: [
          generating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.accent))
              : const Icon(Icons.picture_as_pdf_outlined,
                  size: 18, color: AppTheme.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Generate Tax Summary',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accent)),
                Text(
                  hasData
                      ? 'Export $yearLabel as a PDF — estimates only'
                      : 'Add transactions to generate a summary',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.accent,
                      fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right,
              size: 16,
              color: AppTheme.accent.withOpacity(onGenerate != null ? 0.8 : 0.3)),
        ]),
      ),
    );
  }
}

// ─── Tax settings card ────────────────────────────────────────────────────────

class _TaxSettingsCard extends StatefulWidget {
  final bool isAU;
  const _TaxSettingsCard({required this.isAU});

  @override
  State<_TaxSettingsCard> createState() => _TaxSettingsCardState();
}

class _TaxSettingsCardState extends State<_TaxSettingsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final colors = AppTheme.of(context);
    final taxPct = (provider.taxRate * 100).round();

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ─────────────────────────────────────────────────
            Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Center(
                    child: Icon(Icons.tune_outlined,
                        size: 17, color: AppTheme.accent)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ESTIMATE SETTINGS',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: colors.textMuted)),
                    Text('$taxPct% income tax · tap to adjust',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary)),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.expand_more,
                    size: 18, color: colors.textMuted),
              ),
            ]),

            if (_expanded) ...[
              const SizedBox(height: 14),
              Divider(height: 1, color: colors.border),
              const SizedBox(height: 14),

              // ── Income tax rate ───────────────────────────────────────────
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Income tax rate',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary)),
                      Text('Applied to your taxable profit',
                          style: TextStyle(
                              fontSize: 11, color: colors.textSecondary)),
                    ],
                  ),
                ),
                _RateBtn(
                  icon: Icons.remove,
                  enabled: provider.taxRate > 0.01,
                  onTap: () =>
                      provider.setTaxRate(provider.taxRate - 0.01),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 54,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: AppTheme.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$taxPct%',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.amber)),
                ),
                const SizedBox(width: 8),
                _RateBtn(
                  icon: Icons.add,
                  enabled: provider.taxRate < 0.60,
                  onTap: () =>
                      provider.setTaxRate(provider.taxRate + 0.01),
                ),
              ]),

              // ── Mileage rate (non-AU only) ────────────────────────────────
              if (!widget.isAU) ...[
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Mileage rate (per ${provider.mileageUseKm ? 'km' : 'mi'})',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary)),
                        Text('Used to calculate mileage deductions',
                            style: TextStyle(
                                fontSize: 11,
                                color: colors.textSecondary)),
                      ],
                    ),
                  ),
                  _RateBtn(
                    icon: Icons.remove,
                    enabled: provider.customMileageRate > 0.01,
                    onTap: () => provider.setCustomMileageRate(
                        provider.customMileageRate - 0.01),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 66,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                        '\$${provider.customMileageRate.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF8B5CF6))),
                  ),
                  const SizedBox(width: 8),
                  _RateBtn(
                    icon: Icons.add,
                    enabled: provider.customMileageRate < 5.0,
                    onTap: () => provider.setCustomMileageRate(
                        provider.customMileageRate + 0.01),
                  ),
                ]),
              ] else ...[
                // AU: show ATO rate as read-only
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(children: [
                    const Text('🇦🇺',
                        style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ATO mileage: \$0.85/km (set by ATO, capped at 5,000 km/year)',
                        style: TextStyle(
                            fontSize: 11,
                            color: colors.textSecondary,
                            height: 1.4),
                      ),
                    ),
                  ]),
                ),
              ],

              const SizedBox(height: 12),
              Text(
                'These are estimates only. Consult a qualified accountant for your actual obligations.',
                style: TextStyle(
                    fontSize: 10,
                    color: colors.textMuted,
                    height: 1.45,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Rate adjustment button ───────────────────────────────────────────────────

class _RateBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _RateBtn(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.border),
        ),
        child: Icon(icon,
            size: 14,
            color: enabled
                ? colors.textPrimary
                : colors.textMuted.withOpacity(0.25)),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _TaxEmptyState extends StatelessWidget {
  const _TaxEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppTheme.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                  child: Icon(Icons.receipt_long_outlined, size: 36, color: AppTheme.amber)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your tax summary lives here',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add a SideStack and log some transactions to see your estimated tax, deductible expenses, and mileage deductions.',
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.of(context).textSecondary,
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
