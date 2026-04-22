import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'shared_widgets.dart';

// ─── Entry points ────────────────────────────────────────────────────────────

void showCashFlowSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CashFlowSheet(),
  );
}

/// Push a full-screen cash flow view — preferred over the sheet for
/// navigation destinations (dashboard card, quick action).
void showCashFlowScreen(BuildContext context) {
  Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => const CashFlowScreen(),
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
}

/// Full-screen Cash Flow — same content as the sheet, presented as a Scaffold.
class CashFlowScreen extends StatelessWidget {
  const CashFlowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final sym = provider.currencySymbol;
    final entries = buildCashFlowProjection(provider);

    final totalIn = entries
        .where((e) =>
            e.type == CashFlowEntryType.income ||
            e.type == CashFlowEntryType.invoice)
        .fold(0.0, (s, e) => s + e.amount);
    final totalOut = entries
        .where((e) => e.type == CashFlowEntryType.expense)
        .fold(0.0, (s, e) => s + e.amount);
    final net = totalIn - totalOut;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: false,
            expandedHeight: 72,
            leading: BackButton(
                color: AppTheme.of(context).textPrimary),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(52, 0, 20, 12),
              title: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Cash Flow',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: AppTheme.of(context).textPrimary),
                  ),
                  const Spacer(),
                  Text(
                    'Next 30 days',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.of(context).textMuted,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),

          // ── Summary strip ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(children: [
                _SummaryPill(
                    label: 'Expected in',
                    value: formatCurrency(totalIn, sym),
                    color: AppTheme.green,
                    bg: AppTheme.greenDim),
                const SizedBox(width: 8),
                _SummaryPill(
                    label: 'Expected out',
                    value: formatCurrency(totalOut, sym),
                    color: AppTheme.red,
                    bg: AppTheme.redDim),
                const SizedBox(width: 8),
                _SummaryPill(
                    label: 'Net',
                    value: formatCurrency(net, sym),
                    color: net >= 0 ? AppTheme.green : AppTheme.red,
                    bg: net >= 0 ? AppTheme.greenDim : AppTheme.redDim),
              ]),
            ),
          ),

          const SliverToBoxAdapter(
            child: Divider(height: 1),
          ),

          // ── Entry list ────────────────────────────────────────────────────
          if (entries.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 42, color: AppTheme.accent),
                      const SizedBox(height: 16),
                      const Text(
                        'Nothing upcoming',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add recurring income or expenses and send invoices to see your cash flow forecast here.',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.of(context).textSecondary,
                            height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final entry = entries[i];
                    final showBucket = i == 0 ||
                        !_sameWeekBucket(entries[i - 1].date, entry.date);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showBucket) ...[
                          if (i != 0) const SizedBox(height: 16),
                          _WeekLabel(date: entry.date),
                          const SizedBox(height: 6),
                        ],
                        _EntryTile(entry: entry, symbol: sym),
                        const SizedBox(height: 6),
                      ],
                    );
                  },
                  childCount: entries.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Data model ──────────────────────────────────────────────────────────────

enum CashFlowEntryType { income, expense, invoice }

class CashFlowEntry {
  final DateTime date;
  final CashFlowEntryType type;
  final double amount;
  final String label;
  final String? stackName;
  final String? note;

  const CashFlowEntry({
    required this.date,
    required this.type,
    required this.amount,
    required this.label,
    this.stackName,
    this.note,
  });
}

// ─── Projection logic ────────────────────────────────────────────────────────

List<CashFlowEntry> buildCashFlowProjection(AppProvider provider) {
  final now = DateTime.now();
  final horizon = now.add(const Duration(days: 30));
  final entries = <CashFlowEntry>[];

  // ── Recurring transactions ─────────────────────────────────────────────────
  for (final stack in provider.stacks) {
    final recurring = stack.transactions.where((t) => t.isRecurring).toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // latest first

    // Group by category to deduplicate (take the most recent per category)
    final seen = <String>{};
    for (final tx in recurring) {
      final key = '${stack.id}|${tx.category}|${tx.type.name}';
      if (seen.contains(key)) continue;
      seen.add(key);

      final interval = tx.recurrenceInterval ?? RecurrenceInterval.monthly;

      // Project next occurrences within the 30-day window.
      // Start from the last known date and step forward.
      DateTime next = tx.date;
      while (next.isBefore(now)) {
        next = _advance(next, interval);
      }

      while (!next.isAfter(horizon)) {
        entries.add(CashFlowEntry(
          date: next,
          type: tx.type == TransactionType.income
              ? CashFlowEntryType.income
              : CashFlowEntryType.expense,
          amount: tx.amount,
          label: tx.category,
          stackName: stack.name,
          note: tx.notes,
        ));
        next = _advance(next, interval);
      }
    }
  }

  // ── Unpaid invoices due in window ──────────────────────────────────────────
  for (final inv in provider.allInvoices) {
    if (inv.status == InvoiceStatus.paid) continue;
    if (inv.dueDate.isBefore(now.subtract(const Duration(days: 1)))) {
      // Overdue — include anyway so user can see them
      if (inv.dueDate.isBefore(now.subtract(const Duration(days: 14)))) {
        continue; // too far in the past, skip
      }
    }
    if (inv.dueDate.isAfter(horizon)) continue;

    final stackName = provider.stacks
        .where((s) => s.id == inv.stackId)
        .map((s) => s.name)
        .firstOrNull;

    entries.add(CashFlowEntry(
      date: inv.dueDate,
      type: CashFlowEntryType.invoice,
      amount: inv.amount,
      label: 'Invoice #${inv.invoiceNumber}',
      stackName: stackName ?? inv.clientName,
      note: inv.clientName,
    ));
  }

  entries.sort((a, b) => a.date.compareTo(b.date));
  return entries;
}

DateTime _advance(DateTime from, RecurrenceInterval interval) {
  if (interval == RecurrenceInterval.weekly) {
    return from.add(const Duration(days: 7));
  }
  // Monthly: same day next month
  final next = DateTime(from.year, from.month + 1, from.day);
  return next;
}

// ─── Sheet ───────────────────────────────────────────────────────────────────

class _CashFlowSheet extends StatelessWidget {
  const _CashFlowSheet();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final sym = provider.currencySymbol;
    final entries = buildCashFlowProjection(provider);

    final totalIn = entries
        .where((e) =>
            e.type == CashFlowEntryType.income ||
            e.type == CashFlowEntryType.invoice)
        .fold(0.0, (s, e) => s + e.amount);
    final totalOut = entries
        .where((e) => e.type == CashFlowEntryType.expense)
        .fold(0.0, (s, e) => s + e.amount);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: AppTheme.of(context).background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: AppTheme.of(context).border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined, size: 22, color: AppTheme.accent),
                      const SizedBox(width: 10),
                      const Text(
                        'Cash Flow',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Text(
                        'Next 30 days',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.of(context).textMuted,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // In / Out / Net summary pills
                  Row(children: [
                    _SummaryPill(
                      label: 'Expected in',
                      value: formatCurrency(totalIn, sym),
                      color: AppTheme.green,
                      bg: AppTheme.greenDim,
                    ),
                    const SizedBox(width: 8),
                    _SummaryPill(
                      label: 'Expected out',
                      value: formatCurrency(totalOut, sym),
                      color: AppTheme.red,
                      bg: AppTheme.redDim,
                    ),
                    const SizedBox(width: 8),
                    _SummaryPill(
                      label: 'Net',
                      value: formatCurrency(totalIn - totalOut, sym),
                      color: (totalIn - totalOut) >= 0
                          ? AppTheme.green
                          : AppTheme.red,
                      bg: (totalIn - totalOut) >= 0
                          ? AppTheme.greenDim
                          : AppTheme.redDim,
                    ),
                  ]),
                ],
              ),
            ),

            const Divider(height: 1),

            // List
            Expanded(
              child: entries.isEmpty
                  ? _buildEmpty(context)
                  : ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                      itemCount: entries.length,
                      itemBuilder: (_, i) {
                        final entry = entries[i];
                        final showDate = i == 0 ||
                            !_sameWeekBucket(
                                entries[i - 1].date, entry.date);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showDate) ...[
                              if (i != 0) const SizedBox(height: 16),
                              _WeekLabel(date: entry.date),
                              const SizedBox(height: 6),
                            ],
                            _EntryTile(entry: entry, symbol: sym),
                            const SizedBox(height: 6),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_outlined, size: 42, color: AppTheme.accent),
            const SizedBox(height: 16),
            const Text(
              'Nothing upcoming',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add recurring income or expenses and send invoices to see your cash flow forecast here.',
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

// ─── Helpers ──────────────────────────────────────────────────────────────────

bool _sameWeekBucket(DateTime a, DateTime b) {
  final now = DateTime.now();
  return _weekBucket(a, now) == _weekBucket(b, now);
}

int _weekBucket(DateTime d, DateTime now) {
  return d.difference(now).inDays ~/ 7;
}

String _weekBucketLabel(DateTime date) {
  final now = DateTime.now();
  final bucket = _weekBucket(date, now);
  if (bucket < 0) return 'Overdue';
  if (bucket == 0) return 'This week';
  if (bucket == 1) return 'Next week';
  return 'In ${bucket + 1} weeks';
}

String _formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${d.day} ${months[d.month - 1]}';
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _SummaryPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bg;

  const _SummaryPill({
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekLabel extends StatelessWidget {
  final DateTime date;
  const _WeekLabel({required this.date});

  @override
  Widget build(BuildContext context) {
    final label = _weekBucketLabel(date);
    final isOverdue = label == 'Overdue';
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 0, 0),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isOverdue ? AppTheme.red : AppTheme.of(context).textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final CashFlowEntry entry;
  final String symbol;
  const _EntryTile({required this.entry, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final isIncome = entry.type != CashFlowEntryType.expense;
    final isInvoice = entry.type == CashFlowEntryType.invoice;
    final isOverdue = entry.date.isBefore(DateTime.now()) && isInvoice;

    Color tileColor;
    Color borderColor;
    Color amountColor;
    IconData icon;
    Color iconBg;
    Color iconColor;

    if (isOverdue) {
      tileColor = AppTheme.redDim;
      borderColor = AppTheme.red.withOpacity(0.3);
      amountColor = AppTheme.red;
      icon = Icons.warning_amber_rounded;
      iconBg = AppTheme.redDim;
      iconColor = AppTheme.red;
    } else if (isInvoice) {
      tileColor = AppTheme.of(context).card;
      borderColor = AppTheme.of(context).border;
      amountColor = AppTheme.green;
      icon = Icons.receipt_outlined;
      iconBg = AppTheme.greenDim;
      iconColor = AppTheme.green;
    } else if (isIncome) {
      tileColor = AppTheme.of(context).card;
      borderColor = AppTheme.of(context).border;
      amountColor = AppTheme.green;
      icon = Icons.trending_up;
      iconBg = AppTheme.greenDim;
      iconColor = AppTheme.green;
    } else {
      tileColor = AppTheme.of(context).card;
      borderColor = AppTheme.of(context).border;
      amountColor = AppTheme.red;
      icon = Icons.trending_down;
      iconBg = AppTheme.redDim;
      iconColor = AppTheme.red;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.label,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${isIncome ? '+' : '-'}${formatCurrency(entry.amount, symbol)}',
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: amountColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (entry.stackName != null) ...[
                      Text(
                        entry.stackName!,
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.of(context).textMuted),
                      ),
                      Text(
                        ' · ',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.of(context).textMuted),
                      ),
                    ],
                    Text(
                      isOverdue
                          ? 'Due ${_formatDate(entry.date)} · OVERDUE'
                          : _formatDate(entry.date),
                      style: TextStyle(
                        fontSize: 11,
                        color: isOverdue
                            ? AppTheme.red
                            : AppTheme.of(context).textMuted,
                        fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
