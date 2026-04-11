import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/add_transaction_sheet.dart';
import '../services/tax_pdf_service.dart';

// Public entry point so the Dashboard can open the layout editor directly.
void showInsightsLayoutEditor(BuildContext context) {
  final provider = context.read<AppProvider>();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LayoutEditorSheet(
      order: List<String>.from(provider.analyticsOrder),
      hidden: Set<String>.from(provider.analyticsHidden),
      onSave: (newOrder, newHidden) {
        provider.setAnalyticsOrder(newOrder);
        provider.setAnalyticsHidden(newHidden);
      },
    ),
  );
}

// ─── Tax-deductible expense categories (mirrors add_transaction_sheet.dart) ───
const _kTaxDeductibleExpenses = {
  'Motor Vehicle',
  'Tools & Equipment',
  'Home Office',
  'Marketing',
  'Professional Fees',
  'Travel',
  'Meals',
  'Software & Subscriptions',
  'Supplies',
  'Insurance',
};

// ─── Colour palettes ──────────────────────────────────────────────────────────
const _kIncomeColors = [
  AppTheme.green,
  Color(0xFF26C6A2),
  Color(0xFF4FC3F7),
  Color(0xFF81C784),
];
const _kExpenseColors = [
  AppTheme.red,
  AppTheme.amber,
  AppTheme.accent,
  Color(0xFFE040FB),
];
const _kDow = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

// ─── Section metadata ─────────────────────────────────────────────────────────

const _kSectionLabels = <String, String>{
  kAnalyticsSectionKpi: 'KPI Summary',
  kAnalyticsSectionInsights: 'What\'s Happening',
  kAnalyticsSectionProfitTrend: 'Profit Trend',
  kAnalyticsSectionIncomeExpense: 'Income vs Expenses',
  kAnalyticsSectionCumulative: 'Cumulative Earnings',
  kAnalyticsSectionIncomeBreakdown: 'Income Sources',
  kAnalyticsSectionExpenseBreakdown: 'Expense Breakdown',
  kAnalyticsSectionTopCategories: 'Top Categories',
  kAnalyticsSectionDayOfWeek: 'Activity by Day',
  kAnalyticsSectionStackComparison: 'Stack Comparison',
  kAnalyticsSectionMarginOverTime: 'Margin Over Time',
  kAnalyticsSectionExpenseRatio: 'Expense Ratio',
  kAnalyticsSectionYoY: 'Year-over-Year',
  kAnalyticsSectionTax: 'Tax Estimate',
  kAnalyticsSectionProjection: 'Annual Projection',
  // Premium
  kAnalyticsSectionInsightEngine:      'Insight Engine',
  kAnalyticsSectionClientIntelligence: 'Client Intelligence',
  kAnalyticsSectionHourlyRate:         'Hourly Rate Tracker',
  kAnalyticsSectionGoalVelocity:       'Goal Velocity',
  kAnalyticsSectionAnomalies:          'Spending Anomalies',
};

const _kSectionIcons = <String, IconData>{
  kAnalyticsSectionKpi: Icons.dashboard_outlined,
  kAnalyticsSectionInsights: Icons.lightbulb_outline,
  kAnalyticsSectionProfitTrend: Icons.show_chart,
  kAnalyticsSectionIncomeExpense: Icons.bar_chart,
  kAnalyticsSectionCumulative: Icons.trending_up,
  kAnalyticsSectionIncomeBreakdown: Icons.pie_chart_outline,
  kAnalyticsSectionExpenseBreakdown: Icons.donut_small_outlined,
  kAnalyticsSectionTopCategories: Icons.list_alt_outlined,
  kAnalyticsSectionDayOfWeek: Icons.calendar_view_week_outlined,
  kAnalyticsSectionStackComparison: Icons.compare_arrows,
  kAnalyticsSectionMarginOverTime: Icons.percent,
  kAnalyticsSectionExpenseRatio: Icons.speed_outlined,
  kAnalyticsSectionYoY: Icons.compare_outlined,
  kAnalyticsSectionTax: Icons.account_balance_outlined,
  kAnalyticsSectionProjection: Icons.rocket_launch_outlined,
  // Premium
  kAnalyticsSectionInsightEngine:      Icons.psychology_outlined,
  kAnalyticsSectionClientIntelligence: Icons.people_outline,
  kAnalyticsSectionHourlyRate:         Icons.timer_outlined,
  kAnalyticsSectionGoalVelocity:       Icons.flag_outlined,
  kAnalyticsSectionAnomalies:          Icons.warning_amber_outlined,
};

// ─── Screen ───────────────────────────────────────────────────────────────────

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  DateTimeRange? _dateRange;
  // '1M', '3M', '6M', 'All', or null when a custom range is active
  String _selectedPreset = 'All';

  void _setPreset(String preset) {
    final now = DateTime.now();
    DateTimeRange? range;
    switch (preset) {
      case '1M':
        range = DateTimeRange(
            start: DateTime(now.year, now.month - 1, now.day), end: now);
        break;
      case '3M':
        range = DateTimeRange(
            start: DateTime(now.year, now.month - 3, now.day), end: now);
        break;
      case '6M':
        range = DateTimeRange(
            start: DateTime(now.year, now.month - 6, now.day), end: now);
        break;
      case 'All':
      default:
        range = null;
    }
    setState(() {
      _dateRange = range;
      _selectedPreset = preset;
    });
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _dateRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month - 2, 1),
            end: now,
          ),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppTheme.accent,
            surface: AppTheme.of(context).card,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _dateRange = picked;
        _selectedPreset = 'Custom'; // Custom range — no preset highlighted
      });
    }
  }

  // ── data builders ──────────────────────────────────────────────────────────

  static Map<String, Map<String, double>> _monthly(List<Transaction> txs) {
    final map = <String, Map<String, double>>{};
    for (final tx in txs) {
      final key = DateFormat('MMM yy').format(tx.date);
      map.putIfAbsent(key, () => {'income': 0.0, 'expense': 0.0});
      if (tx.type == TransactionType.income) {
        map[key]!['income'] = map[key]!['income']! + tx.amount;
      } else {
        map[key]!['expense'] = map[key]!['expense']! + tx.amount;
      }
    }
    final sorted = map.keys.toList()
      ..sort((a, b) => DateFormat('MMM yy')
          .parse(a)
          .compareTo(DateFormat('MMM yy').parse(b)));
    return {for (final k in sorted) k: map[k]!};
  }

  static Map<String, double> _byCategory(
      List<Transaction> txs, TransactionType type) {
    final map = <String, double>{};
    for (final tx in txs.where((t) => t.type == type)) {
      map[tx.category] = (map[tx.category] ?? 0) + tx.amount;
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in sorted) e.key: e.value};
  }

  static List<double> _dowTotals(List<Transaction> txs) {
    // index 0 = Mon (weekday 1), 6 = Sun (weekday 7)
    final totals = List<double>.filled(7, 0);
    for (final tx in txs) {
      totals[tx.date.weekday - 1] += tx.amount;
    }
    return totals;
  }

  /// Returns monthly net-profit for [year], indexed 0–11 (Jan–Dec).
  static List<double> _yoyMonthlyProfit(List<Transaction> txs, int year) {
    final totals = List<double>.filled(12, 0);
    for (final tx in txs.where((t) => t.date.year == year)) {
      final idx = tx.date.month - 1;
      if (tx.type == TransactionType.income) {
        totals[idx] += tx.amount;
      } else {
        totals[idx] -= tx.amount;
      }
    }
    return totals;
  }

  // ── layout editor ──────────────────────────────────────────────────────────

  void _showLayoutEditor(BuildContext context, AppProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LayoutEditorSheet(
        order: List<String>.from(provider.analyticsOrder),
        hidden: Set<String>.from(provider.analyticsHidden),
        onSave: (newOrder, newHidden) {
          provider.setAnalyticsOrder(newOrder);
          provider.setAnalyticsHidden(newHidden);
        },
      ),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final symbol = provider.currencySymbol;
    final allTx = provider.allTransactions.toList();

    if (allTx.isEmpty) {
      return Scaffold(
        body: EmptyState(
          emoji: '📊',
          title: 'No insights yet',
          subtitle: 'Log your first income or expense and your analytics will appear here automatically.',
          buttonLabel: 'Add a transaction',
          onButton: () => showAddTransactionSheet(context),
        ),
      );
    }

    // Apply optional date range filter
    final filteredTx = _dateRange == null
        ? allTx
        : allTx
            .where((t) =>
                !t.date.isBefore(_dateRange!.start) &&
                !t.date.isAfter(
                    _dateRange!.end.add(const Duration(days: 1))))
            .toList();

    // Filtered totals — computed early because insights reference them
    final filteredIncome = filteredTx
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (a, t) => a + t.amount);
    final filteredExpenses = filteredTx
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (a, t) => a + t.amount);
    final filteredProfit = filteredIncome - filteredExpenses;

    final monthlyData = _monthly(filteredTx);
    final months = monthlyData.keys.toList();
    final incBreakdown = _byCategory(filteredTx, TransactionType.income);
    final expBreakdown = _byCategory(filteredTx, TransactionType.expense);
    final dowData = _dowTotals(filteredTx);
    final stackComp = provider.stacks
        .map((s) => MapEntry(s.name, s.netProfit))
        .toList();

    // Year-over-year: compare current year vs previous year using ALL transactions
    final nowYear = DateTime.now().year;
    final yoyThisYear = _yoyMonthlyProfit(allTx, nowYear);
    final yoyLastYear = _yoyMonthlyProfit(allTx, nowYear - 1);
    final yoyHasLastYear = yoyLastYear.any((v) => v != 0);

    // KPI calculations
    final avgMonthly = months.isNotEmpty
        ? monthlyData.values.fold<double>(
                0, (a, m) => a + m['income']! - m['expense']!) /
            months.length
        : 0.0;

    String bestLabel = months.isNotEmpty ? months.first : '—';
    double bestVal = double.negativeInfinity;
    for (final e in monthlyData.entries) {
      final p = e.value['income']! - e.value['expense']!;
      if (p > bestVal) {
        bestVal = p;
        bestLabel = e.key;
      }
    }

    // ── Top client (for named insights) ──────────────────────────────────
    final clientRevMap = <String, double>{};
    for (final tx in filteredTx.where(
        (t) => t.type == TransactionType.income && t.clientName != null)) {
      final name = tx.clientName!.trim();
      if (name.isNotEmpty) {
        clientRevMap[name] = (clientRevMap[name] ?? 0) + tx.amount;
      }
    }
    final topClient = clientRevMap.isEmpty
        ? null
        : clientRevMap.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;

    // ── AI Insight paragraph ─────────────────────────────────────────────
    final monthList = monthlyData.entries.toList();
    final aiSentences = <String>[];

    // Consecutive profitable months streak
    int streak = 0;
    for (final e in monthList.reversed) {
      if (e.value['income']! - e.value['expense']! > 0) streak++;
      else break;
    }

    // Income trend vs last month
    if (monthList.length >= 2) {
      final cur  = monthList.last.value;
      final prev = monthList[monthList.length - 2].value;
      if (prev['income']! > 0) {
        final pct = ((cur['income']! - prev['income']!) / prev['income']! * 100).round();
        if (pct >= 10) {
          final clientSuffix = topClient != null ? ' $topClient is leading the charge.' : '';
          aiSentences.add('Your income jumped $pct% compared to last month. That\'s a strong result worth building on.$clientSuffix');
        } else if (pct >= 0) {
          aiSentences.add('Income held steady with a modest $pct% gain over last month.');
        } else {
          aiSentences.add('Income dipped ${pct.abs()}% from last month, so it\'s worth reviewing what changed and whether it\'s a one-off or a trend.');
        }
      }
      // Expense movement
      if (prev['expense']! > 0) {
        final pct = ((cur['expense']! - prev['expense']!) / prev['expense']! * 100).round();
        if (pct > 30) {
          aiSentences.add('Expenses spiked $pct% this month. A closer look at where the extra spend went could protect your margins.');
        } else if (pct < -10) {
          aiSentences.add('You trimmed expenses by ${pct.abs()}% from last month, which is excellent cost discipline.');
        }
      }
    }

    // Profit margin
    if (filteredIncome > 0) {
      final marginPct = filteredProfit / filteredIncome * 100;
      if (marginPct > 60) {
        aiSentences.add('A ${marginPct.toStringAsFixed(0)}% profit margin puts you in great shape. Most of what you earn is staying in your pocket.');
      } else if (marginPct > 30) {
        aiSentences.add('Your ${marginPct.toStringAsFixed(0)}% profit margin is healthy and suggests your hustles are running efficiently.');
      } else if (marginPct > 0) {
        aiSentences.add('At ${marginPct.toStringAsFixed(0)}% profit margin there\'s room to grow. Even small reductions in recurring costs can make a noticeable difference.');
      } else {
        aiSentences.add('You\'re currently spending more than you\'re earning, so focusing on either boosting revenue or cutting costs should be the priority right now.');
      }
    }

    // Streak
    if (streak >= 3) {
      aiSentences.add('$streak profitable months in a row is a real streak. Keep doing what\'s working.');
    } else if (streak == 2) {
      aiSentences.add('Two profitable months back-to-back is a good sign. One more and you\'ve got a proper streak going.');
    }

    // Income acceleration
    if (monthList.length >= 3) {
      final inc1 = monthList[monthList.length - 3].value['income']!;
      final inc2 = monthList[monthList.length - 2].value['income']!;
      final inc3 = monthList.last.value['income']!;
      if (inc1 > 0 && inc2 > inc1 && inc3 > inc2) {
        final totalGrowth = ((inc3 - inc1) / inc1 * 100).round();
        aiSentences.add('Revenue has grown $totalGrowth% over the last three months in a row. That\'s genuine momentum.');
      }
    }

    // Best performing stack (margin-based, with specific name)
    if (provider.stacks.length > 1) {
      final ranked = provider.stacks
          .where((s) => s.totalIncome > 0)
          .toList()
        ..sort((a, b) => b.profitMargin.compareTo(a.profitMargin));
      if (ranked.isNotEmpty) {
        final best = ranked.first;
        aiSentences.add('"${best.name}" is your highest-margin hustle at ${best.profitMargin.toStringAsFixed(0)}%. It may be worth investing more time there.');
      }
    } else if (provider.stacks.length == 1 && topClient != null) {
      // Single stack — surface the top client instead
      final clientPct = clientRevMap.isNotEmpty && filteredIncome > 0
          ? (clientRevMap[topClient]! / filteredIncome * 100).round()
          : 0;
      if (clientPct >= 40) {
        aiSentences.add('$topClient accounts for $clientPct% of your income. Strong relationship, but worth keeping your client mix diversified over time.');
      } else if (clientPct > 0) {
        aiSentences.add('$topClient is your biggest earner so far, bringing in $clientPct% of your revenue this period.');
      }
    }

    // Top client (multi-stack context — only if not already mentioned)
    if (provider.stacks.length > 1 && topClient != null) {
      final clientPct = clientRevMap.isNotEmpty && filteredIncome > 0
          ? (clientRevMap[topClient]! / filteredIncome * 100).round()
          : 0;
      if (clientPct >= 40) {
        aiSentences.add('$topClient is responsible for $clientPct% of your total income this period. A valuable relationship, though it\'s worth building other revenue streams alongside it.');
      }
    }

    // Dormant month
    if (monthList.isNotEmpty) {
      final lastMonthIncome = monthList.last.value['income']!;
      if (lastMonthIncome == 0 && filteredIncome > 0) {
        aiSentences.add('No income has been logged this month yet. If that\'s just timing, no worries, but if things have slowed down it\'s a good time to check in on your hustles.');
      }
    }

    final aiInsight = aiSentences.isEmpty
        ? 'Log a few more transactions and come back. Once there\'s enough data, this section will surface personalised observations about how your hustles are really performing.'
        : aiSentences.join(' ');

    // ── Financial health computations ────────────────────────────────────
    final marginOverTime = monthList
        .map((e) => MapEntry(
              e.key,
              e.value['income']! > 0
                  ? ((e.value['income']! - e.value['expense']!) /
                          e.value['income']! *
                          100)
                  : 0.0,
            ))
        .toList();

    final expenseRatio = filteredIncome > 0
        ? (filteredExpenses / filteredIncome).clamp(0.0, 1.5)
        : 0.0;

    double projectionMonthly = avgMonthly;
    if (monthList.length >= 3) {
      final last3 = monthList.sublist(monthList.length - 3);
      projectionMonthly = last3.fold<double>(
              0, (a, e) => a + e.value['income']! - e.value['expense']!) /
          3;
    }
    final projectionAnnual = projectionMonthly * 12;

    // ── Premium analytics data computations ───────────────────────────────

    // 1. Insight Engine — generate prioritised, prescriptive recommendations
    final insightItems = <_InsightItem>[];

    // Concentration risk: single client > 60% revenue
    if (clientRevMap.isNotEmpty && filteredIncome > 0) {
      final topEntry = clientRevMap.entries
          .reduce((a, b) => a.value > b.value ? a : b);
      final pct = (topEntry.value / filteredIncome * 100).round();
      if (pct >= 60) {
        insightItems.add(_InsightItem(
          priority: _InsightPriority.warning,
          title: 'Revenue concentration risk',
          body: '${topEntry.key} accounts for $pct% of your income. A single client at more than 60% creates fragility. Prioritise landing at least one more.',
          action: 'Diversify client mix',
        ));
      }
    }

    // Expense spike vs prior month
    if (monthList.length >= 2) {
      final cur  = monthList.last.value;
      final prev = monthList[monthList.length - 2].value;
      if (prev['expense']! > 0) {
        final expPct = ((cur['expense']! - prev['expense']!) / prev['expense']! * 100).round();
        if (expPct >= 40) {
          insightItems.add(_InsightItem(
            priority: _InsightPriority.warning,
            title: 'Expense spike this month',
            body: 'Your costs jumped $expPct% vs last month. Review your expense log. If it\'s a one-off purchase that\'s fine, but watch for repeat spend.',
            action: 'Review expenses',
          ));
        }
      }
      // Income drop
      if (prev['income']! > 0) {
        final incPct = ((cur['income']! - prev['income']!) / prev['income']! * 100).round();
        if (incPct <= -25) {
          insightItems.add(_InsightItem(
            priority: _InsightPriority.warning,
            title: 'Income dropped ${incPct.abs()}% this month',
            body: 'Revenue fell sharply compared to last month. Consider whether any recurring clients paused, or whether seasonal factors are at play.',
            action: 'Investigate revenue drop',
          ));
        }
      }
    }

    // Low margin opportunity
    if (filteredIncome > 0) {
      final margin = filteredProfit / filteredIncome * 100;
      if (margin > 0 && margin < 25) {
        insightItems.add(_InsightItem(
          priority: _InsightPriority.watch,
          title: 'Thin profit margin (${margin.toStringAsFixed(0)}%)',
          body: 'You\'re keeping less than a quarter of what you earn. Look at your expense categories. Even cutting one recurring cost can noticeably lift take-home.',
          action: 'Audit expense categories',
        ));
      }
    }

    // Hourly rate decline opportunity
    for (final stack in provider.stacks) {
      if (stack.effectiveHourlyRate != null && stack.totalHoursWorked >= 5) {
        final rate = stack.effectiveHourlyRate!;
        if (rate < 15) {
          insightItems.add(_InsightItem(
            priority: _InsightPriority.watch,
            title: 'Low hourly rate on "${stack.name}"',
            body: 'Your effective rate is ${symbol}${rate.toStringAsFixed(0)}/hr. Consider whether you can raise prices, work more efficiently, or shift to higher-value tasks.',
            action: 'Review pricing',
          ));
        }
      }
    }

    // Momentum opportunity
    if (monthList.length >= 3) {
      final inc1 = monthList[monthList.length - 3].value['income']!;
      final inc2 = monthList[monthList.length - 2].value['income']!;
      final inc3 = monthList.last.value['income']!;
      if (inc1 > 0 && inc2 > inc1 && inc3 > inc2) {
        final totalGrowth = ((inc3 - inc1) / inc1 * 100).round();
        if (totalGrowth >= 20) {
          insightItems.add(_InsightItem(
            priority: _InsightPriority.opportunity,
            title: 'Strong growth momentum (+$totalGrowth% over 3 months)',
            body: 'Revenue has grown three months in a row. This is a good time to invest in scaling: raise rates, expand capacity, or tackle a bigger client.',
            action: 'Double down on what\'s working',
          ));
        }
      }
    }

    // Best stack opportunity
    if (provider.stacks.length > 1) {
      final profitable = provider.stacks
          .where((s) => s.totalIncome > 0)
          .toList()
        ..sort((a, b) => b.profitMargin.compareTo(a.profitMargin));
      if (profitable.length >= 2) {
        final best  = profitable.first;
        final worst = profitable.last;
        if (best.profitMargin - worst.profitMargin > 30) {
          insightItems.add(_InsightItem(
            priority: _InsightPriority.opportunity,
            title: '"${best.name}" outperforms "${worst.name}" by ${(best.profitMargin - worst.profitMargin).round()}pp',
            body: '"${best.name}" has a ${best.profitMargin.toStringAsFixed(0)}% margin vs ${worst.profitMargin.toStringAsFixed(0)}% for "${worst.name}". Consider shifting time toward your higher-margin hustle.',
            action: 'Rebalance time allocation',
          ));
        }
      }
    }

    // 2. Client Intelligence data
    final sortedClients = clientRevMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalClientRevenue = sortedClients.fold(0.0, (s, e) => s + e.value);
    final topClientConcentration = (totalClientRevenue > 0 && sortedClients.isNotEmpty)
        ? sortedClients.first.value / totalClientRevenue
        : 0.0;

    // 3. Hourly rate data — collect per-stack
    final hourlyRateData = <_StackHourlyRate>[];
    for (final stack in provider.stacks) {
      if (stack.effectiveHourlyRate != null && stack.totalHoursWorked >= 1) {
        hourlyRateData.add(_StackHourlyRate(
          name: stack.name,
          rate: stack.effectiveHourlyRate!,
          hours: stack.totalHoursWorked,
        ));
      }
    }
    hourlyRateData.sort((a, b) => b.rate.compareTo(a.rate));

    // 4. Goal velocity — stacks with monthly goals
    final goalVelocityData = <_GoalVelocityEntry>[];
    for (final stack in provider.stacks) {
      if (stack.monthlyGoalAmount != null && stack.monthlyGoalAmount! > 0) {
        final now = DateTime.now();
        final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
        final dayOfMonth  = now.day;
        final paceRatio   = dayOfMonth > 0
            ? (stack.thisMonthIncome / stack.monthlyGoalAmount!) /
              (dayOfMonth / daysInMonth)
            : 0.0;
        goalVelocityData.add(_GoalVelocityEntry(
          name: stack.name,
          goal: stack.monthlyGoalAmount!,
          earned: stack.thisMonthIncome,
          progress: stack.monthlyGoalProgress,
          paceRatio: paceRatio,
        ));
      }
    }

    // 5. Spending anomalies — compare halves of the filtered period
    final anomalies = <_AnomalyEntry>[];
    if (filteredTx.length >= 6 && monthList.length >= 2) {
      // Split filtered transactions into first-half and second-half months
      final halfIdx = monthList.length ~/ 2;
      final firstHalfKeys = monthList.sublist(0, halfIdx).map((e) => e.key).toSet();
      final secondHalfKeys = monthList.sublist(halfIdx).map((e) => e.key).toSet();
      final Map<String, double> firstHalfExp  = {};
      final Map<String, double> secondHalfExp = {};
      for (final tx in filteredTx.where((t) => t.type == TransactionType.expense)) {
        final key = DateFormat('MMM yy').format(tx.date);
        if (firstHalfKeys.contains(key)) {
          firstHalfExp[tx.category] = (firstHalfExp[tx.category] ?? 0) + tx.amount;
        } else if (secondHalfKeys.contains(key)) {
          secondHalfExp[tx.category] = (secondHalfExp[tx.category] ?? 0) + tx.amount;
        }
      }
      // Normalise to per-month averages
      final firstMonths  = halfIdx.toDouble().clamp(1.0, 100.0);
      final secondMonths = (monthList.length - halfIdx).toDouble().clamp(1.0, 100.0);
      final allCategories = {...firstHalfExp.keys, ...secondHalfExp.keys};
      for (final cat in allCategories) {
        final avgFirst  = (firstHalfExp[cat] ?? 0) / firstMonths;
        final avgSecond = (secondHalfExp[cat] ?? 0) / secondMonths;
        if (avgFirst > 0 && avgSecond > avgFirst * 1.5) {
          anomalies.add(_AnomalyEntry(
            category: cat,
            oldAvg: avgFirst,
            newAvg: avgSecond,
            isIncrease: true,
          ));
        } else if (avgSecond > 0 && avgFirst > avgSecond * 1.5) {
          anomalies.add(_AnomalyEntry(
            category: cat,
            oldAvg: avgFirst,
            newAvg: avgSecond,
            isIncrease: false,
          ));
        }
      }
      anomalies.sort((a, b) {
        final ra = (a.newAvg - a.oldAvg).abs();
        final rb = (b.newAvg - b.oldAvg).abs();
        return rb.compareTo(ra);
      });
    }

    // ── Build ordered section widgets ─────────────────────────────────────
    Widget? _sw(String id) {
      switch (id) {
        case kAnalyticsSectionKpi:
          return _KpiRow(
            txCount: filteredTx.length,
            bestLabel: bestLabel,
            bestVal: bestVal.isInfinite ? 0 : bestVal,
            avgMonthly: avgMonthly,
            margin: filteredIncome > 0
                ? filteredProfit / filteredIncome * 100
                : 0.0,
            symbol: symbol,
          );
        case kAnalyticsSectionProfitTrend:
          if (months.length <= 1) return null;
          return _ChartCard(
            title: 'Profit Trend',
            subtitle: 'Net profit per month',
            child: SizedBox(
              height: 160,
              child: _ProfitTrendChart(monthly: monthlyData, months: months),
            ),
          );
        case kAnalyticsSectionIncomeExpense:
          if (months.length <= 1) return null;
          return _ChartCard(
            title: 'Income vs Expenses',
            subtitle: 'Side-by-side monthly view',
            child: SizedBox(
              height: 160,
              child: _IncomeExpenseChart(monthly: monthlyData, months: months),
            ),
          );
        case kAnalyticsSectionCumulative:
          if (months.length <= 1) return null;
          return _ChartCard(
            title: 'Cumulative Earnings',
            subtitle: 'Running total profit over time',
            child: SizedBox(
              height: 130,
              child: _CumulativeChart(monthly: monthlyData, months: months),
            ),
          );
        case kAnalyticsSectionIncomeBreakdown:
          if (incBreakdown.isEmpty) return null;
          return _ChartCard(
            title: 'Income Sources',
            subtitle: 'Revenue by category',
            child: _PieWithLegend(
                data: incBreakdown, colors: _kIncomeColors, symbol: symbol),
          );
        case kAnalyticsSectionExpenseBreakdown:
          if (expBreakdown.isEmpty) return null;
          final estDeductions = expBreakdown.entries
              .where((e) => _kTaxDeductibleExpenses.contains(e.key))
              .fold<double>(0, (s, e) => s + e.value);
          return _ChartCard(
            title: 'Expense Breakdown',
            subtitle: 'Spending by category',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (estDeductions > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppTheme.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.savings_outlined,
                            size: 14, color: AppTheme.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Est. tax deductions: $symbol${estDeductions.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                _PieWithLegend(
                    data: expBreakdown,
                    colors: _kExpenseColors,
                    symbol: symbol),
              ],
            ),
          );
        case kAnalyticsSectionTopCategories:
          if (incBreakdown.isEmpty && expBreakdown.isEmpty) return null;
          return _ChartCard(
            title: 'Top Categories',
            subtitle: 'By total transaction volume',
            child: _TopCategoriesList(
                income: incBreakdown, expenses: expBreakdown, symbol: symbol),
          );
        case kAnalyticsSectionDayOfWeek:
          return _ChartCard(
            title: 'Activity by Day',
            subtitle: 'Transaction volume by weekday',
            child: SizedBox(height: 120, child: _DayOfWeekChart(data: dowData)),
          );
        case kAnalyticsSectionStackComparison:
          if (stackComp.length <= 1) {
            return _ChartCard(
              title: 'SideStack Comparison',
              subtitle: 'Net profit by stack',
              child: _SingleStackCta(),
            );
          }
          return _ChartCard(
            title: 'SideStack Comparison',
            subtitle: 'Net profit by stack',
            child: SizedBox(
              height: stackComp.length * 52.0 + 20,
              child: _StackComparisonChart(stacks: stackComp),
            ),
          );
        case kAnalyticsSectionYoY:
          if (!yoyHasLastYear) return null;
          return _ChartCard(
            title: 'Year-over-Year',
            subtitle: '${nowYear - 1} vs $nowYear monthly profit',
            child: SizedBox(
              height: 170,
              child: _YoYChart(
                thisYear: yoyThisYear,
                lastYear: yoyLastYear,
                thisYearLabel: '$nowYear',
                lastYearLabel: '${nowYear - 1}',
                symbol: symbol,
              ),
            ),
          );
        case kAnalyticsSectionInsights:
          return _ChartCard(
            title: 'What\'s happening',
            subtitle: 'Plain-English summary of your performance',
            child: _AiInsightCard(text: aiInsight),
          );
        case kAnalyticsSectionMarginOverTime:
          if (marginOverTime.length <= 1) return null;
          return _ChartCard(
            title: 'Profit Margin Over Time',
            subtitle: '% of income kept as profit',
            child: SizedBox(
              height: 130,
              child: _MarginOverTimeChart(data: marginOverTime),
            ),
          );
        case kAnalyticsSectionExpenseRatio:
          return _ChartCard(
            title: 'Expense Ratio',
            subtitle: 'Expenses as % of income',
            child: _ExpenseRatioCard(ratio: expenseRatio, symbol: symbol),
          );
        case kAnalyticsSectionTax:
          return _ChartCard(
            title: 'Tax Summary',
            subtitle: 'Year view · deductible expenses included',
            child: _TaxEstimateCard(
              allTransactions: allTx,
              profit: filteredProfit,
              annualProfit: projectionAnnual,
              taxRate: provider.taxRate,
              symbol: symbol,
              onRateChanged: (r) => provider.setTaxRate(r),
            ),
          );
        case kAnalyticsSectionProjection:
          return _ProjectionBanner(
            monthlyAvg: projectionMonthly,
            annualProjection: projectionAnnual,
            symbol: symbol,
          );

        // ── Premium sections ──────────────────────────────────────────────

        case kAnalyticsSectionInsightEngine:
          if (!provider.isPremium) {
            return _ProLockedCard(
              icon: Icons.psychology_outlined,
              title: 'Insight Engine',
              description: 'Prescriptive actions based on your data. Concentration risk, expense spikes, margin opportunities and more.',
              onUpgrade: () => showPaywallSheet(context),
            );
          }
          if (insightItems.isEmpty) return null;
          return _ChartCard(
            title: 'Insight Engine',
            subtitle: '${insightItems.length} action${insightItems.length == 1 ? '' : 's'} for you',
            child: _InsightEngineCard(items: insightItems),
          );

        case kAnalyticsSectionClientIntelligence:
          if (!provider.isPremium) {
            return _ProLockedCard(
              icon: Icons.people_outline,
              title: 'Client Intelligence',
              description: 'Revenue by client, concentration risk, and who your highest-value relationships really are.',
              onUpgrade: () => showPaywallSheet(context),
            );
          }
          if (sortedClients.isEmpty) return null;
          return _ChartCard(
            title: 'Client Intelligence',
            subtitle: '${sortedClients.length} client${sortedClients.length == 1 ? '' : 's'}',
            child: _ClientIntelligenceCard(
              clients: sortedClients,
              totalRevenue: totalClientRevenue,
              concentrationRatio: topClientConcentration,
              symbol: symbol,
            ),
          );

        case kAnalyticsSectionHourlyRate:
          if (!provider.isPremium) {
            return _ProLockedCard(
              icon: Icons.timer_outlined,
              title: 'Hourly Rate Tracker',
              description: 'Your real effective hourly rate per stack. Find out which hustle is actually worth your time.',
              onUpgrade: () => showPaywallSheet(context),
            );
          }
          if (hourlyRateData.isEmpty) return null;
          return _ChartCard(
            title: 'Hourly Rate Tracker',
            subtitle: 'Effective ${symbol}/hr by stack',
            child: _HourlyRateCard(data: hourlyRateData, symbol: symbol),
          );

        case kAnalyticsSectionGoalVelocity:
          if (!provider.isPremium) {
            return _ProLockedCard(
              icon: Icons.flag_outlined,
              title: 'Goal Velocity',
              description: 'Track your monthly income goal pace and see whether you\'re on track to hit it.',
              onUpgrade: () => showPaywallSheet(context),
            );
          }
          if (goalVelocityData.isEmpty) return null;
          return _ChartCard(
            title: 'Goal Velocity',
            subtitle: 'Monthly goal pace analysis',
            child: _GoalVelocityCard(entries: goalVelocityData, symbol: symbol),
          );

        case kAnalyticsSectionAnomalies:
          if (!provider.isPremium) {
            return _ProLockedCard(
              icon: Icons.search_outlined,
              title: 'Spending Anomalies',
              description: 'Automatically flags unusual spend in any category vs your prior period average.',
              onUpgrade: () => showPaywallSheet(context),
            );
          }
          if (anomalies.isEmpty) return null;
          return _ChartCard(
            title: 'Spending Anomalies',
            subtitle: 'Category changes vs prior period',
            child: _AnomaliesCard(anomalies: anomalies.take(5).toList(), symbol: symbol),
          );

        default:
          return null;
      }
    }

    final hidden = provider.analyticsHidden;
    final sectionWidgets = <Widget>[];
    for (final id in provider.analyticsOrder) {
      if (hidden.contains(id)) continue;
      final w = _sw(id);
      if (w != null) {
        sectionWidgets.add(w);
        sectionWidgets.add(const SizedBox(height: 10));
      }
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Analytics',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.4)),
                Text(
                  _selectedPreset == 'All'
                      ? 'All SideStacks combined'
                      : _selectedPreset == 'Custom' && _dateRange != null
                          ? '${DateFormat('MMM d').format(_dateRange!.start)} – ${DateFormat('MMM d').format(_dateRange!.end)}'
                          : 'Last $_selectedPreset · all stacks',
                  style: TextStyle(
                      fontSize: 11,
                      color: _selectedPreset == 'All'
                          ? AppTheme.of(context).textSecondary
                          : AppTheme.accent,
                      fontWeight: FontWeight.w400),
                ),
              ],
            ),
            actions: [
              GestureDetector(
                onTap: () => _showLayoutEditor(context, provider),
                child: Container(
                  margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.accentDim,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppTheme.accent.withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.tune_outlined,
                          size: 13, color: AppTheme.accent),
                      SizedBox(width: 4),
                      Text('Customise',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accent,
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Quick date filter pills
          SliverToBoxAdapter(
            child: _DatePresetStrip(
              selected: _selectedPreset,
              onSelect: _setPreset,
              onCustom: () => _pickDateRange(context),
            ),
          ),
          // Summary strip
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Row(children: [
                Expanded(
                    child: SummaryCard(
                        label: 'Income',
                        value: filteredIncome,
                        symbol: symbol)),
                const SizedBox(width: 8),
                Expanded(
                    child: SummaryCard(
                        label: 'Expenses',
                        value: filteredExpenses,
                        symbol: symbol)),
                const SizedBox(width: 8),
                Expanded(
                    child: SummaryCard(
                        label: 'Profit',
                        value: filteredProfit,
                        isProfit: true,
                        highlight: true,
                        symbol: symbol)),
              ]),
            ),
          ),
          // All sections in one ordered scroll
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate(sectionWidgets),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Date Preset Strip ────────────────────────────────────────────────────────

class _DatePresetStrip extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onCustom;

  const _DatePresetStrip({
    required this.selected,
    required this.onSelect,
    required this.onCustom,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    const presets = ['1M', '3M', '6M', 'All'];

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          ...presets.map((preset) {
            final active = selected == preset;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onSelect(preset),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: active ? AppTheme.accent : theme.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active
                          ? AppTheme.accent
                          : theme.textSecondary.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    preset,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          active ? FontWeight.w600 : FontWeight.w400,
                      color: active ? Colors.white : theme.textSecondary,
                      fontFamily: 'Sora',
                    ),
                  ),
                ),
              ),
            );
          }),
          // Custom range button
          GestureDetector(
            onTap: onCustom,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: selected == 'Custom' ? AppTheme.accent : theme.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected == 'Custom'
                      ? AppTheme.accent
                      : theme.textSecondary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.date_range_outlined,
                    size: 13,
                    color: selected == 'Custom'
                        ? Colors.white
                        : theme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    selected == 'Custom' ? 'Custom ✕' : 'Custom',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected == 'Custom'
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: selected == 'Custom'
                          ? Colors.white
                          : theme.textSecondary,
                      fontFamily: 'Sora',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── KPI Row ──────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  final int txCount;
  final String bestLabel;
  final double bestVal;
  final double avgMonthly;
  final double margin;
  final String symbol;

  const _KpiRow({
    required this.txCount,
    required this.bestLabel,
    required this.bestVal,
    required this.avgMonthly,
    required this.margin,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: _KpiTile(
          icon: Icons.receipt_long_outlined,
          iconColor: AppTheme.accent,
          label: 'Transactions',
          value: '$txCount',
          sub: txCount == 1 ? 'entry' : 'entries',
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _KpiTile(
          icon: Icons.emoji_events_outlined,
          iconColor: AppTheme.amber,
          label: 'Best Month',
          value: bestLabel,
          sub: formatCurrency(bestVal, symbol),
          subColor: bestVal >= 0 ? AppTheme.green : AppTheme.red,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _KpiTile(
          icon: Icons.calendar_today_outlined,
          iconColor: AppTheme.green,
          label: 'Avg / Month',
          value: formatCurrency(avgMonthly, symbol),
          sub: avgMonthly >= 0 ? 'profit' : 'loss',
          subColor: avgMonthly >= 0 ? AppTheme.green : AppTheme.red,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _KpiTile(
          icon: Icons.percent_outlined,
          iconColor: margin >= 0 ? AppTheme.green : AppTheme.red,
          label: 'Margin',
          value: formatPercent(margin),
          sub: 'overall',
          subColor: margin >= 0 ? AppTheme.green : AppTheme.red,
        ),
      ),
    ]);
  }
}

class _KpiTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? sub;
  final Color? subColor;

  const _KpiTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.sub,
    this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.of(context).card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.of(context).border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(height: 7),
          Text(
            label.toUpperCase(),
            style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: AppTheme.of(context).textMuted,
                letterSpacing: 0.6),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.of(context).textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (sub != null)
            Text(
              sub!,
              style: TextStyle(
                fontSize: 9,
                color: subColor ?? AppTheme.of(context).textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Profit Trend Line Chart ──────────────────────────────────────────────────

class _ProfitTrendChart extends StatelessWidget {
  final Map<String, Map<String, double>> monthly;
  final List<String> months;
  const _ProfitTrendChart({required this.monthly, required this.months});

  @override
  Widget build(BuildContext context) {
    return LineChart(LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: AppTheme.of(context).border, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 20,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= months.length) return const SizedBox();
              return Text(months[i],
                  style: TextStyle(
                      fontSize: 9, color: AppTheme.of(context).textMuted));
            },
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: months.asMap().entries.map((e) {
            final d = monthly[e.value]!;
            return FlSpot(
                e.key.toDouble(), d['income']! - d['expense']!);
          }).toList(),
          isCurved: true,
          color: AppTheme.green,
          barWidth: 2.5,
          dotData: FlDotData(
            getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 3,
                color: AppTheme.green,
                strokeWidth: 0,
                strokeColor: Colors.transparent),
          ),
          belowBarData: BarAreaData(
              show: true, color: AppTheme.green.withOpacity(0.08)),
        ),
      ],
    ));
  }
}

// ─── Income vs Expense Bar Chart ──────────────────────────────────────────────

class _IncomeExpenseChart extends StatelessWidget {
  final Map<String, Map<String, double>> monthly;
  final List<String> months;
  const _IncomeExpenseChart({required this.monthly, required this.months});

  @override
  Widget build(BuildContext context) {
    return BarChart(BarChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: AppTheme.of(context).border, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 20,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= months.length) return const SizedBox();
              return Text(months[i],
                  style: TextStyle(
                      fontSize: 9, color: AppTheme.of(context).textMuted));
            },
          ),
        ),
      ),
      barGroups: months.asMap().entries.map((e) {
        final d = monthly[e.value]!;
        return BarChartGroupData(x: e.key, barRods: [
          BarChartRodData(
              toY: d['income']!,
              color: AppTheme.green,
              width: 8,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4))),
          BarChartRodData(
              toY: d['expense']!,
              color: AppTheme.red,
              width: 8,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4))),
        ]);
      }).toList(),
    ));
  }
}

// ─── Cumulative Earnings Line Chart ───────────────────────────────────────────

class _CumulativeChart extends StatelessWidget {
  final Map<String, Map<String, double>> monthly;
  final List<String> months;
  const _CumulativeChart({required this.monthly, required this.months});

  @override
  Widget build(BuildContext context) {
    double running = 0;
    final spots = months.asMap().entries.map((e) {
      running +=
          monthly[e.value]!['income']! - monthly[e.value]!['expense']!;
      return FlSpot(e.key.toDouble(), running);
    }).toList();
    final positive = running >= 0;
    final lineColor = positive ? AppTheme.accent : AppTheme.red;

    return LineChart(LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: AppTheme.of(context).border, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 18,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= months.length) return const SizedBox();
              return Text(months[i],
                  style: TextStyle(
                      fontSize: 9, color: AppTheme.of(context).textMuted));
            },
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: lineColor,
          barWidth: 2.5,
          dotData: FlDotData(
            getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 3,
                color: lineColor,
                strokeWidth: 0,
                strokeColor: Colors.transparent),
          ),
          belowBarData: BarAreaData(
              show: true, color: lineColor.withOpacity(0.07)),
        ),
      ],
    ));
  }
}

// ─── Pie Chart + Percentage Legend ───────────────────────────────────────────

class _PieWithLegend extends StatelessWidget {
  final Map<String, double> data;
  final List<Color> colors;
  final String symbol;
  const _PieWithLegend(
      {required this.data, required this.colors, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.take(5).toList();
    final total = data.values.fold<double>(0, (a, b) => a + b);

    return SizedBox(
      height: 150,
      child: Row(children: [
        Expanded(
          child: PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 34,
            sections: entries.asMap().entries.map((e) {
              return PieChartSectionData(
                value: e.value.value,
                color: colors[e.key % colors.length],
                radius: 42,
                showTitle: false,
              );
            }).toList(),
          )),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries.asMap().entries.map((e) {
              final pct = total > 0
                  ? (e.value.value / total * 100).toStringAsFixed(0)
                  : '0';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: colors[e.key % colors.length],
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(e.value.key,
                        style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.of(context).textSecondary),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 4),
                  Text('$pct%',
                      style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.of(context).textPrimary)),
                ]),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}

// ─── Top Categories List ──────────────────────────────────────────────────────

class _TopCategoriesList extends StatelessWidget {
  final Map<String, double> income;
  final Map<String, double> expenses;
  final String symbol;
  const _TopCategoriesList(
      {required this.income, required this.expenses, required this.symbol});

  @override
  Widget build(BuildContext context) {
    // Merge top income + expense categories, deduplicate, sort by amount
    final all = <_CatEntry>[];
    for (final e in income.entries.take(5)) {
      all.add(_CatEntry(e.key, e.value, true));
    }
    for (final e in expenses.entries.take(5)) {
      if (!all.any((a) => a.name == e.key)) {
        all.add(_CatEntry(e.key, e.value, false));
      }
    }
    all.sort((a, b) => b.amount.compareTo(a.amount));
    final top = all.take(6).toList();
    if (top.isEmpty) return const SizedBox();

    final maxVal = top.first.amount;

    return Column(
      children: top.map((entry) {
        final frac = maxVal > 0 ? entry.amount / maxVal : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: entry.isIncome ? AppTheme.green : AppTheme.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 88,
              child: Text(entry.name,
                  style: TextStyle(
                      fontSize: 11, color: AppTheme.of(context).textSecondary),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: frac,
                  backgroundColor: AppTheme.of(context).cardAlt,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      entry.isIncome ? AppTheme.green : AppTheme.red),
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatCurrency(entry.amount, symbol),
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: entry.isIncome ? AppTheme.green : AppTheme.red,
              ),
            ),
          ]),
        );
      }).toList(),
    );
  }
}

class _CatEntry {
  final String name;
  final double amount;
  final bool isIncome;
  _CatEntry(this.name, this.amount, this.isIncome);
}

// ─── Day of Week Chart ────────────────────────────────────────────────────────

class _DayOfWeekChart extends StatelessWidget {
  final List<double> data; // 7 values, Mon–Sun
  const _DayOfWeekChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) {
      return Center(
        child: Text('Not enough data',
            style:
                TextStyle(color: AppTheme.of(context).textMuted, fontSize: 12)),
      );
    }
    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxVal * 1.25,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 20,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= _kDow.length) return const SizedBox();
              return Text(_kDow[i],
                  style: TextStyle(
                      fontSize: 9, color: AppTheme.of(context).textMuted));
            },
          ),
        ),
      ),
      barGroups: data.asMap().entries.map((e) {
        final isWeekend = e.key >= 5;
        return BarChartGroupData(x: e.key, barRods: [
          BarChartRodData(
            toY: e.value,
            color: isWeekend ? AppTheme.amber : AppTheme.accent,
            width: 20,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ]);
      }).toList(),
    ));
  }
}

// ─── Stack Comparison Chart ───────────────────────────────────────────────────

class _StackComparisonChart extends StatelessWidget {
  final List<MapEntry<String, double>> stacks;
  const _StackComparisonChart({required this.stacks});

  @override
  Widget build(BuildContext context) {
    return BarChart(BarChartData(
      alignment: BarChartAlignment.center,
      borderData: FlBorderData(show: false),
      gridData: FlGridData(
        show: true,
        drawHorizontalLine: false,
        getDrawingVerticalLine: (_) =>
            FlLine(color: AppTheme.of(context).border, strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 90,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= stacks.length) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(stacks[i].key,
                    style: TextStyle(
                        fontSize: 9, color: AppTheme.of(context).textMuted),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              );
            },
          ),
        ),
      ),
      barGroups: stacks.asMap().entries.map((e) {
        final profit = e.value.value;
        return BarChartGroupData(x: e.key, barRods: [
          BarChartRodData(
            toY: profit,
            color: profit >= 0 ? AppTheme.green : AppTheme.red,
            width: 18,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
        ]);
      }).toList(),
    ));
  }
}

// ─── AI Insight Card ──────────────────────────────────────────────────────────

class _AiInsightCard extends StatelessWidget {
  final String text;
  const _AiInsightCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF14B8A6).withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insights_outlined, size: 12, color: Color(0xFF14B8A6)),
              SizedBox(width: 5),
              Text(
                'Your Summary',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF14B8A6),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Observation paragraph
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            height: 1.65,
            color: colors.textPrimary,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ─── Pro Locked Card ─────────────────────────────────────────────────────────

class _ProLockedCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onUpgrade;

  const _ProLockedCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF14B8A6).withOpacity(0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: const Color(0xFF14B8A6)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Pro',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF14B8A6),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: colors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onUpgrade,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFF14B8A6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Unlock with Pro',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0B1120),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Margin Over Time Line Chart ──────────────────────────────────────────────

class _MarginOverTimeChart extends StatelessWidget {
  final List<MapEntry<String, double>> data;
  const _MarginOverTimeChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final spots = data.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();
    final months = data.map((e) => e.key).toList();
    final last = data.last.value;
    final lineColor = last >= 0 ? AppTheme.accent : AppTheme.red;

    return LineChart(LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: AppTheme.of(context).border, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 18,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= months.length) return const SizedBox();
              return Text(months[i],
                  style:
                      TextStyle(fontSize: 9, color: AppTheme.of(context).textMuted));
            },
          ),
        ),
      ),
      lineBarsData: [
        // Zero reference line
        LineChartBarData(
          spots: [
            FlSpot(0, 0),
            FlSpot((data.length - 1).toDouble(), 0),
          ],
          color: AppTheme.of(context).border,
          barWidth: 1,
          dotData: const FlDotData(show: false),
          dashArray: [4, 4],
        ),
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: lineColor,
          barWidth: 2.5,
          dotData: FlDotData(
            getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 3,
                color: lineColor,
                strokeWidth: 0,
                strokeColor: Colors.transparent),
          ),
          belowBarData: BarAreaData(
              show: true, color: lineColor.withOpacity(0.07)),
        ),
      ],
    ));
  }
}

// ─── Expense Ratio Card ───────────────────────────────────────────────────────

class _ExpenseRatioCard extends StatelessWidget {
  final double ratio; // 0.0–1.5+
  final String symbol;
  const _ExpenseRatioCard({required this.ratio, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final clampedRatio = ratio.clamp(0.0, 1.0);
    final pct = (ratio * 100).toStringAsFixed(0);
    final Color barColor;
    final String label;
    if (ratio <= 0.5) {
      barColor = AppTheme.green;
      label = 'Excellent — very lean';
    } else if (ratio <= 0.7) {
      barColor = AppTheme.accent;
      label = 'Healthy ratio';
    } else if (ratio <= 0.9) {
      barColor = AppTheme.amber;
      label = 'Watch your costs';
    } else {
      barColor = AppTheme.red;
      label = 'Expenses exceed income';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                '$pct% of income spent',
                style: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: barColor),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: barColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: barColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Gauge track
        Stack(children: [
          // Background track with zone markers
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.green.withOpacity(0.3),
                    AppTheme.accent.withOpacity(0.3),
                    AppTheme.amber.withOpacity(0.3),
                    AppTheme.red.withOpacity(0.3),
                  ],
                  stops: const [0.0, 0.5, 0.7, 1.0],
                ),
              ),
            ),
          ),
          // Fill
          FractionallySizedBox(
            widthFactor: clampedRatio,
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0%',
                style:
                    TextStyle(fontSize: 9, color: AppTheme.of(context).textMuted)),
            Text('50%',
                style:
                    TextStyle(fontSize: 9, color: AppTheme.of(context).textMuted)),
            Text('70%',
                style:
                    TextStyle(fontSize: 9, color: AppTheme.of(context).textMuted)),
            Text('100%',
                style:
                    TextStyle(fontSize: 9, color: AppTheme.of(context).textMuted)),
          ],
        ),
      ],
    );
  }
}

// ─── Projection Banner ────────────────────────────────────────────────────────

class _ProjectionBanner extends StatelessWidget {
  final double monthlyAvg;
  final double annualProjection;
  final String symbol;
  const _ProjectionBanner({
    required this.monthlyAvg,
    required this.annualProjection,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    final positive = annualProjection >= 0;
    // Green for profit growth, red for loss — purple accent made banners look
    // washed-out in light mode and carries no semantic meaning here.
    final accentColor = positive ? AppTheme.green : AppTheme.red;
    final dimColor    = positive ? AppTheme.greenDim : AppTheme.redDim;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dimColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.30)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              positive
                  ? Icons.rocket_launch_outlined
                  : Icons.warning_amber_outlined,
              color: accentColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AT THIS RATE',
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: accentColor.withOpacity(0.75),
                      letterSpacing: 1.0),
                ),
                const SizedBox(height: 3),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 18,
                        fontWeight: FontWeight.w700),
                    children: [
                      TextSpan(
                        text: formatCurrency(annualProjection, symbol),
                        style: TextStyle(color: accentColor),
                      ),
                      TextSpan(
                        text: ' / year',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.of(context).textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatCurrency(monthlyAvg, symbol)} avg monthly profit · 3-month trend',
                  style: TextStyle(
                      fontSize: 10, color: AppTheme.of(context).textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Chart Card ───────────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _ChartCard(
      {required this.title, required this.child, this.subtitle});

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title.toUpperCase(),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.of(context).textMuted,
                      letterSpacing: 0.8)),
              if (subtitle != null)
                Text(subtitle!,
                    style: TextStyle(
                        fontSize: 9,
                        color: AppTheme.of(context).textMuted,
                        fontWeight: FontWeight.w400)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ─── Tax Estimate Card ────────────────────────────────────────────────────────

// Common bracket presets shown as quick-select chips
const _kTaxPresets = <String, double>{
  '0%': 0.0,
  '20%': 0.20,
  '25%': 0.25,
  '30%': 0.30,
  '40%': 0.40,
  '45%': 0.45,
};

class _TaxEstimateCard extends StatefulWidget {
  final List<Transaction> allTransactions; // full unfiltered history
  final double profit;       // filtered period profit (used as fallback)
  final double annualProfit; // projected annual profit
  final double taxRate;
  final String symbol;
  final ValueChanged<double> onRateChanged;

  const _TaxEstimateCard({
    required this.allTransactions,
    required this.profit,
    required this.annualProfit,
    required this.taxRate,
    required this.symbol,
    required this.onRateChanged,
  });

  @override
  State<_TaxEstimateCard> createState() => _TaxEstimateCardState();
}

class _TaxEstimateCardState extends State<_TaxEstimateCard> {
  late double _rate;
  late int _selectedYear;
  bool _deductionsExpanded = true;

  @override
  void initState() {
    super.initState();
    _rate = widget.taxRate;
    _selectedYear = DateTime.now().year;
  }

  @override
  void didUpdateWidget(_TaxEstimateCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taxRate != widget.taxRate) {
      _rate = widget.taxRate;
    }
  }

  void _showRatePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaxRateSheet(
        initialRate: _rate,
        onSave: (r) {
          setState(() => _rate = r);
          widget.onRateChanged(r);
        },
      ),
    );
  }

  /// Returns transactions for the selected tax year.
  List<Transaction> get _yearTx => widget.allTransactions
      .where((t) => t.date.year == _selectedYear)
      .toList();

  /// Deductible expense totals grouped by category for the selected year.
  Map<String, double> get _deductibleByCategory {
    final result = <String, double>{};
    for (final tx in _yearTx) {
      if (tx.type == TransactionType.expense &&
          _kTaxDeductibleExpenses.contains(tx.category)) {
        result[tx.category] = (result[tx.category] ?? 0) + tx.amount;
      }
    }
    // Sort descending by value
    final sorted = result.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted);
  }

  /// Net profit for the selected year.
  double get _yearProfit {
    final income = _yearTx
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + t.amount);
    final expenses = _yearTx
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + t.amount);
    return income - expenses;
  }

  /// Available years from transaction history.
  List<int> get _availableYears {
    final years = widget.allTransactions.map((t) => t.date.year).toSet().toList()
      ..sort();
    final now = DateTime.now().year;
    if (!years.contains(now)) years.add(now);
    return years;
  }

  @override
  Widget build(BuildContext context) {
    final deductibles = _deductibleByCategory;
    final totalDeductions = deductibles.values.fold(0.0, (s, v) => s + v);
    final taxSaved = totalDeductions * _rate;
    final yearProfit = _yearProfit;
    final taxOnProfit = yearProfit > 0 ? yearProfit * _rate : 0.0;
    final takeHome = yearProfit > 0 ? yearProfit - taxOnProfit : 0.0;
    final years = _availableYears;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Year picker row ────────────────────────────────────────────────
        Row(
          children: [
            Text(
              'Tax year',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.of(context).textSecondary),
            ),
            const Spacer(),
            ...years.map((y) => GestureDetector(
              onTap: () => setState(() => _selectedYear = y),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _selectedYear == y
                      ? AppTheme.accentDim
                      : AppTheme.of(context).card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _selectedYear == y
                          ? AppTheme.accent
                          : AppTheme.of(context).border),
                ),
                child: Text(
                  '$y',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _selectedYear == y
                          ? AppTheme.accent
                          : AppTheme.of(context).textSecondary),
                ),
              ),
            )),
          ],
        ),
        const SizedBox(height: 14),

        // ── Key figures row ────────────────────────────────────────────────
        Row(
          children: [
            _TaxMetric(
              label: 'Net profit',
              value: formatCurrency(yearProfit.abs(), widget.symbol),
              color: yearProfit >= 0 ? AppTheme.green : AppTheme.red,
            ),
            const SizedBox(width: 8),
            _TaxMetric(
              label: 'Est. tax',
              value: formatCurrency(taxOnProfit, widget.symbol),
              color: AppTheme.red,
            ),
            const SizedBox(width: 8),
            _TaxMetric(
              label: 'Take-home',
              value: formatCurrency(takeHome, widget.symbol),
              color: AppTheme.accent,
              highlight: true,
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Deductible expenses breakdown ──────────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _deductionsExpanded = !_deductionsExpanded),
          child: Row(
            children: [
              Icon(Icons.savings_outlined,
                  size: 14, color: AppTheme.green),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  totalDeductions > 0
                      ? 'Deductible expenses · ${formatCurrency(totalDeductions, widget.symbol)} total'
                      : 'No deductible expenses logged this year',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: totalDeductions > 0
                          ? AppTheme.green
                          : AppTheme.of(context).textMuted),
                ),
              ),
              if (totalDeductions > 0)
                AnimatedRotation(
                  turns: _deductionsExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down,
                      size: 16, color: AppTheme.of(context).textMuted),
                ),
            ],
          ),
        ),

        // Deductions list (collapsible)
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: (_deductionsExpanded && deductibles.isNotEmpty)
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Column(
            children: [
              const SizedBox(height: 10),
              ...deductibles.entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.green.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(e.key,
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.of(context).textPrimary)),
                  ),
                  Text(
                    formatCurrency(e.value, widget.symbol),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Courier',
                        color: AppTheme.green),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.greenDim,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'saves ${formatCurrency(e.value * _rate, widget.symbol)}',
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.green),
                    ),
                  ),
                ]),
              )),
              const SizedBox(height: 4),
              // Totals row
              if (taxSaved > 0)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.greenDim,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppTheme.green.withOpacity(0.25)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.celebration_outlined,
                        size: 14, color: AppTheme.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Est. tax saving from deductions',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.of(context).textSecondary),
                      ),
                    ),
                    Text(
                      formatCurrency(taxSaved, widget.symbol),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.green),
                    ),
                  ]),
                ),
            ],
          ),
          secondChild: const SizedBox.shrink(),
        ),
        const SizedBox(height: 14),

        // ── Tax rate selector ──────────────────────────────────────────────
        Row(
          children: [
            Text(
              'Tax rate',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.of(context).textSecondary),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => _showRatePicker(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accentDim,
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: AppTheme.accent.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(_rate * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accent),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.edit_outlined,
                        size: 12, color: AppTheme.accent),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Share tax report button ────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.share_outlined, size: 15),
            label: const Text('Share tax report',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accent,
              side: BorderSide(
                  color: AppTheme.accent.withOpacity(0.4), width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final sym = widget.symbol;
              final txs = widget.allTransactions;
              final yr  = _selectedYear;
              final rt  = _rate;
              try {
                await shareTaxReportPdf(
                  context: context,
                  allTransactions: txs,
                  year: yr,
                  taxRate: rt,
                  currencySymbol: sym,
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Could not generate PDF: $e'),
                    backgroundColor: const Color(0xFFEF4444),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '⚠️  Estimates only — consult a tax professional for advice.',
          style: TextStyle(
              fontSize: 10,
              color: AppTheme.of(context).textMuted,
              fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}

class _TaxMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool highlight;

  const _TaxMetric({
    required this.label,
    required this.value,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: highlight
              ? color.withOpacity(0.10)
              : AppTheme.of(context).cardAlt,
          borderRadius: BorderRadius.circular(10),
          border: highlight
              ? Border.all(color: color.withOpacity(0.3))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    color: AppTheme.of(context).textMuted,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

// ─── Tax rate picker sheet ────────────────────────────────────────────────────

class _TaxRateSheet extends StatefulWidget {
  final double initialRate;
  final ValueChanged<double> onSave;
  const _TaxRateSheet({required this.initialRate, required this.onSave});

  @override
  State<_TaxRateSheet> createState() => _TaxRateSheetState();
}

class _TaxRateSheetState extends State<_TaxRateSheet> {
  late double _rate;

  @override
  void initState() {
    super.initState();
    _rate = widget.initialRate;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: AppTheme.of(context).surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.of(context).borderLight),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.of(context).borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text('Your Tax Rate',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'Select your income tax bracket or set a custom rate.',
            style: TextStyle(
                fontSize: 12, color: AppTheme.of(context).textSecondary),
          ),
          const SizedBox(height: 20),

          // Quick presets
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kTaxPresets.entries.map((e) {
              final selected = (_rate * 100).round() ==
                  (e.value * 100).round();
              return GestureDetector(
                onTap: () => setState(() => _rate = e.value),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.accent
                        : AppTheme.of(context).card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: selected
                            ? AppTheme.accent
                            : AppTheme.of(context).border),
                  ),
                  child: Text(
                    e.key,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white
                          : AppTheme.of(context).textPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Slider for custom rate
          Row(
            children: [
              Text('Custom:',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.of(context).textSecondary)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppTheme.accent,
                    inactiveTrackColor: AppTheme.of(context).border,
                    thumbColor: AppTheme.accent,
                    overlayColor: AppTheme.accent.withOpacity(0.15),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: _rate,
                    min: 0,
                    max: 0.60,
                    divisions: 60,
                    onChanged: (v) => setState(() => _rate = v),
                  ),
                ),
              ),
              SizedBox(
                width: 42,
                child: Text(
                  '${(_rate * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accent),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onSave(_rate);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Save',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Single-stack CTA ─────────────────────────────────────────────────────────

class _SingleStackCta extends StatelessWidget {
  const _SingleStackCta();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.add_circle_outline,
                color: AppTheme.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add a second SideStack',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.of(context).textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Compare performance across multiple hustles once you have two or more stacks.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.of(context).textSecondary,
                    height: 1.4,
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

// ─── Year-over-Year Chart ─────────────────────────────────────────────────────

class _YoYChart extends StatelessWidget {
  final List<double> thisYear;  // 12 values, Jan–Dec
  final List<double> lastYear;  // 12 values, Jan–Dec
  final String thisYearLabel;
  final String lastYearLabel;
  final String symbol;

  const _YoYChart({
    required this.thisYear,
    required this.lastYear,
    required this.thisYearLabel,
    required this.lastYearLabel,
    required this.symbol,
  });

  static const _months = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

  @override
  Widget build(BuildContext context) {
    final allValues = [...thisYear, ...lastYear];
    final maxAbs = allValues.map((v) => v.abs()).fold(0.0, (a, b) => a > b ? a : b);
    final maxY = maxAbs == 0 ? 1.0 : maxAbs * 1.25;

    return Column(
      children: [
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: AppTheme.accent, label: thisYearLabel),
            const SizedBox(width: 16),
            _LegendDot(
                color: AppTheme.of(context).textMuted, label: lastYearLabel),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: maxY,
              minY: -maxY,
              gridData: FlGridData(
                show: true,
                horizontalInterval: maxY / 2,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: AppTheme.of(context).border,
                  strokeWidth: 0.5,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= 12) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _months[idx],
                          style: TextStyle(
                            fontSize: 9,
                            color: AppTheme.of(context).textMuted,
                          ),
                        ),
                      );
                    },
                    reservedSize: 18,
                  ),
                ),
              ),
              barGroups: List.generate(12, (i) {
                return BarChartGroupData(
                  x: i,
                  groupVertically: false,
                  barRods: [
                    BarChartRodData(
                      toY: lastYear[i],
                      color: AppTheme.of(context).textMuted.withOpacity(0.5),
                      width: 5,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    BarChartRodData(
                      toY: thisYear[i],
                      color: thisYear[i] >= 0
                          ? AppTheme.accent
                          : AppTheme.red,
                      width: 5,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ],
                  barsSpace: 2,
                );
              }),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppTheme.of(context).card,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final label =
                        rodIndex == 0 ? lastYearLabel : thisYearLabel;
                    return BarTooltipItem(
                      '$label\n',
                      TextStyle(
                          fontSize: 11,
                          color: AppTheme.of(context).textSecondary,
                          fontWeight: FontWeight.w500),
                      children: [
                        TextSpan(
                          text: formatCurrency(rod.toY, symbol),
                          style: TextStyle(
                            fontSize: 12,
                            color: rod.toY >= 0
                                ? AppTheme.green
                                : AppTheme.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
              fontSize: 11, color: AppTheme.of(context).textSecondary),
        ),
      ],
    );
  }
}

// ─── Layout Editor Bottom Sheet ───────────────────────────────────────────────

class _LayoutEditorSheet extends StatefulWidget {
  final List<String> order;
  final Set<String> hidden;
  final void Function(List<String> order, Set<String> hidden) onSave;
  const _LayoutEditorSheet(
      {required this.order, required this.hidden, required this.onSave});

  @override
  State<_LayoutEditorSheet> createState() => _LayoutEditorSheetState();
}

class _LayoutEditorSheetState extends State<_LayoutEditorSheet> {
  late List<String> _order;
  late Set<String> _hidden;

  @override
  void initState() {
    super.initState();
    _order = List<String>.from(widget.order);
    _hidden = Set<String>.from(widget.hidden);
  }

  void _save() => widget.onSave(List<String>.from(_order), Set<String>.from(_hidden));

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: BoxDecoration(
        color: AppTheme.of(context).surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.of(context).borderLight),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.of(context).borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Edit Layout',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _order = List<String>.from(kDefaultAnalyticsOrder);
                    _hidden.clear();
                  });
                  _save();
                },
                child: Text(
                  'Reset',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.of(context).textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Drag to reorder · tap eye to hide/show.',
            style: TextStyle(
                fontSize: 11, color: AppTheme.of(context).textSecondary),
          ),
          const SizedBox(height: 14),
          Flexible(
            child: ReorderableListView(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _order.removeAt(oldIndex);
                  _order.insert(newIndex, item);
                });
                _save();
              },
              children: _order.map((id) {
                final label = _kSectionLabels[id] ?? id;
                final icon = _kSectionIcons[id] ?? Icons.grid_view_outlined;
                final isHidden = _hidden.contains(id);
                return AnimatedOpacity(
                  key: ValueKey(id),
                  opacity: isHidden ? 0.45 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.of(context).card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isHidden
                              ? AppTheme.of(context).border
                              : AppTheme.of(context).border),
                    ),
                    child: Row(children: [
                      Icon(icon,
                          size: 16,
                          color: isHidden
                              ? AppTheme.of(context).textMuted
                              : AppTheme.of(context).textSecondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isHidden
                                ? AppTheme.of(context).textMuted
                                : AppTheme.of(context).textPrimary,
                          ),
                        ),
                      ),
                      // Eye toggle
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isHidden) {
                              _hidden.remove(id);
                            } else {
                              _hidden.add(id);
                            }
                          });
                          _save();
                        },
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            isHidden
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                            color: isHidden
                                ? AppTheme.of(context).textMuted
                                : AppTheme.accent,
                          ),
                        ),
                      ),
                      Icon(Icons.drag_handle,
                          size: 18,
                          color: AppTheme.of(context).textMuted),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PREMIUM ANALYTICS WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Insight Engine ───────────────────────────────────────────────────────────

enum _InsightPriority { warning, watch, opportunity }

class _InsightItem {
  final _InsightPriority priority;
  final String title;
  final String body;
  final String action;

  const _InsightItem({
    required this.priority,
    required this.title,
    required this.body,
    required this.action,
  });
}

class _InsightEngineCard extends StatelessWidget {
  final List<_InsightItem> items;

  const _InsightEngineCard({required this.items});

  Color _priorityColor(_InsightPriority p) {
    switch (p) {
      case _InsightPriority.warning:     return AppTheme.red;
      case _InsightPriority.watch:       return AppTheme.amber;
      case _InsightPriority.opportunity: return AppTheme.green;
    }
  }

  IconData _priorityIcon(_InsightPriority p) {
    switch (p) {
      case _InsightPriority.warning:     return Icons.error_outline;
      case _InsightPriority.watch:       return Icons.visibility_outlined;
      case _InsightPriority.opportunity: return Icons.trending_up;
    }
  }

  String _priorityLabel(_InsightPriority p) {
    switch (p) {
      case _InsightPriority.warning:     return 'ACTION NEEDED';
      case _InsightPriority.watch:       return 'WATCH';
      case _InsightPriority.opportunity: return 'OPPORTUNITY';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.asMap().entries.map((entry) {
        final i    = entry.key;
        final item = entry.value;
        final c    = _priorityColor(item.priority);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (i > 0) const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_priorityIcon(item.priority), size: 14, color: c),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _priorityLabel(item.priority),
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: c,
                              letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.body,
                    style: TextStyle(
                        fontSize: 12,
                        height: 1.55,
                        color: colors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.arrow_forward_ios_rounded, size: 10, color: c),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          item.action,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: c),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

// ─── Client Intelligence ──────────────────────────────────────────────────────

class _ClientIntelligenceCard extends StatelessWidget {
  final List<MapEntry<String, double>> clients;
  final double totalRevenue;
  final double concentrationRatio; // 0.0–1.0
  final String symbol;

  const _ClientIntelligenceCard({
    required this.clients,
    required this.totalRevenue,
    required this.concentrationRatio,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final topClients = clients.take(5).toList();
    final concentrationPct = (concentrationRatio * 100).round();
    final riskColor = concentrationRatio >= 0.6
        ? AppTheme.red
        : concentrationRatio >= 0.4
            ? AppTheme.amber
            : AppTheme.green;
    final riskLabel = concentrationRatio >= 0.6
        ? 'High risk'
        : concentrationRatio >= 0.4
            ? 'Moderate'
            : 'Diversified';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Concentration header
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Top client share',
                      style: TextStyle(
                          fontSize: 11, color: colors.textMuted)),
                  const SizedBox(height: 2),
                  Text(
                    '$concentrationPct%',
                    style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: riskColor),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: riskColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(riskLabel,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: riskColor)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Client bars
        ...topClients.asMap().entries.map((e) {
          final rank   = e.key + 1;
          final name   = e.value.key;
          final amount = e.value.value;
          final share  = totalRevenue > 0 ? amount / totalRevenue : 0.0;
          final barColors = [
            AppTheme.accent,
            AppTheme.green,
            const Color(0xFF26C6A2),
            const Color(0xFF4FC3F7),
            colors.textMuted,
          ];
          final c = barColors[e.key % barColors.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: c.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      alignment: Alignment.center,
                      child: Text('$rank',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: c)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(name,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: colors.textPrimary),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      '${(share * 100).round()}% · ${formatCurrency(amount, symbol)}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: c),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: share.clamp(0.0, 1.0),
                    backgroundColor: c.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(c),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          );
        }),
        if (clients.length > 5) ...[
          const SizedBox(height: 4),
          Text(
            '+${clients.length - 5} more clients',
            style: TextStyle(
                fontSize: 11, color: colors.textMuted),
          ),
        ],
      ],
    );
  }
}

// ─── Hourly Rate Tracker ──────────────────────────────────────────────────────

class _StackHourlyRate {
  final String name;
  final double rate;
  final double hours;
  const _StackHourlyRate({required this.name, required this.rate, required this.hours});
}

class _HourlyRateCard extends StatelessWidget {
  final List<_StackHourlyRate> data;
  final String symbol;
  const _HourlyRateCard({required this.data, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final colors  = AppTheme.of(context);
    final maxRate = data.fold(0.0, (m, d) => d.rate > m ? d.rate : m);

    Color rateColor(double rate) {
      if (rate >= 50) return AppTheme.green;
      if (rate >= 25) return AppTheme.accent;
      if (rate >= 15) return AppTheme.amber;
      return AppTheme.red;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...data.map((d) {
          final c    = rateColor(d.rate);
          final fill = maxRate > 0 ? (d.rate / maxRate).clamp(0.0, 1.0) : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(d.name,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: colors.textPrimary),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      '$symbol${d.rate.toStringAsFixed(0)}/hr',
                      style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: c),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '· ${d.hours.toStringAsFixed(0)}h logged',
                      style: TextStyle(
                          fontSize: 10, color: colors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Stack(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: c.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: fill,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 2),
        Row(
          children: [
            _RateBenchmark(label: 'Low', color: AppTheme.red),
            const SizedBox(width: 12),
            _RateBenchmark(label: 'Fair', color: AppTheme.amber),
            const SizedBox(width: 12),
            _RateBenchmark(label: 'Good', color: AppTheme.accent),
            const SizedBox(width: 12),
            _RateBenchmark(label: 'Strong', color: AppTheme.green),
          ],
        ),
      ],
    );
  }
}

class _RateBenchmark extends StatelessWidget {
  final String label;
  final Color color;
  const _RateBenchmark({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppTheme.of(context).textMuted),
        ),
      ],
    );
  }
}

// ─── Goal Velocity ────────────────────────────────────────────────────────────

class _GoalVelocityEntry {
  final String name;
  final double goal;
  final double earned;
  final double progress;   // 0.0–1.0
  final double paceRatio;  // > 1.0 means ahead of pace

  const _GoalVelocityEntry({
    required this.name,
    required this.goal,
    required this.earned,
    required this.progress,
    required this.paceRatio,
  });
}

class _GoalVelocityCard extends StatelessWidget {
  final List<_GoalVelocityEntry> entries;
  final String symbol;
  const _GoalVelocityCard({required this.entries, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries.asMap().entries.map((e) {
        final idx   = e.key;
        final entry = e.value;
        final Color c;
        final String paceLabel;
        final IconData paceIcon;

        if (entry.paceRatio >= 1.2) {
          c = AppTheme.green;
          paceLabel = 'Ahead of pace';
          paceIcon  = Icons.rocket_launch_outlined;
        } else if (entry.paceRatio >= 0.85) {
          c = AppTheme.accent;
          paceLabel = 'On track';
          paceIcon  = Icons.check_circle_outline;
        } else if (entry.paceRatio >= 0.5) {
          c = AppTheme.amber;
          paceLabel = 'Slightly behind';
          paceIcon  = Icons.schedule_outlined;
        } else {
          c = AppTheme.red;
          paceLabel = 'Off pace';
          paceIcon  = Icons.warning_amber_outlined;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (idx > 0) const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.name,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        '${formatCurrency(entry.earned, symbol)} of ${formatCurrency(entry.goal, symbol)} goal',
                        style: TextStyle(fontSize: 11, color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(paceIcon, size: 11, color: c),
                      const SizedBox(width: 4),
                      Text(paceLabel,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: c)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Dual-layer progress bar: goal progress vs expected pace
            Stack(
              children: [
                // Background
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Container(
                    height: 8,
                    color: c.withOpacity(0.10),
                  ),
                ),
                // Actual progress
                FractionallySizedBox(
                  widthFactor: entry.progress.clamp(0.0, 1.0),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${(entry.progress * 100).round()}% complete · pace ratio ${entry.paceRatio.toStringAsFixed(1)}x',
              style: TextStyle(fontSize: 10, color: colors.textMuted),
            ),
          ],
        );
      }).toList(),
    );
  }
}

// ─── Spending Anomalies ───────────────────────────────────────────────────────

class _AnomalyEntry {
  final String category;
  final double oldAvg;
  final double newAvg;
  final bool isIncrease;
  const _AnomalyEntry({
    required this.category,
    required this.oldAvg,
    required this.newAvg,
    required this.isIncrease,
  });
}

class _AnomaliesCard extends StatelessWidget {
  final List<_AnomalyEntry> anomalies;
  final String symbol;
  const _AnomaliesCard({required this.anomalies, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comparing first vs second half of selected period (per-month averages)',
          style: TextStyle(
              fontSize: 10, color: colors.textMuted, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 12),
        ...anomalies.map((a) {
          final c = a.isIncrease ? AppTheme.red : AppTheme.green;
          final icon = a.isIncrease
              ? Icons.arrow_upward_rounded
              : Icons.arrow_downward_rounded;
          final changePct = a.oldAvg > 0
              ? ((a.newAvg - a.oldAvg) / a.oldAvg * 100).abs().round()
              : 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: c, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.category,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary)),
                      Text(
                        '${formatCurrency(a.oldAvg, symbol)}/mo → ${formatCurrency(a.newAvg, symbol)}/mo',
                        style: TextStyle(
                            fontSize: 11, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${a.isIncrease ? '+' : '-'}$changePct%',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: c),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
