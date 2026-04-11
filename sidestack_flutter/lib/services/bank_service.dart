import 'package:cloud_functions/cloud_functions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BankService — TrueLayer integration
//
// TrueLayer uses a standard OAuth2 flow:
//   1. createAuthLink() → get an OAuth URL
//   2. App opens URL via url_launcher; user picks bank & logs in
//   3. TrueLayer redirects to sidestack://bank-callback?code=X&state=Y
//   4. App deep-link handler calls exchangeCode(code, state)
//   5. fetchTransactions() pulls new transactions for review
//
// All tokens are stored server-side in Firestore — never in the app.
// ─────────────────────────────────────────────────────────────────────────────

/// A single transaction returned from TrueLayer, ready for the review screen.
class BankTransaction {
  final String transactionId;
  final DateTime date;
  final double amount;
  final bool isIncome;
  final String name;
  final String category;
  final String institution;

  const BankTransaction({
    required this.transactionId,
    required this.date,
    required this.amount,
    required this.isIncome,
    required this.name,
    required this.category,
    required this.institution,
  });

  factory BankTransaction.fromMap(Map<String, dynamic> map) {
    return BankTransaction(
      transactionId: map['transaction_id'] as String,
      date: DateTime.parse(map['date'] as String),
      amount: (map['amount'] as num).toDouble(),
      isIncome: map['is_income'] as bool,
      name: map['name'] as String,
      category: map['category'] as String? ?? 'Other',
      institution: map['institution'] as String? ?? 'Bank',
    );
  }
}

class BankService {
  BankService._();
  static final instance = BankService._();

  final _functions = FirebaseFunctions.instance;

  // ── Create auth link ───────────────────────────────────────────────────────

  /// Returns a TrueLayer OAuth URL to open in the browser.
  /// The user selects their bank, authenticates, then TrueLayer redirects
  /// back to "sidestack://bank-callback?code=X&state=Y".
  Future<String> createAuthLink() async {
    try {
      final result = await _functions
          .httpsCallable('createAuthLink')
          .call<Map<String, dynamic>>();
      final url = result.data['auth_url'] as String?;
      if (url == null || url.isEmpty) {
        throw BankServiceException('Could not generate bank connection link.');
      }
      return url;
    } on FirebaseFunctionsException catch (e) {
      throw BankServiceException(e.message ?? 'Could not reach bank service.');
    } catch (e) {
      if (e is BankServiceException) rethrow;
      throw BankServiceException('Unexpected error creating auth link.');
    }
  }

  // ── Exchange code ──────────────────────────────────────────────────────────

  /// Called when the deep link comes back with a code.
  /// Returns the institution name on success.
  Future<String> exchangeCode({
    required String code,
    required String state,
  }) async {
    try {
      final result = await _functions.httpsCallable('exchangeCode').call({
        'code': code,
        'state': state,
      });
      return result.data['institution_name'] as String? ?? 'Bank';
    } on FirebaseFunctionsException catch (e) {
      throw BankServiceException(e.message ?? 'Could not connect bank account.');
    } catch (e) {
      if (e is BankServiceException) rethrow;
      throw BankServiceException('Unexpected error exchanging code.');
    }
  }

  // ── Fetch transactions ─────────────────────────────────────────────────────

  /// Fetches up to [daysBack] days of new bank transactions.
  /// Already-imported transactions are excluded automatically.
  Future<List<BankTransaction>> fetchTransactions({int daysBack = 90}) async {
    try {
      final result = await _functions
          .httpsCallable('fetchBankTransactions')
          .call({'days_back': daysBack});
      final raw = List<Map<String, dynamic>>.from(
        (result.data['transactions'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map)),
      );
      return raw.map(BankTransaction.fromMap).toList();
    } on FirebaseFunctionsException catch (e) {
      throw BankServiceException(e.message ?? 'Could not fetch transactions.');
    } catch (e) {
      if (e is BankServiceException) rethrow;
      throw BankServiceException('Unexpected error fetching transactions.');
    }
  }

  // ── Mark imported ──────────────────────────────────────────────────────────

  /// Records IDs so they won't appear in future syncs.
  Future<void> markImported(List<String> transactionIds) async {
    if (transactionIds.isEmpty) return;
    try {
      await _functions
          .httpsCallable('markTransactionsImported')
          .call({'transaction_ids': transactionIds});
    } catch (_) {
      // Non-critical
    }
  }

  // ── Disconnect ─────────────────────────────────────────────────────────────

  /// Revokes TrueLayer access and removes the stored connection.
  Future<void> disconnectBank(String connectionId) async {
    try {
      await _functions
          .httpsCallable('disconnectBank')
          .call({'connection_id': connectionId});
    } on FirebaseFunctionsException catch (e) {
      throw BankServiceException(e.message ?? 'Could not disconnect bank.');
    } catch (e) {
      if (e is BankServiceException) rethrow;
      throw BankServiceException('Unexpected error disconnecting bank.');
    }
  }
}

// ── Exception ──────────────────────────────────────────────────────────────

class BankServiceException implements Exception {
  final String message;
  const BankServiceException(this.message);
  @override
  String toString() => message;
}
