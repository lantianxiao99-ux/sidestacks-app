import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'shared_widgets.dart';

Future<void> showEditStackSheet(
  BuildContext context, {
  required SideStack stack,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => EditStackSheet(stack: stack),
  );
}

class EditStackSheet extends StatefulWidget {
  final SideStack stack;
  const EditStackSheet({super.key, required this.stack});

  @override
  State<EditStackSheet> createState() => _EditStackSheetState();
}

class _EditStackSheetState extends State<EditStackSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _businessNameController;
  late final TextEditingController _descController;
  late final TextEditingController _monthlyGoalController;
  late final TextEditingController _goalController;
  late final TextEditingController _monthlyBudgetController;
  late final TextEditingController _savingsTargetController;
  late HustleType _hustleType;
  late bool _isPersonal;

  StackType get _stackType => widget.stack.stackType;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.stack.name);
    _businessNameController =
        TextEditingController(text: widget.stack.businessName ?? '');
    _descController =
        TextEditingController(text: widget.stack.description ?? '');
    _monthlyGoalController = TextEditingController(
      text: widget.stack.monthlyGoalAmount != null
          ? widget.stack.monthlyGoalAmount!.toStringAsFixed(0)
          : '',
    );
    _goalController = TextEditingController(
      text: widget.stack.goalAmount != null
          ? widget.stack.goalAmount!.toStringAsFixed(0)
          : '',
    );
    _monthlyBudgetController = TextEditingController(
      text: widget.stack.monthlyBudget != null
          ? widget.stack.monthlyBudget!.toStringAsFixed(0)
          : '',
    );
    _savingsTargetController = TextEditingController(
      text: widget.stack.savingsTarget != null
          ? widget.stack.savingsTarget!.toStringAsFixed(0)
          : '',
    );
    _hustleType = widget.stack.hustleType;
    _isPersonal = widget.stack.isPersonal;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _businessNameController.dispose();
    _descController.dispose();
    _monthlyGoalController.dispose();
    _goalController.dispose();
    _monthlyBudgetController.dispose();
    _savingsTargetController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final desc = _descController.text.trim().isEmpty
        ? null
        : _descController.text.trim();

    if (_stackType == StackType.salary) {
      // Salary: name + employer (description) + monthly net pay stored in monthlyGoalAmount
      final payText = _monthlyGoalController.text.trim();
      final monthlyPay = payText.isEmpty ? null : double.tryParse(payText);
      final clearPay = payText.isEmpty && widget.stack.monthlyGoalAmount != null;
      context.read<AppProvider>().updateSideStack(
        widget.stack.id,
        name: name,
        description: desc,
        monthlyGoalAmount: monthlyPay,
        clearMonthlyGoal: clearPay,
      );
    } else if (_stackType == StackType.budget) {
      final budgetText = _monthlyBudgetController.text.trim();
      final monthlyBudget =
          budgetText.isEmpty ? null : double.tryParse(budgetText);
      final clearMonthlyBudget =
          budgetText.isEmpty && widget.stack.monthlyBudget != null;
      context.read<AppProvider>().updateSideStack(
        widget.stack.id,
        name: name,
        description: desc,
        monthlyBudget: monthlyBudget,
        clearMonthlyBudget: clearMonthlyBudget,
        isPersonal: _isPersonal,
      );
    } else if (_stackType == StackType.savings) {
      final targetText = _savingsTargetController.text.trim();
      final savingsTarget =
          targetText.isEmpty ? null : double.tryParse(targetText);
      final clearSavingsTarget =
          targetText.isEmpty && widget.stack.savingsTarget != null;
      context.read<AppProvider>().updateSideStack(
        widget.stack.id,
        name: name,
        description: desc,
        savingsTarget: savingsTarget,
        clearSavingsTarget: clearSavingsTarget,
        isPersonal: _isPersonal,
      );
    } else {
      // income
      final monthlyGoalText = _monthlyGoalController.text.trim();
      final monthlyGoalAmount =
          monthlyGoalText.isEmpty ? null : double.tryParse(monthlyGoalText);
      final clearMonthlyGoal =
          monthlyGoalText.isEmpty && widget.stack.monthlyGoalAmount != null;
      final goalText = _goalController.text.trim();
      final goalAmount =
          goalText.isEmpty ? null : double.tryParse(goalText);
      final clearGoal =
          goalText.isEmpty && widget.stack.goalAmount != null;
      final businessNameText = _businessNameController.text.trim();
      final businessName = businessNameText.isEmpty ? null : businessNameText;
      final clearBusinessName =
          businessNameText.isEmpty && widget.stack.businessName != null;
      context.read<AppProvider>().updateSideStack(
        widget.stack.id,
        name: name,
        businessName: businessName,
        clearBusinessName: clearBusinessName,
        description: desc,
        hustleType: _hustleType,
        goalAmount: goalAmount,
        clearGoal: clearGoal,
        monthlyGoalAmount: monthlyGoalAmount,
        clearMonthlyGoal: clearMonthlyGoal,
      );
    }
    Navigator.pop(context);
  }

  String get _sheetTitle {
    switch (_stackType) {
      case StackType.budget:
        return 'Edit Budget';
      case StackType.savings:
        return 'Edit Savings Goal';
      case StackType.income:
        return 'Edit Stack';
      case StackType.salary:
        return 'Edit Salary';
    }
  }

  @override
  Widget build(BuildContext context) {
    final symbol = context.watch<AppProvider>().currencySymbol;
    final padding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + padding),
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

          // Title with stack type badge
          Row(
            children: [
              Text(
                _sheetTitle,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _stackType.color(context).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_stackType.icon,
                        size: 10, color: _stackType.color(context)),
                    const SizedBox(width: 4),
                    Text(
                      _stackType.label,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _stackType.color(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Name
          _FieldLabel('Name'),
          TextField(
            controller: _nameController,
            autofocus: true,
            style: TextStyle(
                fontSize: 14, color: AppTheme.of(context).textPrimary),
            decoration: InputDecoration(
              hintText: _stackType == StackType.budget
                  ? 'e.g. Groceries'
                  : _stackType == StackType.savings
                      ? 'e.g. Emergency Fund'
                      : 'e.g. Etsy Shop',
            ),
            inputFormatters: [LengthLimitingTextInputFormatter(60)],
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),

          // Description
          _FieldLabel('Description (optional)'),
          TextField(
            controller: _descController,
            style: TextStyle(
                fontSize: 13, color: AppTheme.of(context).textPrimary),
            decoration: InputDecoration(
              hintText: _stackType == StackType.budget
                  ? 'What does this budget cover?'
                  : _stackType == StackType.savings
                      ? 'What are you saving for?'
                      : 'What is this hustle about?',
            ),
            inputFormatters: [LengthLimitingTextInputFormatter(300)],
          ),
          const SizedBox(height: 14),

          // ── Income-specific fields ──────────────────────────────────────
          if (_stackType == StackType.income) ...[
            // Business name
            _FieldLabel('Business name (optional)'),
            TextField(
              controller: _businessNameController,
              style: TextStyle(
                  fontSize: 14, color: AppTheme.of(context).textPrimary),
              decoration: const InputDecoration(
                  hintText: 'e.g. Dawes Creative Studio'),
              textCapitalization: TextCapitalization.words,
              inputFormatters: [LengthLimitingTextInputFormatter(100)],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Shown on invoices and exports instead of your name',
                style: TextStyle(
                    fontSize: 11, color: AppTheme.of(context).textMuted),
              ),
            ),
            const SizedBox(height: 14),

            // Hustle type
            _FieldLabel('Type'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: HustleType.values
                  .map((t) => GestureDetector(
                        onTap: () => setState(() => _hustleType = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _hustleType == t
                                ? AppTheme.accentDim
                                : AppTheme.of(context).card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _hustleType == t
                                  ? AppTheme.accent
                                  : AppTheme.of(context).border,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(t.icon,
                                  size: 11,
                                  color: _hustleType == t
                                      ? AppTheme.accent
                                      : AppTheme.of(context).textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                t.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _hustleType == t
                                      ? AppTheme.accent
                                      : AppTheme.of(context).textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 14),

            // Monthly income goal
            _FieldLabel('Monthly Income Goal (optional)'),
            TextField(
              controller: _monthlyGoalController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.of(context).textPrimary,
              ),
              decoration: InputDecoration(
                prefixText: '$symbol  ',
                prefixStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.of(context).textMuted,
                ),
                hintText: '0',
                helperText: 'Tracks your progress each month',
                helperStyle: TextStyle(
                    fontSize: 11, color: AppTheme.of(context).textMuted),
              ),
              inputFormatters: [LengthLimitingTextInputFormatter(12)],
            ),
            const SizedBox(height: 14),

            // All-time revenue goal
            _FieldLabel('All-time Revenue Goal (optional)'),
            TextField(
              controller: _goalController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.of(context).textPrimary,
              ),
              decoration: InputDecoration(
                prefixText: '$symbol  ',
                prefixStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.of(context).textMuted,
                ),
                hintText: '0',
                helperText: 'e.g. a savings milestone or total income target',
                helperStyle: TextStyle(
                    fontSize: 11, color: AppTheme.of(context).textMuted),
              ),
              inputFormatters: [LengthLimitingTextInputFormatter(12)],
            ),
          ],

          // ── Budget-specific fields ──────────────────────────────────────
          if (_stackType == StackType.budget) ...[
            _FieldLabel('Monthly Budget Limit'),
            TextField(
              controller: _monthlyBudgetController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.of(context).textPrimary,
              ),
              decoration: InputDecoration(
                prefixText: '$symbol  ',
                prefixStyle: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.of(context).textMuted,
                ),
                hintText: '0',
                helperText: 'How much can you spend on this each month?',
                helperStyle: TextStyle(
                    fontSize: 11, color: AppTheme.of(context).textMuted),
              ),
              inputFormatters: [LengthLimitingTextInputFormatter(12)],
            ),
          ],

          // ── Savings-specific fields ─────────────────────────────────────
          if (_stackType == StackType.savings) ...[
            _FieldLabel('Savings Target'),
            TextField(
              controller: _savingsTargetController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.of(context).textPrimary,
              ),
              decoration: InputDecoration(
                prefixText: '$symbol  ',
                prefixStyle: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.of(context).textMuted,
                ),
                hintText: '0',
                helperText: 'How much are you trying to save in total?',
                helperStyle: TextStyle(
                    fontSize: 11, color: AppTheme.of(context).textMuted),
              ),
              inputFormatters: [LengthLimitingTextInputFormatter(12)],
            ),
          ],

          // ── Salary-specific fields ──────────────────────────────────────
          if (_stackType == StackType.salary) ...[
            _FieldLabel('Monthly Net Pay (optional)'),
            TextField(
              controller: _monthlyGoalController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.of(context).textPrimary,
              ),
              decoration: InputDecoration(
                prefixText: '$symbol  ',
                prefixStyle: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.of(context).textMuted,
                ),
                hintText: '0',
                helperText: 'Your take-home after tax — used as a reference',
                helperStyle: TextStyle(
                    fontSize: 11, color: AppTheme.of(context).textMuted),
              ),
              inputFormatters: [LengthLimitingTextInputFormatter(12)],
            ),
          ],

          // ── Section toggle (budget/savings only) ─────────────────────────
          if (_stackType == StackType.budget ||
              _stackType == StackType.savings) ...[
            const SizedBox(height: 14),
            _FieldLabel('This is for…'),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(
                        () => _isPersonal = true),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _isPersonal
                            ? const Color(0xFF2563EB).withOpacity(0.1)
                            : AppTheme.of(context).card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _isPersonal
                              ? const Color(0xFF2563EB)
                              : AppTheme.of(context).border,
                          width: _isPersonal ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.home_outlined,
                              size: 13,
                              color: _isPersonal
                                  ? const Color(0xFF2563EB)
                                  : AppTheme.of(context).textMuted),
                          const SizedBox(width: 5),
                          Text('Main life',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _isPersonal
                                      ? const Color(0xFF2563EB)
                                      : AppTheme.of(context).textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(
                        () => _isPersonal = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: !_isPersonal
                            ? AppTheme.accentDim
                            : AppTheme.of(context).card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: !_isPersonal
                              ? AppTheme.accent
                              : AppTheme.of(context).border,
                          width: !_isPersonal ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bolt_outlined,
                              size: 13,
                              color: !_isPersonal
                                  ? AppTheme.accent
                                  : AppTheme.of(context).textMuted),
                          const SizedBox(width: 5),
                          Text('Side hustle',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: !_isPersonal
                                      ? AppTheme.accent
                                      : AppTheme.of(context).textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          PrimaryButton(
            label: 'Save Changes',
            onPressed: _nameController.text.trim().isEmpty ? null : _submit,
          ),
        ],
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
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.of(context).textMuted,
          ),
        ),
      );
}
