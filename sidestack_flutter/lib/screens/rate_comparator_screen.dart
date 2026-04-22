import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

// ─── Entry point ─────────────────────────────────────────────────────────────

void showRateComparatorScreen(BuildContext context) {
  Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => const RateComparatorScreen(),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: FadeTransition(opacity: anim, child: child),
      ),
      transitionDuration: const Duration(milliseconds: 280),
    ),
  );
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class RateComparatorScreen extends StatefulWidget {
  const RateComparatorScreen({super.key});

  @override
  State<RateComparatorScreen> createState() => _RateComparatorScreenState();
}

class _RateComparatorScreenState extends State<RateComparatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.surface,
        surfaceTintColor: Colors.transparent,
        leading: const BackButton(),
        title: const Text(
          'Worth My Time?',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.accent,
          unselectedLabelColor: theme.textSecondary,
          indicatorColor: AppTheme.accent,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Single Gig'),
            Tab(text: 'Compare Two'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _SingleGigTab(),
          _CompareTab(),
        ],
      ),
    );
  }
}

// ─── Single gig calculator ────────────────────────────────────────────────────

class _SingleGigTab extends StatefulWidget {
  const _SingleGigTab();

  @override
  State<_SingleGigTab> createState() => _SingleGigTabState();
}

class _SingleGigTabState extends State<_SingleGigTab> {
  bool _isProject = false; // false = hourly, true = fixed project
  final _grossCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  final _travelCtrl = TextEditingController();
  final _expensesCtrl = TextEditingController();
  bool _includesGst = false;
  bool _includesSuper = true;

  @override
  void dispose() {
    _grossCtrl.dispose();
    _hoursCtrl.dispose();
    _travelCtrl.dispose();
    _expensesCtrl.dispose();
    super.dispose();
  }

  RateResult? _compute(double taxRate, String sym) {
    final gross = double.tryParse(_grossCtrl.text.replaceAll(',', ''));
    final hours = double.tryParse(_hoursCtrl.text) ?? 0;
    final travel = double.tryParse(_travelCtrl.text) ?? 0;
    final expenses = double.tryParse(_expensesCtrl.text) ?? 0;
    if (gross == null || gross <= 0) return null;
    final totalHours = hours + travel;
    if (totalHours <= 0) return null;
    return computeRate(
      gross: gross,
      totalHours: totalHours,
      expenses: expenses,
      taxRate: taxRate,
      includesGst: _includesGst,
      includesSuper: _includesSuper,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final taxRate = provider.taxRate;
    final sym = provider.currencySymbol;
    final theme = AppTheme.of(context);
    final result = _compute(taxRate, sym);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rate type toggle
          _SectionLabel('Rate type'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ToggleChip(
                  label: 'Hourly rate',
                  selected: !_isProject,
                  onTap: () => setState(() => _isProject = false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ToggleChip(
                  label: 'Fixed project',
                  selected: _isProject,
                  onTap: () => setState(() => _isProject = true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Gross amount
          _SectionLabel(_isProject ? 'Project fee' : 'Hourly rate'),
          const SizedBox(height: 8),
          _InputField(
            controller: _grossCtrl,
            prefix: sym,
            hint: _isProject ? '1200' : '45',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Hours worked
          _SectionLabel(_isProject ? 'Hours to complete' : 'Hours per session'),
          const SizedBox(height: 8),
          _InputField(
            controller: _hoursCtrl,
            prefix: 'hrs',
            hint: '8',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Travel
          _SectionLabel('Travel time (optional)'),
          const SizedBox(height: 8),
          _InputField(
            controller: _travelCtrl,
            prefix: 'hrs',
            hint: '0',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Expenses
          _SectionLabel('Direct expenses (optional)'),
          const SizedBox(height: 8),
          _InputField(
            controller: _expensesCtrl,
            prefix: sym,
            hint: '0',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),

          // Toggles
          _ToggleRow(
            label: 'GST included in my rate',
            value: _includesGst,
            onChanged: (v) => setState(() => _includesGst = v),
          ),
          const SizedBox(height: 8),
          _ToggleRow(
            label: 'Account for 11.5% super',
            value: _includesSuper,
            onChanged: (v) => setState(() => _includesSuper = v),
          ),
          const SizedBox(height: 24),

          // Result
          if (result != null)
            _ResultCard(result: result, sym: sym)
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: theme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.border),
              ),
              child: Column(
                children: [
                  Icon(Icons.calculate_outlined,
                      size: 32, color: theme.textMuted),
                  const SizedBox(height: 8),
                  Text('Enter your rate and hours to see\nyour true take-home',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 13, color: theme.textSecondary)),
                ],
              ),
            ),

          const SizedBox(height: 16),
          Text(
            'Tax rate used: ${(taxRate * 100).toStringAsFixed(0)}% — adjust in Profile → Tax rate',
            style: TextStyle(fontSize: 11, color: theme.textMuted),
          ),
        ],
      ),
    );
  }
}

// ─── Compare two gigs ─────────────────────────────────────────────────────────

class _CompareTab extends StatefulWidget {
  const _CompareTab();

  @override
  State<_CompareTab> createState() => _CompareTabState();
}

class _CompareTabState extends State<_CompareTab> {
  final _gigA = _GigInputs();
  final _gigB = _GigInputs();

  @override
  void dispose() {
    _gigA.dispose();
    _gigB.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final taxRate = provider.taxRate;
    final sym = provider.currencySymbol;
    final theme = AppTheme.of(context);

    final resultA = _gigA.compute(taxRate);
    final resultB = _gigB.compute(taxRate);

    final aWins = resultA != null &&
        resultB != null &&
        resultA.netEffectiveHourly > resultB.netEffectiveHourly;
    final bWins = resultA != null &&
        resultB != null &&
        resultB.netEffectiveHourly > resultA.netEffectiveHourly;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _GigColumn(
                  label: 'Gig A',
                  inputs: _gigA,
                  sym: sym,
                  winner: aWins,
                  onChanged: () => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GigColumn(
                  label: 'Gig B',
                  inputs: _gigB,
                  sym: sym,
                  winner: bWins,
                  onChanged: () => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Side-by-side results
          if (resultA != null && resultB != null) ...[
            Text('Results',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.textPrimary)),
            const SizedBox(height: 10),
            _ComparisonTable(
              sym: sym,
              resultA: resultA,
              resultB: resultB,
            ),
            const SizedBox(height: 16),
            // Verdict
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.green.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 20, color: AppTheme.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _verdict(resultA, resultB, sym),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.green),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Tax rate: ${(taxRate * 100).toStringAsFixed(0)}% — adjust in Profile → Tax rate',
            style: TextStyle(fontSize: 11, color: theme.textMuted),
          ),
        ],
      ),
    );
  }

  String _verdict(RateResult a, RateResult b, String sym) {
    final diff = (a.netEffectiveHourly - b.netEffectiveHourly).abs();
    if (a.netEffectiveHourly > b.netEffectiveHourly) {
      return 'Gig A pays $sym${diff.toStringAsFixed(2)}/hr more after tax and expenses.';
    } else if (b.netEffectiveHourly > a.netEffectiveHourly) {
      return 'Gig B pays $sym${diff.toStringAsFixed(2)}/hr more after tax and expenses.';
    }
    return 'Both gigs pay the same effective hourly rate.';
  }
}

// ─── Rate calculation engine ──────────────────────────────────────────────────

class RateResult {
  final double grossHourly;
  final double gstComponent;
  final double grossExGst;
  final double taxPayable;
  final double superPayable;
  final double expensesHourly;
  final double netEffectiveHourly;

  const RateResult({
    required this.grossHourly,
    required this.gstComponent,
    required this.grossExGst,
    required this.taxPayable,
    required this.superPayable,
    required this.expensesHourly,
    required this.netEffectiveHourly,
  });
}

RateResult computeRate({
  required double gross,
  required double totalHours,
  required double expenses,
  required double taxRate,
  required bool includesGst,
  required bool includesSuper,
}) {
  final grossHourly = gross / totalHours;
  final gstComponent = includesGst ? grossHourly / 11.0 : 0.0;
  final grossExGst = grossHourly - gstComponent;
  final taxPayable = grossExGst * taxRate;
  final superPayable = includesSuper ? grossExGst * 0.115 : 0.0;
  final expensesHourly = expenses / totalHours;
  final net = grossExGst - taxPayable - superPayable - expensesHourly;

  return RateResult(
    grossHourly: grossHourly,
    gstComponent: gstComponent,
    grossExGst: grossExGst,
    taxPayable: taxPayable,
    superPayable: superPayable,
    expensesHourly: expensesHourly,
    netEffectiveHourly: max(net, 0),
  );
}

// ─── Result card ──────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final RateResult result;
  final String sym;
  const _ResultCard({required this.result, required this.sym});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final net = result.netEffectiveHourly;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accent.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your effective hourly rate',
              style:
                  TextStyle(fontSize: 11, color: theme.textSecondary)),
          const SizedBox(height: 4),
          Text(
            '$sym${net.toStringAsFixed(2)}/hr',
            style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: AppTheme.accent,
                letterSpacing: -0.8),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _Row(label: 'Gross hourly', value: '$sym${result.grossHourly.toStringAsFixed(2)}', theme: theme),
          if (result.gstComponent > 0)
            _Row(label: 'GST component (−)', value: '$sym${result.gstComponent.toStringAsFixed(2)}', theme: theme, negative: true),
          _Row(label: 'Gross ex-GST', value: '$sym${result.grossExGst.toStringAsFixed(2)}', theme: theme),
          _Row(label: 'Income tax (−)', value: '$sym${result.taxPayable.toStringAsFixed(2)}', theme: theme, negative: true),
          if (result.superPayable > 0)
            _Row(label: 'Super set-aside (−)', value: '$sym${result.superPayable.toStringAsFixed(2)}', theme: theme, negative: true),
          if (result.expensesHourly > 0)
            _Row(label: 'Direct expenses (−)', value: '$sym${result.expensesHourly.toStringAsFixed(2)}', theme: theme, negative: true),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _Row(
            label: 'Take-home /hr',
            value: '$sym${net.toStringAsFixed(2)}',
            theme: theme,
            bold: true,
            valueColor: AppTheme.green,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  final AppColors theme;
  final bool negative, bold;
  final Color? valueColor;
  const _Row({
    required this.label,
    required this.value,
    required this.theme,
    this.negative = false,
    this.bold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = valueColor ??
        (negative ? AppTheme.red : theme.textPrimary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: theme.textSecondary,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Compare table ────────────────────────────────────────────────────────────

class _ComparisonTable extends StatelessWidget {
  final String sym;
  final RateResult resultA, resultB;
  const _ComparisonTable(
      {required this.sym, required this.resultA, required this.resultB});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    rows(String label, double a, double b) {
      final aWins = a > b;
      final bWins = b > a;
      return TableRow(children: [
        _TableCell(label, theme: theme),
        _TableCell('$sym${a.toStringAsFixed(2)}',
            highlight: aWins, theme: theme),
        _TableCell('$sym${b.toStringAsFixed(2)}',
            highlight: bWins, theme: theme),
      ]);
    }

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1.2),
        2: FlexColumnWidth(1.2),
      },
      border: TableBorder.all(color: theme.border, width: 0.5),
      children: [
        TableRow(
          decoration: BoxDecoration(color: theme.card),
          children: [
            _TableCell('', theme: theme, header: true),
            _TableCell('Gig A', theme: theme, header: true),
            _TableCell('Gig B', theme: theme, header: true),
          ],
        ),
        rows('Gross /hr', resultA.grossHourly, resultB.grossHourly),
        if (resultA.gstComponent > 0 || resultB.gstComponent > 0)
          rows('GST (−)', resultA.gstComponent, resultB.gstComponent),
        rows('Tax (−)', resultA.taxPayable, resultB.taxPayable),
        if (resultA.superPayable > 0 || resultB.superPayable > 0)
          rows('Super (−)', resultA.superPayable, resultB.superPayable),
        if (resultA.expensesHourly > 0 || resultB.expensesHourly > 0)
          rows('Expenses (−)', resultA.expensesHourly, resultB.expensesHourly),
        TableRow(
          decoration: BoxDecoration(color: AppTheme.green.withOpacity(0.08)),
          children: [
            _TableCell('Take-home /hr', theme: theme, header: true),
            _TableCell(
              '$sym${resultA.netEffectiveHourly.toStringAsFixed(2)}',
              theme: theme,
              highlight: resultA.netEffectiveHourly >= resultB.netEffectiveHourly,
              header: true,
            ),
            _TableCell(
              '$sym${resultB.netEffectiveHourly.toStringAsFixed(2)}',
              theme: theme,
              highlight: resultB.netEffectiveHourly >= resultA.netEffectiveHourly,
              header: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final AppColors theme;
  final bool highlight, header;
  const _TableCell(this.text,
      {required this.theme, this.highlight = false, this.header = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: header || highlight ? FontWeight.w700 : FontWeight.w400,
          color: highlight ? AppTheme.green : theme.textPrimary,
        ),
      ),
    );
  }
}

// ─── Gig inputs model ─────────────────────────────────────────────────────────

class _GigInputs {
  final grossCtrl = TextEditingController();
  final hoursCtrl = TextEditingController();
  final travelCtrl = TextEditingController();
  final expensesCtrl = TextEditingController();
  bool includesGst = false;
  bool includesSuper = true;

  void dispose() {
    grossCtrl.dispose();
    hoursCtrl.dispose();
    travelCtrl.dispose();
    expensesCtrl.dispose();
  }

  RateResult? compute(double taxRate) {
    final gross = double.tryParse(grossCtrl.text.replaceAll(',', ''));
    final hours = double.tryParse(hoursCtrl.text) ?? 0;
    final travel = double.tryParse(travelCtrl.text) ?? 0;
    final expenses = double.tryParse(expensesCtrl.text) ?? 0;
    if (gross == null || gross <= 0) return null;
    final total = hours + travel;
    if (total <= 0) return null;
    return computeRate(
      gross: gross,
      totalHours: total,
      expenses: expenses,
      taxRate: taxRate,
      includesGst: includesGst,
      includesSuper: includesSuper,
    );
  }
}

// ─── Gig column (compare tab) ─────────────────────────────────────────────────

class _GigColumn extends StatefulWidget {
  final String label, sym;
  final _GigInputs inputs;
  final bool winner;
  final VoidCallback onChanged;
  const _GigColumn({
    required this.label,
    required this.inputs,
    required this.sym,
    required this.winner,
    required this.onChanged,
  });

  @override
  State<_GigColumn> createState() => _GigColumnState();
}

class _GigColumnState extends State<_GigColumn> {
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final inp = widget.inputs;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.winner
            ? AppTheme.green.withOpacity(0.07)
            : theme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.winner
              ? AppTheme.green.withOpacity(0.4)
              : theme.border,
          width: widget.winner ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(widget.label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: widget.winner ? AppTheme.green : theme.textPrimary)),
              if (widget.winner) ...[
                const SizedBox(width: 4),
                const Icon(Icons.emoji_events_outlined, size: 13, color: AppTheme.green),
              ],
            ],
          ),
          const SizedBox(height: 10),
          _MiniInput(label: 'Rate (${widget.sym})', ctrl: inp.grossCtrl, onChanged: widget.onChanged),
          const SizedBox(height: 8),
          _MiniInput(label: 'Hours', ctrl: inp.hoursCtrl, onChanged: widget.onChanged),
          const SizedBox(height: 8),
          _MiniInput(label: 'Travel hrs', ctrl: inp.travelCtrl, onChanged: widget.onChanged),
          const SizedBox(height: 8),
          _MiniInput(label: 'Expenses (${widget.sym})', ctrl: inp.expensesCtrl, onChanged: widget.onChanged),
          const SizedBox(height: 10),
          Row(
            children: [
              Checkbox(
                value: inp.includesGst,
                activeColor: AppTheme.accent,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onChanged: (v) => setState(() {
                  inp.includesGst = v ?? false;
                  widget.onChanged();
                }),
              ),
              Expanded(
                child: Text('GST incl.',
                    style:
                        TextStyle(fontSize: 11, color: theme.textSecondary)),
              ),
            ],
          ),
          Row(
            children: [
              Checkbox(
                value: inp.includesSuper,
                activeColor: AppTheme.accent,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onChanged: (v) => setState(() {
                  inp.includesSuper = v ?? true;
                  widget.onChanged();
                }),
              ),
              Expanded(
                child: Text('Super 11.5%',
                    style:
                        TextStyle(fontSize: 11, color: theme.textSecondary)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Shared UI primitives ─────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.of(context).textSecondary),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String prefix, hint;
  final ValueChanged<String> onChanged;
  const _InputField({
    required this.controller,
    required this.prefix,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        prefixText: '$prefix ',
        hintText: hint,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        filled: true,
        fillColor: theme.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
        ),
      ),
    );
  }
}

class _MiniInput extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final VoidCallback onChanged;
  const _MiniInput(
      {required this.label, required this.ctrl, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 10, color: theme.textSecondary)),
        const SizedBox(height: 3),
        SizedBox(
          height: 36,
          child: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onChanged(),
            style:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              filled: true,
              fillColor: theme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AppTheme.accent, width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : AppTheme.of(context).card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected
                  ? AppTheme.accent
                  : AppTheme.of(context).border),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppTheme.of(context).textPrimary),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Row(
      children: [
        Expanded(
            child: Text(label,
                style:
                    TextStyle(fontSize: 13, color: theme.textPrimary))),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppTheme.accent,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }
}
