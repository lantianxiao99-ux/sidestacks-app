import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/add_transaction_sheet.dart';
import 'stack_detail_screen.dart';

// ─── Screen ────────────────────────────────────────────────────────────────────

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  _TxFilter _filter = _TxFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final symbol = provider.currencySymbol;

    // Gather all txs with their parent stack
    final allEntries = <_TxEntry>[];
    for (final stack in provider.stacks) {
      for (final tx in stack.transactions) {
        allEntries.add(_TxEntry(tx: tx, stack: stack));
      }
    }

    // Apply filters
    var filtered = allEntries;
    if (_filter == _TxFilter.income) {
      filtered = filtered
          .where((e) => e.tx.type == TransactionType.income)
          .toList();
    } else if (_filter == _TxFilter.expense) {
      filtered = filtered
          .where((e) => e.tx.type == TransactionType.expense)
          .toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      filtered = filtered
          .where((e) =>
              e.tx.category.toLowerCase().contains(q) ||
              (e.tx.notes?.toLowerCase().contains(q) ?? false) ||
              e.stack.name.toLowerCase().contains(q))
          .toList();
    }

    // Sort newest first
    filtered.sort((a, b) => b.tx.date.compareTo(a.tx.date));

    // Group by date label
    final groups = _groupByDate(filtered);

    final hasFilters = _filter != _TxFilter.all || _query.isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: false,
            title: Text('Transactions',
                style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(88),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Column(
                  children: [
                    // Search bar
                    SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _query = v),
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.of(context).textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search by category, note or stack…',
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
                                      color:
                                          AppTheme.of(context).textMuted),
                                )
                              : null,
                          filled: true,
                          fillColor: AppTheme.of(context).card,
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: AppTheme.of(context).border)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: AppTheme.of(context).border)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: AppTheme.accent, width: 1.5)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Filter chips
                    Row(children: [
                      _Chip(
                          label: 'All',
                          active: _filter == _TxFilter.all,
                          onTap: () =>
                              setState(() => _filter = _TxFilter.all)),
                      const SizedBox(width: 6),
                      _Chip(
                          label: 'Income',
                          active: _filter == _TxFilter.income,
                          color: AppTheme.green,
                          onTap: () =>
                              setState(() => _filter = _TxFilter.income)),
                      const SizedBox(width: 6),
                      _Chip(
                          label: 'Expense',
                          active: _filter == _TxFilter.expense,
                          color: AppTheme.red,
                          onTap: () => setState(
                              () => _filter = _TxFilter.expense)),
                      const Spacer(),
                      Text(
                        '${filtered.length} transaction${filtered.length == 1 ? '' : 's'}',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.of(context).textMuted),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),

          if (filtered.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 40,
                        color: AppTheme.of(context).textMuted),
                    const SizedBox(height: 12),
                    Text(
                      hasFilters
                          ? 'No transactions match'
                          : 'No transactions yet',
                      style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.of(context).textSecondary),
                    ),
                    if (hasFilters) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => setState(() {
                          _filter = _TxFilter.all;
                          _query = '';
                          _searchController.clear();
                        }),
                        child: Text('Clear filters',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.accent)),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    // Flatten groups into a list of items (headers + rows)
                    final items = <_ListItem>[];
                    for (final group in groups.entries) {
                      items.add(_ListItem.header(group.key));
                      for (final entry in group.value) {
                        items.add(_ListItem.entry(entry));
                      }
                    }
                    if (index >= items.length) return null;
                    final item = items[index];
                    if (item.isHeader) {
                      return _DateHeader(label: item.header!);
                    }
                    return _GlobalTxRow(
                      entry: item.entry!,
                      symbol: symbol,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StackDetailScreen(
                              stackId: item.entry!.stack.id),
                        ),
                      ),
                    );
                  },
                  childCount: () {
                    int count = 0;
                    for (final g in groups.entries) {
                      count += 1 + g.value.length;
                    }
                    return count;
                  }(),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddTransactionSheet(context),
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Map<String, List<_TxEntry>> _groupByDate(List<_TxEntry> entries) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final groups = <String, List<_TxEntry>>{};
    for (final e in entries) {
      final d = DateTime(e.tx.date.year, e.tx.date.month, e.tx.date.day);
      final String label;
      if (d == today) {
        label = 'Today';
      } else if (d == yesterday) {
        label = 'Yesterday';
      } else if (d.isAfter(weekAgo)) {
        label = DateFormat('EEEE').format(d); // e.g. "Monday"
      } else if (d.year == now.year) {
        label = DateFormat('MMMM').format(d); // e.g. "January"
      } else {
        label = DateFormat('MMMM yyyy').format(d);
      }
      groups.putIfAbsent(label, () => []).add(e);
    }
    return groups;
  }
}

// ─── Models ────────────────────────────────────────────────────────────────────

class _TxEntry {
  final Transaction tx;
  final SideStack stack;
  const _TxEntry({required this.tx, required this.stack});
}

class _ListItem {
  final String? header;
  final _TxEntry? entry;
  const _ListItem.header(this.header) : entry = null;
  const _ListItem.entry(this.entry) : header = null;
  bool get isHeader => header != null;
}

enum _TxFilter { all, income, expense }

// ─── Widgets ───────────────────────────────────────────────────────────────────

class _DateHeader extends StatelessWidget {
  final String label;
  const _DateHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 0, 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.of(context).textMuted,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _GlobalTxRow extends StatelessWidget {
  final _TxEntry entry;
  final String symbol;
  final VoidCallback onTap;
  const _GlobalTxRow(
      {required this.entry, required this.symbol, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tx = entry.tx;
    final isIncome = tx.type == TransactionType.income;
    final color = isIncome ? AppTheme.green : AppTheme.red;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.of(context).card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.of(context).border),
        ),
        child: Row(
          children: [
            // Type circle
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isIncome ? AppTheme.greenDim : AppTheme.redDim,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  isIncome ? '+' : '−',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: color),
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
                      // Stack tag
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.of(context).cardAlt,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: AppTheme.of(context).border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(entry.stack.hustleType.icon,
                                size: 9,
                                color: AppTheme.of(context).textSecondary),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                entry.stack.name,
                                style: TextStyle(
                                    fontSize: 9,
                                    color: AppTheme.of(context).textSecondary,
                                    fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        DateFormat('MMM d').format(tx.date),
                        style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.of(context).textMuted),
                      ),
                      if (tx.notes != null) ...[
                        Text(' · ',
                            style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.of(context).textMuted)),
                        Expanded(
                          child: Text(tx.notes!,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.of(context).textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      if (tx.isRecurring)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          child: const Icon(Icons.autorenew,
                              size: 10, color: AppTheme.accent),
                        ),
                    ],
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
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final Color? color;
  final VoidCallback onTap;
  const _Chip(
      {required this.label,
      required this.active,
      this.color,
      required this.onTap});

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
              color: active ? c : AppTheme.of(context).border),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: active ? c : AppTheme.of(context).textSecondary)),
      ),
    );
  }
}
