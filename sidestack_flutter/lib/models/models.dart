import 'dart:convert';
import 'package:flutter/material.dart';

enum HustleType { reselling, freelance, business, content, other }

extension HustleTypeExtension on HustleType {
  String get label {
    switch (this) {
      case HustleType.reselling: return 'Reselling';
      case HustleType.freelance: return 'Freelance';
      case HustleType.business: return 'Business';
      case HustleType.content: return 'Content';
      case HustleType.other: return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case HustleType.reselling: return Icons.sell_outlined;
      case HustleType.freelance: return Icons.laptop_outlined;
      case HustleType.business: return Icons.storefront_outlined;
      case HustleType.content:  return Icons.photo_camera_outlined;
      case HustleType.other:    return Icons.bolt_outlined;
    }
  }

  static HustleType fromString(String s) {
    return HustleType.values.firstWhere(
      (e) => e.name == s,
      orElse: () => HustleType.other,
    );
  }
}

enum TransactionType { income, expense }

enum RecurrenceInterval { weekly, monthly }

extension RecurrenceIntervalExtension on RecurrenceInterval {
  String get label {
    switch (this) {
      case RecurrenceInterval.weekly: return 'Weekly';
      case RecurrenceInterval.monthly: return 'Monthly';
    }
  }

  static RecurrenceInterval? fromString(String? s) {
    if (s == null) return null;
    return RecurrenceInterval.values.firstWhere(
      (e) => e.name == s,
      orElse: () => RecurrenceInterval.monthly,
    );
  }
}

class Transaction {
  final String id;
  final TransactionType type;
  final double amount;
  final DateTime date;
  final String category;
  final String? notes;
  final bool isRecurring;
  final RecurrenceInterval? recurrenceInterval;
  // Premium fields
  final String? clientName;
  final double? hoursWorked;
  final String? receiptUrl;
  // GST (Australian)
  /// Whether this transaction amount already includes 10% GST.
  final bool includesGst;
  /// Pre-computed GST component = amount / 11. Non-null only when [includesGst] is true.
  double? get gstAmount => includesGst ? amount / 11 : null;
  /// Amount ex-GST (useful for BAS reporting).
  double get amountExGst => includesGst ? amount - (amount / 11) : amount;

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.category,
    this.notes,
    this.isRecurring = false,
    this.recurrenceInterval,
    this.clientName,
    this.hoursWorked,
    this.receiptUrl,
    this.includesGst = false,
  });

  /// Effective hourly rate for income transactions with hours logged.
  double? get hourlyRate =>
      (type == TransactionType.income && hoursWorked != null && hoursWorked! > 0)
          ? amount / hoursWorked!
          : null;

  Map<String, dynamic> toJson() => {
    'id': id,
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
  };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'],
    type: json['type'] == 'income' ? TransactionType.income : TransactionType.expense,
    amount: (json['amount'] as num).toDouble(),
    date: DateTime.parse(json['date']),
    category: json['category'],
    notes: json['notes'],
    isRecurring: json['isRecurring'] ?? false,
    recurrenceInterval: RecurrenceIntervalExtension.fromString(json['recurrenceInterval']),
    clientName: json['clientName'],
    hoursWorked: (json['hoursWorked'] as num?)?.toDouble(),
    receiptUrl: json['receiptUrl'],
    includesGst: json['includesGst'] as bool? ?? false,
  );
}

class SideStack {
  final String id;
  String name;
  /// Optional trading/business name shown on invoices and exports.
  /// If set, replaces the user's full name as the sender on all documents.
  String? businessName;
  String? description;
  final DateTime startDate;
  HustleType hustleType;
  List<Transaction> transactions;
  double? goalAmount;
  double? monthlyGoalAmount;
  bool isArchived;

  SideStack({
    required this.id,
    required this.name,
    this.businessName,
    this.description,
    required this.startDate,
    required this.hustleType,
    List<Transaction>? transactions,
    this.goalAmount,
    this.monthlyGoalAmount,
    this.isArchived = false,
  }) : transactions = transactions ?? [];

  double get totalIncome => transactions
      .where((t) => t.type == TransactionType.income)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalExpenses => transactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get netProfit => totalIncome - totalExpenses;

  double get profitMargin => totalIncome > 0 ? (netProfit / totalIncome) * 100 : 0;

  /// Total hours worked across all income transactions.
  double get totalHoursWorked => transactions
      .where((t) => t.type == TransactionType.income && t.hoursWorked != null)
      .fold(0.0, (sum, t) => sum + t.hoursWorked!);

  /// Effective hourly rate across the stack (income / hours). Null if no hours logged.
  double? get effectiveHourlyRate {
    final hours = totalHoursWorked;
    return hours > 0 ? totalIncome / hours : null;
  }

  /// Per-client revenue map, sorted descending.
  Map<String, double> get clientRevenue {
    final map = <String, double>{};
    for (final t in transactions.where(
        (t) => t.type == TransactionType.income && t.clientName != null)) {
      final name = t.clientName!.trim();
      if (name.isEmpty) continue;
      map[name] = (map[name] ?? 0) + t.amount;
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in sorted) e.key: e.value};
  }

  /// Progress toward monthly goal (0.0 – 1.0). Returns 0 if no goal is set.
  double get goalProgress {
    if (goalAmount == null || goalAmount! <= 0) return 0;
    return (totalIncome / goalAmount!).clamp(0.0, 1.0);
  }

  /// Income earned in the current calendar month.
  double get thisMonthIncome {
    final now = DateTime.now();
    return transactions
        .where((t) =>
            t.type == TransactionType.income &&
            t.date.year == now.year &&
            t.date.month == now.month)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Progress toward monthly goal this month (0.0 – 1.0).
  double get monthlyGoalProgress {
    if (monthlyGoalAmount == null || monthlyGoalAmount! <= 0) return 0;
    return (thisMonthIncome / monthlyGoalAmount!).clamp(0.0, 1.0);
  }

  /// Pace indicator: >1.0 means ahead, <1.0 means behind, null if no goal.
  double? get goalPaceRatio {
    if (monthlyGoalAmount == null || monthlyGoalAmount! <= 0) return null;
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysPassed = now.day;
    final expectedProgress = daysPassed / daysInMonth;
    if (expectedProgress <= 0) return null;
    return monthlyGoalProgress / expectedProgress;
  }

  /// Human-readable pace message. Null if no monthly goal set.
  String? goalPaceMessage(String symbol) {
    final ratio = goalPaceRatio;
    if (ratio == null || monthlyGoalAmount == null) return null;
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft = daysInMonth - now.day;
    final remaining = (monthlyGoalAmount! - thisMonthIncome).clamp(0, double.infinity);

    if (thisMonthIncome >= monthlyGoalAmount!) {
      return 'Goal hit! ${symbol}${thisMonthIncome.toStringAsFixed(0)} / ${symbol}${monthlyGoalAmount!.toStringAsFixed(0)}';
    }
    if (ratio >= 1.0) {
      return 'Ahead of pace';
    } else if (daysLeft > 0) {
      final needed = remaining / daysLeft;
      return 'Behind pace · need ${symbol}${needed.toStringAsFixed(0)}/day';
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'businessName': businessName,
    'description': description,
    'startDate': startDate.toIso8601String(),
    'hustleType': hustleType.name,
    'goalAmount': goalAmount,
    'monthlyGoalAmount': monthlyGoalAmount,
    'isArchived': isArchived,
    'transactions': transactions.map((t) => t.toJson()).toList(),
  };

  factory SideStack.fromJson(Map<String, dynamic> json) => SideStack(
    id: json['id'],
    name: json['name'],
    businessName: json['businessName'] as String?,
    description: json['description'],
    startDate: DateTime.parse(json['startDate']),
    hustleType: HustleTypeExtension.fromString(json['hustleType']),
    goalAmount: (json['goalAmount'] as num?)?.toDouble(),
    monthlyGoalAmount: (json['monthlyGoalAmount'] as num?)?.toDouble(),
    isArchived: json['isArchived'] ?? false,
    transactions: (json['transactions'] as List)
        .map((t) => Transaction.fromJson(t))
        .toList(),
  );

  String toJsonString() => jsonEncode(toJson());

  static SideStack fromJsonString(String s) => SideStack.fromJson(jsonDecode(s));
}

// ─── Invoice ──────────────────────────────────────────────────────────────────

enum InvoiceStatus { draft, sent, viewed, paid, overdue }

extension InvoiceStatusExtension on InvoiceStatus {
  String get label {
    switch (this) {
      case InvoiceStatus.draft: return 'Draft';
      case InvoiceStatus.sent: return 'Sent';
      case InvoiceStatus.viewed: return 'Viewed';
      case InvoiceStatus.paid: return 'Paid';
      case InvoiceStatus.overdue: return 'Overdue';
    }
  }
  IconData get icon {
    switch (this) {
      case InvoiceStatus.draft:   return Icons.edit_outlined;
      case InvoiceStatus.sent:    return Icons.send_outlined;
      case InvoiceStatus.viewed:  return Icons.visibility_outlined;
      case InvoiceStatus.paid:    return Icons.check_circle_outline;
      case InvoiceStatus.overdue: return Icons.warning_amber_outlined;
    }
  }
  static InvoiceStatus fromString(String s) {
    return InvoiceStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => InvoiceStatus.draft,
    );
  }
}

class Invoice {
  final String id;
  String clientName;
  String clientEmail;
  double amount;
  String? description;
  InvoiceStatus status;
  DateTime issuedDate;
  DateTime dueDate;
  DateTime? paidDate;
  String? paymentLink;
  String? pdfUrl;
  String stackId;
  String invoiceNumber;
  /// Your Australian Business Number shown on the invoice (e.g. "12 345 678 901")
  String? abn;
  /// Whether to add 10% GST on top of the invoice amount.
  bool includesGst;
  /// GST component (amount * 0.10) when [includesGst] is true.
  double? get gstAmount => includesGst ? amount * 0.10 : null;
  /// Total payable (amount + GST when applicable).
  double get totalPayable => includesGst ? amount * 1.10 : amount;

  Invoice({
    required this.id,
    required this.clientName,
    this.clientEmail = '',
    required this.amount,
    this.description,
    this.status = InvoiceStatus.draft,
    required this.issuedDate,
    required this.dueDate,
    this.paidDate,
    this.paymentLink,
    this.pdfUrl,
    required this.stackId,
    String? invoiceNumber,
    this.abn,
    this.includesGst = false,
  }) : invoiceNumber = invoiceNumber ?? id;

  bool get isOverdue =>
      status != InvoiceStatus.paid &&
      DateTime.now().isAfter(dueDate);

  int get daysUntilDue => dueDate.difference(DateTime.now()).inDays;

  int get daysOverdue => isOverdue ? DateTime.now().difference(dueDate).inDays : 0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'clientName': clientName,
    'clientEmail': clientEmail,
    'amount': amount,
    'description': description,
    'status': status.name,
    'issuedDate': issuedDate.toIso8601String(),
    'dueDate': dueDate.toIso8601String(),
    'paidDate': paidDate?.toIso8601String(),
    'paymentLink': paymentLink,
    'pdfUrl': pdfUrl,
    'stackId': stackId,
    'invoiceNumber': invoiceNumber,
    'abn': abn,
    'includesGst': includesGst,
  };

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
    id: json['id'] as String,
    clientName: json['clientName'] as String,
    clientEmail: json['clientEmail'] as String? ?? '',
    amount: (json['amount'] as num).toDouble(),
    description: json['description'] as String?,
    status: InvoiceStatusExtension.fromString(json['status'] as String? ?? 'draft'),
    issuedDate: DateTime.parse(json['issuedDate'] as String),
    dueDate: DateTime.parse(json['dueDate'] as String),
    paidDate: json['paidDate'] != null ? DateTime.parse(json['paidDate'] as String) : null,
    paymentLink: json['paymentLink'] as String?,
    pdfUrl: json['pdfUrl'] as String?,
    stackId: json['stackId'] as String,
    invoiceNumber: json['invoiceNumber'] as String?,
    abn: json['abn'] as String?,
    includesGst: json['includesGst'] as bool? ?? false,
  );
}

// ─── Idea ─────────────────────────────────────────────────────────────────────

enum IdeaStatus { newIdea, reviewing, approved, archived }

extension IdeaStatusExtension on IdeaStatus {
  String get label {
    switch (this) {
      case IdeaStatus.newIdea:   return 'New';
      case IdeaStatus.reviewing: return 'Reviewing';
      case IdeaStatus.approved:  return 'Approved';
      case IdeaStatus.archived:  return 'Archived';
    }
  }

  IconData get icon {
    switch (this) {
      case IdeaStatus.newIdea:   return Icons.lightbulb_outline;
      case IdeaStatus.reviewing: return Icons.manage_search_outlined;
      case IdeaStatus.approved:  return Icons.check_circle_outline;
      case IdeaStatus.archived:  return Icons.inventory_2_outlined;
    }
  }

  static IdeaStatus fromString(String? s) {
    if (s == null) return IdeaStatus.newIdea;
    return IdeaStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => IdeaStatus.newIdea,
    );
  }
}

class Idea {
  final String id;
  String title;
  String? description;
  HustleType hustleType;
  IdeaStatus status;
  double? estimatedStartupCost;
  double? estimatedMonthlyIncome;
  String? notes;
  final DateTime createdAt;

  Idea({
    required this.id,
    required this.title,
    this.description,
    required this.hustleType,
    this.status = IdeaStatus.newIdea,
    this.estimatedStartupCost,
    this.estimatedMonthlyIncome,
    this.notes,
    required this.createdAt,
  });

  /// Estimated annual income based on monthly figure.
  double? get estimatedAnnualIncome =>
      estimatedMonthlyIncome != null ? estimatedMonthlyIncome! * 12 : null;

  /// Payback period in months (startup cost / monthly income).
  double? get paybackMonths {
    if (estimatedStartupCost == null || estimatedStartupCost! <= 0) return null;
    if (estimatedMonthlyIncome == null || estimatedMonthlyIncome! <= 0) return null;
    return estimatedStartupCost! / estimatedMonthlyIncome!;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'hustleType': hustleType.name,
    'status': status.name,
    'estimatedStartupCost': estimatedStartupCost,
    'estimatedMonthlyIncome': estimatedMonthlyIncome,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Idea.fromJson(Map<String, dynamic> json) => Idea(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    hustleType: HustleTypeExtension.fromString(
        json['hustleType'] as String? ?? 'other'),
    status: IdeaStatusExtension.fromString(json['status'] as String?),
    estimatedStartupCost:
        (json['estimatedStartupCost'] as num?)?.toDouble(),
    estimatedMonthlyIncome:
        (json['estimatedMonthlyIncome'] as num?)?.toDouble(),
    notes: json['notes'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
