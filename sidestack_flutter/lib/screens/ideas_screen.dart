import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/idea_sheet.dart';

class IdeasScreen extends StatefulWidget {
  final bool showBackButton;
  const IdeasScreen({super.key, this.showBackButton = false});

  @override
  State<IdeasScreen> createState() => _IdeasScreenState();
}

class _IdeasScreenState extends State<IdeasScreen> {
  final _searchCtrl = TextEditingController();
  IdeaStatus? _filterStatus; // null = All
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Idea> _filtered(List<Idea> ideas) {
    return ideas.where((idea) {
      final matchesStatus =
          _filterStatus == null || idea.status == _filterStatus;
      final matchesQuery = _query.isEmpty ||
          idea.title.toLowerCase().contains(_query) ||
          (idea.description?.toLowerCase().contains(_query) ?? false) ||
          (idea.notes?.toLowerCase().contains(_query) ?? false);
      return matchesStatus && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final ideas = provider.ideas;
    final filtered = _filtered(ideas);
    final symbol = provider.currencySymbol;

    return Scaffold(
      backgroundColor: AppTheme.of(context).background,
      body: CustomScrollView(
        slivers: [
          // ── App bar ───────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: widget.showBackButton,
            backgroundColor: AppTheme.of(context).surface,
            surfaceTintColor: Colors.transparent,
            title: Row(
              children: [
                const Text(
                  'Ideas',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5),
                ),
                if (ideas.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentDim,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${ideas.length}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accent),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add, size: 26),
                color: AppTheme.accent,
                onPressed: () => showCreateIdeaSheet(context),
              ),
              const SizedBox(width: 4),
            ],
          ),

          // ── Search + filters ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  // Search bar
                  TextField(
                    controller: _searchCtrl,
                    style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.of(context).textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search ideas…',
                      hintStyle: TextStyle(
                          color: AppTheme.of(context).textMuted,
                          fontSize: 13),
                      prefixIcon: Icon(Icons.search,
                          size: 18,
                          color: AppTheme.of(context).textMuted),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              color: AppTheme.of(context).textMuted,
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppTheme.of(context).card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppTheme.accent, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All',
                          isSelected: _filterStatus == null,
                          onTap: () =>
                              setState(() => _filterStatus = null),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'New',
                          isSelected:
                              _filterStatus == IdeaStatus.newIdea,
                          onTap: () => setState(
                              () => _filterStatus = IdeaStatus.newIdea),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: '🔍 Reviewing',
                          isSelected:
                              _filterStatus == IdeaStatus.reviewing,
                          onTap: () => setState(
                              () => _filterStatus = IdeaStatus.reviewing),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Approved',
                          isSelected:
                              _filterStatus == IdeaStatus.approved,
                          onTap: () => setState(
                              () => _filterStatus = IdeaStatus.approved),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────────
          if (ideas.isEmpty)
            SliverFillRemaining(
              child: _EmptyState(
                onAdd: () => showCreateIdeaSheet(context),
              ),
            )
          else if (filtered.isEmpty)
            SliverFillRemaining(
              child: _NoResults(query: _query),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final idea = filtered[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _IdeaCard(
                        idea: idea,
                        symbol: symbol,
                        onTap: () =>
                            showEditIdeaSheet(context, idea: idea),
                        onDelete: () => _confirmDelete(context, idea),
                        onConvert: idea.status == IdeaStatus.approved
                            ? () => _confirmConvert(context, idea)
                            : null,
                      ),
                    );
                  },
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: ideas.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => showCreateIdeaSheet(context),
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.lightbulb_outline, size: 18),
              label: const Text(
                'New Idea',
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13),
              ),
            )
          : null,
    );
  }

  Future<void> _confirmDelete(BuildContext context, Idea idea) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.of(context).surface,
        title: const Text('Delete idea?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content:
            Text('Delete "${idea.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(
                    color: AppTheme.of(context).textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<AppProvider>().deleteIdea(idea.id);
    }
  }

  Future<void> _confirmConvert(BuildContext context, Idea idea) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.of(context).surface,
        title: const Text('Launch as SideStack?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          'This will create a new SideStack called "${idea.title}" '
          'and archive this idea.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(
                    color: AppTheme.of(context).textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Launch it',
                style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        await context.read<AppProvider>().convertIdeaToStack(idea.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${idea.title}" is now a SideStack!'),
              backgroundColor: AppTheme.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed: $e'),
              backgroundColor: AppTheme.of(context).card,
            ),
          );
        }
      }
    }
  }
}

// ─── Idea card ────────────────────────────────────────────────────────────────

class _IdeaCard extends StatelessWidget {
  final Idea idea;
  final String symbol;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;
  final VoidCallback? onConvert;

  const _IdeaCard({
    required this.idea,
    required this.symbol,
    required this.onTap,
    required this.onDelete,
    this.onConvert,
  });

  Color _statusColor(BuildContext context) {
    switch (idea.status) {
      case IdeaStatus.newIdea:
        return AppTheme.accent;
      case IdeaStatus.reviewing:
        return AppTheme.amber;
      case IdeaStatus.approved:
        return AppTheme.green;
      case IdeaStatus.archived:
        return AppTheme.of(context).textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(context);

    return Dismissible(
      key: ValueKey(idea.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.red.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: AppTheme.red),
      ),
      confirmDismiss: (_) async {
        await onDelete();
        return false; // let the provider update handle list removal
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.of(context).card,
            borderRadius: BorderRadius.circular(16),
            border: Border(
              left: BorderSide(color: statusColor, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Icon(idea.hustleType.icon, size: 18,
                      color: Theme.of(context).textTheme.bodySmall?.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      idea.title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusPill(status: idea.status, color: statusColor),
                ],
              ),

              // Description
              if (idea.description != null &&
                  idea.description!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  idea.description!,
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.of(context).textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Financial pills
              if (idea.estimatedMonthlyIncome != null ||
                  idea.estimatedStartupCost != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (idea.estimatedMonthlyIncome != null)
                      _MetaPill(
                        icon: Icons.trending_up,
                        label:
                            '$symbol${idea.estimatedMonthlyIncome!.toStringAsFixed(0)}/mo',
                        color: AppTheme.green,
                      ),
                    if (idea.estimatedStartupCost != null &&
                        idea.estimatedStartupCost! > 0)
                      _MetaPill(
                        icon: Icons.account_balance_wallet_outlined,
                        label:
                            '$symbol${idea.estimatedStartupCost!.toStringAsFixed(0)} startup',
                        color: AppTheme.of(context).textSecondary,
                      ),
                    if (idea.paybackMonths != null)
                      _MetaPill(
                        icon: Icons.timer_outlined,
                        label:
                            '${idea.paybackMonths!.ceil()}mo payback',
                        color: AppTheme.amber,
                      ),
                  ],
                ),
              ],

              // Convert CTA for approved ideas
              if (onConvert != null) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: onConvert,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppTheme.green.withOpacity(0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.rocket_launch_outlined,
                            size: 13, color: AppTheme.green),
                        const SizedBox(width: 6),
                        Text(
                          'Launch as SideStack',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.green,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward,
                            size: 13, color: AppTheme.green),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Status pill ──────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final IdeaStatus status;
  final Color color;
  const _StatusPill({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            status.label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

// ─── Meta pill ────────────────────────────────────────────────────────────────

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MetaPill(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.of(context).background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

// ─── Filter chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color:
              isSelected ? AppTheme.accentDim : AppTheme.of(context).card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected ? AppTheme.accent : AppTheme.of(context).border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? AppTheme.accent
                : AppTheme.of(context).textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Empty states ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accent.withOpacity(0.2),
                    AppTheme.accent.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: const Icon(Icons.lightbulb_outline, size: 40, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your idea backlog lives here',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Capture side hustle ideas before they disappear. '
              'Research them, track financials, then launch the best ones as real SideStacks.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.of(context).textSecondary,
                  height: 1.5),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.lightbulb_outline, size: 16),
              label: const Text(
                'Capture first idea',
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  final String query;
  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '🔍',
            style: const TextStyle(fontSize: 36),
          ),
          const SizedBox(height: 12),
          Text(
            query.isNotEmpty
                ? 'No ideas match "$query"'
                : 'No ideas in this category yet',
            style: TextStyle(
                fontSize: 14,
                color: AppTheme.of(context).textSecondary),
          ),
        ],
      ),
    );
  }
}
