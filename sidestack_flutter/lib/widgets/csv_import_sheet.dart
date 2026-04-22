import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

const _uuid = Uuid();

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showCsvImportSheet(BuildContext context,
    {String? preselectedStackId}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.of(context).card,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _CsvImportSheet(preselectedStackId: preselectedStackId),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CsvImportSheet extends StatefulWidget {
  final String? preselectedStackId;
  const _CsvImportSheet({this.preselectedStackId});

  @override
  State<_CsvImportSheet> createState() => _CsvImportSheetState();
}

enum _ImportStep { pick, map, preview }

class _CsvImportSheetState extends State<_CsvImportSheet> {
  _ImportStep _step = _ImportStep.pick;
  bool _loading = false;
  String? _error;

  // Parsed raw CSV data
  List<String> _headers = [];
  List<List<String>> _rows = [];

  // Column mapping
  int? _dateCol;
  int? _amountCol;
  int? _descCol;
  int? _incomeCol; // optional: separate income column
  int? _expenseCol; // optional: separate expense column
  bool _positiveIsIncome = true;

  // Stack selection
  late String _stackId;

  // Preview transactions
  List<Transaction> _preview = [];

  @override
  void initState() {
    super.initState();
    final provider = context.read<AppProvider>();
    _stackId = widget.preselectedStackId ?? provider.stacks.first.id;
  }

  // ── File picking ───────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _loading = false);
        return;
      }
      final file = result.files.first;
      String content;
      if (file.bytes != null) {
        content = String.fromCharCodes(file.bytes!);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        throw Exception('Could not read file');
      }
      _parseCSV(content);
      setState(() { _step = _ImportStep.map; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── CSV parsing ────────────────────────────────────────────────────────────

  void _parseCSV(String content) {
    final lines = content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    if (lines.isEmpty) throw Exception('File appears to be empty');

    _headers = _splitCsvLine(lines.first);
    _rows = lines.skip(1).map(_splitCsvLine).toList();

    if (_rows.isEmpty) throw Exception('No data rows found');

    // Auto-detect common column names
    for (int i = 0; i < _headers.length; i++) {
      final h = _headers[i].toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
      if (_dateCol == null &&
          (h.contains('date') || h.contains('time'))) _dateCol = i;
      if (_amountCol == null &&
          (h == 'amount' || h == 'value' || h == 'sum' ||
           h == 'debit' || h == 'credit' || h == 'net')) _amountCol = i;
      if (_descCol == null &&
          (h.contains('desc') || h.contains('narr') ||
           h.contains('payee') || h.contains('merchant') ||
           h.contains('detail') || h.contains('ref'))) _descCol = i;
    }
    _amountCol ??= _headers.indexWhere((h) {
      final lo = h.toLowerCase();
      return lo.contains('amount') || lo.contains('debit') || lo.contains('credit');
    }).let((i) => i >= 0 ? i : null);
  }

  List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;
    for (final ch in line.split('')) {
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == ',' && !inQuotes) {
        result.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    result.add(buffer.toString().trim());
    return result;
  }

  // ── Build preview transactions ─────────────────────────────────────────────

  void _buildPreview() {
    if (_dateCol == null || _amountCol == null) {
      setState(() => _error = 'Please map Date and Amount columns');
      return;
    }
    setState(() => _error = null);

    final txs = <Transaction>[];
    for (final row in _rows) {
      if (row.length <= (_amountCol!)) continue;

      // Parse date
      DateTime? date;
      if (_dateCol != null && row.length > _dateCol!) {
        date = _parseDate(row[_dateCol!]);
      }
      date ??= DateTime.now();

      // Parse amount
      final rawAmt = row[_amountCol!]
          .replaceAll(RegExp(r'[£$€,\s]'), '')
          .replaceAll('(', '-')
          .replaceAll(')', '');
      final amount = double.tryParse(rawAmt);
      if (amount == null) continue;

      // Determine type
      TransactionType type;
      if (_incomeCol != null && _expenseCol != null) {
        final incAmt = double.tryParse(
                row.length > _incomeCol! ? row[_incomeCol!].replaceAll(RegExp(r'[£$€,\s]'), '') : '') ??
            0;
        type = incAmt > 0
            ? TransactionType.income
            : TransactionType.expense;
      } else if (amount >= 0) {
        type = _positiveIsIncome
            ? TransactionType.income
            : TransactionType.expense;
      } else {
        type = _positiveIsIncome
            ? TransactionType.expense
            : TransactionType.income;
      }

      // Description
      final desc = _descCol != null && row.length > _descCol!
          ? row[_descCol!]
          : 'Imported';

      txs.add(Transaction(
        id: _uuid.v4(),
        type: type,
        amount: amount.abs(),
        category: type == TransactionType.income ? 'Sales' : 'General',
        date: date,
        notes: desc.isNotEmpty ? desc : null,
      ));
    }

    if (txs.isEmpty) {
      setState(() => _error = 'No valid transactions could be parsed');
      return;
    }

    setState(() {
      _preview = txs;
      _step = _ImportStep.preview;
    });
  }

  DateTime? _parseDate(String s) {
    s = s.trim();
    // Try common formats: dd/MM/yyyy, MM/dd/yyyy, yyyy-MM-dd, dd-MM-yyyy, dd MMM yyyy
    final formats = [
      RegExp(r'^(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})$'),
      RegExp(r'^(\d{4})[/\-](\d{1,2})[/\-](\d{1,2})$'),
    ];
    for (final fmt in formats) {
      final m = fmt.firstMatch(s);
      if (m != null) {
        try {
          final a = int.parse(m.group(1)!);
          final b = int.parse(m.group(2)!);
          final c = int.parse(m.group(3)!);
          // yyyy-MM-dd
          if (a > 31) return DateTime(a, b, c);
          // dd/MM/yyyy (assume day first)
          return DateTime(c, b, a);
        } catch (_) {}
      }
    }
    return DateTime.tryParse(s);
  }

  // ── Import ────────────────────────────────────────────────────────────────

  Future<void> _import() async {
    setState(() => _loading = true);
    try {
      final count = await context
          .read<AppProvider>()
          .importTransactions(_stackId, _preview);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Imported $count transactions',
              style: const TextStyle(fontFamily: 'Sora', fontSize: 13)),
          backgroundColor: AppTheme.of(context).card,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => Column(children: [
          // Handle
          Container(
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.of(context).border,
                  borderRadius: BorderRadius.circular(2))),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              const Icon(Icons.account_balance_outlined, size: 20, color: AppTheme.accent),
              const SizedBox(width: 10),
              Text(
                _step == _ImportStep.pick
                    ? 'Import Bank CSV'
                    : _step == _ImportStep.map
                        ? 'Map Columns'
                        : 'Preview (${_preview.length})',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.redDim,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, size: 14, color: AppTheme.red),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.red))),
                ]),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildStepContent(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case _ImportStep.pick:
        return _buildPickStep();
      case _ImportStep.map:
        return _buildMapStep();
      case _ImportStep.preview:
        return _buildPreviewStep();
    }
  }

  // ── Step 1: Pick file ─────────────────────────────────────────────────────

  Widget _buildPickStep() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.of(context).cardAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppTheme.of(context).border,
              style: BorderStyle.solid),
        ),
        child: Column(children: [
          const Icon(Icons.folder_open_outlined, size: 36, color: AppTheme.accent),
          const SizedBox(height: 12),
          Text('Select your bank export',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.of(context).textPrimary)),
          const SizedBox(height: 6),
          Text(
            'Supports CSV files from most banks.\nYou\'ll map columns on the next screen.',
            style: TextStyle(
                fontSize: 12, color: AppTheme.of(context).textSecondary),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _loading ? null : _pickFile,
          icon: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.upload_file_outlined, size: 18),
          label: Text(_loading ? 'Loading…' : 'Choose CSV File'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      const SizedBox(height: 24),
    ]);
  }

  // ── Step 2: Map columns ────────────────────────────────────────────────────

  Widget _buildMapStep() {
    final provider = context.read<AppProvider>();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Stack selector
      Text('Import into stack',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.of(context).textMuted,
              letterSpacing: 0.6)),
      const SizedBox(height: 6),
      _DropdownField<String>(
        value: _stackId,
        items: provider.stacks
            .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
            .toList(),
        onChanged: (v) => setState(() => _stackId = v!),
      ),
      const SizedBox(height: 16),
      Text('Column mapping',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.of(context).textMuted,
              letterSpacing: 0.6)),
      const SizedBox(height: 6),
      _ColMapper(
        label: 'Date *',
        headers: _headers,
        value: _dateCol,
        onChanged: (v) => setState(() => _dateCol = v),
      ),
      const SizedBox(height: 8),
      _ColMapper(
        label: 'Amount *',
        headers: _headers,
        value: _amountCol,
        onChanged: (v) => setState(() => _amountCol = v),
      ),
      const SizedBox(height: 8),
      _ColMapper(
        label: 'Description',
        headers: _headers,
        value: _descCol,
        nullable: true,
        onChanged: (v) => setState(() => _descCol = v),
      ),
      const SizedBox(height: 16),
      // Positive amount = income / expense toggle
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.of(context).cardAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.of(context).border),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Positive amounts are',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
              Text('How to interpret positive values',
                  style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.of(context).textSecondary)),
            ]),
          ),
          DropdownButton<bool>(
            value: _positiveIsIncome,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: true, child: Text('Income')),
              DropdownMenuItem(value: false, child: Text('Expense')),
            ],
            onChanged: (v) => setState(() => _positiveIsIncome = v!),
          ),
        ]),
      ),
      const SizedBox(height: 6),
      Text('${_rows.length} rows detected · ${_headers.length} columns',
          style: TextStyle(
              fontSize: 10, color: AppTheme.of(context).textMuted)),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _buildPreview,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Preview Transactions'),
        ),
      ),
      const SizedBox(height: 24),
    ]);
  }

  // ── Step 3: Preview ───────────────────────────────────────────────────────

  Widget _buildPreviewStep() {
    final symbol = context.read<AppProvider>().currencySymbol;
    final incomeCount = _preview.where((t) => t.type == TransactionType.income).length;
    final expenseCount = _preview.length - incomeCount;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _StatChip(label: '${_preview.length} total', color: AppTheme.accent),
        const SizedBox(width: 8),
        _StatChip(label: '$incomeCount income', color: AppTheme.green),
        const SizedBox(width: 8),
        _StatChip(label: '$expenseCount expenses', color: AppTheme.red),
      ]),
      const SizedBox(height: 14),
      ..._preview.take(50).map((tx) {
        final isIncome = tx.type == TransactionType.income;
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: AppTheme.of(context).cardAlt,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isIncome ? AppTheme.greenDim : AppTheme.redDim,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(isIncome ? '+' : '−',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isIncome ? AppTheme.green : AppTheme.red)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tx.notes ?? tx.category,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  '${tx.date.day}/${tx.date.month}/${tx.date.year}',
                  style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.of(context).textSecondary),
                ),
              ]),
            ),
            Text(
              '${isIncome ? '+' : '−'}${formatCurrency(tx.amount, symbol)}',
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isIncome ? AppTheme.green : AppTheme.red,
              ),
            ),
          ]),
        );
      }),
      if (_preview.length > 50)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '… and ${_preview.length - 50} more',
            style: TextStyle(
                fontSize: 11, color: AppTheme.of(context).textMuted),
          ),
        ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => setState(() => _step = _ImportStep.map),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.of(context).textSecondary,
              side: BorderSide(color: AppTheme.of(context).border),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Back'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _loading ? null : _import,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text('Import ${_preview.length} Transactions'),
          ),
        ),
      ]),
      const SizedBox(height: 24),
    ]);
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _ColMapper extends StatelessWidget {
  final String label;
  final List<String> headers;
  final int? value;
  final bool nullable;
  final ValueChanged<int?> onChanged;

  const _ColMapper({
    required this.label,
    required this.headers,
    required this.value,
    required this.onChanged,
    this.nullable = false,
  });

  @override
  Widget build(BuildContext context) {
    return _DropdownField<int?>(
      label: label,
      value: value,
      items: [
        if (nullable)
          const DropdownMenuItem<int?>(value: null, child: Text('— skip —')),
        ...headers.asMap().entries.map(
              (e) => DropdownMenuItem<int?>(
                  value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
            ),
      ],
      onChanged: onChanged,
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final String? label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.of(context).cardAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.of(context).border),
      ),
      child: Row(children: [
        if (label != null) ...[
          SizedBox(
            width: 90,
            child: Text(label!,
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.of(context).textSecondary)),
          ),
        ],
        Expanded(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.of(context).textPrimary,
                fontFamily: 'Sora'),
            items: items,
            onChanged: onChanged,
          ),
        ),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );
}

// Extension helper
extension _NullableInt on int {
  T? let<T>(T? Function(int) fn) => fn(this);
}
