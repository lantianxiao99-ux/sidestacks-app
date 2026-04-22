import 'package:flutter/material.dart';
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
  late HustleType _hustleType;

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
    _hustleType = widget.stack.hustleType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _businessNameController.dispose();
    _descController.dispose();
    _monthlyGoalController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final desc = _descController.text.trim().isEmpty
        ? null
        : _descController.text.trim();
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
    Navigator.pop(context);
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

          const Text(
            'Edit SideStack',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          // Name
          _FieldLabel('Name'),
          TextField(
            controller: _nameController,
            autofocus: true,
            style:
                TextStyle(fontSize: 14, color: AppTheme.of(context).textPrimary),
            decoration: const InputDecoration(hintText: 'e.g. Etsy Shop'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),

          // Business name
          _FieldLabel('Business name (optional)'),
          TextField(
            controller: _businessNameController,
            style: TextStyle(fontSize: 14, color: AppTheme.of(context).textPrimary),
            decoration: const InputDecoration(hintText: 'e.g. Dawes Creative Studio'),
            textCapitalization: TextCapitalization.words,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Shown on invoices and exports instead of your name',
              style: TextStyle(fontSize: 10, color: AppTheme.of(context).textMuted),
            ),
          ),
          const SizedBox(height: 14),

          // Description
          _FieldLabel('Description (optional)'),
          TextField(
            controller: _descController,
            style:
                TextStyle(fontSize: 13, color: AppTheme.of(context).textPrimary),
            decoration: const InputDecoration(
                hintText: 'What is this hustle about?'),
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
                            Icon(t.icon, size: 11,
                                color: _hustleType == t
                                    ? AppTheme.accent
                                    : AppTheme.of(context).textSecondary),
                            const SizedBox(width: 4),
                            Text(t.label,
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
              fontFamily: 'Courier',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.of(context).textPrimary,
            ),
            decoration: InputDecoration(
              prefixText: '$symbol  ',
              prefixStyle: TextStyle(
                fontFamily: 'Courier',
                fontSize: 18,
                fontWeight: FontWeight.w400,
                color: AppTheme.of(context).textMuted,
              ),
              hintText: '0',
              helperText: 'Tracks your progress each month',
              helperStyle: TextStyle(
                  fontSize: 10, color: AppTheme.of(context).textMuted),
            ),
          ),
          const SizedBox(height: 14),

          // All-time revenue goal
          _FieldLabel('All-time Revenue Goal (optional)'),
          TextField(
            controller: _goalController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.of(context).textPrimary,
            ),
            decoration: InputDecoration(
              prefixText: '$symbol  ',
              prefixStyle: TextStyle(
                fontFamily: 'Courier',
                fontSize: 18,
                fontWeight: FontWeight.w400,
                color: AppTheme.of(context).textMuted,
              ),
              hintText: '0',
              helperText: 'e.g. a savings milestone or total income target',
              helperStyle: TextStyle(
                  fontSize: 10, color: AppTheme.of(context).textMuted),
            ),
          ),
          const SizedBox(height: 16),

          PrimaryButton(
            label: 'Save Changes',
            onPressed:
                _nameController.text.trim().isEmpty ? null : _submit,
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
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppTheme.of(context).textMuted,
            letterSpacing: 0.8,
          ),
        ),
      );
}
