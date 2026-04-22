import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'analytics_screen.dart';
import 'tax_screen.dart';

// ─── Insights shell — ANALYTICS | TAX in one bottom-nav slot ─────────────────

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.of(context).background,
      body: Column(
        children: [
          // Tab bar sits at the very top (below the status bar).
          // Each child screen renders its own SliverAppBar / app bar.
          Material(
            color: AppTheme.of(context).surface,
            child: SafeArea(
              bottom: false,
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.accent,
                indicatorWeight: 2,
                labelColor: AppTheme.accent,
                unselectedLabelColor: AppTheme.of(context).textSecondary,
                labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5),
                tabs: const [
                  Tab(text: 'ANALYTICS'),
                  Tab(text: 'TAX'),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              // physics: never-scroll so the inner screens can scroll freely
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                AnalyticsScreen(),
                TaxScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
