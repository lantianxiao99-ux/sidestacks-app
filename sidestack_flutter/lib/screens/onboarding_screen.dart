import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/create_stack_sheet.dart';

// ─── Slide data ───────────────────────────────────────────────────────────────

class _Slide {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> bullets;
  final Color accent;
  final Widget preview;

  const _Slide({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.bullets,
    required this.accent,
    required this.preview,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  int _page = 0;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // Personalisation state (slides 4 & 5)
  HustleType? _selectedHustleType;
  final _monthlyGoalCtrl = TextEditingController();

  static const int _totalPages = 5; // 3 info + 2 personalisation

  late final List<_Slide> _slides = [
    _Slide(
      icon: Icons.psychology_outlined,
      title: 'Still guessing\nwhat you make?',
      subtitle:
          'Most side hustlers have no idea if they\'re actually profitable after costs, time, and tax. SideStacks changes that.',
      bullets: [
        'One place for every hustle you run',
        'Real profit, not just revenue',
        'Know your numbers in under 60 seconds',
      ],
      accent: AppTheme.accent,
      preview: const _WelcomePreview(),
    ),
    _Slide(
      icon: Icons.payments_outlined,
      title: 'Log money\nin seconds',
      subtitle:
          'No spreadsheets. No faff. Tap once, done. Your books stay clean without the pain.',
      bullets: [
        'Add income or expenses instantly',
        'Attach receipts straight from your camera roll',
        'Set recurring transactions and forget them',
      ],
      accent: AppTheme.green,
      preview: const _TransactionPreview(),
    ),
    _Slide(
      icon: Icons.bar_chart_outlined,
      title: 'Know exactly\nwhere you stand',
      subtitle:
          'Real charts, margin data, and tax estimates. No surprises at the end of the year.',
      bullets: [
        'Profit trend, projections & tax estimates',
        'Invoice clients and get paid faster',
        'Compare every hustle side-by-side',
      ],
      accent: AppTheme.amber,
      preview: const _AnalyticsPreview(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeCtrl.dispose();
    _monthlyGoalCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _totalPages - 1) {
      _fadeCtrl.reverse().then((_) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOut,
        );
        _fadeCtrl.forward();
      });
    } else {
      _finish();
    }
  }

  void _finish() {
    final double? goal = double.tryParse(_monthlyGoalCtrl.text.trim());
    context.read<AppProvider>().completeOnboarding();
    showCreateStackSheet(
      context,
      initialHustleType: _selectedHustleType,
      initialMonthlyGoal: goal,
    );
  }

  void _skip() {
    context.read<AppProvider>().completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    // For personalisation pages (index >= _slides.length) use last info slide's accent
    final slide = _slides[_page.clamp(0, _slides.length - 1)];
    return Scaffold(
      backgroundColor: AppTheme.of(context).background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page counter
                  Text(
                    '${_page + 1} of $_totalPages',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.of(context).textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  // Skip
                  GestureDetector(
                    onTap: _skip,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 4),
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.of(context).textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Slide content ─────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) {
                  setState(() => _page = i);
                  _fadeCtrl.reset();
                  _fadeCtrl.forward();
                },
                itemCount: _totalPages,
                itemBuilder: (context, i) {
                  if (i < _slides.length) return _SlideView(slide: _slides[i]);
                  if (i == 3) {
                    return _HustleTypeSlide(
                      selected: _selectedHustleType,
                      onSelect: (t) =>
                          setState(() => _selectedHustleType = t),
                    );
                  }
                  // i == 4
                  return _MonthlyGoalSlide(
                    controller: _monthlyGoalCtrl,
                    hustleType: _selectedHustleType,
                  );
                },
              ),
            ),

            // ── Dot indicators ────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _totalPages,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _page == i ? 24 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _page == i
                        ? slide.accent
                        : AppTheme.of(context).border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── CTA button ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: _page < _slides.length && _page == _slides.length - 1
                        ? [slide.accent, slide.accent.withOpacity(0.7)]
                        : [AppTheme.accent, AppTheme.accent.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _next,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          _page == _totalPages - 1
                              ? 'Start tracking for free'
                              : _page == 3
                                  ? (_selectedHustleType == null
                                      ? 'Skip this step'
                                      : 'Continue →')
                                  : 'Continue',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ─── Individual slide ─────────────────────────────────────────────────────────

class _SlideView extends StatelessWidget {
  final _Slide slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Glowing emoji hero ──────────────────────────────────────────
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glow
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        slide.accent.withOpacity(0.28),
                        slide.accent.withOpacity(0),
                      ],
                    ),
                  ),
                ),
                // Icon box
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: slide.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: slide.accent.withOpacity(0.35), width: 1.5),
                  ),
                  child: Center(
                    child: Icon(
                      slide.icon,
                      size: 40,
                      color: slide.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Title ───────────────────────────────────────────────────────
          Text(
            slide.title,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AppTheme.of(context).textPrimary,
              letterSpacing: -0.7,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),

          // ── Subtitle ────────────────────────────────────────────────────
          Text(
            slide.subtitle,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.of(context).textSecondary,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 22),

          // ── Feature bullets ─────────────────────────────────────────────
          ...slide.bullets.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: slide.accent.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(Icons.check,
                            size: 10, color: slide.accent),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        b,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.of(context).textPrimary,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 20),

          // ── Mini preview card ────────────────────────────────────────────
          slide.preview,
        ],
      ),
    );
  }
}

// ─── Preview widgets ──────────────────────────────────────────────────────────

class _PreviewCard extends StatelessWidget {
  final Widget child;
  const _PreviewCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.of(context).card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.of(context).border),
      ),
      child: child,
    );
  }
}

// Slide 1 preview — three mini stack metric tiles
class _WelcomePreview extends StatelessWidget {
  const _WelcomePreview();

  @override
  Widget build(BuildContext context) {
    return _PreviewCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your SideStacks',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.of(context).textMuted)),
          const SizedBox(height: 10),
          Row(children: [
            _MiniMetric(label: 'Income', value: '\$4,200', color: AppTheme.green),
            const SizedBox(width: 8),
            _MiniMetric(label: 'Expenses', value: '\$980', color: AppTheme.red),
            const SizedBox(width: 8),
            _MiniMetric(label: 'Profit', value: '\$3,220', color: AppTheme.accent),
          ]),
        ],
      ),
    );
  }
}

// Slide 2 preview — a couple of mock transactions
class _TransactionPreview extends StatelessWidget {
  const _TransactionPreview();

  @override
  Widget build(BuildContext context) {
    return _PreviewCard(
      child: Column(children: [
        _MockTx(label: 'Client payment', amount: '+\$850', color: AppTheme.green),
        Divider(height: 16, color: AppTheme.of(context).border),
        _MockTx(label: 'Adobe CC', amount: '-\$55', color: AppTheme.red),
        Divider(height: 16, color: AppTheme.of(context).border),
        _MockTx(label: 'Etsy sale', amount: '+\$120', color: AppTheme.green),
      ]),
    );
  }
}

// Slide 3 preview — a tiny bar graph mockup
class _AnalyticsPreview extends StatelessWidget {
  const _AnalyticsPreview();

  static const _bars = [0.4, 0.65, 0.5, 0.8, 0.6, 0.9];
  static const _months = ['Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Jan'];

  @override
  Widget build(BuildContext context) {
    return _PreviewCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Monthly Profit',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.of(context).textMuted)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_bars.length, (i) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: _bars[i] * 60,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.25 + _bars[i] * 0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(_months[i],
                      style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.of(context).textMuted)),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniMetric(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    color: AppTheme.of(context).textMuted,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 3),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

class _MockTx extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;
  const _MockTx(
      {required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
            color == AppTheme.green
                ? Icons.arrow_downward
                : Icons.arrow_upward,
            size: 14,
            color: color),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.of(context).textPrimary)),
      ),
      Text(amount,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color)),
    ]);
  }
}

// ─── Personalisation: HustleType slide ───────────────────────────────────────

class _HustleTypeSlide extends StatelessWidget {
  final HustleType? selected;
  final ValueChanged<HustleType> onSelect;

  const _HustleTypeSlide({
    required this.selected,
    required this.onSelect,
  });

  static const _descriptions = {
    HustleType.freelance: 'Design, dev, writing, consulting…',
    HustleType.reselling: 'eBay, Vinted, car boot, thrift…',
    HustleType.business: 'Products, services, local trade…',
    HustleType.content: 'YouTube, TikTok, newsletters…',
    HustleType.other: 'Something different entirely',
  };

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: AppTheme.accent.withOpacity(0.35), width: 1.5),
              ),
              child: const Center(
                  child: Icon(Icons.track_changes_outlined, size: 40, color: AppTheme.accent)),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'What kind of\nhustle are you running?',
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: theme.textPrimary,
                height: 1.2,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 6),
          Text(
            'We\'ll tailor your first SideStack to match.',
            style: TextStyle(
                fontSize: 14,
                color: theme.textSecondary,
                height: 1.5),
          ),
          const SizedBox(height: 20),
          ...HustleType.values.map((t) {
            final active = selected == t;
            return GestureDetector(
              onTap: () => onSelect(t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: active
                      ? AppTheme.accent.withOpacity(0.12)
                      : theme.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: active
                        ? AppTheme.accent
                        : theme.border.withOpacity(0.5),
                    width: active ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(t.icon, size: 22,
                        color: active ? AppTheme.accent : theme.textSecondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.label,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: active
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: active
                                    ? AppTheme.accent
                                    : theme.textPrimary),
                          ),
                          Text(
                            _descriptions[t] ?? '',
                            style: TextStyle(
                                fontSize: 11,
                                color: theme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (active)
                      const Icon(Icons.check_circle_rounded,
                          color: AppTheme.accent, size: 18),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Personalisation: Monthly goal slide ─────────────────────────────────────

class _MonthlyGoalSlide extends StatelessWidget {
  final TextEditingController controller;
  final HustleType? hustleType;

  const _MonthlyGoalSlide({
    required this.controller,
    this.hustleType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final typeLabel =
        hustleType != null ? hustleType!.label.toLowerCase() : 'hustle';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: AppTheme.green.withOpacity(0.35), width: 1.5),
              ),
              child: const Center(
                  child: Icon(Icons.savings_outlined, size: 40, color: AppTheme.green)),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'What\'s your\nmonthly target?',
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: theme.textPrimary,
                height: 1.2,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 6),
          Text(
            'We\'ll track your $typeLabel income against this goal each month.',
            style: TextStyle(
                fontSize: 14,
                color: theme.textSecondary,
                height: 1.5),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                  RegExp(r'^\d+\.?\d{0,2}')),
            ],
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
                letterSpacing: -0.5),
            decoration: InputDecoration(
              prefixText: '  ',
              hintText: '0',
              hintStyle: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                  color: theme.textMuted),
              filled: true,
              fillColor: theme.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                    color: theme.border.withOpacity(0.4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: AppTheme.accent, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 18),
              suffixText: '/month',
              suffixStyle: TextStyle(
                  fontSize: 14,
                  color: theme.textMuted,
                  fontWeight: FontWeight.w400),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.green.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline, size: 16, color: AppTheme.green),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'You can always update or remove this goal later in your stack settings.',
                    style: TextStyle(
                        fontSize: 12,
                        color: theme.textSecondary,
                        height: 1.4),
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
