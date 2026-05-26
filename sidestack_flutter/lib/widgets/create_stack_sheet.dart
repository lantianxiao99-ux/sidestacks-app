import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'shared_widgets.dart';

// ─── Templates ────────────────────────────────────────────────────────────────

class _StackTemplate {
  final String name;
  final String description;
  final HustleType hustleType;
  final StackType stackType;
  final double? suggestedBudget;
  final double? suggestedTarget;

  const _StackTemplate({
    required this.name,
    required this.description,
    this.hustleType = HustleType.other,
    this.stackType = StackType.income,
    this.suggestedBudget,
    this.suggestedTarget,
  });
}

const _kIncomeTemplates = [
  _StackTemplate(name: 'Freelance Dev', description: 'Client projects & consulting', hustleType: HustleType.freelance),
  _StackTemplate(name: 'Design Work', description: 'Logos, branding & creative', hustleType: HustleType.freelance),
  _StackTemplate(name: 'Reselling', description: 'Flipping products online or in person', hustleType: HustleType.reselling),
  _StackTemplate(name: 'Content Creator', description: 'YouTube, TikTok & brand deals', hustleType: HustleType.content),
  _StackTemplate(name: 'Photography', description: 'Shoots, editing & licensing', hustleType: HustleType.freelance),
  _StackTemplate(name: 'Tutoring', description: 'Teaching, coaching & courses'),
  _StackTemplate(name: 'Delivery / Gigs', description: 'Uber, DoorDash & similar'),
  _StackTemplate(name: 'Online Store', description: 'Etsy, Shopify or own products', hustleType: HustleType.business),
];

const _kBudgetTemplates = [
  _StackTemplate(name: 'Groceries', description: 'Supermarket & food shopping', stackType: StackType.budget, suggestedBudget: 400),
  _StackTemplate(name: 'Rent / Mortgage', description: 'Monthly housing cost', stackType: StackType.budget, suggestedBudget: 1500),
  _StackTemplate(name: 'Dining Out', description: 'Restaurants, takeaway & cafes', stackType: StackType.budget, suggestedBudget: 200),
  _StackTemplate(name: 'Transport', description: 'Petrol, tolls & public transport', stackType: StackType.budget, suggestedBudget: 300),
  _StackTemplate(name: 'Entertainment', description: 'Nights out, events & activities', stackType: StackType.budget, suggestedBudget: 150),
  _StackTemplate(name: 'Subscriptions', description: 'Streaming, apps & memberships', stackType: StackType.budget, suggestedBudget: 80),
  _StackTemplate(name: 'Health & Fitness', description: 'Gym, meds & appointments', stackType: StackType.budget, suggestedBudget: 100),
  _StackTemplate(name: 'Shopping', description: 'Clothes, homewares & general spend', stackType: StackType.budget, suggestedBudget: 200),
];

const _kSavingsTemplates = [
  _StackTemplate(name: 'Emergency Fund', description: '3–6 months of expenses', stackType: StackType.savings, suggestedTarget: 10000),
  _StackTemplate(name: 'Holiday', description: 'Trip, flights & accommodation', stackType: StackType.savings, suggestedTarget: 3000),
  _StackTemplate(name: 'House Deposit', description: 'Saving to buy a home', stackType: StackType.savings, suggestedTarget: 50000),
  _StackTemplate(name: 'New Car', description: 'Upgrade or first car', stackType: StackType.savings, suggestedTarget: 15000),
  _StackTemplate(name: 'New Laptop', description: 'Tech upgrade for work or life', stackType: StackType.savings, suggestedTarget: 2000),
  _StackTemplate(name: 'Investment', description: 'Lump sum to invest', stackType: StackType.savings, suggestedTarget: 5000),
  _StackTemplate(name: 'Wedding', description: 'The big day fund', stackType: StackType.savings, suggestedTarget: 20000),
  _StackTemplate(name: 'Education', description: 'Course, degree or certification', stackType: StackType.savings, suggestedTarget: 8000),
];

// ─── Sheet entry point ────────────────────────────────────────────────────────

Future<void> showCreateStackSheet(
  BuildContext context, {
  HustleType? initialHustleType,
  StackType? initialStackType,
  double? initialMonthlyGoal,
  bool? initialIsPersonal,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CreateStackSheet(
      initialHustleType: initialHustleType,
      initialStackType: initialStackType,
      initialMonthlyGoal: initialMonthlyGoal,
      initialIsPersonal: initialIsPersonal,
    ),
  );
}

class CreateStackSheet extends StatefulWidget {
  final HustleType? initialHustleType;
  final StackType? initialStackType;
  final double? initialMonthlyGoal;
  final bool? initialIsPersonal;

  const CreateStackSheet({
    super.key,
    this.initialHustleType,
    this.initialStackType,
    this.initialMonthlyGoal,
    this.initialIsPersonal,
  });

  @override
  State<CreateStackSheet> createState() => _CreateStackSheetState();
}

class _CreateStackSheetState extends State<CreateStackSheet> {
  final _nameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();

  late StackType _stackType;
  late HustleType _hustleType;
  late bool _isPersonal;
  bool _showTemplates = true;

  @override
  void initState() {
    super.initState();
    _stackType = widget.initialStackType ?? StackType.income;
    _hustleType = widget.initialHustleType ?? HustleType.other;
    // isPersonal: explicit override → stackType default
    _isPersonal = widget.initialIsPersonal ?? _stackType.isPersonalByDefault;
    // Salary and specified types skip templates
    if (widget.initialHustleType != null ||
        widget.initialStackType != null ||
        _stackType == StackType.salary) {
      _showTemplates = false;
    }
    if (widget.initialMonthlyGoal != null) {
      _amountController.text = widget.initialMonthlyGoal!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _businessNameController.dispose();
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  List<_StackTemplate> get _templates {
    switch (_stackType) {
      case StackType.income:  return _kIncomeTemplates;
      case StackType.budget:  return _kBudgetTemplates;
      case StackType.savings: return _kSavingsTemplates;
      case StackType.salary:  return []; // salary goes straight to form
    }
  }

  void _applyTemplate(_StackTemplate t) {
    setState(() {
      _nameController.text = t.name;
      _descController.text = t.description;
      _hustleType = t.hustleType;
      if (t.suggestedBudget != null) {
        _amountController.text = t.suggestedBudget!.toStringAsFixed(0);
      } else if (t.suggestedTarget != null) {
        _amountController.text = t.suggestedTarget!.toStringAsFixed(0);
      }
      _showTemplates = false;
    });
  }

  String? get _businessName {
    final v = _businessNameController.text.trim();
    return v.isEmpty ? null : v;
  }

  void _submit() async {
    if (_nameController.text.trim().isEmpty) return;
    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));
    await context.read<AppProvider>().addSideStack(
      name: _nameController.text.trim(),
      businessName: _stackType == StackType.income ? _businessName : null,
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      hustleType: _hustleType,
      stackType: _stackType,
      monthlyGoalAmount: _stackType == StackType.income ? widget.initialMonthlyGoal : null,
      monthlyBudget: _stackType == StackType.budget ? amount : null,
      savingsTarget: _stackType == StackType.savings ? amount : null,
      isPersonal: _isPersonal,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).viewInsets.bottom;
    final symbol = context.read<AppProvider>().currencySymbol;

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

            Row(
              children: [
                Text('New Stack',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (!_showTemplates)
                  GestureDetector(
                    onTap: () => setState(() => _showTemplates = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.of(context).card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.of(context).border),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.bolt_outlined, size: 13, color: AppTheme.of(context).textMuted),
                        const SizedBox(width: 4),
                        Text('Templates',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                color: AppTheme.of(context).textSecondary)),
                      ]),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Stack type picker (2×2 grid) ─────────────────────────────────
            _FieldLabel('What kind of stack?'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 3.2,
              children: StackType.values.map((t) {
                final selected = _stackType == t;
                final color = t.color(context);
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _stackType = t;
                      _isPersonal = t.isPersonalByDefault;
                      _showTemplates = t != StackType.salary;
                      _nameController.clear();
                      _descController.clear();
                      _amountController.clear();
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withOpacity(0.12)
                          : AppTheme.of(context).card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? color : AppTheme.of(context).border,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(t.icon,
                            size: 15,
                            color: selected
                                ? color
                                : AppTheme.of(context).textMuted),
                        const SizedBox(width: 6),
                        Text(
                          t.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? color
                                : AppTheme.of(context).textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // ── Section toggle (budget/savings only) ─────────────────────────
            if (_stackType == StackType.budget ||
                _stackType == StackType.savings) ...[
              _FieldLabel('This is for…'),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isPersonal = true),
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
                      onTap: () => setState(() => _isPersonal = false),
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
              const SizedBox(height: 16),
            ],

            // ── Template grid ────────────────────────────────────────────────
            if (_showTemplates) ...[
              Text(
                'Pick a template to get started quickly',
                style: TextStyle(fontSize: 11, color: AppTheme.of(context).textSecondary),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.6,
                ),
                itemCount: _templates.length,
                itemBuilder: (context, i) {
                  final t = _templates[i];
                  return GestureDetector(
                    onTap: () => _applyTemplate(t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.of(context).card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.of(context).border),
                      ),
                      child: Row(children: [
                        Icon(_stackType.icon, size: 16,
                            color: AppTheme.of(context).textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(t.name,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Center(
                child: GestureDetector(
                  onTap: () => setState(() => _showTemplates = false),
                  child: Text('Start from scratch instead',
                      style: TextStyle(fontSize: 11,
                          color: AppTheme.of(context).textMuted,
                          decoration: TextDecoration.underline)),
                ),
              ),
              const SizedBox(height: 8),
            ] else ...[
              // ── Manual form ────────────────────────────────────────────────
              _FieldLabel('Name'),
              TextField(
                controller: _nameController,
                style: TextStyle(fontSize: 14, color: AppTheme.of(context).textPrimary),
                decoration: InputDecoration(
                  hintText: _stackType == StackType.income
                      ? 'e.g. Vintage Reselling'
                      : _stackType == StackType.budget
                          ? 'e.g. Groceries'
                          : _stackType == StackType.savings
                              ? 'e.g. Holiday Fund'
                              : 'e.g. Full-time Job',
                ),
                autofocus: true,
                inputFormatters: [LengthLimitingTextInputFormatter(60)],
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),

              // Business name — income only
              if (_stackType == StackType.income) ...[
                _FieldLabel('Business name (optional)'),
                TextField(
                  controller: _businessNameController,
                  style: TextStyle(fontSize: 14, color: AppTheme.of(context).textPrimary),
                  decoration: const InputDecoration(hintText: 'e.g. Dawes Creative Studio'),
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [LengthLimitingTextInputFormatter(100)],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Shown on invoices and exports instead of your name',
                    style: TextStyle(fontSize: 11, color: AppTheme.of(context).textMuted),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Description / employer hint
              _FieldLabel(_stackType == StackType.salary
                  ? 'Employer (optional)'
                  : 'Description (optional)'),
              TextField(
                controller: _descController,
                style: TextStyle(fontSize: 13, color: AppTheme.of(context).textPrimary),
                decoration: InputDecoration(
                  hintText: _stackType == StackType.income
                      ? "What's this hustle about?"
                      : _stackType == StackType.budget
                          ? 'What does this cover?'
                          : _stackType == StackType.savings
                              ? "What are you saving for?"
                              : 'e.g. Acme Corp',
                ),
                inputFormatters: [LengthLimitingTextInputFormatter(300)],
              ),
              const SizedBox(height: 14),

              // Monthly budget limit — budget type only
              if (_stackType == StackType.budget) ...[
                _FieldLabel('Monthly limit'),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600,
                      color: AppTheme.of(context).textPrimary),
                  decoration: InputDecoration(
                    prefixText: '$symbol  ',
                    prefixStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w400,
                        color: AppTheme.of(context).textMuted),
                    hintText: '0',
                  ),
                  inputFormatters: [LengthLimitingTextInputFormatter(10)],
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),
              ],

              // Savings target — savings type only
              if (_stackType == StackType.savings) ...[
                _FieldLabel('Savings target'),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600,
                      color: AppTheme.of(context).textPrimary),
                  decoration: InputDecoration(
                    prefixText: '$symbol  ',
                    prefixStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w400,
                        color: AppTheme.of(context).textMuted),
                    hintText: '0',
                  ),
                  inputFormatters: [LengthLimitingTextInputFormatter(10)],
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),
              ],

              // Monthly net pay — salary type only
              if (_stackType == StackType.salary) ...[
                _FieldLabel('Monthly net pay (optional)'),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600,
                      color: AppTheme.of(context).textPrimary),
                  decoration: InputDecoration(
                    prefixText: '$symbol  ',
                    prefixStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w400,
                        color: AppTheme.of(context).textMuted),
                    hintText: '0',
                    helperText: 'Your take-home after tax — used as a reference',
                    helperStyle: TextStyle(fontSize: 11, color: AppTheme.of(context).textMuted),
                  ),
                  inputFormatters: [LengthLimitingTextInputFormatter(10)],
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),
              ],

              // Hustle type picker — income only
              if (_stackType == StackType.income) ...[
                _FieldLabel('Type'),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: HustleType.values.map((t) => _HustleTypeChip(
                    type: t,
                    selected: _hustleType == t,
                    onTap: () => setState(() => _hustleType = t),
                  )).toList(),
                ),
                const SizedBox(height: 20),
              ],

              PrimaryButton(
                label: _stackType == StackType.income
                    ? 'Create Stack'
                    : _stackType == StackType.budget
                        ? 'Create Budget'
                        : _stackType == StackType.savings
                            ? 'Create Savings Goal'
                            : 'Add Salary',
                onPressed: _nameController.text.trim().isEmpty ? null : _submit,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _HustleTypeChip extends StatelessWidget {
  final HustleType type;
  final bool selected;
  final VoidCallback onTap;

  const _HustleTypeChip({required this.type, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accentDim : AppTheme.of(context).card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.accent : AppTheme.of(context).border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(type.icon, size: 14,
                color: selected ? AppTheme.accent : AppTheme.of(context).textSecondary),
            const SizedBox(width: 6),
            Text(type.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppTheme.accent : AppTheme.of(context).textSecondary,
                )),
          ],
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
        child: Text(text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.of(context).textMuted,
            )),
      );
}
