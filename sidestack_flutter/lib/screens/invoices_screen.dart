import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/invoice_sheet.dart';
import '../widgets/shared_widgets.dart';

// ─── Clients Hub (tab: CLIENTS | INVOICES) ───────────────────────────────────

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen>
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
    return Scaffold(
      backgroundColor: AppTheme.of(context).background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            forceElevated: innerBoxIsScrolled,
            backgroundColor: AppTheme.of(context).surface,
            surfaceTintColor: Colors.transparent,
            title: const Text(
              'Clients',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.accent,
              indicatorWeight: 2,
              labelColor: AppTheme.accent,
              unselectedLabelColor: AppTheme.of(context).textSecondary,
              labelStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
              tabs: const [
                Tab(text: 'CLIENTS'),
                Tab(text: 'INVOICES'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: const [
            _ClientsTab(),
            _InvoicesTab(),
          ],
        ),
      ),
    );
  }
}

// ─── CLIENTS TAB ─────────────────────────────────────────────────────────────

class _ClientsTab extends StatelessWidget {
  const _ClientsTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final symbol = provider.currencySymbol;

    // Aggregate client revenue from all stacks
    final revenueMap = <String, double>{};
    for (final stack in provider.stacks) {
      stack.clientRevenue.forEach((name, rev) {
        revenueMap[name] = (revenueMap[name] ?? 0) + rev;
      });
    }

    // Aggregate invoice counts and outstanding per client
    final invoiceCountMap = <String, int>{};
    final outstandingMap = <String, double>{};
    for (final inv in provider.allInvoices) {
      final name = inv.clientName;
      invoiceCountMap[name] = (invoiceCountMap[name] ?? 0) + 1;
      if (inv.status != InvoiceStatus.paid &&
          inv.status != InvoiceStatus.draft) {
        outstandingMap[name] = (outstandingMap[name] ?? 0) + inv.amount;
      }
    }

    // Merge all client names from both sources
    final allNames = <String>{
      ...revenueMap.keys,
      ...invoiceCountMap.keys,
    }.toList()
      ..sort((a, b) =>
          (revenueMap[b] ?? 0).compareTo(revenueMap[a] ?? 0));

    if (allNames.isEmpty) {
      return const _ClientsEmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: allNames.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final name = allNames[i];
        final revenue = revenueMap[name] ?? 0.0;
        final invoiceCount = invoiceCountMap[name] ?? 0;
        final outstanding = outstandingMap[name] ?? 0.0;
        return _ClientCard(
          name: name,
          revenue: revenue,
          invoiceCount: invoiceCount,
          outstanding: outstanding,
          symbol: symbol,
        );
      },
    );
  }
}

class _ClientCard extends StatelessWidget {
  final String name;
  final double revenue;
  final int invoiceCount;
  final double outstanding;
  final String symbol;

  const _ClientCard({
    required this.name,
    required this.revenue,
    required this.invoiceCount,
    required this.outstanding,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final hasOutstanding = outstanding > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.of(context).card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasOutstanding
              ? AppTheme.amber.withOpacity(0.35)
              : AppTheme.of(context).border,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.accentDim,
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppTheme.accent.withOpacity(0.3), width: 1.5),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (invoiceCount > 0) ...[
                      Icon(Icons.receipt_outlined,
                          size: 11,
                          color: AppTheme.of(context).textMuted),
                      const SizedBox(width: 3),
                      Text(
                        '$invoiceCount invoice${invoiceCount == 1 ? '' : 's'}',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.of(context).textMuted),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (hasOutstanding) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.amber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$symbol${outstanding.toStringAsFixed(0)} owed',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.amber),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Revenue
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$symbol${revenue.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Courier',
                  color: AppTheme.green,
                ),
              ),
              Text(
                'earned',
                style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.of(context).textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClientsEmptyState extends StatelessWidget {
  const _ClientsEmptyState();

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      emoji: '🤝',
      title: 'No clients yet',
      subtitle: 'Add a client name when logging income and they\'ll appear here automatically.',
    );
  }
}

// ─── INVOICES TAB ─────────────────────────────────────────────────────────────

class _InvoicesTab extends StatefulWidget {
  const _InvoicesTab();

  @override
  State<_InvoicesTab> createState() => _InvoicesTabState();
}

class _InvoicesTabState extends State<_InvoicesTab> {
  InvoiceStatus? _filterStatus;

  List<Invoice> _filtered(List<Invoice> invoices) {
    return invoices.where((inv) {
      if (_filterStatus == null) return true;
      return inv.status == _filterStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final allInvoices = List<Invoice>.from(provider.allInvoices)
      ..sort((a, b) => b.issuedDate.compareTo(a.issuedDate));
    final filtered = _filtered(allInvoices);
    final symbol = provider.currencySymbol;
    final stackMap = {for (var s in provider.stacks) s.id: s.name};

    if (allInvoices.isEmpty) {
      return _InvoicesEmptyState(provider: provider);
    }

    return CustomScrollView(
      slivers: [
        // Summary strip
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                // Paid pill (always shown)
                Expanded(
                  child: _SummaryPill(
                    label: 'Paid',
                    value: '$symbol${provider.totalPaid.toStringAsFixed(0)}',
                    color: AppTheme.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryPill(
                    label: 'Outstanding',
                    value:
                        '$symbol${provider.totalOutstanding.toStringAsFixed(0)}',
                    color: AppTheme.amber,
                  ),
                ),
                if (provider.overdueInvoiceCount > 0) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SummaryPill(
                      label: '${provider.overdueInvoiceCount} overdue',
                      value: 'Action needed',
                      color: AppTheme.red,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Filter chips
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _Chip(
                    label: 'All',
                    selected: _filterStatus == null,
                    onTap: () => setState(() => _filterStatus = null),
                  ),
                  const SizedBox(width: 8),
                  for (final status in InvoiceStatus.values) ...[
                    _Chip(
                      label: '${status.emoji} ${status.label}',
                      selected: _filterStatus == status,
                      onTap: () => setState(() => _filterStatus = status),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Invoice list
        if (filtered.isEmpty)
          const SliverFillRemaining(
            child: Center(
              child: Text('No invoices in this category',
                  style: TextStyle(fontSize: 13)),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final inv = filtered[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _InvoiceCard(
                      invoice: inv,
                      stackName: stackMap[inv.stackId] ?? '',
                      symbol: symbol,
                      onTap: () => _showStatusSheet(context, inv),
                      onDelete: () => _confirmDelete(context, inv),
                    ),
                  );
                },
                childCount: filtered.length,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showStatusSheet(BuildContext context, Invoice invoice) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.of(context).surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _StatusSheet(invoice: invoice),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Invoice invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.of(context).surface,
        title: const Text('Delete invoice?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Delete invoice for ${invoice.clientName}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: TextStyle(
                      color: AppTheme.of(context).textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppTheme.red))),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<AppProvider>().deleteInvoice(invoice.id);
    }
  }
}

// ─── Invoice card ─────────────────────────────────────────────────────────────

class _InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  final String stackName;
  final String symbol;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _InvoiceCard({
    required this.invoice,
    required this.stackName,
    required this.symbol,
    required this.onTap,
    required this.onDelete,
  });

  Color _statusColor() {
    switch (invoice.status) {
      case InvoiceStatus.paid:
        return AppTheme.green;
      case InvoiceStatus.overdue:
        return AppTheme.red;
      case InvoiceStatus.sent:
      case InvoiceStatus.viewed:
        return AppTheme.amber;
      case InvoiceStatus.draft:
        return const Color(0xFF64748B);
    }
  }

  String _dueDateLabel() {
    if (invoice.status == InvoiceStatus.paid && invoice.paidDate != null) {
      final d = invoice.paidDate!;
      return 'Paid ${d.day}/${d.month}/${d.year}';
    }
    if (invoice.isOverdue) return '${invoice.daysOverdue}d overdue';
    final days = invoice.daysUntilDue;
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    return 'Due in ${days}d';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();

    return Dismissible(
      key: ValueKey(invoice.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.red.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: AppTheme.red),
      ),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.of(context).card,
            borderRadius: BorderRadius.circular(14),
            border: Border(left: BorderSide(color: statusColor, width: 3)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(invoice.status.emoji,
                            style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            invoice.clientName,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      stackName.isNotEmpty
                          ? '$stackName · ${_dueDateLabel()}'
                          : _dueDateLabel(),
                      style: TextStyle(
                          fontSize: 11,
                          color: invoice.isOverdue
                              ? AppTheme.red
                              : AppTheme.of(context).textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$symbol${invoice.amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Courier',
                  color: statusColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Status sheet ─────────────────────────────────────────────────────────────

class _StatusSheet extends StatefulWidget {
  final Invoice invoice;
  const _StatusSheet({required this.invoice});

  @override
  State<_StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends State<_StatusSheet> {
  late InvoiceStatus _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.invoice.status;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppTheme.of(context).border,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          const Text('Update Status',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          ...InvoiceStatus.values.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selected = s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: _selected == s
                          ? AppTheme.accentDim
                          : AppTheme.of(context).card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _selected == s
                              ? AppTheme.accent
                              : AppTheme.of(context).border),
                    ),
                    child: Row(
                      children: [
                        Text(s.emoji,
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(s.label,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _selected == s
                                      ? AppTheme.accent
                                      : AppTheme.of(context).textPrimary)),
                        ),
                        if (_selected == s)
                          const Icon(Icons.check_circle,
                              color: AppTheme.accent, size: 18),
                      ],
                    ),
                  ),
                ),
              )),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel',
                    style: TextStyle(
                        color: AppTheme.of(context).textSecondary,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _selected == widget.invoice.status
                    ? null
                    : () {
                        context
                            .read<AppProvider>()
                            .updateInvoiceStatus(widget.invoice.id, _selected);
                        Navigator.pop(context);
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.of(context).border,
                ),
                child: const Text('Save',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ─── Invoices empty state ─────────────────────────────────────────────────────

class _InvoicesEmptyState extends StatelessWidget {
  final AppProvider provider;
  const _InvoicesEmptyState({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: EmptyState(
            emoji: '🧾',
            title: 'No invoices yet',
            subtitle:
                'Send professional invoices in seconds. See what one looks like, then create your own.',
            // Primary CTA: sample invoice (QBSE pattern — show the product first)
            buttonLabel: 'See a sample invoice',
            onButton: () => _showSampleInvoice(context),
            // Secondary link: create real invoice (only shown when stacks exist)
            secondaryLabel: provider.stacks.isNotEmpty
                ? 'Create my first invoice'
                : null,
            onSecondary: provider.stacks.isNotEmpty
                ? () => showInvoiceSheet(context, stack: provider.stacks.first)
                : null,
          ),
        ),
      ],
    );
  }

  void _showSampleInvoice(BuildContext context) {
    final symbol = provider.currencySymbol;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SampleInvoicePreview(symbol: symbol),
    );
  }
}

/// A read-only preview of what a completed invoice looks like — shows
/// before the user has created any invoices (QBSE-style sample invoice).
class _SampleInvoicePreview extends StatelessWidget {
  final String symbol;
  const _SampleInvoicePreview({required this.symbol});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: AppTheme.of(context).surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 0),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.of(context).border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(children: [
                const Text('📄 Sample Invoice',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentDim,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('PREVIEW',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accent)),
                ),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Invoice header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.of(context).card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppTheme.of(context).border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text('FROM',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.8,
                                          color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  const Text('Alex Johnson',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700)),
                                  Text('alex@example.com',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.of(context)
                                              .textMuted)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('INV-202412-001',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                                Text('Due 15 Jan 2025',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.of(context)
                                            .textSecondary)),
                              ],
                            ),
                          ]),
                          const SizedBox(height: 14),
                          Row(children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text('TO',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.8,
                                          color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  const Text('Acme Corp',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700)),
                                  Text('billing@acme.com',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.of(context)
                                              .textMuted)),
                                ],
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Line items
                    _SampleLineItem(
                        symbol: symbol,
                        desc: 'Brand identity design',
                        detail: 'Flat rate',
                        total: 850),
                    _SampleLineItem(
                        symbol: symbol,
                        desc: 'Strategy consultation',
                        detail: '3 hrs @ ${symbol}150/hr',
                        total: 450),
                    _SampleLineItem(
                        symbol: symbol,
                        desc: 'Social media assets',
                        detail: '12 × ${symbol}25',
                        total: 300),
                    const SizedBox(height: 8),

                    // Total
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.accentDim,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        const Text('TOTAL',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5)),
                        const Spacer(),
                        Text('${symbol}1,600.00',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Courier',
                                color: AppTheme.accent)),
                      ]),
                    ),
                    const SizedBox(height: 20),

                    // CTA
                    Text(
                      'Your invoice will be exported as a professional PDF you can send directly to your client.',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.of(context).textSecondary,
                          height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SampleLineItem extends StatelessWidget {
  final String symbol;
  final String desc;
  final String detail;
  final double total;
  const _SampleLineItem(
      {required this.symbol,
      required this.desc,
      required this.detail,
      required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.of(context).card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.of(context).border),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(desc,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(detail,
                  style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.of(context).textMuted)),
            ],
          ),
        ),
        Text(
          '$symbol${total.toStringAsFixed(0)}',
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFamily: 'Courier',
              color: AppTheme.accent),
        ),
      ]),
    );
  }
}

// ─── Summary pill ─────────────────────────────────────────────────────────────

class _SummaryPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryPill(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.of(context).textMuted)),
                Text(value,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color,
                        fontFamily: 'Courier')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter chip ──────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accentDim : AppTheme.of(context).card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected
                  ? AppTheme.accent
                  : AppTheme.of(context).border),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected
                    ? AppTheme.accent
                    : AppTheme.of(context).textSecondary)),
      ),
    );
  }
}
