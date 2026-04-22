import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'transactions_screen.dart';
import 'invoices_screen.dart' show InvoicesScreen, ReportsTab;

// ─── Stacks Hub — merged Transactions + Clients tab ───────────────────────────

class StacksHubScreen extends StatefulWidget {
  const StacksHubScreen({super.key});

  @override
  State<StacksHubScreen> createState() => _StacksHubScreenState();
}

class _StacksHubScreenState extends State<StacksHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() {
      if (!_tab.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _showReports(BuildContext context) {
    final colors = AppTheme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.88,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: Text(
                'Reports',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: colors.textPrimary),
              ),
            ),
            const Expanded(child: ReportsTab()),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final onTransactions = _tab.index == 0;

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          // ── Sticky header ─────────────────────────────────────────────────
          Container(
            color: colors.surface,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Stacks',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                            color: colors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        // Reports button — only shown on Transactions tab
                        AnimatedOpacity(
                          opacity: onTransactions ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 180),
                          child: GestureDetector(
                            onTap: onTransactions
                                ? () => _showReports(context)
                                : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: colors.card,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: colors.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.picture_as_pdf_outlined,
                                      size: 13, color: colors.textMuted),
                                  const SizedBox(width: 5),
                                  Text('Reports',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: colors.textMuted)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _SegmentPill(tab: _tab),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
          Divider(height: 1, color: colors.border),

          // ── Tab content ───────────────────────────────────────────────────
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: TabBarView(
                controller: _tab,
                children: const [
                  TransactionsScreen(),
                  InvoicesScreen(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pill segment switcher ────────────────────────────────────────────────────

class _SegmentPill extends StatefulWidget {
  final TabController tab;
  const _SegmentPill({required this.tab});

  @override
  State<_SegmentPill> createState() => _SegmentPillState();
}

class _SegmentPillState extends State<_SegmentPill> {
  @override
  void initState() {
    super.initState();
    widget.tab.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.tab.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final selected = widget.tab.index;
    const segments = ['Transactions', 'Clients'];

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(segments.length, (i) {
          final active = selected == i;
          return GestureDetector(
            onTap: () => widget.tab.animateTo(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
              decoration: BoxDecoration(
                color: active ? AppTheme.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                segments[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : colors.textMuted,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
