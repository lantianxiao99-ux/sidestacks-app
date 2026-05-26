import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'shared_widgets.dart';
import 'transaction_confirmation.dart';

const _txUuid = Uuid();

const _incomeCategories = [
  'Sales',
  'Freelance',
  'Consulting',
  'Content / Creator',
  'Commission',
  'Other',
];

const _expenseCategories = [
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
  'Other',
];

/// Expense categories that qualify as tax deductions.
/// Displayed with a green "Tax deductible" badge in the category picker.
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

/// Show sheet to add a brand-new transaction.
Future<void> showAddTransactionSheet(
  BuildContext context, {
  String? preselectedStackId,
  TransactionType? initialType,
  bool lockType = false,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => AddTransactionSheet(
        preselectedStackId: preselectedStackId,
        initialType: initialType,
        lockType: lockType,
      ),
    ),
  );
}

/// Show sheet pre-filled with [tx] so the user can edit it.
Future<void> showEditTransactionSheet(
  BuildContext context, {
  required Transaction tx,
  required String stackId,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => AddTransactionSheet(
        preselectedStackId: stackId,
        existingTx: tx,
      ),
    ),
  );
}

class AddTransactionSheet extends StatefulWidget {
  final String? preselectedStackId;
  final Transaction? existingTx;
  final TransactionType? initialType;
  /// When true, the income/expense toggle is hidden and type is fixed.
  final bool lockType;
  const AddTransactionSheet({super.key, this.preselectedStackId, this.existingTx, this.initialType, this.lockType = false});

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  late TransactionType _type;
  late String _category;
  late String? _stackId;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  late final TextEditingController _clientController;
  late final TextEditingController _hoursController;
  late DateTime _date;
  late bool _isRecurring;
  RecurrenceInterval? _recurrenceInterval;

  // Photo receipt
  File? _receiptFile;
  String? _existingReceiptUrl;
  bool _uploadingReceipt = false;

  // Receipt OCR scanning
  bool _scanning = false;

  // GST (Australian)
  bool _includesGst = false;

  // Custom category
  bool _isCustomCategory = false;
  late final TextEditingController _customCategoryController;
  final FocusNode _customCategoryFocusNode = FocusNode();

  bool get _isEditing => widget.existingTx != null;
  bool get _isIncome => _type == TransactionType.income;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingTx;
    _type = existing?.type ?? widget.initialType ?? TransactionType.income;
    _date = existing?.date ?? DateTime.now();
    _amountController = TextEditingController(
      text: existing != null ? existing.amount.toStringAsFixed(2) : '',
    );
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _clientController = TextEditingController(text: existing?.clientName ?? '');
    _hoursController = TextEditingController(
      text: existing?.hoursWorked != null
          ? existing!.hoursWorked!.toStringAsFixed(1)
          : '',
    );
    _existingReceiptUrl = existing?.receiptUrl;
    if (existing != null) {
      _category = existing.category;
      // Detect whether the saved category is a custom one
      final presetList = existing.type == TransactionType.income
          ? _incomeCategories
          : _expenseCategories;
      if (!presetList.contains(_category)) {
        _isCustomCategory = true;
        _customCategoryController = TextEditingController(text: _category);
      } else {
        _customCategoryController = TextEditingController();
      }
    } else {
      _category = _type == TransactionType.income ? 'Sales' : 'Marketing';
      _customCategoryController = TextEditingController();
    }
    _isRecurring = existing?.isRecurring ?? false;
    _recurrenceInterval = existing?.recurrenceInterval;
    _includesGst = existing?.includesGst ?? false;
    final stacks = context.read<AppProvider>().stacks;
    _stackId = widget.preselectedStackId ?? stacks.first.id;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _clientController.dispose();
    _hoursController.dispose();
    _customCategoryController.dispose();
    _customCategoryFocusNode.dispose();
    super.dispose();
  }

  List<String> get _categories =>
      _isIncome ? _incomeCategories : _expenseCategories;

  // ── Receipt OCR ──────────────────────────────────────────────────────────────

  Future<void> _scanReceipt() async {
    HapticFeedback.lightImpact();
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: AppTheme.of(context).surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.of(context).border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: AppTheme.of(context).border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('Attach receipt',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Photo will be saved with this transaction.',
                style: TextStyle(fontSize: 13, color: AppTheme.of(context).textSecondary)),
            const SizedBox(height: 20),
            _ReceiptSourceButton(
              icon: Icons.camera_alt_outlined,
              label: 'Take a photo',
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 10),
            _ReceiptSourceButton(
              icon: Icons.photo_library_outlined,
              label: 'Choose from library',
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    setState(() => _scanning = true);
    try {
      final XFile? file = await picker.pickImage(source: source, imageQuality: 80);
      if (file == null) return;
      setState(() => _receiptFile = File(file.path));
      if (mounted) AppToast.show(context, 'Receipt attached. Fill in the amount manually.');
    } catch (e) {
      if (mounted) AppToast.error(context, 'Could not attach receipt.');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _setType(TransactionType t) {
    HapticFeedback.selectionClick();
    setState(() {
      _type = t;
      if (!_isEditing) {
        _category = t == TransactionType.income ? 'Sales' : 'Marketing';
        _isCustomCategory = false;
        _customCategoryController.clear();
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickReceipt() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.of(context).surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.of(context).borderLight),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: AppTheme.accent),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: AppTheme.accent),
              title: const Text('Photo Library'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            if (_receiptFile != null || _existingReceiptUrl != null)
              ListTile(
                leading: Icon(Icons.delete_outline, color: AppTheme.red),
                title: Text('Remove receipt',
                    style: TextStyle(color: AppTheme.red)),
                onTap: () {
                  setState(() {
                    _receiptFile = null;
                    _existingReceiptUrl = null;
                  });
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: source, maxWidth: 1200, imageQuality: 80);
    if (picked != null) setState(() => _receiptFile = File(picked.path));
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0 || _stackId == null) return;
    final provider = context.read<AppProvider>();
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();
    // Resolve the actual category: prefer custom text when in custom mode
    final resolvedCategory = _isCustomCategory &&
            _customCategoryController.text.trim().isNotEmpty
        ? _customCategoryController.text.trim()
        : _category;
    final clientName = _clientController.text.trim().isEmpty
        ? null
        : _clientController.text.trim();
    final hoursWorked = double.tryParse(_hoursController.text);

    // Pre-generate the transaction ID so the receipt is uploaded under the
    // same key that will be used when the transaction is saved. This prevents
    // stranded Storage files if the transaction save subsequently fails.
    final newTxId = _isEditing ? widget.existingTx!.id : _txUuid.v4();

    // Upload receipt if a new file was picked
    String? receiptUrl = _existingReceiptUrl;
    if (_receiptFile != null) {
      setState(() => _uploadingReceipt = true);
      receiptUrl =
          await provider.uploadReceipt(_stackId!, newTxId, _receiptFile!);
      if (mounted) setState(() => _uploadingReceipt = false);
    }

    if (_isEditing) {
      provider.updateTransaction(
        stackId: _stackId!,
        txId: newTxId,
        type: _type,
        amount: amount,
        date: _date,
        category: resolvedCategory,
        notes: notes,
        isRecurring: _isRecurring,
        recurrenceInterval: _isRecurring ? _recurrenceInterval : null,
        clientName: clientName,
        hoursWorked: _isIncome ? hoursWorked : null,
        receiptUrl: receiptUrl,
        includesGst: _includesGst,
      );
      if (mounted) Navigator.pop(context);
    } else {
      provider.addTransaction(
        stackId: _stackId!,
        type: _type,
        amount: amount,
        date: _date,
        category: resolvedCategory,
        notes: notes,
        isRecurring: _isRecurring,
        recurrenceInterval: _isRecurring ? _recurrenceInterval : null,
        clientName: clientName,
        hoursWorked: _isIncome ? hoursWorked : null,
        receiptUrl: receiptUrl,
        pregenId: newTxId,
        includesGst: _includesGst,
      );
      // Haptic + confirmation overlay before dismissing the sheet
      if (mounted) {
        HapticFeedback.lightImpact();
        await showTransactionConfirmation(
          context,
          isIncome: _isIncome,
          amount: amount,
          symbol: provider.currencySymbol,
        );
        if (mounted) Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stacks = context.watch<AppProvider>().stacks;
    final symbol = context.watch<AppProvider>().currencySymbol;
    final actionColor = _isIncome ? AppTheme.green : AppTheme.expense;
    final padding = MediaQuery.of(context).viewInsets.bottom;
    final hasReceipt = _receiptFile != null || _existingReceiptUrl != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + padding),
      decoration: BoxDecoration(
        color: AppTheme.of(context).surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.of(context).borderLight),
      ),
      child: SingleChildScrollView(
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

            Builder(builder: (context) {
              final stacks = context.read<AppProvider>().stacks;
              final stack = _stackId != null
                  ? stacks.firstWhere((s) => s.id == _stackId,
                      orElse: () => stacks.first)
                  : null;
              final isSavings = stack?.stackType == StackType.savings;
              String title = _isEditing ? 'Edit Transaction' : 'Quick Add';
              if (!_isEditing && isSavings) title = 'Add Deposit';
              return Text(title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600));
            }),
            const SizedBox(height: 16),

            // Income / Expense toggle — hidden when type is locked
            if (!widget.lockType) ...[
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppTheme.of(context).card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.of(context).border),
                ),
                child: Row(
                  children: [
                    _TypeToggle(
                      label: 'Income',
                      active: _isIncome,
                      activeColor: AppTheme.green,
                      textColor: Colors.white,
                      onTap: () => _setType(TransactionType.income),
                    ),
                    _TypeToggle(
                      label: 'Expense',
                      active: !_isIncome,
                      activeColor: AppTheme.expense,
                      textColor: Colors.white,
                      onTap: () => _setType(TransactionType.expense),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Stack selector
            if (!_isEditing && stacks.length > 1) ...[
              _FieldLabel('SideStack'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppTheme.of(context).card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.of(context).border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _stackId,
                    isExpanded: true,
                    dropdownColor: AppTheme.of(context).card,
                    style: TextStyle(
                      fontFamily: 'Sora', fontSize: 13,
                      color: AppTheme.of(context).textPrimary,
                    ),
                    items: stacks
                        .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _stackId = v),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Amount
            Row(
              children: [
                _FieldLabel('Amount'),
                const Spacer(),
                if (_scanning)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.accent),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: _scanReceipt,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.document_scanner_outlined,
                            size: 14, color: AppTheme.accent),
                        const SizedBox(width: 4),
                        Text('Scan receipt',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accent)),
                      ]),
                    ),
                  ),
              ],
            ),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppTheme.of(context).textPrimary,
              ),
              decoration: InputDecoration(
                prefixText: '$symbol  ',
                prefixStyle: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.of(context).textMuted,
                ),
                hintText: '0.00',
              ),
              inputFormatters: [LengthLimitingTextInputFormatter(12)],
              autofocus: !_isEditing,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),

            // Date
            _FieldLabel('Date'),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.of(context).card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.of(context).border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 14, color: AppTheme.of(context).textMuted),
                    const SizedBox(width: 10),
                    Text(
                      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.of(context).textPrimary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Category
            _FieldLabel('Category'),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _categories.map((c) {
                final isOtherChip = c == 'Other';
                final isSelected = isOtherChip
                    ? _isCustomCategory
                    : (!_isCustomCategory && _category == c);
                final isDeductible =
                    !_isIncome && _kTaxDeductibleExpenses.contains(c);
                return _TaxCategoryChip(
                  label: c,
                  selected: isSelected,
                  isDeductible: isDeductible,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      if (isOtherChip) {
                        _isCustomCategory = true;
                        _category = 'Other';
                      } else {
                        _isCustomCategory = false;
                        _customCategoryController.clear();
                        _category = c;
                      }
                    });
                    if (isOtherChip) {
                      WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _customCategoryFocusNode.requestFocus());
                    }
                  },
                );
              }).toList(),
            ),
            // Deductible hint shown when a deductible category is selected
            if (!_isIncome &&
                !_isCustomCategory &&
                _kTaxDeductibleExpenses.contains(_category)) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 12, color: AppTheme.green),
                  const SizedBox(width: 4),
                  Text(
                    '$_category is a recognised tax-deductible expense',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.green),
                  ),
                ],
              ),
            ],
            // Custom category text field — shown when 'Other' is selected
            if (_isCustomCategory) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _customCategoryController,
                focusNode: _customCategoryFocusNode,
                style: TextStyle(
                    fontSize: 13, color: AppTheme.of(context).textPrimary),
                decoration: InputDecoration(
                  hintText: 'Type your category…',
                  prefixIcon: Icon(Icons.edit_outlined,
                      size: 16, color: AppTheme.of(context).textMuted),
                ),
                inputFormatters: [LengthLimitingTextInputFormatter(50)],
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 14),

            // Client name (income only) — with autocomplete from existing clients
            if (_isIncome) ...[
              _FieldLabel('Client (optional)'),
              Builder(builder: (ctx) {
                final provider = context.read<AppProvider>();
                // Gather all distinct client names from all stacks
                final knownClients = <String>{};
                for (final stack in provider.allStacks) {
                  knownClients.addAll(stack.clientRevenue.keys);
                }
                final clientList = knownClients.toList()..sort();
                return Autocomplete<String>(
                  initialValue: TextEditingValue(
                      text: _clientController.text),
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) return const [];
                    return clientList.where((c) => c
                        .toLowerCase()
                        .contains(
                            textEditingValue.text.toLowerCase()));
                  },
                  onSelected: (String selected) {
                    _clientController.text = selected;
                  },
                  fieldViewBuilder:
                      (ctx, controller, focusNode, onFieldSubmitted) {
                    // Sync our controller with the autocomplete's internal one
                    controller.text = _clientController.text;
                    controller.addListener(() {
                      _clientController.text = controller.text;
                    });
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.of(context).textPrimary),
                      decoration: const InputDecoration(
                          hintText: 'e.g. Acme Corp'),
                      inputFormatters: [LengthLimitingTextInputFormatter(100)],
                    );
                  },
                  optionsViewBuilder: (ctx, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        color: AppTheme.of(context).card,
                        borderRadius: BorderRadius.circular(12),
                        elevation: 4,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                              maxHeight: 160, maxWidth: 280),
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                vertical: 4),
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (ctx, i) {
                              final opt = options.elementAt(i);
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.people_outline,
                                    size: 18, color: AppTheme.accent),
                                title: Text(opt,
                                    style: const TextStyle(fontSize: 13)),
                                onTap: () => onSelected(opt),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
              const SizedBox(height: 14),

              // Hours worked (income only)
              _FieldLabel('Hours worked (optional)'),
              TextField(
                controller: _hoursController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                    fontSize: 13, color: AppTheme.of(context).textPrimary),
                decoration: InputDecoration(
                  hintText: '0.0',
                  suffixText: 'hrs',
                  suffixStyle: TextStyle(
                      fontSize: 11,
                      color: AppTheme.of(context).textMuted),
                ),
                inputFormatters: [LengthLimitingTextInputFormatter(6)],
              ),
              const SizedBox(height: 14),
            ],

            // Notes
            TextField(
              controller: _notesController,
              style: TextStyle(
                  fontSize: 13, color: AppTheme.of(context).textPrimary),
              decoration: const InputDecoration(hintText: 'Notes (optional)'),
              inputFormatters: [LengthLimitingTextInputFormatter(500)],
            ),
            const SizedBox(height: 14),

            // Receipt photo row
            GestureDetector(
              onTap: _pickReceipt,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: hasReceipt
                      ? AppTheme.accent.withOpacity(0.08)
                      : AppTheme.of(context).card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: hasReceipt
                        ? AppTheme.accent
                        : AppTheme.of(context).border,
                  ),
                ),
                child: Row(children: [
                  // Thumbnail or icon
                  if (_receiptFile != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(_receiptFile!,
                          width: 36, height: 36, fit: BoxFit.cover),
                    )
                  else if (_existingReceiptUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(_existingReceiptUrl!,
                          width: 36, height: 36, fit: BoxFit.cover),
                    )
                  else
                    Icon(Icons.receipt_long_outlined,
                        size: 18,
                        color: AppTheme.of(context).textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      hasReceipt ? 'Receipt attached' : 'Attach receipt photo',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: hasReceipt
                            ? AppTheme.accent
                            : AppTheme.of(context).textSecondary,
                      ),
                    ),
                  ),
                  Icon(
                    hasReceipt
                        ? Icons.check_circle_outline
                        : Icons.add_circle_outline,
                    size: 16,
                    color: hasReceipt
                        ? AppTheme.accent
                        : AppTheme.of(context).textMuted,
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 14),

            // Recurring toggle
            GestureDetector(
              onTap: () => setState(() {
                _isRecurring = !_isRecurring;
                if (_isRecurring && _recurrenceInterval == null) {
                  _recurrenceInterval = RecurrenceInterval.monthly;
                }
              }),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _isRecurring
                      ? AppTheme.accentDim
                      : AppTheme.of(context).card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isRecurring
                        ? AppTheme.accent
                        : AppTheme.of(context).border,
                  ),
                ),
                child: Row(children: [
                  Icon(Icons.repeat,
                      size: 16,
                      color: _isRecurring
                          ? AppTheme.accent
                          : AppTheme.of(context).textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Recurring transaction',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _isRecurring
                            ? AppTheme.accent
                            : AppTheme.of(context).textSecondary,
                      ),
                    ),
                  ),
                  if (_isRecurring) ...[
                    GestureDetector(
                      onTap: () => setState(() {
                        _recurrenceInterval =
                            _recurrenceInterval == RecurrenceInterval.monthly
                                ? RecurrenceInterval.weekly
                                : RecurrenceInterval.monthly;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _recurrenceInterval?.label ?? 'Monthly',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ] else ...[
                    Icon(Icons.add_circle_outline,
                        size: 16, color: AppTheme.of(context).textMuted),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: 10),

            // GST toggle — Australian users only
            if (context.watch<AppProvider>().isAustraliaMode) ...[
              GestureDetector(
                onTap: () => setState(() => _includesGst = !_includesGst),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _includesGst
                        ? const Color(0xFF0F766E).withOpacity(0.10)
                        : AppTheme.of(context).card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _includesGst
                          ? const Color(0xFF0F766E)
                          : AppTheme.of(context).border,
                    ),
                  ),
                  child: Row(children: [
                    const Text('🇦🇺',
                        style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Includes GST (10%)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _includesGst
                                  ? const Color(0xFF0F766E)
                                  : AppTheme.of(context).textSecondary,
                            ),
                          ),
                          if (_includesGst) ...[
                            const SizedBox(height: 2),
                            Builder(builder: (ctx) {
                              final amt = double.tryParse(
                                  _amountController.text) ?? 0;
                              final sym = context
                                  .read<AppProvider>()
                                  .currencySymbol;
                              final gst = amt / 11;
                              return Text(
                                'GST: $sym${gst.toStringAsFixed(2)}  ·  Ex-GST: $sym${(amt - gst).toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF0F766E)),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                    Switch(
                      value: _includesGst,
                      onChanged: (v) => setState(() => _includesGst = v),
                      activeColor: const Color(0xFF0F766E),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
            ] else
              const SizedBox(height: 16),

            // Submit
            _uploadingReceipt
                ? Center(
                    child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(color: AppTheme.accent),
                  ))
                : PrimaryButton(
                    label: _isEditing
                        ? 'Save Changes'
                        : (_isIncome ? 'Add Income' : 'Add Expense'),
                    color: actionColor,
                    textColor: Colors.white,
                    onPressed:
                        _amountController.text.isEmpty ? null : _submit,
                  ),
          ],
        ),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final Color textColor;
  final VoidCallback onTap;

  const _TypeToggle({
    required this.label, required this.active,
    required this.activeColor, required this.textColor, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: active
                    ? textColor
                    : AppTheme.of(context).textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w500,
            color: AppTheme.of(context).textMuted,
          ),
        ),
      );
}

/// A category chip that optionally shows a small green "Tax deductible" badge.
class _TaxCategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDeductible;
  final VoidCallback onTap;

  const _TaxCategoryChip({
    required this.label,
    required this.selected,
    required this.isDeductible,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColor = AppTheme.accent;
    final bg = selected
        ? selectedColor.withOpacity(0.15)
        : AppTheme.of(context).card;
    final border = selected ? selectedColor : AppTheme.of(context).border;
    final textColor =
        selected ? selectedColor : AppTheme.of(context).textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w500,
                color: textColor,
              ),
            ),
            if (isDeductible) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.savings_outlined,
                      size: 9, color: AppTheme.green),
                  const SizedBox(width: 2),
                  Text(
                    'Tax deductible',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.green),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Receipt source picker button ────────────────────────────────────────────

class _ReceiptSourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ReceiptSourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = AppTheme.of(context).card;
    final border = AppTheme.of(context).border;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.accent),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
