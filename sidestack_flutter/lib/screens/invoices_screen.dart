import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
// auth_provider not needed here currently
import '../theme/app_theme.dart';
import '../widgets/invoice_sheet.dart';
import '../widgets/shared_widgets.dart';
import '../services/pdf_export_service.dart';
import '../services/tax_pdf_service.dart';
import '../services/invoice_pdf_service.dart';

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
            title: AnimatedBuilder(
              animation: _tabController,
              builder: (_, __) {
                const titles = ['Clients', 'Invoices'];
                return Text(
                  titles[_tabController.index],
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5),
                );
              },
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

// ─── REPORTS TAB ─────────────────────────────────────────────────────────────

class ReportsTab extends StatefulWidget {
  const ReportsTab();
  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  String? _generatingId;

  Future<void> _generate(String id, Future<void> Function() action) async {
    setState(() => _generatingId = id);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to generate PDF: $e'),
          backgroundColor: AppTheme.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _generatingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final symbol = provider.currencySymbol;
    final stacks = provider.stacks;
    final allTx = provider.allTransactions;

    final totalIncome = allTx
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + t.amount);
    final totalExpenses = allTx
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + t.amount);

    return CustomScrollView(
      slivers: [
        // ── Summary strip ─────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accentDim,
                    AppTheme.greenDim,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
              ),
              child: Row(children: [
                Expanded(
                  child: _MiniStat(
                      label: 'Total Income', value: '$symbol${totalIncome.toStringAsFixed(0)}', color: AppTheme.green),
                ),
                Container(width: 1, height: 32, color: AppTheme.of(context).border),
                Expanded(
                  child: _MiniStat(
                      label: 'Total Expenses', value: '$symbol${totalExpenses.toStringAsFixed(0)}', color: AppTheme.red),
                ),
                Container(width: 1, height: 32, color: AppTheme.of(context).border),
                Expanded(
                  child: _MiniStat(
                      label: 'Net Profit',
                      value: '$symbol${(totalIncome - totalExpenses).toStringAsFixed(0)}',
                      color: AppTheme.accent),
                ),
              ]),
            ),
          ),
        ),

        // ── Section header ────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'FINANCIAL REPORTS',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppTheme.of(context).textMuted),
            ),
          ),
        ),

        // ── Full financial summary ─────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _ReportCard(
              id: 'tax',
              icon: Icons.account_balance_outlined,
              iconBg: AppTheme.accentDim,
              iconColor: AppTheme.accent,
              title: 'Tax Summary',
              subtitle: 'Income, deductible expenses & estimated tax owed — ready for your accountant',
              badge: 'PDF',
              badgeColor: AppTheme.accent,
              generating: _generatingId == 'tax',
              onTap: () => _generate('tax', () async {
                final now = DateTime.now();
                await shareTaxReportPdf(
                  context: context,
                  allTransactions: provider.allTransactions,
                  year: now.month >= 7 ? now.year : now.year - 1,
                  taxRate: 0.25,
                  currencySymbol: symbol,
                );
              }),
            ),
          ),
        ),

        // ── Per-stack reports ──────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'PER STACK',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppTheme.of(context).textMuted),
            ),
          ),
        ),

        if (stacks.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.of(context).card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.of(context).border),
                ),
                child: Text(
                  'Create a SideStack to generate per-stack PDFs',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: AppTheme.of(context).textMuted),
                ),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final stack = stacks[i];
                final income = stack.totalIncome;
                final profit = stack.netProfit;
                final id = 'stack_${stack.id}';
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: _ReportCard(
                    id: id,
                    icon: _hustleIcon(stack.hustleType),
                    iconBg: AppTheme.accentDim,
                    iconColor: AppTheme.accent,
                    title: stack.name,
                    subtitle:
                        '$symbol${income.toStringAsFixed(0)} income · $symbol${profit.toStringAsFixed(0)} profit · ${stack.transactions.length} transactions',
                    badge: 'PDF',
                    badgeColor: AppTheme.green,
                    generating: _generatingId == id,
                    onTap: () => _generate(id, () async {
                      await exportStackPdf(
                        context: context,
                        stack: stack,
                        currencySymbol: symbol,
                      );
                    }),
                  ),
                );
              },
              childCount: stacks.length,
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

// ─── Report card ──────────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  final String id;
  final IconData icon;
  final Color iconBg, iconColor;
  final String title, subtitle;
  final String badge;
  final Color badgeColor;
  final bool generating;
  final VoidCallback onTap;

  const _ReportCard({
    required this.id,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.generating,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: generating ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: generating
              ? AppTheme.accentDim
              : AppTheme.of(context).card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: generating
                ? AppTheme.accent.withOpacity(0.4)
                : AppTheme.of(context).border,
          ),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.of(context).textMuted,
                        height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (generating)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  color: AppTheme.accent, strokeWidth: 2),
            )
          else
            Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(badge,
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: badgeColor)),
                ),
                const SizedBox(height: 4),
                Icon(Icons.ios_share_outlined,
                    size: 14, color: AppTheme.of(context).textMuted),
              ],
            ),
        ]),
      ),
    );
  }
}

// ─── Mini stat ────────────────────────────────────────────────────────────────

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontFamily: 'Courier')),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: AppTheme.of(context).textMuted),
              textAlign: TextAlign.center),
        ],
      );
}

IconData _hustleIcon(HustleType type) {
  switch (type) {
    case HustleType.reselling:
      return Icons.sell_outlined;
    case HustleType.freelance:
      return Icons.laptop_outlined;
    case HustleType.business:
      return Icons.storefront_outlined;
    case HustleType.content:
      return Icons.photo_camera_outlined;
    case HustleType.other:
      return Icons.bolt_outlined;
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
      icon: Icons.people_outline,
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
                      label: status.label,
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
                      onTap: () => _showInvoiceActions(context, inv, stackMap[inv.stackId] ?? ''),
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

  Future<void> _showInvoiceActions(BuildContext context, Invoice invoice, String stackName) async {
    final provider = context.read<AppProvider>();
    final symbol = provider.currencySymbol;

    InvoiceData _buildData() => InvoiceData(
      businessName: stackName.isNotEmpty ? stackName : 'My Business',
      clientName: invoice.clientName,
      clientEmail: invoice.clientEmail.isNotEmpty ? invoice.clientEmail : null,
      invoiceNumber: invoice.invoiceNumber,
      issueDate: invoice.issuedDate,
      dueDate: invoice.dueDate,
      currencySymbol: symbol,
      abn: invoice.abn,
      paymentLink: invoice.paymentLink,
      includesGst: invoice.includesGst,
      notes: invoice.description,
      items: [
        InvoiceLineItem(
          description: invoice.description ?? 'Services',
          quantity: 1,
          unitPrice: invoice.amount,
        ),
      ],
    );

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.of(context).surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.of(ctx).borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      invoice.clientName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '$symbol${invoice.amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.accent),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.visibility_outlined, color: AppTheme.accent),
              title: const Text('View PDF'),
              onTap: () async {
                Navigator.pop(ctx);
                final data = _buildData();
                final bytes = await buildInvoicePdfBytes(data);
                if (!context.mounted) return;
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(
                        title: Text('Invoice #${invoice.invoiceNumber}'),
                        backgroundColor: AppTheme.of(context).surface,
                      ),
                      body: PdfPreview(
                        build: (_) async => bytes,
                        canChangeOrientation: false,
                        canChangePageFormat: false,
                        allowSharing: true,
                        allowPrinting: true,
                      ),
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined, color: AppTheme.accent),
              title: const Text('Share PDF'),
              onTap: () async {
                Navigator.pop(ctx);
                await shareInvoicePdf(_buildData());
              },
            ),
            ListTile(
              leading: Icon(Icons.edit_outlined, color: AppTheme.of(ctx).textSecondary),
              title: const Text('Update Status'),
              onTap: () {
                Navigator.pop(ctx);
                _showStatusSheet(context, invoice);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
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
                        Icon(invoice.status.icon,
                            size: 14, color: statusColor),
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
                        Icon(s.icon,
                            size: 18,
                            color: _selected == s
                                ? AppTheme.accent
                                : AppTheme.of(context).textSecondary),
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
            icon: Icons.receipt_long_outlined,
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
                const Text('Sample Invoice',
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
