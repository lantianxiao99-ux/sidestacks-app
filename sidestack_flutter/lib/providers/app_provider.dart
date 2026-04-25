import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart' as models;
import '../services/notification_service.dart';
import '../services/purchase_service.dart';
import '../services/bank_service.dart';
import '../services/demo_service.dart';
import 'package:intl/intl.dart';

// Lifetime-premium is granted server-side by setting `lifetimePremium: true`
// on the user's Firestore doc (users/{uid}). Never hard-code emails here.

const _uuid = Uuid();

// ── Analytics section IDs ─────────────────────────────────────────────────────

const kAnalyticsSectionKpi = 'kpi';
const kAnalyticsSectionInsights = 'insights';
const kAnalyticsSectionProfitTrend = 'profitTrend';
const kAnalyticsSectionIncomeExpense = 'incomeExpense';
const kAnalyticsSectionCumulative = 'cumulative';
const kAnalyticsSectionIncomeBreakdown = 'incomeBreakdown';
const kAnalyticsSectionExpenseBreakdown = 'expenseBreakdown';
const kAnalyticsSectionTopCategories = 'topCategories';
const kAnalyticsSectionDayOfWeek = 'dayOfWeek';
const kAnalyticsSectionStackComparison = 'stackComparison';
const kAnalyticsSectionMarginOverTime = 'marginOverTime';
const kAnalyticsSectionExpenseRatio = 'expenseRatio';
const kAnalyticsSectionProjection = 'projection';
const kAnalyticsSectionYoY = 'yoy';
const kAnalyticsSectionTax = 'tax';
// ── Premium analytics sections ───────────────────────────────────────────────
const kAnalyticsSectionInsightEngine     = 'insightEngine';
const kAnalyticsSectionClientIntelligence = 'clientIntelligence';
const kAnalyticsSectionHourlyRate        = 'hourlyRate';
const kAnalyticsSectionGoalVelocity      = 'goalVelocity';
const kAnalyticsSectionAnomalies         = 'anomalies';

const kDefaultAnalyticsOrder = [
  // Premium insight engine — most valuable, top of screen
  kAnalyticsSectionInsightEngine,       // prescriptive actions, not just observations
  kAnalyticsSectionGoalVelocity,        // am I on pace to hit my monthly goal?
  // Core
  kAnalyticsSectionInsights,            // plain-English summary
  kAnalyticsSectionProfitTrend,         // am I growing?
  kAnalyticsSectionIncomeExpense,       // what's my income/expense ratio?
  kAnalyticsSectionIncomeBreakdown,
  kAnalyticsSectionExpenseBreakdown,
  kAnalyticsSectionAnomalies,           // spending / income anomalies vs prior period
  kAnalyticsSectionClientIntelligence,  // client revenue intelligence
  kAnalyticsSectionHourlyRate,          // effective hourly rate per stack
  kAnalyticsSectionTax,                 // actionable: set aside this much
  kAnalyticsSectionProjection,          // motivating: you're on track for £X
  // Advanced — hidden by default, user can enable via layout editor
  kAnalyticsSectionKpi,
  kAnalyticsSectionCumulative,
  kAnalyticsSectionTopCategories,
  kAnalyticsSectionStackComparison,
  kAnalyticsSectionMarginOverTime,
  kAnalyticsSectionExpenseRatio,
  kAnalyticsSectionDayOfWeek,
  kAnalyticsSectionYoY,
];

// Sections hidden by default — only shown if user explicitly enables them
const kDefaultAnalyticsHidden = {
  kAnalyticsSectionKpi,
  kAnalyticsSectionCumulative,
  kAnalyticsSectionTopCategories,
  kAnalyticsSectionStackComparison,
  kAnalyticsSectionMarginOverTime,
  kAnalyticsSectionExpenseRatio,
  kAnalyticsSectionDayOfWeek,
  kAnalyticsSectionYoY,
};

// ── Milestones ────────────────────────────────────────────────────────────────

const _kMilestones = [1.0, 10.0, 50.0, 100.0, 500.0, 1000.0, 5000.0, 10000.0];

class AppProvider extends ChangeNotifier {
  List<models.SideStack> _stacks = [];
  List<models.Invoice> _invoices = [];
  bool _stacksLoaded = false;
  bool _invoicesLoaded = false;
  bool _prefsLoaded = false;
  bool _hasSeenOnboarding = false;
  bool _isPremium = false;
  String _currencySymbol = 'A\$';
  String? _profilePictureUrl;
  String? _abn; // Australian Business Number
  String? _username; // optional handle/nickname chosen by the user
  String? _firestoreDisplayName; // display name stored in users/{uid} doc
  bool _useRealName = true; // true = show real name, false = show username
  double? _monthlyIncomeGoal; // user-set monthly income target
  ThemeMode _themeMode = ThemeMode.dark;
  String? _error;
  String? _userId;
  StreamSubscription? _subscription;
  StreamSubscription? _invoicesSubscription;
  List<String> _analyticsOrder = kDefaultAnalyticsOrder;
  Set<String> _analyticsHidden = Set.from(kDefaultAnalyticsHidden);
  double _taxRate = 0.20; // default 20%
  bool _biometricLock = false;
  bool _dailyReminderEnabled = true;
  bool _weeklyReminderEnabled = false;
  Set<String> _claimedMilestones = {};
  double? _pendingMilestone; // set when a new milestone is crossed
  // Paywall trigger key — set at meaningful moments to nudge free users to upgrade.
  // Values: 'third_stack', 'revenue_1k'
  String? _pendingPaywallTrigger;
  // Guard against duplicate recurring-transaction generation in one session
  final Set<String> _recurringProcessed = {};
  // Guard against firing the same notification checks more than once per session
  bool _notifChecksRan = false;
  // Daily logging streak
  int _currentStreak = 0;
  int _longestStreak = 0;
  String? _lastLoggedDateKey; // 'yyyy-MM-dd'
  // Bank connection state
  bool _bankConnected = false;
  String _bankInstitution = '';
  // Bank smart rules: normalised merchant name → stack ID
  Map<String, String> _bankRules = {};
  // Demo mode — shows sample data until user creates a real stack
  bool _isDemoMode = false;
  // Region / tax settings
  bool _isAustraliaMode = true; // AU users get GST, BAS, ABN, ATO mileage
  double _customMileageRate = 0.67; // non-AU default (IRS 2024 rate in USD)
  bool _mileageUseKm = true; // true = km, false = miles

  // ── Getters ──────────────────────────────────────────────────────────────

  /// All stacks, including archived ones (used for analytics + history).
  List<models.SideStack> get allStacks => _stacks;

  /// Non-archived stacks shown on the dashboard.
  List<models.SideStack> get stacks =>
      _stacks.where((s) => !s.isArchived).toList();

  /// Archived stacks, shown in profile settings.
  List<models.SideStack> get archivedStacks =>
      _stacks.where((s) => s.isArchived).toList();

  bool get isLoaded => _stacksLoaded && _prefsLoaded;

  // ── Invoices getters ──────────────────────────────────────────────────────

  List<models.Invoice> get invoices => _invoices
      .where((inv) => inv.status != models.InvoiceStatus.draft)
      .toList()
    ..sort((a, b) => b.issuedDate.compareTo(a.issuedDate));

  List<models.Invoice> get allInvoices => List.unmodifiable(_invoices);
  bool get invoicesLoaded => _invoicesLoaded;

  double get totalOutstanding => _invoices
      .where((inv) => inv.status != models.InvoiceStatus.paid && inv.status != models.InvoiceStatus.draft)
      .fold(0.0, (sum, inv) => sum + inv.amount);

  int get overdueInvoiceCount => _invoices
      .where((inv) => inv.isOverdue && inv.status != models.InvoiceStatus.paid)
      .length;

  double get totalPaid => _invoices
      .where((inv) => inv.status == models.InvoiceStatus.paid)
      .fold(0.0, (sum, inv) => sum + inv.amount);

  bool get hasSeenOnboarding => _hasSeenOnboarding;
  bool get isPremium => _isPremium;
  String get currencySymbol => _currencySymbol;
  String? get profilePictureUrl => _profilePictureUrl;
  String? get abn => _abn;
  String? get username => _username;
  /// Display name stored in Firestore — fallback when Firebase Auth displayName
  /// is null (e.g. Apple sign-in after the first session, or a linked account).
  String? get firestoreDisplayName => _firestoreDisplayName;
  bool get useRealName => _useRealName;
  double? get monthlyIncomeGoal => _monthlyIncomeGoal;

  /// Progress toward this month's income goal (0.0–1.0+). Null if no goal set.
  double? get goalProgress {
    if (_monthlyIncomeGoal == null || _monthlyIncomeGoal! <= 0) return null;
    return thisMonthTotals['income']! / _monthlyIncomeGoal!;
  }

  /// Days remaining in the current calendar month.
  int get goalDaysLeft {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0);
    return lastDay.day - now.day;
  }

  /// Projected FY income based on year-to-date income and months elapsed.
  /// Uses the Australian tax year (Jul 1 → Jun 30).
  double get fyIncomeProjection {
    final now = DateTime.now();
    final fyStart = now.month >= 7
        ? DateTime(now.year, 7, 1)
        : DateTime(now.year - 1, 7, 1);

    // Count months elapsed since FY start (at least 1 to avoid division by zero)
    final monthsElapsed = ((now.year - fyStart.year) * 12 +
        (now.month - fyStart.month) + 1).clamp(1, 12);

    double fyIncome = 0;
    for (final tx in allTransactions) {
      if (tx.type == models.TransactionType.income &&
          !tx.date.isBefore(fyStart)) {
        fyIncome += tx.amount;
      }
    }

    return fyIncome / monthsElapsed * 12;
  }

  /// Last FY total income — for comparing projection against.
  double get lastFyIncome {
    final now = DateTime.now();
    final thisFyStart = now.month >= 7
        ? DateTime(now.year, 7, 1)
        : DateTime(now.year - 1, 7, 1);
    final lastFyStart = DateTime(thisFyStart.year - 1, 7, 1);

    double total = 0;
    for (final tx in allTransactions) {
      if (tx.type == models.TransactionType.income &&
          !tx.date.isBefore(lastFyStart) &&
          tx.date.isBefore(thisFyStart)) {
        total += tx.amount;
      }
    }
    return total;
  }

  ThemeMode get themeMode => _themeMode;
  String? get error => _error;
  List<String> get analyticsOrder => _analyticsOrder;
  Set<String> get analyticsHidden => _analyticsHidden;
  double get taxRate => _taxRate;
  double get taxSetAsideRate => _taxRate;

  String taxSetAsideMessage(double amount) {
    if (_taxRate <= 0) return '';
    final setAside = amount * _taxRate;
    return 'Set aside $_currencySymbol${setAside.toStringAsFixed(2)} for taxes';
  }

  bool get biometricLock => _biometricLock;
  bool get dailyReminderEnabled => _dailyReminderEnabled;
  bool get weeklyReminderEnabled => _weeklyReminderEnabled;
  double? get pendingMilestone => _pendingMilestone;
  String? get pendingPaywallTrigger => _pendingPaywallTrigger;
  bool get bankConnected => _bankConnected;
  String get bankInstitution => _bankInstitution;
  Map<String, String> get bankRules => Map.unmodifiable(_bankRules);
  bool get isDemoMode => _isDemoMode;
  bool get isAustraliaMode => _isAustraliaMode;
  double get customMileageRate => _customMileageRate;
  bool get mileageUseKm => _mileageUseKm;
  int get currentStreak => _currentStreak;
  int get longestStreak => _longestStreak;

  // ── Month-over-month helpers ─────────────────────────────────────────────

  /// Returns {income, expenses, profit} totals for [year]/[month].
  Map<String, double> _monthTotals(int year, int month) {
    double income = 0, expenses = 0;
    for (final tx in allTransactions) {
      if (tx.date.year == year && tx.date.month == month) {
        if (tx.type == models.TransactionType.income) {
          income += tx.amount;
        } else {
          expenses += tx.amount;
        }
      }
    }
    return {'income': income, 'expenses': expenses, 'profit': income - expenses};
  }

  Map<String, double> get thisMonthTotals {
    final now = DateTime.now();
    return _monthTotals(now.year, now.month);
  }

  Map<String, double> get lastMonthTotals {
    final now = DateTime.now();
    final last = DateTime(now.year, now.month - 1);
    return _monthTotals(last.year, last.month);
  }

  /// Returns trend % change for a value vs last month. Null if no last-month data.
  double? monthTrend(double current, double previous) {
    if (previous == 0) return null;
    return ((current - previous) / previous) * 100;
  }

  /// All users can add unlimited stacks. The premium gate is on transaction history depth.
  bool get canAddStack => true;

  /// Free users can see the last 3 months of transactions. Premium unlocks full history.
  bool get canViewFullHistory => _isPremium;

  /// Filter a list of transactions to the visible window.
  /// Free users: last 90 days. Premium: all time.
  List<models.Transaction> visibleTransactions(List<models.Transaction> txs) {
    if (_isPremium) return txs;
    final cutoff = DateTime.now().subtract(const Duration(days: 90));
    return txs.where((t) => t.date.isAfter(cutoff)).toList();
  }

  /// Number of transactions older than 90 days that are hidden for free users.
  int get hiddenTransactionCount {
    if (_isPremium) return 0;
    final cutoff = DateTime.now().subtract(const Duration(days: 90));
    return allTransactions.where((t) => t.date.isBefore(cutoff)).length;
  }

  // ── Aggregated financials (all non-archived stacks) ─────────────────────

  double get totalIncome => stacks.fold(0.0, (a, s) => a + s.totalIncome);
  double get totalExpenses => stacks.fold(0.0, (a, s) => a + s.totalExpenses);
  double get totalProfit => totalIncome - totalExpenses;
  double get totalMargin =>
      totalIncome > 0 ? (totalProfit / totalIncome) * 100 : 0;

  List<models.Transaction> get allTransactions =>
      stacks.expand((s) => s.transactions).toList();

  /// Effective hourly rate across all stacks (income / total hours worked).
  /// Returns null if no hours have been logged anywhere.
  double? get effectiveHourlyRate {
    double totalInc = 0, totalHours = 0;
    for (final tx in allTransactions) {
      if (tx.type == models.TransactionType.income && tx.hoursWorked != null && tx.hoursWorked! > 0) {
        totalInc += tx.amount;
        totalHours += tx.hoursWorked!;
      }
    }
    return totalHours > 0 ? totalInc / totalHours : null;
  }

  // ── Hustle health score (0–100) ──────────────────────────────────────────

  double get hustleHealthScore {
    final txs = allTransactions;
    if (txs.isEmpty || totalIncome == 0) return 0;

    // Build monthly income/expense map
    final monthly = <String, Map<String, double>>{};
    for (final tx in txs) {
      final key =
          '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}';
      monthly.putIfAbsent(key, () => {'income': 0, 'expense': 0});
      if (tx.type == models.TransactionType.income) {
        monthly[key]!['income'] = monthly[key]!['income']! + tx.amount;
      } else {
        monthly[key]!['expense'] = monthly[key]!['expense']! + tx.amount;
      }
    }
    final months = monthly.keys.toList()..sort();

    // Margin score (0–30): profit margin as % of 100
    final marginScore = (totalMargin.clamp(0, 100) / 100) * 30;

    // Efficiency score (0–25): lower expense ratio = higher score
    final expRatio =
        totalIncome > 0 ? (totalExpenses / totalIncome).clamp(0.0, 1.0) : 1.0;
    final efficiencyScore = (1 - expRatio) * 25;

    // Consistency score (0–25): % of months that were profitable
    final profitableMonths = months
        .where((m) => monthly[m]!['income']! > monthly[m]!['expense']!)
        .length;
    final consistencyScore =
        months.isNotEmpty ? (profitableMonths / months.length) * 25 : 0;

    // Growth score (0–20): compare first-half avg vs second-half avg income
    double growthScore = 10; // neutral baseline
    if (months.length >= 4) {
      final half = months.length ~/ 2;
      final firstAvg = months
              .sublist(0, half)
              .fold<double>(0, (a, m) => a + monthly[m]!['income']!) /
          half;
      final secondAvg = months
              .sublist(half)
              .fold<double>(0, (a, m) => a + monthly[m]!['income']!) /
          (months.length - half);
      if (firstAvg > 0) {
        final growthRate = ((secondAvg - firstAvg) / firstAvg).clamp(-1.0, 1.0);
        growthScore = 10 + growthRate * 10;
      }
    }

    return (marginScore + efficiencyScore + consistencyScore + growthScore)
        .clamp(0, 100);
  }

  String get healthScoreLabel {
    final score = hustleHealthScore;
    if (score >= 80) return 'Crushing It';
    if (score >= 60) return 'On the Rise';
    if (score >= 40) return 'Building';
    if (score >= 20) return 'Getting Started';
    return 'Just Launched';
  }

  /// Breakdown of the four health score components so the UI can show detail.
  /// Returns a map with keys: margin, efficiency, consistency, growth.
  /// Values are the raw scores (max: margin=30, efficiency=25, consistency=25, growth=20).
  Map<String, double> get healthScoreBreakdown {
    final txs = allTransactions;
    if (txs.isEmpty || totalIncome == 0) {
      return {'margin': 0, 'efficiency': 0, 'consistency': 0, 'growth': 10};
    }

    final monthly = <String, Map<String, double>>{};
    for (final tx in txs) {
      final key =
          '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}';
      monthly.putIfAbsent(key, () => {'income': 0, 'expense': 0});
      if (tx.type == models.TransactionType.income) {
        monthly[key]!['income'] = monthly[key]!['income']! + tx.amount;
      } else {
        monthly[key]!['expense'] = monthly[key]!['expense']! + tx.amount;
      }
    }
    final months = monthly.keys.toList()..sort();

    final marginScore = (totalMargin.clamp(0, 100) / 100) * 30;
    final expRatio =
        totalIncome > 0 ? (totalExpenses / totalIncome).clamp(0.0, 1.0) : 1.0;
    final efficiencyScore = (1 - expRatio) * 25;
    final profitableMonths = months
        .where((m) => monthly[m]!['income']! > monthly[m]!['expense']!)
        .length;
    final consistencyScore =
        months.isNotEmpty ? (profitableMonths / months.length) * 25 : 0.0;

    double growthScore = 10;
    if (months.length >= 4) {
      final half = months.length ~/ 2;
      final firstAvg = months
              .sublist(0, half)
              .fold<double>(0, (a, m) => a + monthly[m]!['income']!) /
          half;
      final secondAvg = months
              .sublist(half)
              .fold<double>(0, (a, m) => a + monthly[m]!['income']!) /
          (months.length - half);
      if (firstAvg > 0) {
        final growthRate =
            ((secondAvg - firstAvg) / firstAvg).clamp(-1.0, 1.0);
        growthScore = 10 + growthRate * 10;
      }
    }

    return {
      'margin': marginScore,
      'efficiency': efficiencyScore,
      'consistency': consistencyScore,
      'growth': growthScore,
    };
  }

  // ── Top stack this month ─────────────────────────────────────────────────

  /// Returns the non-archived stack with the highest income in the current
  /// calendar month, or null if there are no income transactions this month.
  /// Result: {stack, income, lastMonthIncome, growth}
  Map<String, dynamic>? get topStackThisMonth {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1);

    models.SideStack? best;
    double bestIncome = 0;
    double bestLastMonthIncome = 0;

    for (final stack in stacks) {
      double thisInc = 0;
      double prevInc = 0;
      for (final tx in stack.transactions) {
        if (tx.type != models.TransactionType.income) continue;
        if (tx.date.year == now.year && tx.date.month == now.month) {
          thisInc += tx.amount;
        } else if (tx.date.year == lastMonth.year &&
            tx.date.month == lastMonth.month) {
          prevInc += tx.amount;
        }
      }
      if (thisInc > bestIncome) {
        bestIncome = thisInc;
        bestLastMonthIncome = prevInc;
        best = stack;
      }
    }

    if (best == null || bestIncome == 0) return null;

    final growth = bestLastMonthIncome > 0
        ? ((bestIncome - bestLastMonthIncome) / bestLastMonthIncome) * 100
        : null;

    return {
      'stack': best,
      'income': bestIncome,
      'lastMonthIncome': bestLastMonthIncome,
      'growth': growth,
    };
  }

  // ── Auth ─────────────────────────────────────────────────────────────────

  void onAuthChanged(String? userId) {
    if (userId == _userId) return;
    _userId = userId;
    _subscription?.cancel();
    _invoicesSubscription?.cancel();
    _stacks = [];
    _invoices = [];
    _stacksLoaded = false;
    _invoicesLoaded = false;
    _prefsLoaded = false;
    _hasSeenOnboarding = false;
    _isPremium = false;
    _profilePictureUrl = null;
    _firestoreDisplayName = null;
    _analyticsOrder = kDefaultAnalyticsOrder;
    _analyticsHidden = Set.from(kDefaultAnalyticsHidden);
    _taxRate = 0.20;
    _biometricLock = false;
    _dailyReminderEnabled = true;
    _weeklyReminderEnabled = false;
    _claimedMilestones = {};
    _pendingMilestone = null;
    _pendingPaywallTrigger = null;
    _error = null;
    _notifChecksRan = false;
    _bankConnected = false;
    _bankInstitution = '';
    _isDemoMode = false;
    _monthlyIncomeGoal = null;
    _isAustraliaMode = true;
    _customMileageRate = 0.67;
    _mileageUseKm = true;
    _currentStreak = 0;
    _longestStreak = 0;
    _lastLoggedDateKey = null;
    notifyListeners();
    if (userId != null) {
      // Log the user into RevenueCat so purchases are tied to their account
      unawaited(PurchaseService.instance.logIn(userId));
      _listenToStacks(userId);
      _listenToInvoices(userId);
      _loadPrefs(userId);
    } else {
      // Revert RevenueCat to anonymous mode on sign-out
      unawaited(PurchaseService.instance.logOut());
    }
  }

  // ── Preferences ───────────────────────────────────────────────────────────

  Future<void> _loadPrefs(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    _hasSeenOnboarding =
        _hasSeenOnboarding || (prefs.getBool('onboarding_$userId') ?? false);
    _isPremium = prefs.getBool('premium_$userId') ?? false;
    // Verify against RevenueCat — this is the authoritative source for
    // subscription status. We do it after setting the local cache so the UI
    // is not blocked. lifetimePremium is read from Firestore below.
    PurchaseService.instance.isPremium.then((rcPremium) {
      if (rcPremium && !_isPremium) {
        _isPremium = true;
        prefs.setBool('premium_$userId', true);
        notifyListeners();
      } else if (!rcPremium && _isPremium) {
        // RC says no active subscription — only revoke if Firestore hasn't
        // granted lifetime access. That check happens in the Firestore block
        // below; if _isPremium is still true after that it came from
        // lifetimePremium and should not be revoked here.
        // We intentionally do nothing here and let the Firestore read below
        // be the final word on lifetime status.
      }
    });
    _currencySymbol = prefs.getString('currency_$userId') ?? 'A\$';
    _abn = prefs.getString('abn_$userId');
    _username = prefs.getString('username_$userId');
    _useRealName = prefs.getBool('useRealName_$userId') ?? true;
    _monthlyIncomeGoal = prefs.getDouble('monthlyGoal_$userId');
    _profilePictureUrl = prefs.getString('profilePicUrl_$userId');

    final savedOrder = prefs.getStringList('analyticsOrder_$userId');
    if (savedOrder != null && savedOrder.isNotEmpty) {
      // Merge: keep saved order but add any newly added section IDs at end
      final merged = [
        ...savedOrder,
        ...kDefaultAnalyticsOrder.where((id) => !savedOrder.contains(id)),
      ];
      _analyticsOrder = merged;
    }

    final savedHidden = prefs.getStringList('analyticsHidden_$userId');
    if (savedHidden != null) {
      _analyticsHidden = savedHidden.toSet();
    }

    _taxRate = (prefs.getDouble('taxRate_$userId') ?? 0.20).clamp(0.0, 0.90);
    _biometricLock = prefs.getBool('biometricLock_$userId') ?? false;
    _dailyReminderEnabled = prefs.getBool('dailyReminder_$userId') ?? true;
    _weeklyReminderEnabled = prefs.getBool('weeklyReminder_$userId') ?? false;

    final savedMilestones = prefs.getStringList('milestones_$userId') ?? [];
    _claimedMilestones = savedMilestones.toSet();

    // Load streak data
    _currentStreak = prefs.getInt('streak_current_$userId') ?? 0;
    _longestStreak = prefs.getInt('streak_longest_$userId') ?? 0;
    _lastLoggedDateKey = prefs.getString('streak_lastDate_$userId');

    // Load bank smart rules (merchant → stackId)
    final ruleKeys = prefs.getStringList('bankRuleKeys_$userId') ?? [];
    final ruleVals = prefs.getStringList('bankRuleVals_$userId') ?? [];
    _bankRules = {
      for (int i = 0; i < ruleKeys.length && i < ruleVals.length; i++)
        ruleKeys[i]: ruleVals[i],
    };

    // Region / mileage settings
    _isAustraliaMode = prefs.getBool('isAustraliaMode_$userId') ?? true;
    _customMileageRate = prefs.getDouble('customMileageRate_$userId') ?? 0.67;
    _mileageUseKm = prefs.getBool('mileageUseKm_$userId') ?? true;

    // Theme mode — persisted globally (not per user)
    final savedTheme = prefs.getString('themeMode');
    if (savedTheme != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == savedTheme,
        orElse: () => ThemeMode.dark,
      );
    }

    // Always read the users/{uid} document for authoritative premium status,
    // onboarding flag, profile picture, and bank connection.
    // NOTE: __meta__ (users/{uid}/stacks/__meta__) is a Firestore-reserved
    // document ID pattern and always throws invalid-argument — never use it.
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;

        // Onboarding
        if (!_hasSeenOnboarding && userData['hasSeenOnboarding'] == true) {
          _hasSeenOnboarding = true;
          await prefs.setBool('onboarding_$userId', true);
        }

        // Profile picture
        if (_profilePictureUrl == null && userData['profilePictureUrl'] != null) {
          _profilePictureUrl = userData['profilePictureUrl'] as String;
          await prefs.setString('profilePicUrl_$userId', _profilePictureUrl!);
        }

        // Premium — `lifetimePremium` is set server-side only (Firestore rules
        // block clients from writing it). RevenueCat handles subscriptions.
        final hasLifetime = userData['lifetimePremium'] == true;
        final hasPurchasedPremium = userData['premium'] == true;
        if (!_isPremium && (hasLifetime || hasPurchasedPremium)) {
          _isPremium = true;
          await prefs.setBool('premium_$userId', true);
        }
        // Revoke if neither source grants premium
        if (_isPremium && !hasLifetime && !hasPurchasedPremium) {
          _isPremium = false;
          await prefs.setBool('premium_$userId', false);
        }

        // Display name — stored by auth flows so it persists across providers
        final storedName = userData['displayName'] as String?;
        if (storedName != null && storedName.isNotEmpty) {
          _firestoreDisplayName = storedName;
        }

        // Bank connection
        _bankConnected = userData['bank_connected'] == true;
        _bankInstitution = userData['bank_institution'] as String? ?? '';
      }
    } catch (e) {
      debugPrint('AppProvider Firestore user doc error: $e');
    }

    // If username wasn't in SharedPreferences, look it up from Firestore.
    // This covers the case where the user completed OAuth setup (which writes
    // to the 'usernames' collection) but the app was reinstalled or prefs cleared.
    if (_username == null) {
      try {
        final unameSnap = await FirebaseFirestore.instance
            .collection('usernames')
            .where('uid', isEqualTo: userId)
            .limit(1)
            .get();
        if (unameSnap.docs.isNotEmpty) {
          final uname = unameSnap.docs.first.data()['username'] as String?;
          if (uname != null && uname.isNotEmpty) {
            _username = uname;
            await prefs.setString('username_$userId', uname);
          }
        }
      } catch (e) {
        debugPrint('AppProvider username Firestore lookup error: $e');
      }
    }

    _prefsLoaded = true;
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    if (_userId == null) return;
    _hasSeenOnboarding = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_$_userId', true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .set({'hasSeenOnboarding': true}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('completeOnboarding Firestore error: $e');
    }
  }

  /// Called by the paywall after a successful RevenueCat purchase to sync
  /// the local premium flag.
  Future<void> upgradeToPremium() async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('premium_$_userId', true);
    _isPremium = true;
    notifyListeners();
  }

  /// Restores prior purchases via RevenueCat.
  /// Returns true if the premium entitlement is now active.
  Future<bool> restorePremium() async {
    if (_userId == null) return false;
    final restored = await PurchaseService.instance.restore();
    if (restored) await upgradeToPremium();
    return restored;
  }

  /// Force-reads Firestore to refresh premium status.
  /// Use this when the user reports premium isn't activating after an admin grant.
  Future<void> refreshPremiumStatus() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final prefs = await SharedPreferences.getInstance();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final hasLifetime = userData['lifetimePremium'] == true;
        final hasPurchasedPremium = userData['premium'] == true;
        final shouldBePremium = hasLifetime || hasPurchasedPremium;
        if (shouldBePremium != _isPremium) {
          _isPremium = shouldBePremium;
          await prefs.setBool('premium_$userId', _isPremium);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('refreshPremiumStatus error: $e');
    }
  }

  // ── Bank connection ───────────────────────────────────────────────────────

  /// Called after TrueLayer redirects back with a code.
  /// Exchanges the code server-side and updates bank connection state.
  Future<void> handleBankCallback(String code, String state) async {
    try {
      final institutionName = await BankService.instance.exchangeCode(
        code: code,
        state: state,
      );
      await onBankConnected(institutionName);
    } catch (e) {
      debugPrint('handleBankCallback error: $e');
      rethrow;
    }
  }

  /// Remembers that [merchantName] should be assigned to [stackId].
  /// Called after the user confirms a bank import so next time the stack
  /// is pre-filled automatically.
  Future<void> saveBankRule(String merchantName, String stackId) async {
    if (_userId == null) return;
    final key = merchantName.toLowerCase().trim();
    _bankRules[key] = stackId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('bankRuleKeys_$_userId', _bankRules.keys.toList());
    await prefs.setStringList('bankRuleVals_$_userId', _bankRules.values.toList());
  }

  /// Looks up the remembered stack for a merchant name, or returns null.
  String? stackForMerchant(String merchantName) =>
      _bankRules[merchantName.toLowerCase().trim()];

  /// Deletes a single smart rule for [merchantName].
  Future<void> deleteBankRule(String merchantName) async {
    if (_userId == null) return;
    final key = merchantName.toLowerCase().trim();
    _bankRules.remove(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('bankRuleKeys_$_userId', _bankRules.keys.toList());
    await prefs.setStringList('bankRuleVals_$_userId', _bankRules.values.toList());
    notifyListeners();
  }

  /// Called once the bank is successfully connected.
  Future<void> onBankConnected(String institutionName) async {
    _bankConnected = true;
    _bankInstitution = institutionName;
    notifyListeners();
  }

  /// Removes the bank connection — calls Cloud Function then clears local state.
  Future<void> disconnectBank() async {
    if (_userId == null) return;
    // Fetch the item_id from Firestore to pass to the function
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('bank_connections')
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final itemId = snap.docs.first.id;
        // Import lazily to avoid a hard dependency if Cloud Functions not set up
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .collection('bank_connections')
            .doc(itemId)
            .delete();
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .set({'bank_connected': false, 'bank_institution': null},
              SetOptions(merge: true));
    } catch (_) {}

    _bankConnected = false;
    _bankInstitution = '';
    notifyListeners();
  }

  // ── Demo mode ──────────────────────────────────────────────────────────────

  /// Inject sample data so new users can explore the app before adding real data.
  void enterDemoMode() {
    if (_isDemoMode) return;
    _isDemoMode = true;
    _stacks = DemoService.instance.buildDemoStacks();
    _stacksLoaded = true;
    notifyListeners();
  }

  /// Clear demo data and return to the real (empty) state.
  /// Call this when the user creates their first real stack.
  void exitDemoMode() {
    if (!_isDemoMode) return;
    _isDemoMode = false;
    _stacks = [];
    _stacksLoaded = false;
    notifyListeners();
    if (_userId != null) {
      _listenToStacks(_userId!);
    }
  }

  Future<void> setCurrencySymbol(String symbol) async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency_$_userId', symbol);
    _currencySymbol = symbol;
    notifyListeners();
  }

  Future<void> setMonthlyIncomeGoal(double? goal) async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (goal == null || goal <= 0) {
      await prefs.remove('monthlyGoal_$_userId');
      _monthlyIncomeGoal = null;
    } else {
      await prefs.setDouble('monthlyGoal_$_userId', goal);
      _monthlyIncomeGoal = goal;
    }
    notifyListeners();
  }

  Future<void> setIsAustraliaMode(bool value) async {
    _isAustraliaMode = value;
    notifyListeners();
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAustraliaMode_$_userId', value);
  }

  Future<void> setCustomMileageRate(double rate) async {
    _customMileageRate = rate.clamp(0.0, 10.0);
    notifyListeners();
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('customMileageRate_$_userId', _customMileageRate);
  }

  Future<void> setMileageUseKm(bool useKm) async {
    _mileageUseKm = useKm;
    notifyListeners();
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mileageUseKm_$_userId', useKm);
  }

  Future<void> setUsername(String value) async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await prefs.remove('username_$_userId');
      _username = null;
    } else {
      await prefs.setString('username_$_userId', trimmed);
      _username = trimmed;
    }
    notifyListeners();
  }

  Future<void> setUseRealName(bool value) async {
    _useRealName = value;
    notifyListeners();
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useRealName_$_userId', value);
  }

  Future<void> setAbn(String abn) async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final trimmed = abn.trim();
    if (trimmed.isEmpty) {
      await prefs.remove('abn_$_userId');
      _abn = null;
    } else {
      await prefs.setString('abn_$_userId', trimmed);
      _abn = trimmed;
    }
    notifyListeners();
  }

  Future<void> setAnalyticsOrder(List<String> order) async {
    _analyticsOrder = List.from(order);
    notifyListeners();
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('analyticsOrder_$_userId', order);
  }

  Future<void> setTaxRate(double rate) async {
    _taxRate = rate.clamp(0.0, 0.90);
    notifyListeners();
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('taxRate_$_userId', _taxRate);
  }

  Future<void> setDailyReminder(bool value) async {
    _dailyReminderEnabled = value;
    notifyListeners();
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dailyReminder_$_userId', value);
  }

  Future<void> setWeeklyReminder(bool value) async {
    _weeklyReminderEnabled = value;
    notifyListeners();
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('weeklyReminder_$_userId', value);
  }

  Future<void> setBiometricLock(bool value) async {
    _biometricLock = value;
    notifyListeners();
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometricLock_$_userId', _biometricLock);
  }

  Future<void> setAnalyticsHidden(Set<String> hidden) async {
    _analyticsHidden = Set.from(hidden);
    notifyListeners();
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'analyticsHidden_$_userId', hidden.toList());
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.name);
  }

  Future<void> updateProfilePicture(String url) async {
    _profilePictureUrl = url;
    notifyListeners();
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profilePicUrl_$_userId', url);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .set({'profilePictureUrl': url}, SetOptions(merge: true));
    } catch (_) {}
  }

  // ── Milestones ────────────────────────────────────────────────────────────

  void _checkMilestones() {
    final profit = totalProfit;
    for (final m in _kMilestones) {
      final key = 'ms_${m.toStringAsFixed(0)}';
      if (profit >= m && !_claimedMilestones.contains(key)) {
        _claimedMilestones.add(key);
        _pendingMilestone = m;
        _saveMilestones();
        // At the £1k revenue milestone, also nudge free users to upgrade.
        // The celebration fires first; the paywall trigger fires immediately after.
        if (m >= 1000 && !isPremium && _pendingPaywallTrigger == null) {
          _pendingPaywallTrigger = 'revenue_1k';
        }
        break; // show one at a time
      }
    }
  }

  void clearPendingMilestone() {
    _pendingMilestone = null;
    // No notifyListeners — caller handles UI
  }

  void clearPendingPaywallTrigger() {
    _pendingPaywallTrigger = null;
    // No notifyListeners — caller handles UI
  }

  // ── Streak ────────────────────────────────────────────────────────────────

  void _updateStreak() {
    final now = DateTime.now();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    if (_lastLoggedDateKey == todayKey) return; // already logged today

    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayKey =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    if (_lastLoggedDateKey == yesterdayKey) {
      _currentStreak += 1;
    } else {
      _currentStreak = 1; // streak broken or first log
    }

    if (_currentStreak > _longestStreak) _longestStreak = _currentStreak;
    _lastLoggedDateKey = todayKey;
    _saveStreak();
  }

  Future<void> _saveStreak() async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('streak_current_$_userId', _currentStreak);
    await prefs.setInt('streak_longest_$_userId', _longestStreak);
    if (_lastLoggedDateKey != null) {
      await prefs.setString('streak_lastDate_$_userId', _lastLoggedDateKey!);
    }
  }

  Future<void> _saveMilestones() async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'milestones_$_userId', _claimedMilestones.toList());
  }

  // ── Firestore ─────────────────────────────────────────────────────────────

  void _listenToStacks(String userId) {
    _subscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('stacks')
        .orderBy('startDate', descending: true)
        .snapshots()
        .listen(
      (snapshot) async {
        try {
          final stacks = <models.SideStack>[];
          for (final doc in snapshot.docs) {
            final stackData = doc.data();
            final stack = models.SideStack.fromJson({
              ...stackData,
              'id': doc.id,
              'transactions': <Map<String, dynamic>>[],
              // Ensure optional field is present for fromJson
              if (!stackData.containsKey('monthlyGoalAmount')) 'monthlyGoalAmount': null,
            });
            final txSnap = await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('stacks')
                .doc(doc.id)
                .collection('transactions')
                .orderBy('date', descending: true)
                .get();
            stack.transactions.addAll(
              txSnap.docs.map(
                  (t) => models.Transaction.fromJson({...t.data(), 'id': t.id})),
            );
            stacks.add(stack);
          }
          // If user had demo mode on but now has real stacks, exit demo
          if (_isDemoMode && stacks.isNotEmpty) {
            _isDemoMode = false;
          }
          _stacks = stacks;
          _stacksLoaded = true;
          _error = null;
          // Auto-generate due recurring transactions (runs once per session per key)
          _processRecurringTransactions();
          // Run notification health checks once per session
          _runNotificationChecks();
          if (stacks.isNotEmpty && !_hasSeenOnboarding) {
            _hasSeenOnboarding = true;
            SharedPreferences.getInstance().then((p) {
              if (_userId != null) p.setBool('onboarding_$_userId', true);
            });
          }
          notifyListeners();
        } catch (e) {
          _error = 'Failed to load data. Check your connection.';
          _stacksLoaded = true;
          notifyListeners();
        }
      },
      onError: (e) {
        debugPrint('_listenToStacks error: $e');
        _error = 'Failed to load data. Check your connection.';
        _stacksLoaded = true;
        notifyListeners();
      },
    );
  }

  void retryLoad() {
    if (_userId == null) return;
    _error = null;
    _stacksLoaded = false;
    notifyListeners();
    _subscription?.cancel();
    _listenToStacks(_userId!);
  }

  CollectionReference get _stacksRef => FirebaseFirestore.instance
      .collection('users')
      .doc(_userId)
      .collection('stacks');

  // ── SideStack CRUD ────────────────────────────────────────────────────────

  Future<models.SideStack> addSideStack({
    required String name,
    String? businessName,
    String? description,
    required models.HustleType hustleType,
    double? goalAmount,
    double? monthlyGoalAmount,
  }) async {
    // Exit demo mode when user creates their first real stack
    if (_isDemoMode) {
      _isDemoMode = false;
      _stacks = [];
    }
    final id = _uuid.v4();
    final stack = models.SideStack(
      id: id,
      name: name,
      businessName: businessName,
      description: description,
      startDate: DateTime.now(),
      hustleType: hustleType,
      goalAmount: goalAmount,
      monthlyGoalAmount: monthlyGoalAmount,
    );
    await _stacksRef.doc(id).set({
      'name': name,
      'businessName': businessName,
      'description': description,
      'startDate': stack.startDate.toIso8601String(),
      'hustleType': hustleType.name,
      'goalAmount': goalAmount,
      'monthlyGoalAmount': monthlyGoalAmount,
      'isArchived': false,
    });
    // Milestone paywall: nudge free users who hit 3 stacks to go Pro
    final activeCount = _stacks.where((s) => !s.isArchived).length + 1;
    if (!isPremium && activeCount == 3 && _pendingPaywallTrigger == null) {
      _pendingPaywallTrigger = 'third_stack';
    }
    return stack;
  }

  Future<void> updateSideStack(
    String id, {
    String? name,
    String? businessName,
    bool clearBusinessName = false,
    String? description,
    models.HustleType? hustleType,
    double? goalAmount,
    bool clearGoal = false,
    double? monthlyGoalAmount,
    bool clearMonthlyGoal = false,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (clearBusinessName) {
      updates['businessName'] = null;
    } else if (businessName != null) {
      updates['businessName'] = businessName;
    }
    if (description != null) updates['description'] = description;
    if (hustleType != null) updates['hustleType'] = hustleType.name;
    if (clearGoal) {
      updates['goalAmount'] = null;
    } else if (goalAmount != null) {
      updates['goalAmount'] = goalAmount;
    }
    if (clearMonthlyGoal) {
      updates['monthlyGoalAmount'] = null;
    } else if (monthlyGoalAmount != null) {
      updates['monthlyGoalAmount'] = monthlyGoalAmount;
    }
    await _stacksRef.doc(id).update(updates);
    final i = _stacks.indexWhere((s) => s.id == id);
    if (i != -1) {
      if (name != null) _stacks[i].name = name;
      if (clearBusinessName) {
        _stacks[i].businessName = null;
      } else if (businessName != null) {
        _stacks[i].businessName = businessName;
      }
      if (description != null) _stacks[i].description = description;
      if (hustleType != null) _stacks[i].hustleType = hustleType;
      if (clearGoal) {
        _stacks[i].goalAmount = null;
      } else if (goalAmount != null) {
        _stacks[i].goalAmount = goalAmount;
      }
      if (clearMonthlyGoal) {
        _stacks[i].monthlyGoalAmount = null;
      } else if (monthlyGoalAmount != null) {
        _stacks[i].monthlyGoalAmount = monthlyGoalAmount;
      }
      notifyListeners();
    }
  }

  Future<void> archiveSideStack(String id) async {
    await _stacksRef.doc(id).update({'isArchived': true});
    final i = _stacks.indexWhere((s) => s.id == id);
    if (i != -1) {
      _stacks[i].isArchived = true;
      notifyListeners();
    }
  }

  Future<void> unarchiveSideStack(String id) async {
    await _stacksRef.doc(id).update({'isArchived': false});
    final i = _stacks.indexWhere((s) => s.id == id);
    if (i != -1) {
      _stacks[i].isArchived = false;
      notifyListeners();
    }
  }

  Future<void> deleteSideStack(String id) async {
    // Cascade-delete all transactions in the subcollection first (Firestore
    // does NOT delete subcollections automatically when the parent is deleted).
    final txSnap =
        await _stacksRef.doc(id).collection('transactions').get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in txSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_stacksRef.doc(id));
    await batch.commit();
  }

  // ── Transaction CRUD ───────────────────────────────────────────────────────

  Future<void> addTransaction({
    required String stackId,
    required models.TransactionType type,
    required double amount,
    required DateTime date,
    required String category,
    String? notes,
    bool isRecurring = false,
    models.RecurrenceInterval? recurrenceInterval,
    String? clientName,
    double? hoursWorked,
    String? receiptUrl,
    String? pregenId, // optional pre-generated ID (used to avoid stranded uploads)
    bool includesGst = false,
  }) async {
    final id = pregenId ?? _uuid.v4();
    await _stacksRef.doc(stackId).collection('transactions').doc(id).set({
      'type': type.name,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
      'notes': notes,
      'isRecurring': isRecurring,
      'recurrenceInterval': recurrenceInterval?.name,
      'clientName': clientName,
      'hoursWorked': hoursWorked,
      'receiptUrl': receiptUrl,
      'includesGst': includesGst,
    });
    final tx = models.Transaction(
      id: id, type: type, amount: amount,
      date: date, category: category, notes: notes,
      isRecurring: isRecurring, recurrenceInterval: recurrenceInterval,
      clientName: clientName, hoursWorked: hoursWorked, receiptUrl: receiptUrl,
      includesGst: includesGst,
    );
    final si = _stacks.indexWhere((s) => s.id == stackId);
    if (si != -1) {
      _stacks[si].transactions.insert(0, tx);
      _checkMilestones();
      _updateStreak();
      // After the 5th transaction, free users have enough data to see real
      // analytics for the first time. Nudge them to unlock the full suite.
      if (!isPremium && _pendingPaywallTrigger == null) {
        final total = allTransactions.length;
        if (total == 5) {
          _pendingPaywallTrigger = 'analytics_unlocked';
        }
      }
      notifyListeners();
    }
  }

  Future<void> updateTransaction({
    required String stackId,
    required String txId,
    required models.TransactionType type,
    required double amount,
    required DateTime date,
    required String category,
    String? notes,
    bool isRecurring = false,
    models.RecurrenceInterval? recurrenceInterval,
    String? clientName,
    double? hoursWorked,
    String? receiptUrl,
    bool includesGst = false,
  }) async {
    await _stacksRef
        .doc(stackId)
        .collection('transactions')
        .doc(txId)
        .update({
      'type': type.name,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
      'notes': notes,
      'isRecurring': isRecurring,
      'recurrenceInterval': recurrenceInterval?.name,
      'clientName': clientName,
      'hoursWorked': hoursWorked,
      'receiptUrl': receiptUrl,
      'includesGst': includesGst,
    });
    final si = _stacks.indexWhere((s) => s.id == stackId);
    if (si != -1) {
      final ti = _stacks[si].transactions.indexWhere((t) => t.id == txId);
      if (ti != -1) {
        _stacks[si].transactions[ti] = models.Transaction(
          id: txId, type: type, amount: amount,
          date: date, category: category, notes: notes,
          isRecurring: isRecurring, recurrenceInterval: recurrenceInterval,
          clientName: clientName, hoursWorked: hoursWorked, receiptUrl: receiptUrl,
          includesGst: includesGst,
        );
        _checkMilestones();
        notifyListeners();
      }
    }
  }

  Future<void> deleteTransaction(String stackId, String txId) async {
    await _stacksRef
        .doc(stackId)
        .collection('transactions')
        .doc(txId)
        .delete();
    final si = _stacks.indexWhere((s) => s.id == stackId);
    if (si != -1) {
      _stacks[si].transactions.removeWhere((t) => t.id == txId);
      notifyListeners();
    }
  }

  /// Bulk-import a list of transactions into a stack (from bank CSV).
  Future<int> importTransactions(
      String stackId, List<models.Transaction> txs) async {
    int imported = 0;
    final batch = FirebaseFirestore.instance.batch();
    final ref = _stacksRef.doc(stackId).collection('transactions');
    for (final tx in txs) {
      batch.set(ref.doc(tx.id), tx.toJson());
      imported++;
    }
    await batch.commit();
    final si = _stacks.indexWhere((s) => s.id == stackId);
    if (si != -1) {
      _stacks[si].transactions.addAll(txs);
      notifyListeners();
    }
    return imported;
  }

  /// Upload a receipt image to Firebase Storage and return its download URL.
  Future<String?> uploadReceipt(String stackId, String txId, File file) async {
    try {
      final uid = _userId;
      if (uid == null) return null;
      final ref = FirebaseStorage.instance
          .ref('receipts/$uid/$stackId/$txId.jpg');
      await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('uploadReceipt error: $e');
      return null;
    }
  }

  models.SideStack? getStack(String id) {
    try {
      return _stacks.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Notification health checks ────────────────────────────────────────────

  Future<void> _runNotificationChecks() async {
    if (_notifChecksRan) return;
    _notifChecksRan = true;
    try {
      final svc = NotificationService.instance;
      final now = DateTime.now();

      // 1. Dormant stack alerts
      final summaries = <Map<String, dynamic>>[];
      for (final stack in _stacks) {
        if (stack.isArchived || stack.transactions.isEmpty) continue;
        final latest = stack.transactions
            .map((t) => t.date)
            .reduce((a, b) => a.isAfter(b) ? a : b);
        summaries.add({
          'name': stack.name,
          'daysSinceActivity': now.difference(latest).inDays,
        });
      }
      await svc.checkDormantStacks(summaries);

      // 2. Expense spike check (all stacks combined, current month vs avg)
      final allTx = allTransactions;
      if (allTx.isNotEmpty) {
        final monthly = <String, double>{};
        for (final tx in allTx.where(
            (t) => t.type == models.TransactionType.expense)) {
          final key =
              '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}';
          monthly[key] = (monthly[key] ?? 0) + tx.amount;
        }
        final sortedKeys = monthly.keys.toList()..sort();
        if (sortedKeys.length >= 3) {
          final thisKey =
              '${now.year}-${now.month.toString().padLeft(2, '0')}';
          final prevKeys =
              sortedKeys.where((k) => k != thisKey).toList();
          final avg = prevKeys.fold<double>(
                  0, (a, k) => a + (monthly[k] ?? 0)) /
              prevKeys.length;
          final thisMonthExp = monthly[thisKey] ?? 0;
          await svc.checkExpenseSpike(
            stackName: 'SideStacks',
            thisMonthExpenses: thisMonthExp,
            avgExpenses: avg,
            symbol: currencySymbol,
          );
        }
      }

      // 3. Overdue invoice alerts
      final overdueList = <Map<String, dynamic>>[];
      for (final inv in _invoices) {
        if (inv.isOverdue) {
          overdueList.add({
            'invoiceNumber': inv.invoiceNumber,
            'clientName': inv.clientName,
            'amount': inv.amount,
            'symbol': currencySymbol,
            'daysOverdue': inv.daysOverdue,
          });
        }
      }
      await svc.checkOverdueInvoices(overdueList);

      // 4. Weekly digest — schedule if enabled (reschedule each session with fresh data)
      if (_weeklyReminderEnabled && allTx.isNotEmpty) {
        final weekAgo = now.subtract(const Duration(days: 7));
        double weekIncome = 0, weekExpenses = 0;
        for (final tx in allTx) {
          if (tx.date.isAfter(weekAgo)) {
            if (tx.type == models.TransactionType.income) {
              weekIncome += tx.amount;
            } else {
              weekExpenses += tx.amount;
            }
          }
        }

        // Find best-earning stack this week
        String? bestStackName;
        double bestProfit = double.negativeInfinity;
        for (final stack in _stacks) {
          if (stack.isArchived) continue;
          double sp = 0;
          for (final tx in stack.transactions) {
            if (!tx.date.isAfter(weekAgo)) continue;
            sp += tx.type == models.TransactionType.income
                ? tx.amount
                : -tx.amount;
          }
          if (sp > bestProfit) {
            bestProfit = sp;
            bestStackName = stack.name;
          }
        }

        // Hourly rate this week (if any hours logged)
        double weekHours = 0;
        for (final tx in allTx) {
          if (tx.date.isAfter(weekAgo) &&
              tx.type == models.TransactionType.income &&
              tx.hoursWorked != null) {
            weekHours += tx.hoursWorked!;
            weekIncome; // already counted above
          }
        }
        final weekHourlyRate =
            (weekHours > 0 && weekIncome > 0) ? weekIncome / weekHours : null;

        await svc.scheduleWeeklySummary(
          weeklyIncome: weekIncome,
          weeklyExpenses: weekExpenses,
          symbol: currencySymbol,
          bestStackName: bestStackName,
          weeklyHourlyRate: weekHourlyRate,
        );
      }
    } catch (e) {
      debugPrint('_runNotificationChecks error: $e');
    }
  }

  // ── Recurring transaction auto-generation ─────────────────────────────────

  /// Called after stacks are loaded. For each active recurring transaction,
  /// checks whether a new entry is due for the current period and creates it.
  Future<void> _processRecurringTransactions() async {
    final now = DateTime.now();
    for (final stack in _stacks) {
      if (stack.isArchived) continue;

      // Group recurring txs by their "template key" (type + category + interval)
      final groups = <String, List<models.Transaction>>{};
      for (final tx in stack.transactions) {
        if (!tx.isRecurring) continue;
        final key =
            '${stack.id}|${tx.type.name}|${tx.category}|${tx.recurrenceInterval?.name ?? 'monthly'}';
        groups.putIfAbsent(key, () => []).add(tx);
      }

      for (final entry in groups.entries) {
        final key = entry.key;
        if (_recurringProcessed.contains(key)) continue;
        _recurringProcessed.add(key);

        final txs = entry.value..sort((a, b) => b.date.compareTo(a.date));
        final latest = txs.first;
        final interval =
            latest.recurrenceInterval ?? models.RecurrenceInterval.monthly;

        // Build list of due dates between the latest entry and now.
        // Cap at 6 periods to avoid flooding on first launch after a long gap.
        final dueDates = <DateTime>[];
        var cursor = latest.date;
        const maxBackfill = 6;
        while (dueDates.length < maxBackfill) {
          final next = interval == models.RecurrenceInterval.monthly
              ? DateTime(cursor.year, cursor.month + 1, cursor.day)
              : cursor.add(const Duration(days: 7));
          if (next.isAfter(now)) break;
          dueDates.add(next);
          cursor = next;
        }

        // Create a transaction for each missed period with the correct date.
        for (final dueDate in dueDates) {
          await addTransaction(
            stackId: stack.id,
            type: latest.type,
            amount: latest.amount,
            date: dueDate,
            category: latest.category,
            notes: latest.notes,
            isRecurring: true,
            recurrenceInterval: latest.recurrenceInterval,
          );
        }
      }
    }
  }

  // ── CSV export ────────────────────────────────────────────────────────────

  /// Build CSV content for a single stack (or all active stacks if null).
  String buildCsv({String? stackId}) {
    final fmt = DateFormat('yyyy-MM-dd');
    final rows = <String>[
      'Stack,Date,Type,Category,Amount,Notes,Recurring,Interval',
    ];
    final targets = stackId != null
        ? _stacks.where((s) => s.id == stackId).toList()
        : _stacks.where((s) => !s.isArchived).toList();

    for (final stack in targets) {
      final sorted = [...stack.transactions]
        ..sort((a, b) => a.date.compareTo(b.date));
      for (final tx in sorted) {
        String esc(String? s) {
          if (s == null) return '';
          if (s.contains(',') || s.contains('"') || s.contains('\n')) {
            return '"${s.replaceAll('"', '""')}"';
          }
          return s;
        }

        rows.add([
          esc(stack.name),
          fmt.format(tx.date),
          tx.type.name,
          esc(tx.category),
          tx.amount.toStringAsFixed(2),
          esc(tx.notes),
          tx.isRecurring ? 'yes' : 'no',
          tx.recurrenceInterval?.name ?? '',
        ].join(','));
      }
    }
    return rows.join('\n');
  }

  // ── Invoices Firestore listener ───────────────────────────────────────────

  CollectionReference get _invoicesRef =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('invoices');

  void _listenToInvoices(String userId) {
    _invoicesSubscription?.cancel();
    _invoicesSubscription = _invoicesRef.snapshots().listen((snap) {
      _invoices = snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return models.Invoice.fromJson(data);
      }).toList();
      // Auto-mark overdue (catches sent AND viewed invoices past their due date)
      for (final inv in _invoices) {
        if (inv.isOverdue &&
            (inv.status == models.InvoiceStatus.sent ||
             inv.status == models.InvoiceStatus.viewed)) {
          inv.status = models.InvoiceStatus.overdue;
          _invoicesRef.doc(inv.id).update({'status': 'overdue'});
        }
      }
      _invoicesLoaded = true;
      notifyListeners();
    });
  }

  // ── Invoice CRUD ───────────────────────────────────────────────────────────

  Future<models.Invoice> createInvoice({
    required String clientName,
    String clientEmail = '',
    required double amount,
    String? description,
    required DateTime dueDate,
    String? paymentLink,
    required String stackId,
    String? invoiceNumber,
  }) async {
    final id = const Uuid().v4();
    final invoice = models.Invoice(
      id: id,
      clientName: clientName,
      clientEmail: clientEmail,
      amount: amount,
      description: description,
      status: models.InvoiceStatus.sent,
      issuedDate: DateTime.now(),
      dueDate: dueDate,
      paymentLink: paymentLink,
      stackId: stackId,
      invoiceNumber: invoiceNumber,
    );
    _invoices.add(invoice);
    notifyListeners();
    if (_userId != null) {
      final json = invoice.toJson();
      json.remove('id');
      await _invoicesRef.doc(id).set(json);
    }
    return invoice;
  }

  Future<void> updateInvoiceStatus(String id, models.InvoiceStatus status) async {
    final idx = _invoices.indexWhere((inv) => inv.id == id);
    if (idx == -1) return;
    _invoices[idx].status = status;
    if (status == models.InvoiceStatus.paid) {
      _invoices[idx].paidDate = DateTime.now();
    }
    notifyListeners();
    if (_userId != null) {
      final updates = <String, dynamic>{'status': status.name};
      if (status == models.InvoiceStatus.paid) {
        updates['paidDate'] = DateTime.now().toIso8601String();
      }
      await _invoicesRef.doc(id).update(updates);
    }
  }

  Future<void> deleteInvoice(String id) async {
    _invoices.removeWhere((inv) => inv.id == id);
    notifyListeners();
    if (_userId != null) {
      await _invoicesRef.doc(id).delete();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _invoicesSubscription?.cancel();
    super.dispose();
  }
}
