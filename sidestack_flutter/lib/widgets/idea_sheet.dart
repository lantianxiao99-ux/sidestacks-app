import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'shared_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry points
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showCreateIdeaSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _IdeaSheet(idea: null),
  );
}

Future<void> showEditIdeaSheet(BuildContext context, {required Idea idea}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _IdeaSheet(idea: idea),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _IdeaSheet extends StatefulWidget {
  final Idea? idea; // null = create mode
  const _IdeaSheet({this.idea});

  @override
  State<_IdeaSheet> createState() => _IdeaSheetState();
}

class _IdeaSheetState extends State<_IdeaSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _startupCostCtrl;
  late TextEditingController _monthlyIncomeCtrl;
  late TextEditingController _notesCtrl;
  late HustleType _hustleType;
  late IdeaStatus _status;
  bool _saving = false;

  bool get _isEdit => widget.idea != null;

  @override
  void initState() {
    super.initState();
    final idea = widget.idea;
    _titleCtrl = TextEditingController(text: idea?.title ?? '');
    _descCtrl = TextEditingController(text: idea?.description ?? '');
    _startupCostCtrl = TextEditingController(
        text: idea?.estimatedStartupCost != null
            ? idea!.estimatedStartupCost!.toStringAsFixed(0)
            : '');
    _monthlyIncomeCtrl = TextEditingController(
        text: idea?.estimatedMonthlyIncome != null
            ? idea!.estimatedMonthlyIncome!.toStringAsFixed(0)
            : '');
    _notesCtrl = TextEditingController(text: idea?.notes ?? '');
    _hustleType = idea?.hustleType ?? HustleType.other;
    _status = idea?.status ?? IdeaStatus.newIdea;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _startupCostCtrl.dispose();
    _monthlyIncomeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final provider = context.read<AppProvider>();
    final startupCost = double.tryParse(_startupCostCtrl.text);
    final monthlyIncome = double.tryParse(_monthlyIncomeCtrl.text);
    final desc = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();
    final notes = _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();

    try {
      if (_isEdit) {
        await provider.updateIdea(
          widget.idea!.id,
          title: _titleCtrl.text.trim(),
          description: desc,
          hustleType: _hustleType,
          status: _status,
          estimatedStartupCost: startupCost,
          estimatedMonthlyIncome: monthlyIncome,
          clearStartupCost: startupCost == null,
          clearMonthlyIncome: monthlyIncome == null,
          notes: notes,
        );
      } else {
        await provider.addIdea(
          title: _titleCtrl.text.trim(),
          description: desc,
          hustleType: _hustleType,
          status: _status,
          estimatedStartupCost: startupCost,
          estimatedMonthlyIncome: monthlyIncome,
          notes: notes,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Couldn\'t save your idea right now — try again in a moment.'),
          backgroundColor: AppTheme.of(context).card,
        ));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final symbol = context.read<AppProvider>().currencySymbol;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.97,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: BoxDecoration(
            color: AppTheme.of(context).surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.of(context).border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      Text(
                        _hustleType.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isEdit ? 'Edit Idea' : 'Capture Idea',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                      // Status badge
                      GestureDetector(
                        onTap: _cycleStatus,
                        child: _StatusBadge(status: _status),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Tap the badge to change status',
                    style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.of(context).textMuted),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    controller: ctrl,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        _SheetField(
                          ctrl: _titleCtrl,
                          label: 'Idea name *',
                          hint: 'e.g. Etsy printables shop',
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Give your idea a name'
                                  : null,
                        ),
                        const SizedBox(height: 12),

                        // Description
                        _SheetField(
                          ctrl: _descCtrl,
                          label: 'One-line pitch (optional)',
                          hint: 'e.g. Sell digital wall art to home decor fans',
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),

                        // Category
                        _SectionLabel('Category'),
                        _HustleTypeSelector(
                          selected: _hustleType,
                          onChanged: (t) =>
                              setState(() => _hustleType = t),
                        ),
                        const SizedBox(height: 16),

                        // Financials
                        _SectionLabel('Estimated financials'),
                        Row(
                          children: [
                            Expanded(
                              child: _SheetField(
                                ctrl: _startupCostCtrl,
                                label: 'Startup cost ($symbol)',
                                hint: '0',
                                keyboardType:
                                    TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _SheetField(
                                ctrl: _monthlyIncomeCtrl,
                                label: 'Monthly income ($symbol)',
                                hint: '0',
                                keyboardType:
                                    TextInputType.number,
                              ),
                            ),
                          ],
                        ),

                        // Payback preview
                        if (_monthlyIncomeCtrl.text.isNotEmpty &&
                            _startupCostCtrl.text.isNotEmpty)
                          _PaybackPreview(
                            startupCost: double.tryParse(
                                _startupCostCtrl.text),
                            monthlyIncome: double.tryParse(
                                _monthlyIncomeCtrl.text),
                            symbol: symbol,
                          ),

                        const SizedBox(height: 16),

                        // Notes
                        _SectionLabel('Notes'),
                        _SheetField(
                          ctrl: _notesCtrl,
                          label: 'Research, links, thoughts…',
                          maxLines: 4,
                        ),
                        const SizedBox(height: 28),

                        // Save button
                        PrimaryButton(
                          label: _saving
                              ? 'Saving…'
                              : (_isEdit ? 'Save Changes' : 'Save Idea 💡'),
                          onPressed: _saving ? null : _save,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _cycleStatus() {
    const order = [
      IdeaStatus.newIdea,
      IdeaStatus.reviewing,
      IdeaStatus.approved,
    ];
    final idx = order.indexOf(_status);
    setState(() {
      _status = order[(idx + 1) % order.length];
    });
  }
}

// ─── Status badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final IdeaStatus status;
  const _StatusBadge({required this.status});

  Color _color(BuildContext context) {
    switch (status) {
      case IdeaStatus.newIdea:   return AppTheme.accent;
      case IdeaStatus.reviewing: return AppTheme.amber;
      case IdeaStatus.approved:  return AppTheme.green;
      case IdeaStatus.archived:  return AppTheme.of(context).textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(status.emoji, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color),
          ),
        ],
      ),
    );
  }
}

// ─── Hustle Type Selector ─────────────────────────────────────────────────────

class _HustleTypeSelector extends StatelessWidget {
  final HustleType selected;
  final ValueChanged<HustleType> onChanged;
  const _HustleTypeSelector(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: HustleType.values.map((t) {
        final isSelected = t == selected;
        return GestureDetector(
          onTap: () => onChanged(t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.accentDim
                  : AppTheme.of(context).card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? AppTheme.accent
                    : AppTheme.of(context).border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t.emoji,
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 5),
                Text(
                  t.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppTheme.accent
                        : AppTheme.of(context).textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Payback preview ──────────────────────────────────────────────────────────

class _PaybackPreview extends StatelessWidget {
  final double? startupCost;
  final double? monthlyIncome;
  final String symbol;
  const _PaybackPreview(
      {this.startupCost, this.monthlyIncome, required this.symbol});

  @override
  Widget build(BuildContext context) {
    if (startupCost == null ||
        monthlyIncome == null ||
        monthlyIncome! <= 0) {
      return const SizedBox.shrink();
    }
    final months = (startupCost! / monthlyIncome!).ceil();
    final annualIncome = monthlyIncome! * 12;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.greenDim,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.green.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Text('📈', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$symbol${annualIncome.toStringAsFixed(0)}/yr potential',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.green),
                  ),
                  if (startupCost! > 0)
                    Text(
                      'Payback in ~$months month${months == 1 ? '' : 's'}',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.green.withOpacity(0.8)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Form helpers ─────────────────────────────────────────────────────────────

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
              fontWeight: FontWeight.w700,
              color: AppTheme.of(context).textMuted,
              letterSpacing: 0.8),
        ),
      );
}

class _SheetField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;

  const _SheetField({
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
            fontSize: 14, color: AppTheme.of(context).textPrimary),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(
              fontSize: 12, color: AppTheme.of(context).textMuted),
          labelStyle: TextStyle(
              fontSize: 12,
              color: AppTheme.of(context).textSecondary),
          filled: true,
          fillColor: AppTheme.of(context).card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: AppTheme.of(context).border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: AppTheme.of(context).border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppTheme.accent, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
        ),
      );
}
