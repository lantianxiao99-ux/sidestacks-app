import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─── Formatting helpers ──────────────────────────────────────────────────────

String formatCurrency(double amount, [String symbol = '\$']) {
  final abs = amount.abs();
  if (abs >= 1000) {
    return '$symbol${abs.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},'
    )}';
  }
  return '$symbol${abs.toStringAsFixed(0)}';
}

String formatPercent(double value) =>
    '${value >= 0 ? '' : '-'}${value.abs().toStringAsFixed(1)}%';

// ─── Summary Card (top strip) — animates number on value change ──────────────

class SummaryCard extends StatelessWidget {
  final String label;
  final double value;
  final bool isProfit;
  final bool highlight;
  final String symbol;
  /// Percentage change vs last month — positive = up, negative = down, null = no data.
  final double? trend;

  const SummaryCard({
    super.key,
    required this.label,
    required this.value,
    this.isProfit = false,
    this.highlight = false,
    this.symbol = '\$',
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    final color = isProfit
        ? (value >= 0 ? AppTheme.green : AppTheme.red)
        : (label == 'Expenses' ? AppTheme.red : AppTheme.green);

    // For expenses, going up is bad (red), going down is good (green).
    final trendUp = (trend ?? 0) > 0;
    final trendColor = label == 'Expenses'
        ? (trendUp ? AppTheme.red : AppTheme.green)
        : (trendUp ? AppTheme.green : AppTheme.red);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight
            ? (value >= 0 ? AppTheme.greenDim : AppTheme.redDim)
            : AppTheme.of(context).card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? (value >= 0
                  ? AppTheme.green.withOpacity(0.25)
                  : AppTheme.red.withOpacity(0.25))
              : AppTheme.of(context).border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppTheme.of(context).textMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 5),
          // Animated counter — smoothly tweens to the new value
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            builder: (_, animated, __) => Text(
              formatCurrency(animated, symbol),
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: highlight ? color : AppTheme.of(context).textPrimary,
              ),
            ),
          ),
          if (trend != null) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(
                  trendUp ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 9,
                  color: trendColor,
                ),
                const SizedBox(width: 2),
                Text(
                  '${trend!.abs().toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: trendColor,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Stack Card (home list item) ─────────────────────────────────────────────

class StackMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const StackMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.of(context).cardAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: AppTheme.of(context).textMuted,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppTheme.of(context).textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Header ──────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.of(context).textMuted,
              letterSpacing: 1,
            ),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Row(
                children: [
                  const Icon(Icons.add, size: 14, color: AppTheme.accent),
                  const SizedBox(width: 2),
                  Text(
                    actionLabel!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accent,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Stat Card (detail screen) ───────────────────────────────────────────────

class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.of(context).card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.of(context).border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: valueColor),
          const SizedBox(height: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppTheme.of(context).textMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Skeleton / shimmer loading placeholder ───────────────────────────────────

class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppTheme.of(context).cardAlt,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      ),
    );
  }
}

/// Full-screen loading skeleton shown while stacks are loading.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const SkeletonBox(width: 120, height: 14, radius: 6),
              const SizedBox(height: 6),
              const SkeletonBox(width: 200, height: 22, radius: 6),
              const SizedBox(height: 20),
              // Summary row
              Row(children: [
                Expanded(child: SkeletonBox(width: double.infinity, height: 56, radius: 14)),
                const SizedBox(width: 8),
                Expanded(child: SkeletonBox(width: double.infinity, height: 56, radius: 14)),
                const SizedBox(width: 8),
                Expanded(child: SkeletonBox(width: double.infinity, height: 56, radius: 14)),
              ]),
              const SizedBox(height: 24),
              const SkeletonBox(width: 80, height: 10, radius: 4),
              const SizedBox(height: 12),
              // Stack cards
              for (int i = 0; i < 3; i++) ...[
                SkeletonBox(width: double.infinity, height: 108, radius: 18),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Primary Button ──────────────────────────────────────────────────────────

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? textColor;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? AppTheme.accent,
          foregroundColor: textColor ?? Colors.white,
          disabledBackgroundColor: (color ?? AppTheme.accent).withOpacity(0.3),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          textStyle: TextStyle(
            fontFamily: 'Sora',
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

// ─── Category Chip ───────────────────────────────────────────────────────────

class CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

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
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? AppTheme.accent : AppTheme.of(context).textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Empty State ─────────────────────────────────────────────────────────────

/// Full-screen (centered) empty state with emoji icon, title, subtitle, and
/// an optional single CTA button. Matches the QBSE visual pattern:
/// illustration → one-line explanation → single button.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onButton;

  /// Optional secondary link shown below the primary button.
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const EmptyState({
    super.key,
    this.icon = Icons.bolt_outlined,
    required this.title,
    required this.subtitle,
    this.buttonLabel,
    this.onButton,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Emoji icon in gradient circle
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accent.withOpacity(0.2),
                    AppTheme.accent.withOpacity(0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppTheme.accent.withOpacity(0.25), width: 1.5),
              ),
              child: Center(
                child: Icon(icon, size: 36, color: AppTheme.accent),
              ),
            ),
            const SizedBox(height: 22),

            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            // Subtitle
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.of(context).textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            // Primary CTA
            if (buttonLabel != null) ...[
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child:
                    PrimaryButton(label: buttonLabel!, onPressed: onButton),
              ),
            ],

            // Secondary link
            if (secondaryLabel != null) ...[
              const SizedBox(height: 14),
              GestureDetector(
                onTap: onSecondary,
                child: Text(
                  secondaryLabel!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: AppTheme.accent,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
