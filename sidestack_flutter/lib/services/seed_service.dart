import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:uuid/uuid.dart';
import '../models/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SeedService — writes realistic demo data to Firestore so the account
// looks fully populated for screenshots, app-store previews, and TikTok demos.
//
// HOW TO USE:
//   In debug mode, go to Profile → scroll to bottom → tap "Seed demo data".
//   The button only appears in debug builds (kDebugMode = true).
//   Call seedAll(userId) to write everything, or clearAll(userId) first if
//   you want a clean slate before re-seeding.
// ─────────────────────────────────────────────────────────────────────────────

class SeedService {
  SeedService._();
  static final SeedService instance = SeedService._();

  static const _uuid = Uuid();

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Deletes all stacks, transactions, and invoices for [userId], then
  /// writes a full set of realistic demo data.
  Future<void> seedAll(String userId) async {
    await clearAll(userId);
    await _writeStacks(userId);
    await _writeInvoices(userId);
    await _writeMeta(userId);
  }

  /// Wipes all stacks (+ their transactions) and invoices for [userId].
  Future<void> clearAll(String userId) async {
    final db = fs.FirebaseFirestore.instance;
    final stacksRef = db.collection('users').doc(userId).collection('stacks');
    final invoicesRef = db.collection('users').doc(userId).collection('invoices');

    // Delete stacks + nested transactions
    final stacks = await stacksRef.get();
    for (final stackDoc in stacks.docs) {
      final txs = await stackDoc.reference.collection('transactions').get();
      for (final tx in txs.docs) {
        await tx.reference.delete();
      }
      await stackDoc.reference.delete();
    }

    // Delete invoices
    final invoices = await invoicesRef.get();
    for (final doc in invoices.docs) {
      await doc.reference.delete();
    }
  }

  // ── Stacks ──────────────────────────────────────────────────────────────────

  Future<void> _writeStacks(String userId) async {
    final db = fs.FirebaseFirestore.instance;
    final stacksRef = db.collection('users').doc(userId).collection('stacks');
    final now = DateTime.now();

    for (final stack in _buildStacks(now)) {
      // Write the stack document
      await stacksRef.doc(stack.id).set({
        'name': stack.name,
        'description': stack.description,
        'startDate': stack.startDate.toIso8601String(),
        'hustleType': stack.hustleType.name,
        'goalAmount': stack.goalAmount,
        'monthlyGoalAmount': stack.monthlyGoalAmount,
        'isArchived': false,
      });

      // Write each transaction in a batch (max 500 ops per batch)
      final txRef = stacksRef.doc(stack.id).collection('transactions');
      var batch = db.batch();
      int count = 0;
      for (final tx in stack.transactions) {
        batch.set(txRef.doc(tx.id), tx.toJson());
        count++;
        if (count == 400) {
          await batch.commit();
          batch = db.batch();
          count = 0;
        }
      }
      if (count > 0) await batch.commit();
    }
  }

  // ── Invoices ────────────────────────────────────────────────────────────────

  Future<void> _writeInvoices(String userId) async {
    final db = fs.FirebaseFirestore.instance;
    final invoicesRef = db.collection('users').doc(userId).collection('invoices');
    final now = DateTime.now();

    for (final inv in _buildInvoices(now)) {
      final json = inv.toJson();
      json.remove('id');
      await invoicesRef.doc(inv.id).set(json);
    }
  }

  // ── Meta ────────────────────────────────────────────────────────────────────

  Future<void> _writeMeta(String userId) async {
    await fs.FirebaseFirestore.instance.collection('users').doc(userId).set(
      {'hasSeenOnboarding': true},
      fs.SetOptions(merge: true),
    );
  }

  // ── Data builders ────────────────────────────────────────────────────────────

  List<SideStack> _buildStacks(DateTime now) {
    return [
      _buildFreelanceDesign(now),
      _buildContentCreation(now),
      _buildPhotography(now),
      _buildReselling(now),
    ];
  }

  // Stack 1 — Freelance Design (💻)
  SideStack _buildFreelanceDesign(DateTime now) {
    final id = _uuid.v4();
    return SideStack(
      id: id,
      name: 'Freelance Design',
      description: 'Brand identity, UI & social media',
      startDate: _ago(now, 185),
      hustleType: HustleType.freelance,
      goalAmount: 3000,
      monthlyGoalAmount: 2500,
      transactions: [
        // This month
        _income(id, 1800, 'Client work', _ago(now, 3),
            client: 'TechStart Ltd', notes: 'Brand refresh — final delivery', hours: 16),
        _income(id, 650, 'Client work', _ago(now, 8),
            client: 'Bella & Co', notes: 'Instagram template pack', hours: 6),
        _expense(id, 29, 'Software', _ago(now, 10), notes: 'Figma subscription', recurring: true),
        _income(id, 420, 'Client work', _ago(now, 12),
            client: 'Nova Agency', notes: 'Email newsletter design', hours: 4),
        // Last month
        _income(id, 2400, 'Client work', _ago(now, 34),
            client: 'TechStart Ltd', notes: 'Full website redesign', hours: 24),
        _income(id, 780, 'Client work', _ago(now, 39),
            client: 'Marcus Reeve', notes: 'Logo & business cards', hours: 8),
        _expense(id, 29, 'Software', _ago(now, 40), notes: 'Figma subscription', recurring: true),
        _expense(id, 49, 'Marketing', _ago(now, 42), notes: 'Behance Pro annual'),
        _income(id, 550, 'Client work', _ago(now, 45),
            client: 'The Studio', notes: 'Social media kit', hours: 5),
        // 2 months ago
        _income(id, 1950, 'Client work', _ago(now, 62),
            client: 'Nova Agency', notes: 'Pitch deck — 20 slides', hours: 18),
        _income(id, 680, 'Client work', _ago(now, 68),
            client: 'Bella & Co', notes: 'Product photography edits', hours: 7),
        _expense(id, 29, 'Software', _ago(now, 70), notes: 'Figma subscription', recurring: true),
        _expense(id, 15, 'Software', _ago(now, 72), notes: 'Adobe Fonts add-on'),
        _income(id, 300, 'Client work', _ago(now, 78),
            client: 'Marcus Reeve', notes: 'Banner ads set', hours: 3),
        // 3 months ago
        _income(id, 2100, 'Client work', _ago(now, 95),
            client: 'TechStart Ltd', notes: 'App UI mockups', hours: 20),
        _income(id, 450, 'Client work', _ago(now, 100),
            client: 'The Studio', notes: 'Print materials', hours: 5),
        _expense(id, 29, 'Software', _ago(now, 100), notes: 'Figma subscription', recurring: true),
        _income(id, 350, 'Client work', _ago(now, 108),
            client: 'Nova Agency', notes: 'Icon set — 40 icons', hours: 4),
        // 4 months ago
        _income(id, 1600, 'Client work', _ago(now, 125),
            client: 'Bella & Co', notes: 'E-commerce store design', hours: 15),
        _income(id, 750, 'Client work', _ago(now, 130),
            client: 'Marcus Reeve', notes: 'Rebranding consultation', hours: 6),
        _expense(id, 29, 'Software', _ago(now, 130), notes: 'Figma subscription', recurring: true),
        _expense(id, 99, 'Training', _ago(now, 135), notes: 'Motion design course'),
        // 5 months ago
        _income(id, 1200, 'Client work', _ago(now, 155),
            client: 'Nova Agency', notes: 'Annual report layout', hours: 12),
        _income(id, 600, 'Client work', _ago(now, 160),
            client: 'The Studio', notes: 'Photography edits batch', hours: 6),
        _expense(id, 29, 'Software', _ago(now, 160), notes: 'Figma subscription', recurring: true),
        _income(id, 480, 'Client work', _ago(now, 168),
            client: 'TechStart Ltd', notes: 'Landing page tweaks', hours: 4),
      ],
    );
  }

  // Stack 2 — Content Creation (📱)
  SideStack _buildContentCreation(DateTime now) {
    final id = _uuid.v4();
    return SideStack(
      id: id,
      name: 'Content Creation',
      description: 'YouTube, TikTok & brand deals',
      startDate: _ago(now, 160),
      hustleType: HustleType.content,
      goalAmount: 1500,
      monthlyGoalAmount: 1200,
      transactions: [
        // This month
        _income(id, 620, 'AdSense', _ago(now, 5), notes: 'YouTube ad revenue — April'),
        _income(id, 450, 'Brand deal', _ago(now, 7),
            client: 'NovaNutrition', notes: 'Sponsored integration — 60s', hours: 3),
        _expense(id, 19, 'Software', _ago(now, 9), notes: 'Epidemic Sound', recurring: true),
        _expense(id, 12, 'Software', _ago(now, 9), notes: 'Canva Pro', recurring: true),
        _income(id, 180, 'Tip / Super', _ago(now, 11), notes: 'YouTube Supers & memberships'),
        // Last month
        _income(id, 590, 'AdSense', _ago(now, 35), notes: 'YouTube ad revenue — March'),
        _income(id, 800, 'Brand deal', _ago(now, 37),
            client: 'SkillCraft', notes: '30-day skill challenge sponsorship', hours: 5),
        _expense(id, 19, 'Software', _ago(now, 40), notes: 'Epidemic Sound', recurring: true),
        _expense(id, 12, 'Software', _ago(now, 40), notes: 'Canva Pro', recurring: true),
        _income(id, 210, 'Tip / Super', _ago(now, 42), notes: 'Supers & channel memberships'),
        _expense(id, 65, 'Equipment', _ago(now, 48), notes: 'Ring light replacement'),
        // 2 months ago
        _income(id, 510, 'AdSense', _ago(now, 65), notes: 'YouTube ad revenue — Feb'),
        _income(id, 600, 'Brand deal', _ago(now, 68),
            client: 'PocketTech', notes: 'App review integration', hours: 4),
        _expense(id, 19, 'Software', _ago(now, 70), notes: 'Epidemic Sound', recurring: true),
        _expense(id, 12, 'Software', _ago(now, 70), notes: 'Canva Pro', recurring: true),
        _income(id, 155, 'Tip / Super', _ago(now, 72), notes: 'Supers & memberships'),
        // 3 months ago
        _income(id, 480, 'AdSense', _ago(now, 95), notes: 'YouTube ad revenue — Jan'),
        _income(id, 350, 'Brand deal', _ago(now, 98),
            client: 'NovaNutrition', notes: 'Story set', hours: 2),
        _expense(id, 19, 'Software', _ago(now, 100), notes: 'Epidemic Sound', recurring: true),
        _expense(id, 120, 'Equipment', _ago(now, 105), notes: 'Lavalier microphone'),
        _income(id, 130, 'Tip / Super', _ago(now, 108), notes: 'Supers & memberships'),
        // 4 months ago
        _income(id, 390, 'AdSense', _ago(now, 128), notes: 'YouTube ad revenue — Dec'),
        _income(id, 500, 'Brand deal', _ago(now, 132),
            client: 'SkillCraft', notes: 'Holiday promo', hours: 4),
        _expense(id, 19, 'Software', _ago(now, 132), notes: 'Epidemic Sound', recurring: true),
        _income(id, 95, 'Tip / Super', _ago(now, 135), notes: 'Holiday super stickers'),
      ],
    );
  }

  // Stack 3 — Photography (📷)
  SideStack _buildPhotography(DateTime now) {
    final id = _uuid.v4();
    return SideStack(
      id: id,
      name: 'Photography',
      description: 'Portraits, events & stock photos',
      startDate: _ago(now, 150),
      hustleType: HustleType.freelance,
      goalAmount: 2000,
      monthlyGoalAmount: 1500,
      transactions: [
        // This month
        _income(id, 1200, 'Shoot', _ago(now, 4),
            client: 'Harper & James', notes: 'Engagement session — 2hr', hours: 4),
        _income(id, 350, 'Stock', _ago(now, 6), notes: 'Shutterstock royalties — April'),
        _expense(id, 25, 'Software', _ago(now, 8), notes: 'Lightroom CC', recurring: true),
        _income(id, 550, 'Shoot', _ago(now, 10),
            client: 'Priya Mehta', notes: 'Corporate headshots — 8 portraits', hours: 3),
        // Last month
        _income(id, 2200, 'Shoot', _ago(now, 32),
            client: 'Liam & Zoe', notes: 'Wedding day — 8hr', hours: 10),
        _income(id, 320, 'Stock', _ago(now, 36), notes: 'Shutterstock royalties — March'),
        _expense(id, 25, 'Software', _ago(now, 38), notes: 'Lightroom CC', recurring: true),
        _expense(id, 180, 'Equipment', _ago(now, 40), notes: 'Memory cards x4 + UV filters'),
        _income(id, 750, 'Shoot', _ago(now, 42),
            client: 'Bloom Bakery', notes: 'Product photography — 40 images', hours: 5),
        // 2 months ago
        _income(id, 1800, 'Shoot', _ago(now, 65),
            client: 'Rania & Omar', notes: 'Engagement + pre-wedding', hours: 8),
        _income(id, 290, 'Stock', _ago(now, 68), notes: 'Shutterstock royalties — Feb'),
        _expense(id, 25, 'Software', _ago(now, 68), notes: 'Lightroom CC', recurring: true),
        _income(id, 480, 'Shoot', _ago(now, 72),
            client: 'Harper & James', notes: 'Family portraits', hours: 3),
        // 3 months ago
        _income(id, 600, 'Shoot', _ago(now, 95),
            client: 'Priya Mehta', notes: 'Professional headshots', hours: 3),
        _income(id, 260, 'Stock', _ago(now, 100), notes: 'Shutterstock royalties — Jan'),
        _expense(id, 25, 'Software', _ago(now, 100), notes: 'Lightroom CC', recurring: true),
        _expense(id, 350, 'Equipment', _ago(now, 108), notes: 'Speedlight flash'),
        _income(id, 900, 'Shoot', _ago(now, 110),
            client: 'Bloom Bakery', notes: 'Holiday campaign shoot', hours: 6),
        // 4 months ago
        _income(id, 1500, 'Shoot', _ago(now, 130),
            client: 'Liam & Zoe', notes: 'Engagement session', hours: 6),
        _income(id, 240, 'Stock', _ago(now, 132), notes: 'Shutterstock royalties — Dec'),
        _expense(id, 25, 'Software', _ago(now, 132), notes: 'Lightroom CC', recurring: true),
      ],
    );
  }

  // Stack 4 — Weekend Reselling (🏷️)
  SideStack _buildReselling(DateTime now) {
    final id = _uuid.v4();
    return SideStack(
      id: id,
      name: 'Weekend Reselling',
      description: 'eBay, Depop & Facebook flips',
      startDate: _ago(now, 140),
      goalAmount: 800,
      monthlyGoalAmount: 600,
      hustleType: HustleType.reselling,
      transactions: [
        // This month
        _income(id, 185, 'Sale', _ago(now, 2), notes: 'Vintage Levi\'s jacket — Depop'),
        _income(id, 95, 'Sale', _ago(now, 5), notes: 'Retro games console bundle'),
        _expense(id, 55, 'Inventory', _ago(now, 6), notes: 'Thrift store haul'),
        _income(id, 210, 'Sale', _ago(now, 9), notes: 'Nike Air Max 90 deadstock'),
        _expense(id, 140, 'Inventory', _ago(now, 10), notes: 'Sneaker market finds'),
        _expense(id, 12, 'Fees', _ago(now, 10), notes: 'eBay seller fees'),
        // Last month
        _income(id, 320, 'Sale', _ago(now, 33), notes: 'Designer handbag — authenticated'),
        _income(id, 75, 'Sale', _ago(now, 36), notes: 'Vintage camera + lens'),
        _expense(id, 180, 'Inventory', _ago(now, 37), notes: 'Op-shop + Facebook haul'),
        _income(id, 130, 'Sale', _ago(now, 40), notes: 'Vinyl record collection — 10 LPs'),
        _expense(id, 18, 'Fees', _ago(now, 41), notes: 'eBay + Depop selling fees'),
        _income(id, 90, 'Sale', _ago(now, 44), notes: 'Retro tech — iPod classic'),
        _expense(id, 60, 'Inventory', _ago(now, 45), notes: 'Garage sale finds'),
        // 2 months ago
        _income(id, 260, 'Sale', _ago(now, 65), notes: 'Y2K fashion lot — 8 pieces'),
        _income(id, 115, 'Sale', _ago(now, 68), notes: 'Football jersey bundle x3'),
        _expense(id, 90, 'Inventory', _ago(now, 70), notes: 'Charity shops run'),
        _income(id, 170, 'Sale', _ago(now, 72), notes: 'Rare book — first edition'),
        _expense(id, 15, 'Fees', _ago(now, 73), notes: 'Selling platform fees'),
        // 3 months ago
        _income(id, 195, 'Sale', _ago(now, 98), notes: 'Vintage Adidas tracksuit'),
        _income(id, 85, 'Sale', _ago(now, 102), notes: 'Porcelain figurines lot'),
        _expense(id, 75, 'Inventory', _ago(now, 103), notes: 'Estate sale — mixed lot'),
        _income(id, 150, 'Sale', _ago(now, 108), notes: 'Mechanical keyboard — custom'),
        _expense(id, 14, 'Fees', _ago(now, 110), notes: 'Selling fees'),
      ],
    );
  }

  // ── Invoices ────────────────────────────────────────────────────────────────

  List<Invoice> _buildInvoices(DateTime now) {
    // We need a valid stack reference — use a placeholder; in practice the
    // listener will just show "Unknown stack" gracefully since we don't know
    // the real stack IDs from outside the provider. Alternatively we could
    // pass them in, but a standalone seed is simpler.
    const stackId = 'seed-stack';

    return [
      Invoice(
        id: _uuid.v4(),
        clientName: 'TechStart Ltd',
        clientEmail: 'billing@techstart.io',
        amount: 2400,
        description: 'Full website redesign — 4 pages + mobile responsive',
        status: InvoiceStatus.paid,
        issuedDate: _ago(now, 34),
        dueDate: _ago(now, 20),
        paidDate: _ago(now, 18),
        stackId: stackId,
        invoiceNumber: 'INV-2026-001',
      ),
      Invoice(
        id: _uuid.v4(),
        clientName: 'Nova Agency',
        clientEmail: 'accounts@nova-agency.co',
        amount: 1800,
        description: 'Pitch deck design — 22 slides, brand aligned',
        status: InvoiceStatus.sent,
        issuedDate: _ago(now, 10),
        dueDate: _ago(now, -20), // due in 20 days
        stackId: stackId,
        invoiceNumber: 'INV-2026-002',
      ),
      Invoice(
        id: _uuid.v4(),
        clientName: 'Marcus Reeve',
        clientEmail: 'marcus@reevecreative.com',
        amount: 650,
        description: 'Logo redesign + brand guidelines document',
        status: InvoiceStatus.overdue,
        issuedDate: _ago(now, 52),
        dueDate: _ago(now, 22),
        stackId: stackId,
        invoiceNumber: 'INV-2026-003',
      ),
      Invoice(
        id: _uuid.v4(),
        clientName: 'Harper & James',
        clientEmail: 'hello@harperandjames.com',
        amount: 1200,
        description: 'Engagement session — 60 edited images, online gallery',
        status: InvoiceStatus.paid,
        issuedDate: _ago(now, 8),
        dueDate: _ago(now, 1),
        paidDate: _ago(now, 2),
        stackId: stackId,
        invoiceNumber: 'INV-2026-004',
      ),
      Invoice(
        id: _uuid.v4(),
        clientName: 'The Studio',
        clientEmail: 'finance@thestudio.design',
        amount: 1400,
        description: 'Monthly retainer — social media design package',
        status: InvoiceStatus.draft,
        issuedDate: _ago(now, 1),
        dueDate: _ago(now, -29), // due in 29 days
        stackId: stackId,
        invoiceNumber: 'INV-2026-005',
      ),
      Invoice(
        id: _uuid.v4(),
        clientName: 'SkillCraft',
        clientEmail: 'partnerships@skillcraft.app',
        amount: 800,
        description: '30-day skill challenge — sponsored video integration',
        status: InvoiceStatus.paid,
        issuedDate: _ago(now, 40),
        dueDate: _ago(now, 25),
        paidDate: _ago(now, 24),
        stackId: stackId,
        invoiceNumber: 'INV-2026-006',
      ),
    ];
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  DateTime _ago(DateTime now, int days) => now.subtract(Duration(days: days));

  Transaction _income(
    String stackId,
    double amount,
    String category,
    DateTime date, {
    String? client,
    String? notes,
    double? hours,
  }) =>
      Transaction(
        id: _uuid.v4(),
        type: TransactionType.income,
        amount: amount,
        date: date,
        category: category,
        clientName: client,
        notes: notes,
        hoursWorked: hours,
      );

  Transaction _expense(
    String stackId,
    double amount,
    String category,
    DateTime date, {
    String? notes,
    bool recurring = false,
  }) =>
      Transaction(
        id: _uuid.v4(),
        type: TransactionType.expense,
        amount: amount,
        date: date,
        category: category,
        notes: notes,
        isRecurring: recurring,
        recurrenceInterval:
            recurring ? RecurrenceInterval.monthly : null,
      );
}
