import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/bank_service.dart';
import '../screens/bank_import_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Connect Bank Sheet — TrueLayer OAuth flow
//
// Flow:
//   1. User taps "Connect Bank"
//   2. We call createAuthLink() to get a TrueLayer OAuth URL
//   3. We open that URL in the system browser via url_launcher
//   4. User selects bank, authenticates
//   5. TrueLayer redirects to sidestack://bank-callback?code=X&state=Y
//   6. The deep link is caught by the app (see AndroidManifest / Info.plist)
//      and handleBankCallback(code, state) is called on AppProvider
//   7. AppProvider calls BankService.exchangeCode() then onBankConnected()
//
// Deep link setup (one-time, outside this file):
//   Android: add intent-filter for "sidestack://bank-callback" in AndroidManifest.xml
//   iOS:     add URL scheme "sidestack" in Info.plist and CFBundleURLSchemes
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showConnectBankSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ConnectBankSheet(),
  );
}

class _ConnectBankSheet extends StatefulWidget {
  const _ConnectBankSheet();
  @override
  State<_ConnectBankSheet> createState() => _ConnectBankSheetState();
}

class _ConnectBankSheetState extends State<_ConnectBankSheet> {
  bool _loading = false;
  String? _error;

  static const _perks = [
    _Perk(
      icon: Icons.sync_alt_outlined,
      label: 'Auto-import transactions',
      sub: 'Pulls income & expenses straight from your bank',
    ),
    _Perk(
      icon: Icons.lock_outline,
      label: 'Bank-level security',
      sub: 'Your credentials go directly to your bank — never to us',
    ),
    _Perk(
      icon: Icons.block_outlined,
      label: 'Read-only access',
      sub: 'We can only read transactions. Cannot move money.',
    ),
    _Perk(
      icon: Icons.public_outlined,
      label: '2,300+ banks supported',
      sub: 'UK, EU, US, Australia and more via TrueLayer',
    ),
  ];

  Future<void> _connectBank() async {
    setState(() { _loading = true; _error = null; });

    try {
      // Get the TrueLayer OAuth URL from our Cloud Function
      final authUrl = await BankService.instance.createAuthLink();

      final uri = Uri.parse(authUrl);
      if (!await canLaunchUrl(uri)) {
        throw BankServiceException('Could not open browser. Try again.');
      }

      // Open TrueLayer's hosted bank selection UI in the system browser
      await launchUrl(uri, mode: LaunchMode.externalApplication);

      // The rest of the flow happens via deep link:
      // sidestack://bank-callback?code=X&state=Y
      // → handled by AppProvider.handleBankCallback()
      // → which calls BankService.exchangeCode() then onBankConnected()

      if (mounted) Navigator.pop(context);
    } on BankServiceException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      setState(() {
        _error = 'Something went wrong. Check your connection and try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final isConnected = provider.bankConnected;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: AppTheme.of(context).surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.of(context).borderLight),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppTheme.of(context).borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Icon
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3DD68C), Color(0xFF22C55E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(child: Icon(Icons.account_balance_outlined, size: 30, color: Colors.white)),
          ),
          const SizedBox(height: 16),

          Text(
            isConnected ? 'Bank Connected' : 'Connect Your Bank',
            style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isConnected
                ? '${provider.bankInstitution} is linked and ready to sync.'
                : 'Import transactions automatically — no manual entry.',
            style: TextStyle(
                fontSize: 13, color: AppTheme.of(context).textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          if (!isConnected) ...[
            // Perks list
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.of(context).card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.of(context).border),
              ),
              child: Column(
                children: _perks.map((p) => _PerkRow(perk: p)).toList(),
              ),
            ),
            const SizedBox(height: 20),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.redDim,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, size: 16, color: AppTheme.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(fontSize: 12, color: AppTheme.red)),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            PrimaryButton(
              label: _loading ? 'Opening browser…' : 'Connect Bank',
              onPressed: _loading ? null : _connectBank,
            ),
            const SizedBox(height: 10),
            Text(
              'Powered by TrueLayer · 2,300+ banks · read-only access',
              style: TextStyle(fontSize: 10, color: AppTheme.of(context).textMuted),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            // Connected state
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.of(context).card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.of(context).border),
              ),
              child: Column(children: [
                _ConnectedRow(
                  icon: Icons.sync_outlined,
                  color: AppTheme.accent,
                  label: 'Sync now',
                  sub: 'Import new transactions from your bank',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const BankImportScreen(),
                    ));
                  },
                ),
                Divider(height: 1, color: AppTheme.of(context).border),
                _ConnectedRow(
                  icon: Icons.link_off_outlined,
                  color: AppTheme.red,
                  label: 'Disconnect bank',
                  sub: 'Removes access — imported data stays',
                  onTap: () => _confirmDisconnect(context),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Text('Close',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.of(context).textMuted,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDisconnect(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.of(context).card,
        title: const Text('Disconnect bank?'),
        content: const Text(
            'Your imported transactions stay. Future auto-syncs will stop.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: AppTheme.of(context).textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect', style: TextStyle(color: AppTheme.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await context.read<AppProvider>().disconnectBank();
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bank disconnected.')),
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _Perk {
  final IconData icon;
  final String label;
  final String sub;
  const _Perk({required this.icon, required this.label, required this.sub});
}

class _PerkRow extends StatelessWidget {
  final _Perk perk;
  const _PerkRow({required this.perk});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
              color: AppTheme.greenDim,
              borderRadius: BorderRadius.circular(9)),
          child: Icon(perk.icon, size: 16, color: AppTheme.green),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(perk.label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            Text(perk.sub,
                style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.of(context).textSecondary)),
          ]),
        ),
      ]),
    );
  }
}

class _ConnectedRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String sub;
  final VoidCallback onTap;

  const _ConnectedRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color)),
              Text(sub,
                  style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.of(context).textSecondary)),
            ]),
          ),
          Icon(Icons.chevron_right,
              size: 16, color: AppTheme.of(context).textMuted),
        ]),
      ),
    );
  }
}
