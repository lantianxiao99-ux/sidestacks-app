import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/add_transaction_sheet.dart';
import '../widgets/edit_stack_sheet.dart';
import '../services/csv_export_service.dart';
import '../services/pdf_export_service.dart';
import '../widgets/invoice_sheet.dart';
import '../widgets/paywall_sheet.dart';

class StackDetailScreen extends StatefulWidget {
  final String stackId;
  const StackDetailScreen({super.key, required this.stackId});

  @override
  State<StackDetailScreen> createState() => _StackDetailScreenState();
}

class _StackDetailScreenState extends State<StackDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final stack = provider.getStack(widget.stackId);
    final symbol = provider.currencySymbol;
    if (stack == null) {
      return const Scaffold(body: Center(child: Text('Stack not found')));
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 16),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(stack.hustleType.emoji,
                style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stack.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  if (stack.description != null)
                    Text(stack.description!,
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.of(context).textSecondary)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Edit + archive/delete in a lean overflow menu
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert,
                color: AppTheme.of(context).textSecondary),
            color: AppTheme.of(context).card,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            onSelected: (value) async {
              if (value == 'edit') {
                showEditStackSheet(context, stack: stack);
              } else if (value == 'archive') {
                _confirmArchive(context, stack);
              } else if (value == 'restore') {
                context.read<AppProvider>().unarchiveSideStack(stack.id);
                Navigator.pop(context);
              } else if (value == 'delete') {
                _confirmDelete(context, stack);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_outlined,
                      size: 16,
                      color: AppTheme.of(context).textSecondary),
                  const SizedBox(width: 10),
                  const Text('Edit', style: TextStyle(fontSize: 13)),
                ]),
              ),
              PopupMenuItem<String>(
                value: stack.isArchived ? 'restore' : 'archive',
                child: Row(children: [
                  Icon(
                    stack.isArchived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                    size: 16,
                    color: AppTheme.amber,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    stack.isArchived ? 'Restore' : 'Archive',
                    style: TextStyle(fontSize: 13, color: AppTheme.amber),
                  ),
                ]),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline, size: 16, color: AppTheme.red),
                  const SizedBox(width: 10),
                  Text('Delete',
                      style: TextStyle(fontSize: 13, color: AppTheme.red)),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Visible premium action bar ───────────────────────────────────
          _StackActionBar(
            stack: stack,
            provider: provider,
            onExportCsv: () => _exportCsv(context, stack, provider),
            onExportPdf: () => _exportPdf(context, stack, provider),
            onInvoice: () => showInvoiceSheet(context, stack: stack),
          ),

          // ── Stats grid ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                          icon: Icons.trending_up,
                          label: 'Revenue',
                          value: formatCurrency(stack.totalIncome, symbol),
                          valueColor: AppTheme.green),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatCard(
                          icon: Icons.trending_down,
                          label: 'Expenses',
                          value: formatCurrency(stack.totalExpenses, symbol),
                          valueColor: AppTheme.red),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Net Profit',
                          value: formatCurrency(stack.netProfit, symbol),
                          valueColor: stack.netProfit >= 0
                              ? AppTheme.green
                              : AppTheme.red),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatCard(
                          icon: Icons.percent,
                          label: 'Margin',
                          value: formatPercent(stack.profitMargin),
                          valueColor: stack.profitMargin >= 0
                              ? AppTheme.green
                              : AppTheme.red),
                    ),
                  ],
                ),
                // ── Hourly rate row (only when hours have been logged) ──────
                if (stack.effectiveHourlyRate != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          icon: Icons.timer_outlined,
                          label: 'Hours Logged',
                          value: '${stack.totalHoursWorked.toStringAsFixed(1)} hrs',
                          valueColor: AppTheme.accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StatCard(
                          icon: Icons.attach_money,
                          label: 'Effective ${symbol}/hr',
                          value: formatCurrency(stack.effectiveHourlyRate!, symbol),
                          valueColor: AppTheme.accent,
                        ),
                      ),
                    ],
                  ),
                ],
                if (stack.goalAmount != null || stack.monthlyGoalAmount != null) ...[
                  const SizedBox(height: 8),
                  _GoalProgressBar(stack: stack, symbol: symbol),
                ],
              ],
            ),
          ),
          // ── Tab bar ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppTheme.of(context).card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.of(context).border),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppTheme.of(context).cardAlt,
                  borderRadius: BorderRadius.circular(9),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
                labelColor: AppTheme.of(context).textPrimary,
                unselectedLabelColor: AppTheme.of(context).textSecondary,
                tabs: const [
                  Tab(text: 'Transactions'),
                  Tab(text: 'Analytics'),
                ],
              ),
            ),
          ),
          // ── Tab content ─────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _TransactionTab(stack: stack),
                _AnalyticsTab(stack: stack),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            showAddTransactionSheet(context, preselectedStackId: stack.id),
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _exportCsv(
      BuildContext context, SideStack stack, AppProvider provider) async {
    if (!provider.isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV export is a Pro feature',
              style: TextStyle(fontFamily: 'Sora', fontSize: 13)),
          backgroundColor: AppTheme.of(context).card,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Upgrade',
            textColor: AppTheme.accent,
            onPressed: () {},
          ),
        ),
      );
      return;
    }
    final csv = provider.buildCsv(stackId: stack.id);
    final filename =
        '${stack.name.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}_transactions.csv';
    await downloadCsv(csv, filename);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported $filename',
              style: TextStyle(fontFamily: 'Sora', fontSize: 13)),
          backgroundColor: AppTheme.of(context).card,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _exportPdf(
      BuildContext context, SideStack stack, AppProvider provider) async {
    if (!provider.isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF export is a Pro feature',
              style: TextStyle(fontFamily: 'Sora', fontSize: 13)),
          backgroundColor: AppTheme.of(context).card,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Upgrade',
            textColor: AppTheme.accent,
            onPressed: () {},
          ),
        ),
      );
      return;
    }
    try {
      await exportStackPdf(
        context: context,
        stack: stack,
        currencySymbol: provider.currencySymbol,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not generate PDF: $e',
                style: TextStyle(fontFamily: 'Sora', fontSize: 13)),
            backgroundColor: AppTheme.of(context).card,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _confirmArchive(BuildContext context, SideStack stack) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.of(context).card,
        title: const Text('Archive SideStack?'),
        content: Text(
            '"${stack.name}" will be hidden from your dashboard. All data is preserved and you can restore it any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(
                    color: AppTheme.of(context).textSecondary)),
          ),
          TextButton(
            onPressed: () {
              context.read<AppProvider>().archiveSideStack(stack.id);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Archive',
                style: TextStyle(color: AppTheme.amber)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, SideStack stack) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.of(context).card,
        title: const Text('Delete SideStack?'),
        content: Text(
            'This will permanently delete "${stack.name}" and all its transactions.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(
                    color: AppTheme.of(context).textSecondary)),
          ),
          TextButton(
            onPressed: () {
              context.read<AppProvider>().deleteSideStack(stack.id);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.red)),
          ),
        ],
      ),
    );
  }
}

// ─── Goal Progress Bar ────────────────────────────────────────────────────────

class _GoalProgressBar extends StatelessWidget {
  final SideStack stack;
  final String symbol;
  const _GoalProgressBar({required this.stack, required this.symbol});

  @override
  Widget build(BuildContext context) {
    // Monthly goal takes priority over all-time goal
    final hasMonthly = stack.monthlyGoalAmount != null && stack.monthlyGoalAmount! > 0;
    final hasAllTime = stack.goalAmount != null && stack.goalAmount! > 0;

    if (!hasMonthly && !hasAllTime) return const SizedBox.shrink();

    return Column(
      children: [
        if (hasMonthly) _MonthlyGoalBar(stack: stack, symbol: symbol),
        if (hasMonthly && hasAllTime) const SizedBox(height: 6),
        if (hasAllTime) _AllTimeGoalBar(stack: stack, symbol: symbol),
      ],
    );
  }
}

class _MonthlyGoalBar extends StatelessWidget {
  final SideStack stack;
  final String symbol;
  const _MonthlyGoalBar({required this.stack, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final progress = stack.monthlyGoalProgress;
    final reached = progress >= 1.0;
    final paceMsg = stack.goalPaceMessage(symbol);
    final paceRatio = stack.goalPaceRatio ?? 1.0;
    final color = reached
        ? AppTheme.green
        : (paceRatio >= 1.0 ? AppTheme.accent : AppTheme.amber);
    final now = DateTime.now();
    final monthName = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][now.month - 1];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                reached ? Icons.check_circle_outline : Icons.flag_outlined,
                size: 13,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                '$monthName Goal',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color),
              ),
              const Spacer(),
              Text(
                '${formatCurrency(stack.thisMonthIncome, symbol)} / ${formatCurrency(stack.monthlyGoalAmount!, symbol)}',
                style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.w600,
                    color: color),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          if (paceMsg != null) ...[
            const SizedBox(height: 5),
            Text(
              paceMsg,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: color.withOpacity(0.8)),
            ),
          ],
        ],
      ),
    );
  }
}

class _AllTimeGoalBar extends StatelessWidget {
  final SideStack stack;
  final String symbol;
  const _AllTimeGoalBar({required this.stack, required this.symbol});

  String? _projectionLabel() {
    final goal = stack.goalAmount;
    if (goal == null) return null;
    final remaining = goal - stack.totalIncome;
    if (remaining <= 0) return null;

    final monthly = <String, double>{};
    for (final tx in stack.transactions
        .where((t) => t.type == TransactionType.income)) {
      final key = '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}';
      monthly[key] = (monthly[key] ?? 0) + tx.amount;
    }
    if (monthly.isEmpty) return null;

    final sortedKeys = monthly.keys.toList()..sort();
    final last3 = sortedKeys.reversed.take(3).toList();
    final avgMonthly =
        last3.fold<double>(0, (s, k) => s + monthly[k]!) / last3.length;

    if (avgMonthly <= 0) return null;
    final months = (remaining / avgMonthly).ceil();
    if (months <= 0 || months > 120) return null;
    return months == 1 ? '~1 month at current pace' : '~$months months at current pace';
  }

  @override
  Widget build(BuildContext context) {
    final progress = stack.goalProgress;
    final reached = progress >= 1.0;
    final color = reached ? AppTheme.green : AppTheme.accent;
    final pct = (progress * 100).clamp(0, 100).toStringAsFixed(0);
    final projection = _projectionLabel();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.of(context).card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.of(context).border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                reached ? Icons.check_circle_outline : Icons.flag_outlined,
                size: 13,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                reached
                    ? 'Revenue goal reached! 🎉'
                    : 'Revenue Goal — $pct% there',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.of(context).textSecondary),
              ),
              const Spacer(),
              Text(
                '${formatCurrency(stack.totalIncome, symbol)} / ${formatCurrency(stack.goalAmount!, symbol)}',
                style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'Courier',
                    color: AppTheme.of(context).textMuted),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.of(context).cardAlt,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
          if (projection != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.rocket_launch_outlined,
                    size: 10, color: AppTheme.of(context).textMuted),
                const SizedBox(width: 4),
                Text(
                  projection,
                  style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.of(context).textMuted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Transactions Tab ─────────────────────────────────────────────────────────

enum _TxFilter { all, income, expense }

class _TransactionTab extends StatefulWidget {
  final SideStack stack;
  const _TransactionTab({required this.stack});

  @override
  State<_TransactionTab> createState() => _TransactionTabState();
}

class _TransactionTabState extends State<_TransactionTab> {
  final _searchController = TextEditingController();
  _TxFilter _filter = _TxFilter.all;
  DateTimeRange? _dateRange;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Transaction> _applyFilters(List<Transaction> txs) {
    var result = List<Transaction>.from(txs);

    if (_filter == _TxFilter.income) {
      result =
          result.where((t) => t.type == TransactionType.income).toList();
    } else if (_filter == _TxFilter.expense) {
      result =
          result.where((t) => t.type == TransactionType.expense).toList();
    }

    if (_dateRange != null) {
      result = result.where((t) {
        final d = t.date;
        return !d.isBefore(_dateRange!.start) &&
            !d.isAfter(
                _dateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      result = result
          .where((t) =>
              t.category.toLowerCase().contains(q) ||
              (t.notes?.toLowerCase().contains(q) ?? false))
          .toList();
    }

    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    // Apply the free-tier history gate: free users only see last 90 days
    final visibleTxs = provider.visibleTransactions(widget.stack.transactions);
    final hiddenCount = widget.stack.transactions.length - visibleTxs.length;
    final sorted = _applyFilters(visibleTxs);
    final hasFilters =
        _filter != _TxFilter.all || _dateRange != null || _query.isNotEmpty;

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.of(context).textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search transactions…',
                      hintStyle: TextStyle(
                          fontSize: 12,
                          color: AppTheme.of(context).textMuted),
                      prefixIcon: Icon(Icons.search,
                          size: 16,
                          color: AppTheme.of(context).textMuted),
                      suffixIcon: _query.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              child: Icon(Icons.close,
                                  size: 14,
                                  color: AppTheme.of(context).textMuted),
                            )
                          : null,
                      filled: true,
                      fillColor: AppTheme.of(context).card,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: AppTheme.of(context).border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: AppTheme.of(context).border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: AppTheme.accent, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showFilterSheet(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _dateRange != null
                        ? AppTheme.accentDim
                        : AppTheme.of(context).card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _dateRange != null
                          ? AppTheme.accent
                          : AppTheme.of(context).border,
                    ),
                  ),
                  child: Icon(Icons.tune,
                      size: 16,
                      color: _dateRange != null
                          ? AppTheme.accent
                          : AppTheme.of(context).textMuted),
                ),
              ),
            ],
          ),
        ),
        // Filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  active: _filter == _TxFilter.all,
                  onTap: () => setState(() => _filter = _TxFilter.all),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'Income',
                  active: _filter == _TxFilter.income,
                  color: AppTheme.green,
                  onTap: () =>
                      setState(() => _filter = _TxFilter.income),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'Expense',
                  active: _filter == _TxFilter.expense,
                  color: AppTheme.red,
                  onTap: () =>
                      setState(() => _filter = _TxFilter.expense),
                ),
                if (_dateRange != null) ...[
                  const SizedBox(width: 6),
                  _FilterChip(
                    label:
                        '${DateFormat('MMM d').format(_dateRange!.start)}–${DateFormat('MMM d').format(_dateRange!.end)}',
                    active: true,
                    color: AppTheme.amber,
                    onTap: () => setState(() => _dateRange = null),
                    trailing: Icons.close,
                  ),
                ],
              ],
            ),
          ),
        ),
        // List
        Expanded(
          child: sorted.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off,
                            size: 36,
                            color: AppTheme.of(context).textMuted),
                        const SizedBox(height: 10),
                        Text(
                          hasFilters
                              ? 'No transactions match your filters'
                              : 'No transactions yet',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.of(context).textSecondary),
                        ),
                        if (hasFilters) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _clearFilters,
                            child: Text('Clear filters',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.accent)),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, hiddenCount > 0 ? 20 : 100),
                  itemCount: sorted.length + (hiddenCount > 0 ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i < sorted.length) {
                      return _TransactionRow(
                          tx: sorted[i], stackId: widget.stack.id);
                    }
                    // Locked history banner at the bottom
                    return _LockedHistoryBanner(hiddenCount: hiddenCount);
                  },
                ),
        ),
      ],
    );
  }

  void _clearFilters() => setState(() {
        _filter = _TxFilter.all;
        _dateRange = null;
        _query = '';
        _searchController.clear();
      });

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.of(context).surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FilterSheet(
        initial: _dateRange,
        onApply: (range) => setState(() => _dateRange = range),
        onClear: () => setState(() => _dateRange = null),
      ),
    );
  }
}

// ─── Locked History Banner ─────────────────────────────────────────────────────

class _LockedHistoryBanner extends StatelessWidget {
  final int hiddenCount;
  const _LockedHistoryBanner({required this.hiddenCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 100),
      child: GestureDetector(
        onTap: () => showPaywallSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.accentDim,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lock_outline,
                    size: 16, color: AppTheme.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$hiddenCount older transaction${hiddenCount == 1 ? '' : 's'} hidden',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accent),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Upgrade to Pro to view your full transaction history',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.accent.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 16, color: AppTheme.accent.withOpacity(0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color? color;
  final VoidCallback onTap;
  final IconData? trailing;
  const _FilterChip({
    required this.label,
    required this.active,
    this.color,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? c.withOpacity(0.12) : AppTheme.of(context).card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color:
                  active ? c : AppTheme.of(context).border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: active
                        ? c
                        : AppTheme.of(context).textSecondary)),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              Icon(trailing, size: 11, color: c),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final DateTimeRange? initial;
  final ValueChanged<DateTimeRange?> onApply;
  final VoidCallback onClear;
  const _FilterSheet(
      {required this.initial,
      required this.onApply,
      required this.onClear});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _range = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filter by Date',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.of(context).textPrimary)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () async {
              final result = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 1)),
                initialDateRange: _range,
              );
              if (result != null) setState(() => _range = result);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.of(context).card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _range != null
                        ? AppTheme.accent
                        : AppTheme.of(context).border),
              ),
              child: Row(
                children: [
                  Icon(Icons.date_range_outlined,
                      size: 16,
                      color: AppTheme.of(context).textSecondary),
                  const SizedBox(width: 10),
                  Text(
                    _range != null
                        ? '${fmt.format(_range!.start)}  –  ${fmt.format(_range!.end)}'
                        : 'Select date range',
                    style: TextStyle(
                        fontSize: 13,
                        color: _range != null
                            ? AppTheme.of(context).textPrimary
                            : AppTheme.of(context).textMuted),
                  ),
                  const Spacer(),
                  if (_range != null)
                    GestureDetector(
                      onTap: () => setState(() => _range = null),
                      child: Icon(Icons.close,
                          size: 14,
                          color: AppTheme.of(context).textMuted),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    widget.onClear();
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: AppTheme.of(context).border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Clear',
                      style: TextStyle(
                          color: AppTheme.of(context).textSecondary,
                          fontFamily: 'Sora')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(_range);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Apply',
                      style: TextStyle(fontFamily: 'Sora')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Transaction Row ──────────────────────────────────────────────────────────

class _TransactionRow extends StatelessWidget {
  final Transaction tx;
  final String stackId;
  const _TransactionRow({required this.tx, required this.stackId});

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.type == TransactionType.income;
    final color = isIncome ? AppTheme.green : AppTheme.red;
    final symbol = context.watch<AppProvider>().currencySymbol;

    return Dismissible(
      key: Key(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: AppTheme.redDim,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: AppTheme.red),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.of(context).card,
            title: const Text('Delete transaction?'),
            content: const Text(
                'This transaction will be permanently removed.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel',
                    style: TextStyle(
                        color: AppTheme.of(context).textSecondary)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete',
                    style: TextStyle(color: AppTheme.red)),
              ),
            ],
          ),
        ) ??
            false;
      },
      onDismissed: (_) =>
          context.read<AppProvider>().deleteTransaction(stackId, tx.id),
      child: GestureDetector(
        onTap: () =>
            showEditTransactionSheet(context, tx: tx, stackId: stackId),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.of(context).card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.of(context).border),
          ),
          child: Row(
            children: [
              // Type indicator circle
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isIncome ? AppTheme.greenDim : AppTheme.redDim,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    isIncome ? '+' : '−',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(tx.category,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500)),
                        ),
                        // Recurring badge
                        if (tx.isRecurring)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accentDim,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.autorenew,
                                    size: 9, color: AppTheme.accent),
                                const SizedBox(width: 3),
                                Text(
                                  tx.recurrenceInterval?.label ??
                                      'Recurring',
                                  style: const TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.accent),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    Text(
                      '${DateFormat('MMM d').format(tx.date)}${tx.notes != null ? ' · ${tx.notes}' : ''}',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.of(context).textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${isIncome ? '+' : '−'}${formatCurrency(tx.amount, symbol)}',
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              if (tx.receiptUrl != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _showReceipt(context, tx.receiptUrl!),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentDim,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.receipt_outlined,
                      size: 12,
                      color: AppTheme.accent,
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

void _showReceipt(BuildContext context, String url) {
  Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _ReceiptViewerPage(url: url),
    ),
  );
}

// ─── Receipt Viewer ───────────────────────────────────────────────────────────

class _ReceiptViewerPage extends StatelessWidget {
  final String url;
  const _ReceiptViewerPage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Receipt',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                      : null,
                  color: AppTheme.accent,
                  strokeWidth: 2,
                ),
              );
            },
            errorBuilder: (context, error, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.broken_image_outlined,
                    color: Colors.white54, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Could not load receipt',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Client Breakdown Card ────────────────────────────────────────────────────

class _ClientBreakdownCard extends StatelessWidget {
  final SideStack stack;
  final String symbol;
  const _ClientBreakdownCard({required this.stack, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final clients = stack.clientRevenue;
    if (clients.isEmpty) return const SizedBox.shrink();

    final total = stack.totalIncome;

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
            Icon(Icons.people_outline,
                size: 14, color: AppTheme.of(context).textMuted),
            const SizedBox(width: 6),
            Text(
              'CLIENTS',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.of(context).textMuted,
                  letterSpacing: 0.8),
            ),
            const Spacer(),
            Text(
              '${clients.length} client${clients.length == 1 ? '' : 's'}',
              style: TextStyle(
                  fontSize: 10, color: AppTheme.of(context).textMuted),
            ),
          ]),
          const SizedBox(height: 12),
          ...clients.entries.toList().asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            final pct = total > 0 ? e.value / total : 0.0;
            final colors = [
              AppTheme.accent,
              AppTheme.green,
              AppTheme.amber,
              AppTheme.red,
            ];
            final color = colors[i % colors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(e.key,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ),
                    Text(formatCurrency(e.value, symbol),
                        style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Courier',
                            color: AppTheme.of(context).textSecondary)),
                    const SizedBox(width: 8),
                    Text('${(pct * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: color)),
                  ]),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: AppTheme.of(context).cardAlt,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 4,
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

// ─── Hourly Rate Card ─────────────────────────────────────────────────────────

class _HourlyRateCard extends StatelessWidget {
  final SideStack stack;
  final String symbol;
  const _HourlyRateCard({required this.stack, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final rate = stack.effectiveHourlyRate;
    final hours = stack.totalHoursWorked;
    if (rate == null) return const SizedBox.shrink();

    final color = rate >= 50
        ? AppTheme.green
        : rate >= 20
            ? AppTheme.amber
            : AppTheme.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.timer_outlined, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('EFFECTIVE HOURLY RATE',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: color.withOpacity(0.7),
                      letterSpacing: 0.8)),
              const SizedBox(height: 4),
              Text(
                '${formatCurrency(rate, symbol)}/hr',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontFamily: 'Courier'),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${hours.toStringAsFixed(1)} hrs',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.of(context).textPrimary),
            ),
            Text(
              'logged',
              style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.of(context).textMuted),
            ),
          ],
        ),
      ]),
    );
  }
}

// ─── Analytics Tab ────────────────────────────────────────────────────────────

class _AnalyticsTab extends StatelessWidget {
  final SideStack stack;
  const _AnalyticsTab({required this.stack});

  Map<String, Map<String, double>> _buildMonthlyData() {
    final map = <String, Map<String, double>>{};
    for (final tx in stack.transactions) {
      final key = DateFormat('MMM yy').format(tx.date);
      map.putIfAbsent(key, () => {'income': 0, 'expense': 0});
      if (tx.type == TransactionType.income) {
        map[key]!['income'] = map[key]!['income']! + tx.amount;
      } else {
        map[key]!['expense'] = map[key]!['expense']! + tx.amount;
      }
    }
    final sortedKeys = map.keys.toList()
      ..sort((a, b) => DateFormat('MMM yy')
          .parse(a)
          .compareTo(DateFormat('MMM yy').parse(b)));
    return {for (final k in sortedKeys) k: map[k]!};
  }

  Map<String, double> _buildExpenseBreakdown() {
    final map = <String, double>{};
    for (final tx in stack.transactions
        .where((t) => t.type == TransactionType.expense)) {
      map[tx.category] = (map[tx.category] ?? 0) + tx.amount;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    if (stack.transactions.isEmpty) {
      return const EmptyState(
        emoji: '📈',
        title: 'No data yet',
        subtitle: 'Add your first income or expense to start tracking this stack.',
      );
    }

    final symbol = context.watch<AppProvider>().currencySymbol;
    final monthly = _buildMonthlyData();
    final expBreakdown = _buildExpenseBreakdown();
    final months = monthly.keys.toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // Hourly rate card (shown when hours have been logged)
        _HourlyRateCard(stack: stack, symbol: symbol),
        if (stack.effectiveHourlyRate != null) const SizedBox(height: 10),

        // Client breakdown (shown when client names exist)
        _ClientBreakdownCard(stack: stack, symbol: symbol),
        if (stack.clientRevenue.isNotEmpty) const SizedBox(height: 10),

        if (months.length > 1) ...[
          _ChartCard(
            title: 'Profit Over Time',
            child: SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 200,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppTheme.of(context).border,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 20,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= months.length) {
                            return const SizedBox();
                          }
                          return Text(months[i],
                              style: TextStyle(
                                  fontSize: 9,
                                  color: AppTheme.of(context).textMuted));
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: months.asMap().entries.map((e) {
                        final d = monthly[e.value]!;
                        return FlSpot(e.key.toDouble(),
                            d['income']! - d['expense']!);
                      }).toList(),
                      isCurved: true,
                      color: AppTheme.green,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        getDotPainter: (_, __, ___, ____) =>
                            FlDotCirclePainter(
                                radius: 3,
                                color: AppTheme.green,
                                strokeWidth: 0,
                                strokeColor: Colors.transparent),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.green.withOpacity(0.08),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _ChartCard(
            title: 'Income vs Expenses',
            child: SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                        color: AppTheme.of(context).border,
                        strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 20,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= months.length) {
                            return const SizedBox();
                          }
                          return Text(months[i],
                              style: TextStyle(
                                  fontSize: 9,
                                  color: AppTheme.of(context).textMuted));
                        },
                      ),
                    ),
                  ),
                  barGroups: months.asMap().entries.map((e) {
                    final d = monthly[e.value]!;
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                            toY: d['income']!,
                            color: AppTheme.green,
                            width: 8,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4))),
                        BarChartRodData(
                            toY: d['expense']!,
                            color: AppTheme.red,
                            width: 8,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4))),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (expBreakdown.isNotEmpty)
          _ChartCard(
            title: 'Expense Breakdown',
            child: SizedBox(
              height: 160,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 36,
                        sections: expBreakdown.entries
                            .toList()
                            .asMap()
                            .entries
                            .map((e) {
                          final colors = [
                            AppTheme.red,
                            AppTheme.amber,
                            AppTheme.accent,
                            AppTheme.green
                          ];
                          return PieChartSectionData(
                            value: e.value.value,
                            color: colors[e.key % colors.length],
                            radius: 44,
                            showTitle: false,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: expBreakdown.entries
                        .toList()
                        .asMap()
                        .entries
                        .map((e) {
                      final colors = [
                        AppTheme.red,
                        AppTheme.amber,
                        AppTheme.accent,
                        AppTheme.green
                      ];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: colors[e.key % colors.length],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(e.value.key,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.of(context)
                                        .textSecondary)),
                            const SizedBox(width: 8),
                            Text(formatCurrency(e.value.value, symbol),
                                style: TextStyle(
                                    fontFamily: 'Courier',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.of(context).card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.of(context).border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.of(context).textMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ─── Visible Stack Action Bar ─────────────────────────────────────────────────

class _StackActionBar extends StatelessWidget {
  final SideStack stack;
  final AppProvider provider;
  final VoidCallback onExportCsv;
  final VoidCallback onExportPdf;
  final VoidCallback onInvoice;

  const _StackActionBar({
    required this.stack,
    required this.provider,
    required this.onExportCsv,
    required this.onExportPdf,
    required this.onInvoice,
  });

  @override
  Widget build(BuildContext context) {
    final isPro = provider.isPremium;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.of(context).card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.of(context).border),
      ),
      child: Row(
        children: [
          _ActionButton(
            icon: Icons.receipt_long_outlined,
            label: 'Invoice',
            isPro: !isPro,
            color: AppTheme.accent,
            onTap: () {
              if (isPro) {
                onInvoice();
              } else {
                showPaywallSheet(context);
              }
            },
          ),
          _ActionDivider(),
          _ActionButton(
            icon: Icons.download_outlined,
            label: 'CSV',
            isPro: !isPro,
            color: AppTheme.green,
            onTap: () {
              if (isPro) {
                onExportCsv();
              } else {
                showPaywallSheet(context);
              }
            },
          ),
          _ActionDivider(),
          _ActionButton(
            icon: Icons.picture_as_pdf_outlined,
            label: 'PDF',
            isPro: !isPro,
            color: AppTheme.red,
            onTap: () {
              if (isPro) {
                onExportPdf();
              } else {
                showPaywallSheet(context);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isPro;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.isPro,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isPro
        ? AppTheme.of(context).textMuted
        : color;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 20, color: effectiveColor),
                  if (isPro)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.amber.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'PRO',
                          style: TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: effectiveColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 28,
        color: AppTheme.of(context).border,
      );
}
