import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'shared_widgets.dart';

// ─── Templates ────────────────────────────────────────────────────────────────

class _StackTemplate {
  final String name;
  final String description;
  final HustleType type;
  const _StackTemplate({
    required this.name,
    required this.description,
    required this.type,
  });
}

const _kTemplates = [
  _StackTemplate(
    name: 'Freelance Dev',
    description: 'Client projects, consulting & code work',
    type: HustleType.freelance,
  ),
  _StackTemplate(
    name: 'Design Work',
    description: 'Logos, branding & creative services',
    type: HustleType.freelance,
  ),
  _StackTemplate(
    name: 'Reselling',
    description: 'Flipping products online or in person',
    type: HustleType.reselling,
  ),
  _StackTemplate(
    name: 'Content Creator',
    description: 'YouTube, TikTok, brand deals & sponsorships',
    type: HustleType.content,
  ),
  _StackTemplate(
    name: 'Photography',
    description: 'Shoots, editing & licensing',
    type: HustleType.freelance,
  ),
  _StackTemplate(
    name: 'Tutoring',
    description: 'Teaching, coaching & courses',
    type: HustleType.other,
  ),
  _StackTemplate(
    name: 'Delivery / Gigs',
    description: 'Uber, DoorDash, Instacart & similar',
    type: HustleType.other,
  ),
  _StackTemplate(
    name: 'Online Store',
    description: 'Etsy, Shopify or own product line',
    type: HustleType.business,
  ),
];

// ─── Sheet ────────────────────────────────────────────────────────────────────

Future<void> showCreateStackSheet(
  BuildContext context, {
  HustleType? initialHustleType,
  double? initialMonthlyGoal,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CreateStackSheet(
      initialHustleType: initialHustleType,
      initialMonthlyGoal: initialMonthlyGoal,
    ),
  );
}

class CreateStackSheet extends StatefulWidget {
  final HustleType? initialHustleType;
  final double? initialMonthlyGoal;

  const CreateStackSheet({
    super.key,
    this.initialHustleType,
    this.initialMonthlyGoal,
  });

  @override
  State<CreateStackSheet> createState() => _CreateStackSheetState();
}

class _CreateStackSheetState extends State<CreateStackSheet> {
  final _nameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _descController = TextEditingController();
  late HustleType _selectedType;
  bool _showTemplates = true;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialHustleType ?? HustleType.other;
    // If pre-filled from onboarding, skip templates
    if (widget.initialHustleType != null) _showTemplates = false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _businessNameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _applyTemplate(_StackTemplate t) {
    setState(() {
      _nameController.text = t.name;
      _descController.text = t.description;
      _selectedType = t.type;
      _showTemplates = false;
    });
  }

  String? get _businessName {
    final v = _businessNameController.text.trim();
    return v.isEmpty ? null : v;
  }

  void _submit() async {
    if (_nameController.text.trim().isEmpty) return;
    await context.read<AppProvider>().addSideStack(
      name: _nameController.text.trim(),
      businessName: _businessName,
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      hustleType: _selectedType,
      monthlyGoalAmount: widget.initialMonthlyGoal,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).viewInsets.bottom;

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
                Text('New SideStack',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                // Toggle between templates and manual entry
                GestureDetector(
                  onTap: () => setState(() => _showTemplates = !_showTemplates),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _showTemplates
                          ? AppTheme.accentDim
                          : AppTheme.of(context).card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _showTemplates
                            ? AppTheme.accent
                            : AppTheme.of(context).border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_outlined,
                            size: 13,
                            color: _showTemplates
                                ? AppTheme.accent
                                : AppTheme.of(context).textMuted),
                        const SizedBox(width: 4),
                        Text(
                          'Templates',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _showTemplates
                                ? AppTheme.accent
                                : AppTheme.of(context).textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Template picker
            if (_showTemplates) ...[
              Text(
                'Pick a template to get started quickly',
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.of(context).textSecondary),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.6,
                ),
                itemCount: _kTemplates.length,
                itemBuilder: (context, i) {
                  final t = _kTemplates[i];
                  return GestureDetector(
                    onTap: () => _applyTemplate(t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.of(context).card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.of(context).border),
                      ),
                      child: Row(children: [
                        Icon(t.type.icon, size: 18,
                            color: AppTheme.of(context).textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            t.name,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
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
                  child: Text(
                    'Start from scratch instead',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.of(context).textMuted,
                        decoration: TextDecoration.underline),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ] else ...[
              // Manual form
              _FieldLabel('Name'),
              TextField(
                controller: _nameController,
                style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.of(context).textPrimary),
                decoration: const InputDecoration(
                    hintText: 'e.g. Vintage Reselling'),
                autofocus: true,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),

              _FieldLabel('Business name (optional)'),
              TextField(
                controller: _businessNameController,
                style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.of(context).textPrimary),
                decoration: const InputDecoration(
                    hintText: 'e.g. Dawes Creative Studio'),
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

              _FieldLabel('Description (optional)'),
              TextField(
                controller: _descController,
                style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.of(context).textPrimary),
                decoration: const InputDecoration(
                    hintText: "What's this hustle about?"),
              ),
              const SizedBox(height: 14),

              _FieldLabel('Type'),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: HustleType.values
                    .map((t) => _HustleTypeChip(
                          type: t,
                          selected: _selectedType == t,
                          onTap: () =>
                              setState(() => _selectedType = t),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),

              PrimaryButton(
                label: 'Create SideStack',
                onPressed: _nameController.text.trim().isEmpty
                    ? null
                    : _submit,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HustleTypeChip extends StatelessWidget {
  final HustleType type;
  final bool selected;
  final VoidCallback onTap;

  const _HustleTypeChip(
      {required this.type, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accentDim : AppTheme.of(context).card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppTheme.accent
                : AppTheme.of(context).border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(type.icon, size: 14,
                color: selected ? AppTheme.accent : AppTheme.of(context).textSecondary),
            const SizedBox(width: 6),
            Text(
              type.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected
                    ? AppTheme.accent
                    : AppTheme.of(context).textSecondary,
              ),
            ),
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
