import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/models.dart' as models;
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/bank_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Bank Import Screen
//
// Shows all new bank transactions fetched from Plaid.
// User can:
//   • Toggle income/expense type per transaction
//   • Assign each transaction to a SideStack
//   • Deselect any they don't want to import
//   • Confirm to bulk-add them all at once
// ─────────────────────────────────────────────────────────────────────────────

class BankImportScreen extends StatefulWidget {
  const BankImportScreen({super.key});

  @override
  State<BankImportScreen> createState() => _BankImportScreenState();
}

class _BankImportScreenState extends State<BankImportScreen> {
  List<BankTransaction> _transactions = [];
  bool _loading = true;
  String? _error;
  bool _importing = false;

  // Per-transaction state: selected, assigned stack, type override
  late List<bool> _selected;
  late List<String?> _assignedStackId;
  late List<bool> _isIncome;
  late List<bool> _ruleApplied;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    setState(() { _loading = true; _error = null; });
    try {
      final txs = await BankService.instance.fetchTransactions(daysBack: 90);
      if (!mounted) return;
      final provider = context.read<AppProvider>();
      // Default stack: first stack if available
      final defaultStackId =
          provider.stacks.isNotEmpty ? provider.stacks.first.id : null;

      setState(() {
        _transactions = txs;
        _selected = List.filled(txs.length, true);
        // Pre-fill stack from smart rules, falling back to the default stack
        _ruleApplied = [];
        _assignedStackId = txs.map((t) {
          final remembered = provider.stackForMerchant(t.name);
          if (remembered != null &&
              provider.stacks.any((s) => s.id == remembered)) {
            _ruleApplied.add(true);
            return remembered;
          }
          _ruleApplied.add(false);
          return defaultStackId;
        }).toList();
        _isIncome = txs.map((t) => t.isIncome).toList();
        _loading = false;
      });
    } on BankServiceException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      setState(() {
        _error = 'Could not fetch transactions. Try again.';
        _loading = false;
      });
    }
  }

  Future<void> _importSelected() async {
    final provider = context.read<AppProvider>();
    if (provider.stacks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a SideStack first before importing.')),
      );
      return;
    }

    final selectedIndices = [
      for (int i = 0; i < _selected.length; i++)
        if (_selected[i]) i,
    ];

    if (selectedIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transactions selected.')),
      );
      return;
    }

    // Check all selected have a stack assigned
    final unassigned =
        selectedIndices.where((i) => _assignedStackId[i] == null).length;
    if (unassigned > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '$unassigned transaction${unassigned > 1 ? 's are' : ' is'} not assigned to a SideStack.')),
      );
      return;
    }

    setState(() => _importing = true);

    try {
      // Group by stack for efficient bulk import
      final Map<String, List<models.Transaction>> byStack = {};
      final importedIds = <String>[];

      for (final i in selectedIndices) {
        final tx = _transactions[i];
        final stackId = _assignedStackId[i]!;
        importedIds.add(tx.transactionId);

        final modelTx = models.Transaction(
          id: 'bank_${tx.transactionId}',
          type: _isIncome[i]
              ? models.TransactionType.income
              : models.TransactionType.expense,
          amount: tx.amount,
          date: tx.date,
          category: tx.category,
          notes: tx.name,
        );

        byStack.putIfAbsent(stackId, () => []).add(modelTx);
      }

      // Import into each stack
      for (final entry in byStack.entries) {
        await provider.importTransactions(entry.key, entry.value);
      }

      // Save smart rules so the same merchant is pre-filled next time
      for (final i in selectedIndices) {
        final stackId = _assignedStackId[i];
        if (stackId != null) {
          await provider.saveBankRule(_transactions[i].name, stackId);
        }
      }

      // Mark as imported on the server (prevents re-appearing)
      await BankService.instance.markImported(importedIds);

      if (!mounted) return;

      final count = selectedIndices.length;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $count transaction${count == 1 ? '' : 's'} imported!'),
          backgroundColor: AppTheme.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _importing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }

  int get _selectedCount => _selected.where((s) => s).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.of(context).background,
      appBar: AppBar(
        backgroundColor: AppTheme.of(context).surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bank Import',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (!_loading && _transactions.isNotEmpty)
              Text(
                '$_selectedCount of ${_transactions.length} selected',
                style: TextStyle(
                    fontSize: 11, color: AppTheme.of(context).textSecondary),
              ),
          ],
        ),
        actions: [
          if (!_loading && _transactions.isNotEmpty)
            TextButton(
              onPressed: () => setState(() {
                final allSelected = _selected.every((s) => s);
                for (int i = 0; i < _selected.length; i++) {
                  _selected[i] = !allSelected;
                }
              }),
              child: Text(
                _selected.every((s) => s) ? 'Deselect all' : 'Select all',
                style: const TextStyle(color: AppTheme.accent, fontSize: 13),
              ),
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _transactions.isNotEmpty && !_loading
          ? _ImportBar(
              count: _selectedCount,
              importing: _importing,
              onImport: _importSelected,
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.accent),
            SizedBox(height: 16),
            Text('Fetching transactions…', style: TextStyle(fontSize: 14)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                    color: AppTheme.redDim,
                    borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.wifi_off_outlined,
                    size: 28, color: AppTheme.red),
              ),
              const SizedBox(height: 20),
              Text(_error!,
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              SizedBox(
                width: 160,
                child: PrimaryButton(
                    label: 'Retry', onPressed: _fetchTransactions),
              ),
            ],
          ),
        ),
      );
    }

    if (_transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✅', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 20),
              const Text('All caught up!',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'No new transactions from your bank in the last 90 days.',
                style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.of(context).textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final stacks = context.watch<AppProvider>().stacks;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: _transactions.length,
      itemBuilder: (context, i) => _TransactionReviewCard(
        transaction: _transactions[i],
        selected: _selected[i],
        isIncome: _isIncome[i],
        assignedStackId: _assignedStackId[i],
        stacks: stacks,
        ruleApplied: _ruleApplied[i],
        onToggleSelected: () =>
            setState(() => _selected[i] = !_selected[i]),
        onToggleType: () =>
            setState(() => _isIncome[i] = !_isIncome[i]),
        onStackChanged: (id) =>
            setState(() => _assignedStackId[i] = id),
      ),
    );
  }
}

// ─── Transaction review card ──────────────────────────────────────────────────

class _TransactionReviewCard extends StatelessWidget {
  final BankTransaction transaction;
  final bool selected;
  final bool isIncome;
  final String? assignedStackId;
  final List<models.SideStack> stacks;
  final VoidCallback onToggleSelected;
  final VoidCallback onToggleType;
  final ValueChanged<String?> onStackChanged;
  final bool ruleApplied;

  const _TransactionReviewCard({
    required this.transaction,
    required this.selected,
    required this.isIncome,
    required this.assignedStackId,
    required this.stacks,
    required this.onToggleSelected,
    required this.onToggleType,
    required this.onStackChanged,
    this.ruleApplied = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isIncome ? AppTheme.green : AppTheme.red;
    final dimColor = isIncome ? AppTheme.greenDim : AppTheme.redDim;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: selected ? 1.0 : 0.4,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.of(context).card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppTheme.of(context).border
                : AppTheme.of(context).borderLight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: checkbox + name + amount ──────────────────────────
            Row(children: [
              GestureDetector(
                onTap: onToggleSelected,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: selected
                          ? AppTheme.accent
                          : AppTheme.of(context).border,
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(children: [
                      Text(
                        '${transaction.institution} · ${DateFormat('d MMM').format(transaction.date)}',
                        style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.of(context).textMuted),
                      ),
                      if (ruleApplied) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.accentDim,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('auto',
                              style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.accent)),
                        ),
                      ],
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${isIncome ? '+' : '-'}\$${transaction.amount.toStringAsFixed(2)}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color),
              ),
            ]),
            const SizedBox(height: 10),

            // ── Bottom row: type toggle + stack picker ────────────────────
            Row(children: [
              // Income/expense toggle
              GestureDetector(
                onTap: onToggleType,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: dimColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      isIncome
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      size: 11,
                      color: color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isIncome ? 'Income' : 'Expense',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 8),

              // Stack picker
              Expanded(
                child: stacks.isEmpty
                    ? Text('No stacks yet',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.of(context).textMuted))
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.of(context).cardAlt,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppTheme.of(context).border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: assignedStackId,
                            isDense: true,
                            isExpanded: true,
                            hint: Text('Assign stack',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.of(context).textMuted)),
                            icon: Icon(Icons.expand_more,
                                size: 14,
                                color: AppTheme.of(context).textMuted),
                            dropdownColor: AppTheme.of(context).card,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.of(context).textPrimary,
                                fontFamily: 'Sora'),
                            items: stacks
                                .map((s) => DropdownMenuItem(
                                      value: s.id,
                                      child: Text(
                                          '${s.hustleType.emoji} ${s.name}',
                                          overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: onStackChanged,
                          ),
                        ),
                      ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─── Import bottom bar ────────────────────────────────────────────────────────

class _ImportBar extends StatelessWidget {
  final int count;
  final bool importing;
  final VoidCallback onImport;

  const _ImportBar({
    required this.count,
    required this.importing,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppTheme.of(context).surface,
        border: Border(
            top: BorderSide(color: AppTheme.of(context).border)),
      ),
      child: PrimaryButton(
        label: importing
            ? 'Importing…'
            : count == 0
                ? 'Select transactions to import'
                : 'Import $count transaction${count == 1 ? '' : 's'}',
        onPressed: (count == 0 || importing) ? null : onImport,
      ),
    );
  }
}
