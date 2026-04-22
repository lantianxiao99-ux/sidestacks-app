import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../services/invoice_pdf_service.dart';

// ─── Billing types ─────────────────────────────────────────────────────────────

enum LineItemBillingType { flatRate, hourly, product }

extension _LineItemBillingTypeExt on LineItemBillingType {
  String get label {
    switch (this) {
      case LineItemBillingType.flatRate:
        return 'Flat Rate';
      case LineItemBillingType.hourly:
        return 'Hourly';
      case LineItemBillingType.product:
        return 'Product';
    }
  }

  IconData get icon {
    switch (this) {
      case LineItemBillingType.flatRate:
        return Icons.attach_money;
      case LineItemBillingType.hourly:
        return Icons.timer_outlined;
      case LineItemBillingType.product:
        return Icons.inventory_2_outlined;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showInvoiceSheet(BuildContext context, {required SideStack stack}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.of(context).card,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _InvoiceSheet(stack: stack),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _InvoiceSheet extends StatefulWidget {
  final SideStack stack;
  const _InvoiceSheet({required this.stack});

  @override
  State<_InvoiceSheet> createState() => _InvoiceSheetState();
}

class _InvoiceSheetState extends State<_InvoiceSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _businessCtrl;
  late TextEditingController _businessEmailCtrl;
  late TextEditingController _abnCtrl;
  late TextEditingController _clientCtrl;
  late TextEditingController _clientEmailCtrl;
  late TextEditingController _invoiceNumCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _paymentLinkCtrl;

  DateTime _issueDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  bool _includesGst = false;

  // Line items
  final List<_LineItemController> _items = [];
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final provider = context.read<AppProvider>();

    // Business name: prefer stack's trading name, fall back to user's full name
    final stackBusinessName = widget.stack.businessName;
    final senderName = stackBusinessName != null && stackBusinessName.isNotEmpty
        ? stackBusinessName
        : (auth.userName ?? widget.stack.name);
    _businessCtrl = TextEditingController(text: senderName);
    _businessEmailCtrl = TextEditingController(text: auth.userEmail ?? '');
    // Pre-fill ABN from provider profile if saved
    _abnCtrl = TextEditingController(text: provider.abn ?? '');
    // Pre-fill with top client if available
    final topClient = widget.stack.clientRevenue.isNotEmpty
        ? (widget.stack.clientRevenue.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key
        : '';
    _clientCtrl = TextEditingController(text: topClient);
    _clientEmailCtrl = TextEditingController();
    final now2 = DateTime.now();
    final month = now2.month.toString().padLeft(2, '0');
    final year = now2.year;
    // Auto-increment: total invoice count + 1 gives a unique sequence number
    final allInvoices = context.read<AppProvider>().allInvoices;
    final nextSeq = allInvoices.length + 1;
    _invoiceNumCtrl = TextEditingController(
        text: 'INV-$year$month-${nextSeq.toString().padLeft(3, '0')}');
    _notesCtrl = TextEditingController(
        text: 'Payment due within 30 days. Thank you for your business.');
    _paymentLinkCtrl = TextEditingController();

    // Pre-fill line items from this month's income transactions.
    // Infer billing type from hoursWorked: if hours recorded → Hourly, else Flat Rate.
    final now = DateTime.now();
    final monthTxs = widget.stack.transactions
        .where((t) =>
            t.type == TransactionType.income &&
            t.date.year == now.year &&
            t.date.month == now.month)
        .toList();

    if (monthTxs.isNotEmpty) {
      for (final tx in monthTxs.take(10)) {
        if (tx.hoursWorked != null && tx.hoursWorked! > 0) {
          // Hourly: derive rate from amount / hours
          final rate = tx.amount / tx.hoursWorked!;
          _items.add(_LineItemController.hourly(
            description: tx.category,
            rate: rate,
            hours: tx.hoursWorked!,
          ));
        } else {
          _items.add(_LineItemController.flatRate(
            description: tx.category,
            amount: tx.amount,
          ));
        }
      }
    } else {
      _items.add(_LineItemController.flatRate(description: '', amount: 0));
    }
  }

  @override
  void dispose() {
    _businessCtrl.dispose();
    _businessEmailCtrl.dispose();
    _abnCtrl.dispose();
    _clientCtrl.dispose();
    _clientEmailCtrl.dispose();
    _invoiceNumCtrl.dispose();
    _notesCtrl.dispose();
    _paymentLinkCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  double get _subtotal => _items.fold(0, (s, i) => s + i.lineTotal);

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) return;

    setState(() => _generating = true);
    try {
      final symbol = context.read<AppProvider>().currencySymbol;
      final data = InvoiceData(
        businessName: _businessCtrl.text.trim(),
        businessEmail: _businessEmailCtrl.text.trim().isEmpty
            ? null
            : _businessEmailCtrl.text.trim(),
        abn: _abnCtrl.text.trim().isEmpty ? null : _abnCtrl.text.trim(),
        clientName: _clientCtrl.text.trim(),
        clientEmail: _clientEmailCtrl.text.trim().isEmpty
            ? null
            : _clientEmailCtrl.text.trim(),
        invoiceNumber: _invoiceNumCtrl.text.trim(),
        issueDate: _issueDate,
        dueDate: _dueDate,
        currencySymbol: symbol,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        paymentLink: _paymentLinkCtrl.text.trim().isEmpty
            ? null
            : _paymentLinkCtrl.text.trim(),
        includesGst: _includesGst,
        items: _items
            .where((i) => i.descCtrl.text.trim().isNotEmpty && i.lineTotal > 0)
            .map((i) => i.toInvoiceLineItem(symbol))
            .toList(),
      );
      await shareInvoicePdf(data);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Hmm, something went wrong generating your invoice. Give it another try!',
              style: const TextStyle(fontFamily: 'Sora', fontSize: 13)),
          backgroundColor: AppTheme.of(context).card,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
    if (mounted) setState(() => _generating = false);
  }

  void _showPreview(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    final symbol = context.read<AppProvider>().currencySymbol;
    final validItems = _items
        .where((i) => i.descCtrl.text.trim().isNotEmpty && i.lineTotal > 0)
        .toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Add at least one line item before previewing.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InvoicePreviewSheet(
        businessName: _businessCtrl.text.trim(),
        businessEmail: _businessEmailCtrl.text.trim(),
        clientName: _clientCtrl.text.trim(),
        clientEmail: _clientEmailCtrl.text.trim(),
        invoiceNumber: _invoiceNumCtrl.text.trim(),
        issueDate: _issueDate,
        dueDate: _dueDate,
        notes: _notesCtrl.text.trim(),
        paymentLink: _paymentLinkCtrl.text.trim(),
        items: validItems,
        symbol: symbol,
        onConfirm: () {
          Navigator.pop(context);
          _generate();
        },
      ),
    );
  }

  Future<void> _pickDate(bool isDue) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isDue ? _dueDate : _issueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppTheme.accent,
            surface: AppTheme.of(ctx).card,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isDue) {
          _dueDate = picked;
        } else {
          _issueDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final symbol = context.read<AppProvider>().currencySymbol;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.97,
        expand: false,
        builder: (_, ctrl) => Form(
          key: _formKey,
          child: Column(children: [
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
                const Icon(Icons.receipt_long_outlined, size: 20, color: AppTheme.accent),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Generate Invoice',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                ),
                // Subtotal preview
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.accentDim,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$symbol${_subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accent,
                        fontFamily: 'Courier'),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _SectionLabel('From'),
                  _Field(
                      ctrl: _businessCtrl,
                      label: 'Business / Your name',
                      validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 8),
                  _Field(
                      ctrl: _businessEmailCtrl,
                      label: 'Your email (optional)',
                      keyboardType: TextInputType.emailAddress),
                  // ABN + GST toggle — AU users only
                  if (context.read<AppProvider>().isAustraliaMode) ...[
                    const SizedBox(height: 8),
                    _Field(
                      ctrl: _abnCtrl,
                      label: 'ABN (optional)',
                      hint: 'e.g. 12 345 678 901',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    // GST toggle
                    GestureDetector(
                      onTap: () => setState(() => _includesGst = !_includesGst),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: _includesGst
                              ? const Color(0xFF0F766E).withOpacity(0.10)
                              : AppTheme.of(context).surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _includesGst
                                ? const Color(0xFF0F766E)
                                : AppTheme.of(context).border,
                          ),
                        ),
                        child: Row(children: [
                          const Text('🇦🇺',
                              style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add GST (10%)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: _includesGst
                                        ? const Color(0xFF0F766E)
                                        : AppTheme.of(context).textSecondary,
                                  ),
                                ),
                                if (_includesGst)
                                  Text(
                                    'GST ${symbol}${(_subtotal * 0.10).toStringAsFixed(2)} · Total ${symbol}${(_subtotal * 1.10).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF0F766E)),
                                  ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _includesGst,
                            onChanged: (v) =>
                                setState(() => _includesGst = v),
                            activeColor: const Color(0xFF0F766E),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else
                    const SizedBox(height: 8),
                  _SectionLabel('To'),
                  _Field(
                      ctrl: _clientCtrl,
                      label: 'Client name',
                      validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 8),
                  _Field(
                      ctrl: _clientEmailCtrl,
                      label: 'Client email (optional)',
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  _SectionLabel('Details'),
                  _Field(ctrl: _invoiceNumCtrl, label: 'Invoice number'),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: _DateTile(
                            label: 'Issue date',
                            date: _issueDate,
                            onTap: () => _pickDate(false))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _DateTile(
                            label: 'Due date',
                            date: _dueDate,
                            onTap: () => _pickDate(true))),
                  ]),
                  const SizedBox(height: 16),
                  _SectionLabel('Line items'),
                  ..._items.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    return _LineItemRow(
                      ctrl: item,
                      symbol: symbol,
                      onDelete: _items.length > 1
                          ? () => setState(() => _items.removeAt(i))
                          : null,
                      onChanged: () => setState(() {}),
                      onTypeChanged: (t) => setState(() => item.type = t),
                    );
                  }),
                  // Add line item button
                  TextButton.icon(
                    onPressed: () => setState(() => _items.add(
                        _LineItemController.flatRate(
                            description: '', amount: 0))),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add line item',
                        style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                        foregroundColor: AppTheme.accent,
                        padding: EdgeInsets.zero),
                  ),
                  const SizedBox(height: 8),
                  // Total row
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.accentDim,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      const Text('Total',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text(
                        '$symbol${_subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Courier',
                            color: AppTheme.accent),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  _SectionLabel('Payment'),
                  _Field(
                    ctrl: _paymentLinkCtrl,
                    label: 'Payment link or bank details (optional)',
                    hint:
                        'paypal.me/yourname · stripe.com/pay/… · Sort code + account',
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Text(
                      'This will appear on the PDF so your client can pay immediately.',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.of(context).textMuted),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionLabel('Notes'),
                  _Field(
                    ctrl: _notesCtrl,
                    label: 'Additional notes',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _generating
                          ? null
                          : () => _showPreview(context),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('Preview & Send'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Line item controller ─────────────────────────────────────────────────────

class _LineItemController {
  LineItemBillingType type;
  final TextEditingController descCtrl;

  // Flat Rate — single amount field
  final TextEditingController amountCtrl;

  // Hourly — rate per hour + hours
  final TextEditingController rateCtrl;
  final TextEditingController hoursCtrl;

  // Product — unit price + quantity
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;

  _LineItemController.flatRate({
    required String description,
    required double amount,
  })  : type = LineItemBillingType.flatRate,
        descCtrl = TextEditingController(text: description),
        amountCtrl = TextEditingController(
            text: amount > 0 ? amount.toStringAsFixed(2) : ''),
        rateCtrl = TextEditingController(),
        hoursCtrl = TextEditingController(),
        qtyCtrl = TextEditingController(text: '1'),
        priceCtrl = TextEditingController();

  _LineItemController.hourly({
    required String description,
    required double rate,
    required double hours,
  })  : type = LineItemBillingType.hourly,
        descCtrl = TextEditingController(text: description),
        amountCtrl = TextEditingController(),
        rateCtrl = TextEditingController(
            text: rate > 0 ? rate.toStringAsFixed(2) : ''),
        hoursCtrl = TextEditingController(
            text: hours > 0 ? hours.toStringAsFixed(1) : ''),
        qtyCtrl = TextEditingController(text: '1'),
        priceCtrl = TextEditingController();

  _LineItemController.product({
    required String description,
    required double quantity,
    required double unitPrice,
  })  : type = LineItemBillingType.product,
        descCtrl = TextEditingController(text: description),
        amountCtrl = TextEditingController(),
        rateCtrl = TextEditingController(),
        hoursCtrl = TextEditingController(),
        qtyCtrl = TextEditingController(
            text: quantity % 1 == 0
                ? quantity.toInt().toString()
                : quantity.toString()),
        priceCtrl = TextEditingController(
            text: unitPrice > 0 ? unitPrice.toStringAsFixed(2) : '');

  double get lineTotal {
    switch (type) {
      case LineItemBillingType.flatRate:
        return double.tryParse(amountCtrl.text) ?? 0;
      case LineItemBillingType.hourly:
        final rate = double.tryParse(rateCtrl.text) ?? 0;
        final hours = double.tryParse(hoursCtrl.text) ?? 0;
        return rate * hours;
      case LineItemBillingType.product:
        final qty = double.tryParse(qtyCtrl.text) ?? 1;
        final price = double.tryParse(priceCtrl.text) ?? 0;
        return qty * price;
    }
  }

  /// Converts to InvoiceLineItem. The description is enriched with
  /// billing context so the PDF shows meaningful detail.
  InvoiceLineItem toInvoiceLineItem(String symbol) {
    final desc = descCtrl.text.trim();
    switch (type) {
      case LineItemBillingType.flatRate:
        final amount = double.tryParse(amountCtrl.text) ?? 0;
        return InvoiceLineItem(
          description: desc,
          quantity: 1,
          unitPrice: amount,
        );
      case LineItemBillingType.hourly:
        final rate = double.tryParse(rateCtrl.text) ?? 0;
        final hours = double.tryParse(hoursCtrl.text) ?? 0;
        final hLabel = hours % 1 == 0
            ? hours.toInt().toString()
            : hours.toStringAsFixed(1);
        return InvoiceLineItem(
          description: '$desc ($hLabel hrs @ $symbol${rate.toStringAsFixed(2)}/hr)',
          quantity: 1,
          unitPrice: rate * hours,
        );
      case LineItemBillingType.product:
        final qty = double.tryParse(qtyCtrl.text) ?? 1;
        final price = double.tryParse(priceCtrl.text) ?? 0;
        return InvoiceLineItem(
          description: desc,
          quantity: qty,
          unitPrice: price,
        );
    }
  }

  void dispose() {
    descCtrl.dispose();
    amountCtrl.dispose();
    rateCtrl.dispose();
    hoursCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

// ─── Line item row ────────────────────────────────────────────────────────────

class _LineItemRow extends StatelessWidget {
  final _LineItemController ctrl;
  final String symbol;
  final VoidCallback? onDelete;
  final VoidCallback onChanged;
  final ValueChanged<LineItemBillingType> onTypeChanged;

  const _LineItemRow({
    required this.ctrl,
    required this.symbol,
    required this.onDelete,
    required this.onChanged,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.of(context).cardAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.of(context).border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row: description + delete ──────────────────────────────────────
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: ctrl.descCtrl,
                onChanged: (_) => onChanged(),
                style: TextStyle(
                    fontSize: 12, color: AppTheme.of(context).textPrimary),
                decoration: InputDecoration(
                    hintText: 'Description',
                    hintStyle: TextStyle(
                        fontSize: 12, color: AppTheme.of(context).textMuted),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero),
              ),
            ),
            if (onDelete != null)
              GestureDetector(
                  onTap: onDelete,
                  child: Icon(Icons.close,
                      size: 16, color: AppTheme.of(context).textMuted)),
          ]),

          const SizedBox(height: 8),

          // ── Billing type selector ──────────────────────────────────────────
          Row(
            children: LineItemBillingType.values.map((t) {
              final isActive = ctrl.type == t;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => onTypeChanged(t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.accent.withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isActive
                            ? AppTheme.accent
                            : AppTheme.of(context).border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(t.icon,
                            size: 10,
                            color: isActive
                                ? AppTheme.accent
                                : AppTheme.of(context).textMuted),
                        const SizedBox(width: 4),
                        Text(
                          t.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isActive
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isActive
                                ? AppTheme.accent
                                : AppTheme.of(context).textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 8),

          // ── Fields based on billing type ───────────────────────────────────
          _buildFieldsForType(context),
        ],
      ),
    );
  }

  Widget _buildFieldsForType(BuildContext context) {
    switch (ctrl.type) {
      // ── Flat Rate ───────────────────────────────────────────────────────────
      case LineItemBillingType.flatRate:
        return Row(children: [
          Text(symbol,
              style: TextStyle(
                  fontSize: 12, color: AppTheme.of(context).textSecondary)),
          const SizedBox(width: 4),
          Expanded(
            child: TextFormField(
              controller: ctrl.amountCtrl,
              onChanged: (_) => onChanged(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                  fontSize: 12, color: AppTheme.of(context).textPrimary),
              decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(
                      fontSize: 12, color: AppTheme.of(context).textMuted),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero),
            ),
          ),
          Text(
            '= $symbol${ctrl.lineTotal.toStringAsFixed(2)}',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'Courier',
                color: AppTheme.accent),
          ),
        ]);

      // ── Hourly ──────────────────────────────────────────────────────────────
      case LineItemBillingType.hourly:
        return Row(children: [
          Text('$symbol',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.of(context).textSecondary)),
          const SizedBox(width: 2),
          SizedBox(
            width: 60,
            child: TextFormField(
              controller: ctrl.rateCtrl,
              onChanged: (_) => onChanged(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                  fontSize: 12, color: AppTheme.of(context).textPrimary),
              decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(
                      fontSize: 11, color: AppTheme.of(context).textMuted),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero),
            ),
          ),
          Text('/hr  ×  ',
              style: TextStyle(
                  fontSize: 11, color: AppTheme.of(context).textSecondary)),
          SizedBox(
            width: 44,
            child: TextFormField(
              controller: ctrl.hoursCtrl,
              onChanged: (_) => onChanged(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                  fontSize: 12, color: AppTheme.of(context).textPrimary),
              decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(
                      fontSize: 11, color: AppTheme.of(context).textMuted),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero),
            ),
          ),
          Text(' hrs',
              style: TextStyle(
                  fontSize: 11, color: AppTheme.of(context).textSecondary)),
          const Spacer(),
          Text(
            '= $symbol${ctrl.lineTotal.toStringAsFixed(2)}',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'Courier',
                color: AppTheme.accent),
          ),
        ]);

      // ── Product ─────────────────────────────────────────────────────────────
      case LineItemBillingType.product:
        return Row(children: [
          SizedBox(
            width: 44,
            child: TextFormField(
              controller: ctrl.qtyCtrl,
              onChanged: (_) => onChanged(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                  fontSize: 12, color: AppTheme.of(context).textPrimary),
              decoration: InputDecoration(
                  hintText: 'Qty',
                  hintStyle: TextStyle(
                      fontSize: 11, color: AppTheme.of(context).textMuted),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero),
            ),
          ),
          Text(' × ',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.of(context).textSecondary)),
          Expanded(
            child: TextFormField(
              controller: ctrl.priceCtrl,
              onChanged: (_) => onChanged(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                  fontSize: 12, color: AppTheme.of(context).textPrimary),
              decoration: InputDecoration(
                  prefixText: symbol,
                  prefixStyle: TextStyle(
                      fontSize: 12,
                      color: AppTheme.of(context).textSecondary),
                  hintText: '0.00',
                  hintStyle: TextStyle(
                      fontSize: 12, color: AppTheme.of(context).textMuted),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero),
            ),
          ),
          Text(
            '= $symbol${ctrl.lineTotal.toStringAsFixed(2)}',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'Courier',
                color: AppTheme.accent),
          ),
        ]);
    }
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.of(context).textMuted,
              letterSpacing: 0.8),
        ),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;

  const _Field({
    required this.ctrl,
    required this.label,
    this.hint,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: ctrl,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(
            fontSize: 13, color: AppTheme.of(context).textPrimary),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle:
              TextStyle(fontSize: 11, color: AppTheme.of(context).textMuted),
          labelStyle: TextStyle(
              fontSize: 12, color: AppTheme.of(context).textSecondary),
          filled: true,
          fillColor: AppTheme.of(context).cardAlt,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: AppTheme.of(context).border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: AppTheme.of(context).border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppTheme.accent, width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;
  const _DateTile(
      {required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.of(context).cardAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.of(context).border),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.of(context).textSecondary)),
                const SizedBox(height: 3),
                Text(
                    '${date.day}/${date.month}/${date.year}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
              ]),
        ),
      );
}

// ─── Invoice preview sheet ────────────────────────────────────────────────────

class _InvoicePreviewSheet extends StatelessWidget {
  final String businessName;
  final String businessEmail;
  final String clientName;
  final String clientEmail;
  final String invoiceNumber;
  final DateTime issueDate;
  final DateTime dueDate;
  final String notes;
  final String paymentLink;
  final List<_LineItemController> items;
  final String symbol;
  final VoidCallback onConfirm;

  const _InvoicePreviewSheet({
    required this.businessName,
    required this.businessEmail,
    required this.clientName,
    required this.clientEmail,
    required this.invoiceNumber,
    required this.issueDate,
    required this.dueDate,
    required this.notes,
    required this.paymentLink,
    required this.items,
    required this.symbol,
    required this.onConfirm,
  });

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} / '
      '${d.month.toString().padLeft(2, '0')} / '
      '${d.year}';

  @override
  Widget build(BuildContext context) {
    final subtotal = items.fold<double>(0, (s, i) => s + i.lineTotal);

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.98,
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
              width: 36, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 0),
              decoration: BoxDecoration(
                  color: AppTheme.of(context).border,
                  borderRadius: BorderRadius.circular(2)),
            ),

            // Header bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(children: [
                const Icon(Icons.description_outlined, size: 20, color: AppTheme.accent),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Invoice Preview',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.of(context).cardAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.of(context).border),
                  ),
                  child: Text('Client view',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.of(context).textMuted)),
                ),
              ]),
            ),

            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  // ── Invoice paper ────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Top row: brand + INVOICE label ──────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    businessName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF111217),
                                    ),
                                  ),
                                  if (businessEmail.isNotEmpty)
                                    Text(businessEmail,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF6B7280))),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('INVOICE',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2,
                                      color: Color(0xFF6C6FFF),
                                    )),
                                Text(invoiceNumber,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6B7280))),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),
                        Container(height: 1, color: const Color(0xFFE5E7EB)),
                        const SizedBox(height: 16),

                        // ── Dates row ────────────────────────────────────
                        Row(children: [
                          _PreviewMetaCell(
                              label: 'Issue Date', value: _fmt(issueDate)),
                          const SizedBox(width: 24),
                          _PreviewMetaCell(
                              label: 'Due Date', value: _fmt(dueDate)),
                        ]),

                        const SizedBox(height: 16),

                        // ── Bill To ──────────────────────────────────────
                        const Text('BILL TO',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: Color(0xFF9CA3AF),
                            )),
                        const SizedBox(height: 4),
                        Text(clientName,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111217))),
                        if (clientEmail.isNotEmpty)
                          Text(clientEmail,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6B7280))),

                        const SizedBox(height: 16),
                        Container(height: 1, color: const Color(0xFFE5E7EB)),
                        const SizedBox(height: 12),

                        // ── Line items header ────────────────────────────
                        Row(children: const [
                          Expanded(
                              child: Text('DESCRIPTION',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1,
                                      color: Color(0xFF9CA3AF)))),
                          SizedBox(width: 8),
                          Text('DETAIL',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                  color: Color(0xFF9CA3AF))),
                          SizedBox(width: 16),
                          Text('AMOUNT',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                  color: Color(0xFF9CA3AF))),
                        ]),
                        const SizedBox(height: 8),

                        // ── Line items ───────────────────────────────────
                        ...items.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(children: [
                                Expanded(
                                  child: Text(
                                    item.descCtrl.text.trim().isEmpty
                                        ? '—'
                                        : item.descCtrl.text.trim(),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF111217)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _itemDetail(item),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF6B7280)),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  '$symbol${item.lineTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111217),
                                      fontFamily: 'Courier'),
                                ),
                              ]),
                            )),

                        const SizedBox(height: 8),
                        Container(height: 1, color: const Color(0xFFE5E7EB)),
                        const SizedBox(height: 10),

                        // ── Total ────────────────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text('TOTAL DUE',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF374151))),
                            const SizedBox(width: 20),
                            Text(
                              '$symbol${subtotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF6C6FFF),
                                fontFamily: 'Courier',
                              ),
                            ),
                          ],
                        ),

                        // ── Payment link ─────────────────────────────────
                        if (paymentLink.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F9FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFF93C5FD)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.link,
                                  size: 14, color: Color(0xFF3B82F6)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  paymentLink,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF3B82F6),
                                      fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ]),
                          ),
                        ],

                        // ── Notes ────────────────────────────────────────
                        if (notes.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(height: 1, color: const Color(0xFFE5E7EB)),
                          const SizedBox(height: 10),
                          const Text('NOTES',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: Color(0xFF9CA3AF),
                              )),
                          const SizedBox(height: 4),
                          Text(notes,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6B7280),
                                  height: 1.5)),
                        ],

                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            'Generated with SideStacks',
                            style: TextStyle(
                                fontSize: 9, color: const Color(0xFFD1D5DB)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Action buttons ───────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onConfirm,
                      icon: const Icon(Icons.picture_as_pdf_outlined,
                          size: 18),
                      label: const Text('Generate PDF & Share'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: AppTheme.of(context).border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Edit Invoice',
                          style: TextStyle(
                              color: AppTheme.of(context).textSecondary)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _itemDetail(_LineItemController item) {
    switch (item.type) {
      case LineItemBillingType.hourly:
        final h = double.tryParse(item.hoursCtrl.text) ?? 0;
        final r = double.tryParse(item.rateCtrl.text) ?? 0;
        return '${h.toStringAsFixed(1)} hrs × $symbol${r.toStringAsFixed(2)}';
      case LineItemBillingType.product:
        final q = double.tryParse(item.qtyCtrl.text) ?? 0;
        final p = double.tryParse(item.priceCtrl.text) ?? 0;
        return '${q.toInt()} × $symbol${p.toStringAsFixed(2)}';
      case LineItemBillingType.flatRate:
        return 'Flat rate';
    }
  }
}

class _PreviewMetaCell extends StatelessWidget {
  final String label;
  final String value;
  const _PreviewMetaCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: Color(0xFF9CA3AF))),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111217))),
        ],
      );
}
