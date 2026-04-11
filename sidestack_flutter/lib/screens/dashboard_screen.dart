import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/add_transaction_sheet.dart';
import '../widgets/create_stack_sheet.dart';
import '../widgets/paywall_sheet.dart';
import '../widgets/celebration_overlay.dart';
import '../widgets/invoice_sheet.dart';
import '../widgets/cashflow_sheet.dart';
import '../providers/mileage_provider.dart';
import 'stack_detail_screen.dart';
import 'analytics_screen.dart' show showInsightsLayoutEditor;
import 'mileage_screen.dart';
import 'invoices_screen.dart';
import 'rate_comparator_screen.dart' show showRateComparatorScreen;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check for a pending milestone and show celebration once per milestone.
    final provider = context.read<AppProvider>();
    final milestone = provider.pendingMilestone;
    if (milestone != null) {
      provider.clearPendingMilestone();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showMilestoneCelebration(
            context,
            amount: milestone,
            symbol: provider.currencySymbol,
          );
        }
      });
    }

    // Show paywall at meaningful moments (3rd stack, £1k revenue, etc.)
    final paywallTrigger = provider.pendingPaywallTrigger;
    if (paywallTrigger != null) {
      provider.clearPendingPaywallTrigger();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Small delay after any celebration overlay
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) showPaywallSheet(context);
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    // Re-check milestone on every rebuild triggered by provider changes.
    final milestone = provider.pendingMilestone;
    if (milestone != null) {
      provider.clearPendingMilestone();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showMilestoneCelebration(
            context,
            amount: milestone,
            symbol: provider.currencySymbol,
          );
        }
      });
    }

    // Paywall trigger — check on every rebuild too (e.g., fired from CreateStackSheet)
    final paywallTrigger = provider.pendingPaywallTrigger;
    if (paywallTrigger != null) {
      provider.clearPendingPaywallTrigger();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) showPaywallSheet(context);
          });
        }
      });
    }

    if (!provider.isLoaded) {
      return const DashboardSkeleton();
    }

    if (provider.error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.redDim,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.cloud_off_outlined,
                      size: 28, color: AppTheme.red),
                ),
                const SizedBox(height: 20),
                const Text('Couldn\'t connect',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(provider.error!,
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.of(context).textSecondary),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                SizedBox(
                  width: 160,
                  child: PrimaryButton(
                    label: 'Retry',
                    onPressed: () => provider.retryLoad(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (provider.stacks.isEmpty) {
      return Scaffold(
        body: _EmptyDashboard(provider: provider),
      );
    }

    final score = provider.hustleHealthScore;
    final scoreLabel = provider.healthScoreLabel;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            floating: true,
            pinned: false,
            expandedHeight: 80,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              title: _DashboardHeader(provider: provider),
            ),
            actions: [
              // Streak badge
              if (provider.currentStreak >= 2)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                  child: GestureDetector(
                    onTap: () => _showStreakDialog(context, provider),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppTheme.amber.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🔥',
                              style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 4),
                          Text(
                            '${provider.currentStreak}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.amber),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Image.asset(
                  Theme.of(context).brightness == Brightness.dark
                      ? 'assets/logo_white.png'
                      : 'assets/logo_navy.png',
                  width: 32,
                  height: 32,
                ),
              ),
            ],
          ),

          // Summary strip
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Builder(builder: (context) {
                final thisMonth = provider.thisMonthTotals;
                final lastMonth = provider.lastMonthTotals;
                return Row(children: [
                  Expanded(
                      child: SummaryCard(
                          label: 'Income',
                          value: provider.totalIncome,
                          symbol: provider.currencySymbol,
                          trend: provider.monthTrend(
                              thisMonth['income']!, lastMonth['income']!))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: SummaryCard(
                          label: 'Expenses',
                          value: provider.totalExpenses,
                          symbol: provider.currencySymbol,
                          trend: provider.monthTrend(
                              thisMonth['expenses']!, lastMonth['expenses']!))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: SummaryCard(
                          label: 'Profit',
                          value: provider.totalProfit,
                          isProfit: true,
                          highlight: true,
                          symbol: provider.currencySymbol,
                          trend: provider.monthTrend(
                              thisMonth['profit']!, lastMonth['profit']!))),
                ]);
              }),
            ),
          ),

          // Goal Progress Card (shown when a monthly income goal is set)
          if (provider.goalProgress != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: _GoalProgressCard(provider: provider),
              ),
            ),

          // This Week strip
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: _ThisWeekStrip(provider: provider),
            ),
          ),

          // Best Stack Spotlight (only shown when there's a clear leader)
          if (provider.topStackThisMonth != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: _BestStackSpotlightCard(data: provider.topStackThisMonth!),
              ),
            ),

          // FY Income Projection Card (shown when there's at least 1 month of data)
          if (provider.totalIncome > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: _FyProjectionCard(provider: provider),
              ),
            ),

          // Hustle health score card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: _HealthScoreCard(
                  score: score, label: scoreLabel),
            ),
          ),

          // Tax set-aside card (only shown when profitable)
          if (provider.totalProfit > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: _TaxSetAsideCard(
                  profit: provider.totalProfit,
                  rate: provider.taxSetAsideRate,
                  symbol: provider.currencySymbol,
                ),
              ),
            ),

          // Demo mode banner (shown when sample data is active)
          if (provider.isDemoMode)
            SliverToBoxAdapter(
              child: _DemoModeBanner(provider: provider),
            ),

          // History lock banner (free users with old transactions)
          if (!provider.isDemoMode && !provider.canViewFullHistory && provider.hiddenTransactionCount > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: GestureDetector(
                  onTap: () => showPaywallSheet(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.greenDim,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.green.withOpacity(0.25)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.lock_open_outlined, size: 14, color: AppTheme.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${provider.hiddenTransactionCount} older transaction${provider.hiddenTransactionCount == 1 ? '' : 's'} hidden — upgrade to see full history',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.green),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 11, color: AppTheme.green),
                    ]),
                  ),
                ),
              ),
            ),

          // Mileage snapshot card (drives tax deduction awareness)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: _MileageDashboardCard(),
            ),
          ),

          // Upcoming cash flow peek card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: _UpcomingPeekCard(provider: provider),
            ),
          ),

          // Quick actions row
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: _QuickActionsRow(provider: provider),
            ),
          ),

          // Section header
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Your Hustles',
              actionLabel: 'New',
              onAction: () => provider.canAddStack
                  ? showCreateStackSheet(context)
                  : showPaywallSheet(context),
            ),
          ),

          // Stack cards (non-archived only)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _StackCard(
                  stack: provider.stacks[i],
                  onTap: () => Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) =>
                          StackDetailScreen(stackId: provider.stacks[i].id),
                      transitionsBuilder: (_, anim, __, child) =>
                          SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.06),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                            parent: anim, curve: Curves.easeOut)),
                        child: FadeTransition(opacity: anim, child: child),
                      ),
                      transitionDuration: const Duration(milliseconds: 280),
                    ),
                  ),
                ),
              ),
              childCount: provider.stacks.length,
            ),
          ),

          // Customise dashboard — full-width button (QBSE-style, pinned at scroll bottom)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.tune_outlined, size: 16),
                  label: const Text('Customise dashboard',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accent,
                    side: BorderSide(
                        color: AppTheme.accent.withOpacity(0.4), width: 1.5),
                    backgroundColor: AppTheme.accentDim,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => showInsightsLayoutEditor(context),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddTransactionSheet(context),
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.add, size: 26),
      ),
    );
  }
}

// ─── Dashboard header (personalised greeting) ────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  final AppProvider provider;
  const _DashboardHeader({required this.provider});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final firstName = (auth.userName ?? '').split(' ').first;
    final greetingName = firstName.isNotEmpty ? ', $firstName' : '';
    final hustleTypes = provider.stacks.map((s) => s.hustleType).toSet();
    final stackLabel = hustleTypes.length == 1
        ? '${hustleTypes.first.label} Stacks'
        : 'SideStacks';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_greeting()}$greetingName 👋',
          style: TextStyle(
              fontSize: 11,
              color: AppTheme.of(context).textSecondary,
              fontWeight: FontWeight.w400),
        ),
        Text(
          'Your $stackLabel',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.of(context).textPrimary,
              letterSpacing: -0.4),
        ),
      ],
    );
  }
}

void _showStreakDialog(BuildContext context, AppProvider provider) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.of(context).surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            '${provider.currentStreak}-day streak!',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ve logged your hustle ${provider.currentStreak} days in a row. Keep it going!',
            style: TextStyle(
                fontSize: 13,
                color: AppTheme.of(context).textSecondary,
                height: 1.5),
            textAlign: TextAlign.center,
          ),
          if (provider.longestStreak > provider.currentStreak) ...[
            const SizedBox(height: 12),
            Text(
              'Personal best: ${provider.longestStreak} days',
              style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.of(context).textMuted),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Keep going 💪',
              style: TextStyle(
                  color: AppTheme.accent, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

// ─── Profile avatar in app bar ────────────────────────────────────────────────

class _ProfileAvatar extends StatelessWidget {
  final AppProvider provider;
  const _ProfileAvatar({required this.provider});

  @override
  Widget build(BuildContext context) {
    final picUrl = provider.profilePictureUrl;
    return Container(
      margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppTheme.accentDim,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.accent, width: 1.5),
      ),
      child: ClipOval(
        child: picUrl != null
            ? Image.network(
                picUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text('?',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accent)),
                ),
              )
            : const Center(
                child: Text('⚡',
                    style: TextStyle(fontSize: 16)),
              ),
      ),
    );
  }
}

// ─── Health Score Card ────────────────────────────────────────────────────────

class _HealthScoreCard extends StatefulWidget {
  final double score;
  final String label;
  const _HealthScoreCard({required this.score, required this.label});

  @override
  State<_HealthScoreCard> createState() => _HealthScoreCardState();
}

class _HealthScoreCardState extends State<_HealthScoreCard> {
  bool _expanded = false;

  Color get _color {
    if (widget.score >= 80) return AppTheme.green;
    if (widget.score >= 60) return AppTheme.accent;
    if (widget.score >= 40) return AppTheme.amber;
    return AppTheme.red;
  }

  String get _emoji {
    if (widget.score >= 80) return '🏆';
    if (widget.score >= 60) return '💪';
    if (widget.score >= 40) return '📈';
    return '⚠️';
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final breakdown =
        context.select<AppProvider, Map<String, double>>(
            (p) => p.healthScoreBreakdown);

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Row(children: [
              Text(_emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HUSTLE HEALTH',
                      style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: color.withOpacity(0.7),
                          letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: color),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Score arc
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: widget.score / 100,
                      strokeWidth: 4,
                      backgroundColor: color.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                    Text(
                      widget.score.toStringAsFixed(0),
                      style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 220),
                child: Icon(Icons.expand_more,
                    size: 18, color: color.withOpacity(0.7)),
              ),
            ]),

            // ── Expanded breakdown ─────────────────────────────────────────
            if (_expanded) ...[
              const SizedBox(height: 14),
              Divider(height: 1, color: color.withOpacity(0.15)),
              const SizedBox(height: 12),
              _ScoreRow(
                label: 'How much you keep',
                score: breakdown['margin'] ?? 0,
                maxScore: 30,
                color: color,
                tip: 'After expenses — the % of revenue that\'s actually yours',
              ),
              const SizedBox(height: 8),
              _ScoreRow(
                label: 'How lean you\'re running',
                score: breakdown['efficiency'] ?? 0,
                maxScore: 25,
                color: color,
                tip: 'Lower costs vs income = more take-home money',
              ),
              const SizedBox(height: 8),
              _ScoreRow(
                label: 'How regularly you earn',
                score: breakdown['consistency'] ?? 0,
                maxScore: 25,
                color: color,
                tip: 'Months where you made a profit vs total months tracked',
              ),
              const SizedBox(height: 8),
              _ScoreRow(
                label: 'How fast you\'re growing',
                score: breakdown['growth'] ?? 10,
                maxScore: 20,
                color: color,
                tip: 'Is your income trending up month over month?',
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Tap to collapse',
                  style: TextStyle(
                      fontSize: 10, color: color.withOpacity(0.5)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final double score;
  final double maxScore;
  final Color color;
  final String tip;

  const _ScoreRow({
    required this.label,
    required this.score,
    required this.maxScore,
    required this.color,
    required this.tip,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (score / maxScore).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.of(context).textPrimary)),
            ),
            Text(
              '${score.toStringAsFixed(0)} / ${maxScore.toStringAsFixed(0)}',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 5,
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 3),
        Text(tip,
            style: TextStyle(
                fontSize: 10,
                color: AppTheme.of(context).textMuted)),
      ],
    );
  }
}

// ─── Stack Card ───────────────────────────────────────────────────────────────

class _StackCard extends StatelessWidget {
  final SideStack stack;
  final VoidCallback onTap;
  const _StackCard({required this.stack, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final symbol = provider.currencySymbol;
    final isPremium = provider.isPremium;

    Widget card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.of(context).card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.of(context).border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: AppTheme.of(context).cardAlt,
                  borderRadius: BorderRadius.circular(10)),
              child: Center(
                  child: Text(stack.hustleType.emoji,
                      style: const TextStyle(fontSize: 18))),
            ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stack.name,
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    if (stack.description != null)
                      Text(stack.description!,
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.of(context).textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 18, color: AppTheme.of(context).textMuted),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: StackMetricTile(
                      label: 'Revenue',
                      value: formatCurrency(stack.totalIncome, symbol))),
              const SizedBox(width: 6),
              Expanded(
                  child: StackMetricTile(
                      label: 'Expenses',
                      value: formatCurrency(stack.totalExpenses, symbol))),
              const SizedBox(width: 6),
              Expanded(
                  child: StackMetricTile(
                      label: 'Profit',
                      value: formatCurrency(stack.netProfit, symbol),
                      valueColor: stack.netProfit >= 0
                          ? AppTheme.green
                          : AppTheme.red)),
              const SizedBox(width: 6),
              // Show $/hr when hours have been logged; otherwise show margin
              if (stack.effectiveHourlyRate != null)
                Expanded(
                    child: StackMetricTile(
                        label: '\$/hr',
                        value: '${symbol}${stack.effectiveHourlyRate!.toStringAsFixed(0)}',
                        valueColor: AppTheme.accent))
              else
                Expanded(
                    child: StackMetricTile(
                        label: 'Margin',
                        value: formatPercent(stack.profitMargin),
                        valueColor: stack.profitMargin >= 0
                            ? AppTheme.green
                            : AppTheme.red)),
            ]),
            // ── This-month strip ─────────────────────────────────────────
            const SizedBox(height: 10),
            _ThisMonthStrip(stack: stack, symbol: symbol),

            if (stack.goalAmount != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: stack.goalProgress,
                      backgroundColor: AppTheme.of(context).cardAlt,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        stack.goalProgress >= 1.0
                            ? AppTheme.green
                            : AppTheme.accent,
                      ),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(stack.goalProgress * 100).toStringAsFixed(0)}% of ${formatCurrency(stack.goalAmount!, symbol)} goal',
                  style: TextStyle(
                      fontSize: 9,
                      color: AppTheme.of(context).textMuted,
                      fontWeight: FontWeight.w500),
                ),
              ]),
            ],

            // ── Goal pace message ────────────────────────────────────────
            if (stack.goalPaceMessage(symbol) != null) ...[
              const SizedBox(height: 6),
              Text(
                stack.goalPaceMessage(symbol)!,
                style: TextStyle(
                    fontSize: 10,
                    color: stack.goalPaceRatio != null && stack.goalPaceRatio! >= 1.0
                        ? AppTheme.green
                        : AppTheme.amber,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
    );

    return GestureDetector(
      onTap: onTap,
      child: card,
    );
  }
}

// ─── This-Month Strip (on stack card) ────────────────────────────────────────

class _ThisMonthStrip extends StatelessWidget {
  final SideStack stack;
  final String symbol;
  const _ThisMonthStrip({required this.stack, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // This month income
    final thisMonthIncome = stack.thisMonthIncome;

    // Last month income for trend
    final lastMonthIncome = stack.transactions
        .where((t) =>
            t.type == TransactionType.income &&
            t.date.year == (now.month == 1 ? now.year - 1 : now.year) &&
            t.date.month == (now.month == 1 ? 12 : now.month - 1))
        .fold(0.0, (s, t) => s + t.amount);

    // This month expenses
    final thisMonthExpenses = stack.transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            t.date.year == now.year &&
            t.date.month == now.month)
        .fold(0.0, (s, t) => s + t.amount);

    final trend = lastMonthIncome > 0
        ? ((thisMonthIncome - lastMonthIncome) / lastMonthIncome * 100)
        : null;

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final label = months[now.month - 1];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.of(context).cardAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Text(
          '$label income',
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.of(context).textMuted),
        ),
        const SizedBox(width: 6),
        Text(
          formatCurrency(thisMonthIncome, symbol),
          style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.green),
        ),
        if (trend != null) ...[
          const SizedBox(width: 4),
          Icon(
            trend >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
            size: 10,
            color: trend >= 0 ? AppTheme.green : AppTheme.red,
          ),
          Text(
            '${trend.abs().toStringAsFixed(0)}%',
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: trend >= 0 ? AppTheme.green : AppTheme.red),
          ),
        ],
        const Spacer(),
        Text(
          'spent ${formatCurrency(thisMonthExpenses, symbol)}',
          style: TextStyle(
              fontSize: 10,
              color: AppTheme.of(context).textMuted),
        ),
      ]),
    );
  }
}

// ─── Upcoming Peek Card ───────────────────────────────────────────────────────

class _UpcomingPeekCard extends StatelessWidget {
  final AppProvider provider;
  const _UpcomingPeekCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    // Borrow the same projection logic via the cashflow sheet helper.
    // We only need the first 3 entries for the preview.
    final allEntries = buildCashFlowProjection(provider);
    if (allEntries.isEmpty) return const SizedBox.shrink();

    final preview = allEntries.take(3).toList();
    final sym = provider.currencySymbol;

    return GestureDetector(
      onTap: () => showCashFlowScreen(context),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppTheme.of(context).card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.of(context).border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('💸', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 7),
              Text(
                'UPCOMING',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.of(context).textMuted,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Text(
                'See all',
                style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right, size: 13, color: AppTheme.accent),
            ]),
            const SizedBox(height: 10),
            ...preview.map((e) {
              final isIncome = e.type != CashFlowEntryType.expense;
              final isOverdue =
                  e.type == CashFlowEntryType.invoice &&
                  e.date.isBefore(DateTime.now());
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Container(
                    width: 6, height: 6,
                    margin: const EdgeInsets.only(right: 8, top: 1),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOverdue
                          ? AppTheme.red
                          : isIncome
                              ? AppTheme.green
                              : AppTheme.red,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e.label,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _peekDate(e.date),
                    style: TextStyle(
                        fontSize: 11,
                        color: isOverdue
                            ? AppTheme.red
                            : AppTheme.of(context).textMuted),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${isIncome ? '+' : '-'}${formatCurrency(e.amount, sym)}',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isIncome ? AppTheme.green : AppTheme.red,
                    ),
                  ),
                ]),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _peekDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}

// ─── Mileage Dashboard Card ───────────────────────────────────────────────────
//
// Mirrors QBO's "Save on taxes while you drive for work" card.
// Pulls from MileageProvider so it updates whenever a trip is logged.

class _MileageDashboardCard extends StatelessWidget {
  const _MileageDashboardCard();

  @override
  Widget build(BuildContext context) {
    final mileage = context.watch<MileageProvider>();
    const purple = Color(0xFF8B5CF6);
    const kKmPerMile = 1.60934;
    const kRatePerMile = 0.45;

    // This tax year window (UK: 6 Apr → 5 Apr)
    final now = DateTime.now();
    final taxYearStart = now.month > 4 || (now.month == 4 && now.day >= 6)
        ? DateTime(now.year, 4, 6)
        : DateTime(now.year - 1, 4, 6);

    final yearTrips = mileage.trips
        .where((t) => !t.date.isBefore(taxYearStart))
        .toList();
    final miles = yearTrips.fold(0.0, (s, t) => s + t.distanceKm / kKmPerMile);
    final deduction = miles * kRatePerMile;

    // Empty state — still show the card as a prompt
    if (yearTrips.isEmpty) {
      return GestureDetector(
        onTap: () => showMileageScreen(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: purple.withOpacity(0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: purple.withOpacity(0.2)),
          ),
          child: Row(children: [
            const Text('🚗', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Save on taxes while you drive for work.',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: purple),
              ),
            ),
            Text(
              'Log trip',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: purple),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right, size: 14, color: purple),
          ]),
        ),
      );
    }

    // Active state — show this-year summary
    return GestureDetector(
      onTap: () => showMileageScreen(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: purple.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: purple.withOpacity(0.2)),
        ),
        child: Row(children: [
          const Text('🚗', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MILEAGE THIS TAX YEAR',
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                      color: purple.withOpacity(0.6)),
                ),
                const SizedBox(height: 1),
                Text(
                  '${miles.toStringAsFixed(0)} miles · £${deduction.toStringAsFixed(0)} deduction',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: purple),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: purple.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${yearTrips.length} trip${yearTrips.length == 1 ? '' : 's'}',
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: purple),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 14, color: purple),
        ]),
      ),
    );
  }
}

// ─── Quick Actions Row ────────────────────────────────────────────────────────

class _QuickActionsRow extends StatelessWidget {
  final AppProvider provider;
  const _QuickActionsRow({required this.provider});

  @override
  Widget build(BuildContext context) {
    final overdueCount = provider.overdueInvoiceCount;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _QuickAction(
            icon: Icons.receipt_long_outlined,
            label: 'Invoices',
            color: overdueCount > 0 ? AppTheme.red : AppTheme.accent,
            badgeCount: overdueCount,
            onTap: () {
              if (!provider.isPremium) {
                showPaywallSheet(context);
                return;
              }
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => const InvoicesScreen(),
                  transitionsBuilder: (_, anim, __, child) => SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.06),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  transitionDuration: const Duration(milliseconds: 260),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          _QuickAction(
            icon: Icons.add_circle_outline,
            label: 'Add Income',
            color: AppTheme.green,
            onTap: () => showAddTransactionSheet(context),
          ),
          const SizedBox(width: 8),
          _QuickAction(
            icon: Icons.layers_outlined,
            label: 'New Stack',
            color: AppTheme.amber,
            onTap: () => provider.canAddStack
                ? showCreateStackSheet(context)
                : showPaywallSheet(context),
          ),
          const SizedBox(width: 8),
          _QuickAction(
            icon: Icons.waterfall_chart_outlined,
            label: 'Cash Flow',
            color: const Color(0xFF0EA5E9),
            onTap: () => showCashFlowScreen(context),
          ),
          const SizedBox(width: 8),
          _QuickAction(
            icon: Icons.directions_car_outlined,
            label: 'Mileage',
            color: const Color(0xFF8B5CF6),
            onTap: () => showMileageScreen(context),
          ),
          const SizedBox(width: 8),
          _QuickAction(
            icon: Icons.calculate_outlined,
            label: 'Rate Check',
            color: const Color(0xFF0EA5E9),
            onTap: () => showRateComparatorScreen(context),
          ),
          const SizedBox(width: 8),
          _QuickAction(
            icon: Icons.flag_outlined,
            label: provider.monthlyIncomeGoal != null ? 'Edit Goal' : 'Set Goal',
            color: AppTheme.green,
            onTap: () => _showGoalDialog(context, provider),
          ),
        ],
      ),
    );
  }
}

// ─── Empty Dashboard (with demo mode entry) ───────────────────────────────────

class _EmptyDashboard extends StatelessWidget {
  final AppProvider provider;
  const _EmptyDashboard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Hero icon
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0EA5E9).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: const Center(
                  child: Text('⚡', style: TextStyle(fontSize: 40)),
                ),
              ),
              const SizedBox(height: 28),

              const Text(
                'Still guessing what\nyou actually make?',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'SideStacks shows your real profit across every hustle. Not just revenue.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.of(context).textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),

              // Primary CTA
              PrimaryButton(
                label: 'Create my first SideStack',
                onPressed: () => showCreateStackSheet(context),
              ),
              const SizedBox(height: 12),

              // Demo mode CTA
              GestureDetector(
                onTap: () => provider.enterDemoMode(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.of(context).card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.of(context).border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_circle_outline,
                          size: 16,
                          color: AppTheme.of(context).textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        'Try demo with sample data',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.of(context).textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No account required to explore',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.of(context).textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Tax Set-Aside Card ───────────────────────────────────────────────────────

class _TaxSetAsideCard extends StatelessWidget {
  final double profit;
  final double rate;
  final String symbol;

  const _TaxSetAsideCard({
    required this.profit,
    required this.rate,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    final setAsideAmount = profit * rate;
    final ratePercent = (rate * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.of(context).card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.of(context).border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with icon, label, and amount
          Row(
            children: [
              // Shield icon in green-dim circle
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.greenDim,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(
                    Icons.shield_outlined,
                    size: 16,
                    color: AppTheme.green,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Label
              Expanded(
                child: Text(
                  'TAX SET-ASIDE',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.of(context).textMuted,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              // Amount (bold, green, Courier)
              Text(
                '$symbol${setAsideAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Description text
          Text(
            'Based on your $symbol${profit.toStringAsFixed(2)} profit, set aside $symbol${setAsideAmount.toStringAsFixed(2)} ($ratePercent%) for tax.',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.of(context).textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          // Progress bar showing tax portion vs total
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rate.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppTheme.of(context).cardAlt,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.green),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Demo Mode Banner ─────────────────────────────────────────────────────────

class _DemoModeBanner extends StatelessWidget {
  final AppProvider provider;
  const _DemoModeBanner({required this.provider});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showCreateStackSheet(context),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.amber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.amber.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Text('🧪', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'You\'re viewing sample data',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.amber),
                  ),
                  Text(
                    'Tap to create your first real SideStack',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.amber.withOpacity(0.8)),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 12, color: AppTheme.amber.withOpacity(0.7)),
          ],
        ),
      ),
    );
  }
}

// ─── Goal Progress Card ───────────────────────────────────────────────────────
//
// Shown at the top of the dashboard when the user has set a monthly income goal.
// Tap anywhere on the card to edit the goal.

class _GoalProgressCard extends StatelessWidget {
  final AppProvider provider;
  const _GoalProgressCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final progress = (provider.goalProgress ?? 0).clamp(0.0, 1.0);
    final rawProgress = provider.goalProgress ?? 0;
    final goal = provider.monthlyIncomeGoal!;
    final earned = provider.thisMonthTotals['income']!;
    final daysLeft = provider.goalDaysLeft;
    final sym = provider.currencySymbol;
    final theme = AppTheme.of(context);

    final done = rawProgress >= 1.0;
    final barColor = done
        ? AppTheme.green
        : rawProgress >= 0.75
            ? AppTheme.accent
            : rawProgress >= 0.40
                ? AppTheme.amber
                : AppTheme.red;

    final pct = (rawProgress * 100).toStringAsFixed(0);
    final remaining = (goal - earned).clamp(0, double.infinity);

    return GestureDetector(
      onTap: () => _showGoalDialog(context, provider),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: barColor.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        done ? '🎯 Goal smashed!' : '🎯 Monthly target',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: barColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      RichText(
                        text: TextSpan(children: [
                          TextSpan(
                            text: '$sym${earned.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: theme.textPrimary,
                              fontFamily: 'Arial',
                            ),
                          ),
                          TextSpan(
                            text: ' / $sym${goal.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: theme.textSecondary,
                              fontFamily: 'Arial',
                            ),
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$pct%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: barColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      done
                          ? 'Done!'
                          : daysLeft <= 1
                              ? 'Last day'
                              : '$daysLeft days left',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: barColor.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
                minHeight: 6,
              ),
            ),
            if (!done && remaining > 0) ...[
              const SizedBox(height: 6),
              Text(
                '$sym${remaining.toStringAsFixed(0)} to go',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

void _showGoalDialog(BuildContext context, AppProvider provider) {
  final ctrl = TextEditingController(
    text: provider.monthlyIncomeGoal != null
        ? provider.monthlyIncomeGoal!.toStringAsFixed(0)
        : '',
  );
  final theme = AppTheme.of(context);
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: theme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Monthly Income Target',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How much do you want to earn this month?',
            style: TextStyle(fontSize: 13, color: theme.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixText: '${provider.currencySymbol} ',
              hintText: '3000',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
      actions: [
        if (provider.monthlyIncomeGoal != null)
          TextButton(
            onPressed: () {
              provider.setMonthlyIncomeGoal(null);
              Navigator.pop(ctx);
            },
            child: Text('Remove',
                style: TextStyle(color: theme.textSecondary, fontSize: 13)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel', style: TextStyle(fontSize: 13)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
          onPressed: () {
            final val = double.tryParse(ctrl.text.replaceAll(',', ''));
            if (val != null && val > 0) {
              provider.setMonthlyIncomeGoal(val);
            }
            Navigator.pop(ctx);
          },
          child: const Text('Set Goal',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

// ─── FY Income Projection Card ────────────────────────────────────────────────
//
// Shows the projected full-year income based on YTD data.
// Displayed when the user has any income recorded.

class _FyProjectionCard extends StatelessWidget {
  final AppProvider provider;
  const _FyProjectionCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final projection = provider.fyIncomeProjection;
    final lastFy = provider.lastFyIncome;
    final sym = provider.currencySymbol;
    final theme = AppTheme.of(context);

    final hasLastFy = lastFy > 0;
    final aboveLastFy = projection >= lastFy;
    final growthPct = hasLastFy
        ? ((projection - lastFy) / lastFy * 100).toStringAsFixed(0)
        : null;

    final trendColor = !hasLastFy
        ? AppTheme.accent
        : aboveLastFy
            ? AppTheme.green
            : AppTheme.red;

    final now = DateTime.now();
    final fyLabel = now.month >= 7
        ? 'FY${now.year}-${(now.year + 1) % 100}'
        : 'FY${now.year - 1}-${now.year % 100}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accent.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.rocket_launch_outlined,
                size: 18, color: AppTheme.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'On pace for $fyLabel',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: theme.textSecondary,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$sym${_fmt(projection)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: theme.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
          if (growthPct != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: trendColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    aboveLastFy
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 11,
                    color: trendColor,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${aboveLastFy ? '+' : ''}$growthPct% vs last FY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: trendColor,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              'First year — keep going!',
              style: TextStyle(fontSize: 10, color: theme.textSecondary),
            ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

// ─── Best Stack Spotlight ─────────────────────────────────────────────────────
//
// Shows the #1 income-earning stack for the current calendar month.
// Only rendered when at least one stack has income this month.

class _BestStackSpotlightCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _BestStackSpotlightCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final stack = data['stack'] as SideStack;
    final income = data['income'] as double;
    final growth = data['growth'] as double?;
    final sym = provider.currencySymbol;
    final theme = AppTheme.of(context);

    final growthPositive = growth != null && growth >= 0;
    final growthColor = growth == null
        ? theme.textSecondary
        : growthPositive
            ? AppTheme.green
            : AppTheme.red;
    final growthIcon = growth == null
        ? null
        : growthPositive
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded;
    final growthText = growth == null
        ? 'First month tracked'
        : '${growthPositive ? '+' : ''}${growth.toStringAsFixed(0)}% vs last month';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accent.withOpacity(0.12),
            AppTheme.accent.withOpacity(0.04),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accent.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          // Stack icon / emoji
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                stack.hustleType.emoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Labels
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🏆 Top hustle this month',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accent,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  stack.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: theme.textPrimary,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Income + growth
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$sym${income.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: theme.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (growthIcon != null)
                    Icon(growthIcon, size: 11, color: growthColor),
                  if (growthIcon != null) const SizedBox(width: 2),
                  Text(
                    growthText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: growthColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── This Week Strip ─────────────────────────────────────────────────────────

class _ThisWeekStrip extends StatelessWidget {
  final AppProvider provider;
  const _ThisWeekStrip({required this.provider});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Monday of the current week
    final weekStartDate = DateTime(
        now.year, now.month, now.day - (now.weekday - 1));
    final lastWeekStartDate =
        weekStartDate.subtract(const Duration(days: 7));

    final allTx = provider.allTransactions;
    double thisWeekIncome = 0;
    double lastWeekIncome = 0;
    final dayIncome = <int, double>{};

    for (final tx in allTx) {
      if (tx.type != TransactionType.income) continue;
      final d = DateTime(tx.date.year, tx.date.month, tx.date.day);
      if (!d.isBefore(weekStartDate)) {
        thisWeekIncome += tx.amount;
        dayIncome[tx.date.weekday] =
            (dayIncome[tx.date.weekday] ?? 0) + tx.amount;
      } else if (!d.isBefore(lastWeekStartDate)) {
        lastWeekIncome += tx.amount;
      }
    }

    if (thisWeekIncome == 0) return const SizedBox.shrink();

    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    String? bestDay;
    double bestDayVal = 0;
    for (int i = 1; i <= 7; i++) {
      if ((dayIncome[i] ?? 0) > bestDayVal) {
        bestDayVal = dayIncome[i]!;
        bestDay = dayNames[i - 1];
      }
    }

    final int? vsLastWeek = lastWeekIncome > 0
        ? ((thisWeekIncome - lastWeekIncome) / lastWeekIncome * 100).round()
        : null;

    final symbol = provider.currencySymbol;
    final theme = AppTheme.of(context);
    final vsColor = vsLastWeek == null
        ? theme.textSecondary
        : vsLastWeek >= 0
            ? AppTheme.green
            : AppTheme.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This Week',
                  style: TextStyle(
                      fontSize: 10,
                      color: theme.textSecondary,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  '$symbol${thisWeekIncome.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                      letterSpacing: -0.4),
                ),
              ],
            ),
          ),
          if (bestDay != null) ...[
            _WeekStatPill(
              icon: Icons.star_outline_rounded,
              label: 'Best day',
              value: bestDay,
              color: AppTheme.amber,
            ),
            const SizedBox(width: 8),
          ],
          if (vsLastWeek != null)
            _WeekStatPill(
              icon: vsLastWeek >= 0
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              label: 'vs last week',
              value: vsLastWeek >= 0 ? '+$vsLastWeek%' : '$vsLastWeek%',
              color: vsColor,
            ),
        ],
      ),
    );
  }
}

class _WeekStatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _WeekStatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color),
          ),
          Text(
            label,
            style: TextStyle(
                fontSize: 9,
                color: color.withOpacity(0.7),
                fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final int badgeCount;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 20, color: color),
                  if (badgeCount > 0)
                    Positioned(
                      top: -5,
                      right: -7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$badgeCount',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
