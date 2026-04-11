import '../models/models.dart';
import 'package:uuid/uuid.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DemoService — generates realistic sample stacks and transactions so new
// users land on a populated dashboard instead of a blank screen.
//
// The demo data is entirely in-memory and never written to Firestore.
// It is injected into AppProvider._stacks when demo mode is active and
// cleared the moment the user creates their first real stack.
// ─────────────────────────────────────────────────────────────────────────────

class DemoService {
  DemoService._();
  static final DemoService instance = DemoService._();

  static const _uuid = Uuid();

  /// Build two realistic demo stacks with 3 months of transactions.
  List<SideStack> buildDemoStacks() {
    final now = DateTime.now();

    // ── Stack 1: Freelance Design ───────────────────────────────────────────
    final designId = _uuid.v4();
    final designTxs = <Transaction>[
      _tx(TransactionType.income, 850, 'Client work',
          _ago(now, 2), notes: 'Logo design — Acme Corp', hoursWorked: 8),
      _tx(TransactionType.income, 1200, 'Client work',
          _ago(now, 14), notes: 'Brand identity package', hoursWorked: 14),
      _tx(TransactionType.expense, 29, 'Software',
          _ago(now, 14), notes: 'Figma subscription', isRecurring: true,
          interval: RecurrenceInterval.monthly),
      _tx(TransactionType.income, 400, 'Client work',
          _ago(now, 28), notes: 'Social media graphics', hoursWorked: 5),
      _tx(TransactionType.expense, 15, 'Software',
          _ago(now, 30), notes: 'Adobe Fonts add-on'),
      _tx(TransactionType.income, 650, 'Client work',
          _ago(now, 45), notes: 'Landing page redesign', hoursWorked: 7),
      _tx(TransactionType.income, 950, 'Client work',
          _ago(now, 60), notes: 'Presentation deck', hoursWorked: 10),
      _tx(TransactionType.expense, 29, 'Software',
          _ago(now, 45), notes: 'Figma subscription', isRecurring: true,
          interval: RecurrenceInterval.monthly),
      _tx(TransactionType.income, 300, 'Client work',
          _ago(now, 75), notes: 'Icon set commission', hoursWorked: 4),
      _tx(TransactionType.expense, 49, 'Marketing',
          _ago(now, 80), notes: 'Behance Pro'),
    ];

    final designStack = SideStack(
      id: designId,
      name: 'Freelance Design',
      description: 'Logos, branding & UI work',
      startDate: _ago(now, 90),
      hustleType: HustleType.freelance,
      transactions: designTxs,
      goalAmount: 2000,
    );

    // ── Stack 2: Reselling ──────────────────────────────────────────────────
    final resellId = _uuid.v4();
    final resellTxs = <Transaction>[
      _tx(TransactionType.income, 120, 'Sale',
          _ago(now, 3), notes: 'Vintage sneakers — eBay'),
      _tx(TransactionType.expense, 60, 'Inventory',
          _ago(now, 5), notes: 'Thrift store haul'),
      _tx(TransactionType.income, 75, 'Sale',
          _ago(now, 9), notes: 'Retro games lot'),
      _tx(TransactionType.income, 210, 'Sale',
          _ago(now, 18), notes: 'Designer jacket'),
      _tx(TransactionType.expense, 85, 'Inventory',
          _ago(now, 20), notes: 'Facebook Marketplace finds'),
      _tx(TransactionType.income, 55, 'Sale',
          _ago(now, 25), notes: 'Vintage camera'),
      _tx(TransactionType.expense, 15, 'Fees',
          _ago(now, 25), notes: 'eBay selling fees'),
      _tx(TransactionType.income, 180, 'Sale',
          _ago(now, 38), notes: 'Rare vinyl records'),
      _tx(TransactionType.expense, 70, 'Inventory',
          _ago(now, 40), notes: 'Garage sale finds'),
      _tx(TransactionType.income, 95, 'Sale',
          _ago(now, 55), notes: 'Football jersey bundle'),
      _tx(TransactionType.expense, 40, 'Inventory',
          _ago(now, 58), notes: 'Charity shop run'),
      _tx(TransactionType.income, 130, 'Sale',
          _ago(now, 70), notes: 'Retro tech bundle'),
    ];

    final resellStack = SideStack(
      id: resellId,
      name: 'Weekend Reselling',
      description: 'Vintage & second-hand flips',
      startDate: _ago(now, 90),
      hustleType: HustleType.reselling,
      transactions: resellTxs,
      goalAmount: 500,
    );

    return [designStack, resellStack];
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  DateTime _ago(DateTime now, int days) =>
      now.subtract(Duration(days: days));

  Transaction _tx(
    TransactionType type,
    double amount,
    String category,
    DateTime date, {
    String? notes,
    double? hoursWorked,
    bool isRecurring = false,
    RecurrenceInterval? interval,
  }) {
    return Transaction(
      id: _uuid.v4(),
      type: type,
      amount: amount,
      date: date,
      category: category,
      notes: notes,
      hoursWorked: hoursWorked,
      isRecurring: isRecurring,
      recurrenceInterval: interval,
    );
  }
}
