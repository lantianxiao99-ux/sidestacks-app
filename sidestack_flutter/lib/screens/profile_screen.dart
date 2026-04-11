import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../services/csv_export_service.dart';
import '../widgets/paywall_sheet.dart';
import '../services/notification_service.dart';
import '../widgets/csv_import_sheet.dart';
import '../widgets/connect_bank_sheet.dart';
import 'bank_import_screen.dart';

// ─── Theme mode helpers ───────────────────────────────────────────────────────
const _kThemeModes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];
const _kThemeLabels = ['System', 'Light', 'Dark'];
const _kThemeIcons = [
  Icons.brightness_auto_outlined,
  Icons.light_mode_outlined,
  Icons.dark_mode_outlined,
];

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// Set to true when the user taps the ✕ on the upgrade banner.
  /// Resets each session so the banner returns on next app launch.
  bool _upgradeBannerDismissed = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final auth = context.watch<AuthProvider>();
    final txCount = provider.allTransactions.length;
    final archivedCount = provider.archivedStacks.length;
    final initials = (auth.userName ?? auth.userEmail ?? 'U')
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: Text('Profile',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          ),
          // ── Persistent upgrade banner (free users only) ────────────────
          if (!provider.isPremium && !_upgradeBannerDismissed)
            SliverToBoxAdapter(
              child: GestureDetector(
                onTap: () => showPaywallSheet(context),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF6C6FFF),
                        const Color(0xFF9B59B6),
                        AppTheme.accent,
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    const Text('⚡', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Unlock all SideStack features',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            'Advanced analytics · Unlimited stacks · Exports',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Go Pro',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6C6FFF),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _upgradeBannerDismissed = true),
                      child: const Icon(Icons.close,
                          size: 16, color: Colors.white70),
                    ),
                  ]),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  // ── Avatar ──────────────────────────────────────────────
                  Center(
                    child: Column(
                      children: [
                        _AvatarPicker(
                          initials: initials,
                          pictureUrl: provider.profilePictureUrl,
                          userId: auth.userId,
                          onUploaded: (url) =>
                              context.read<AppProvider>().updateProfilePicture(url),
                        ),
                        const SizedBox(height: 12),
                        Text(auth.userName ?? 'Hustler',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(auth.userEmail ?? '',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.of(context).textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Subscription section header ─────────────────────────
                  _SectionHeader('Subscription'),

                  // ── Premium banner ──────────────────────────────────────
                  if (provider.isPremium) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF6C6FFF).withOpacity(0.15),
                            const Color(0xFFFFB347).withOpacity(0.10),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFFFFB347).withOpacity(0.45)),
                      ),
                      child: Row(children: [
                        const Text('👑', style: TextStyle(fontSize: 26)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Premium Member',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              Text(
                                  'Unlimited stacks · Advanced analytics · CSV export',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.of(context).textSecondary)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6C6FFF), Color(0xFFFFB347)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20)),
                          child: const Text('PRO',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    GestureDetector(
                      onTap: () => showPaywallSheet(context),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.accentDim,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppTheme.accent.withOpacity(0.35)),
                        ),
                        child: Row(children: [
                          const Text('⚡', style: TextStyle(fontSize: 28)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Upgrade to Premium',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 3),
                                Text(
                                    'Unlimited stacks, advanced analytics, CSV export',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.of(context).textSecondary)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                                color: AppTheme.accent,
                                borderRadius: BorderRadius.circular(20)),
                            child: const Text('PRO',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Your stacks section ─────────────────────────────────
                  _SectionHeader('Your Stacks'),
                  _Section(children: [
                    _Row(
                        icon: Icons.layers_outlined,
                        iconBg: AppTheme.accentDim,
                        iconColor: AppTheme.accent,
                        label: 'Active SideStacks',
                        subtitle: 'Your active income streams',
                        trailing: provider.isPremium
                            ? '${provider.stacks.length} / ∞'
                            : '${provider.stacks.length} / 2 free'),
                    if (archivedCount > 0)
                      GestureDetector(
                        onTap: () => _showArchivedStacks(context, provider),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 13),
                          child: Row(children: [
                            Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                  color: AppTheme.of(context).cardAlt,
                                  borderRadius: BorderRadius.circular(9)),
                              child: Icon(Icons.archive_outlined,
                                  size: 16, color: AppTheme.of(context).textMuted),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Archived Stacks',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500)),
                                  Text(
                                    'Restore previously archived stacks',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.of(context).textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Text('$archivedCount',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.of(context).textSecondary)),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right,
                                size: 16, color: AppTheme.of(context).textMuted),
                          ]),
                        ),
                      ),
                    _Row(
                        icon: Icons.receipt_long_outlined,
                        iconBg: AppTheme.greenDim,
                        iconColor: AppTheme.green,
                        label: 'Total Transactions',
                        subtitle: 'Logged across all stacks',
                        trailing: '$txCount'),
                    GestureDetector(
                      onTap: () => _showCurrencyPicker(context, provider),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 13),
                        child: Row(children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: AppTheme.accentDim,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Center(
                              child: Text(provider.currencySymbol,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.accent)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Currency',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500)),
                                Text(
                                  'Symbol shown on all transactions',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.of(context).textMuted),
                                ),
                              ],
                            ),
                          ),
                          Text(provider.currencySymbol,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.of(context).textSecondary)),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right,
                              size: 16, color: AppTheme.of(context).textMuted),
                        ]),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),

                  // ── Region ──────────────────────────────────────────────
                  _SectionHeader('Region'),
                  _Section(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Row(children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Center(
                              child: Icon(Icons.language, size: 17,
                                  color: AppTheme.accent)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Australia mode',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                              Text(
                                provider.isAustraliaMode
                                    ? 'GST, BAS, ABN & ATO mileage rate enabled'
                                    : 'Generic tax rate & custom mileage rate',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.of(context).textMuted),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: provider.isAustraliaMode,
                          onChanged: (v) => provider.setIsAustraliaMode(v),
                          activeColor: AppTheme.accent,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ]),
                    ),
                    // Custom mileage rate — shown only for non-AU users
                    if (!provider.isAustraliaMode) ...[
                      Divider(height: 1, color: AppTheme.of(context).border),
                      GestureDetector(
                        onTap: () => _showMileageRateDialog(context, provider),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 13),
                          child: Row(children: [
                            Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Center(
                                  child: Text('🚗',
                                      style: TextStyle(fontSize: 14))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Mileage rate',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500)),
                                  Text(
                                    '\$${provider.customMileageRate.toStringAsFixed(2)} per ${provider.mileageUseKm ? 'km' : 'mile'}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.of(context).textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                size: 16,
                                color: AppTheme.of(context).textMuted),
                          ]),
                        ),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 10),

                  // ── Australian Tax (ABN) — AU users only ─────────────────
                  if (provider.isAustraliaMode) ...[
                    _SectionHeader('Australian Tax'),
                    _Section(children: [
                      GestureDetector(
                        onTap: () => _showAbnDialog(context, provider),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 13),
                          child: Row(children: [
                            Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F766E).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Center(
                                  child: Text('🇦🇺',
                                      style: TextStyle(fontSize: 14))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('ABN',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500)),
                                  Text(
                                    provider.abn?.isNotEmpty == true
                                        ? 'ABN ${provider.abn}'
                                        : 'Add your Australian Business Number',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.of(context).textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                size: 16,
                                color: AppTheme.of(context).textMuted),
                          ]),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                  ],

                  // ── Appearance section ──────────────────────────────────
                  _SectionHeader('Appearance'),
                  _Section(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.accentDim,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(Icons.palette_outlined,
                              size: 16, color: AppTheme.accent),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('Appearance',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500)),
                        ),
                        // Three-way segmented selector
                        Container(
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.of(context).cardAlt,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppTheme.of(context).border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(_kThemeModes.length, (i) {
                              final selected =
                                  provider.themeMode == _kThemeModes[i];
                              return GestureDetector(
                                onTap: () => context
                                    .read<AppProvider>()
                                    .setThemeMode(_kThemeModes[i]),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppTheme.accent
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _kThemeIcons[i],
                                    size: 14,
                                    color: selected
                                        ? Colors.white
                                        : AppTheme.of(context).textMuted,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 10),


                  // ── Notifications section ───────────────────────────────
                  _SectionHeader('Notifications'),
                  _Section(children: [
                    _ToggleRow(
                        icon: Icons.notifications_outlined,
                        iconBg: AppTheme.accentDim,
                        iconColor: AppTheme.accent,
                        label: 'Daily reminders',
                        subtitle: 'Stay on top of your hustle',
                        value: provider.dailyReminderEnabled,
                        onChanged: (v) async {
                          await context.read<AppProvider>().setDailyReminder(v);
                          if (v) {
                            await NotificationService.instance
                                .scheduleDailyReminder(hour: 20, minute: 0);
                          } else {
                            await NotificationService.instance
                                .cancelNotification(0);
                          }
                        }),
                    _ToggleRow(
                        icon: Icons.bar_chart_outlined,
                        iconBg: AppTheme.greenDim,
                        iconColor: AppTheme.green,
                        label: 'Weekly summary',
                        subtitle: 'Your week at a glance, every Sunday',
                        value: provider.weeklyReminderEnabled,
                        onChanged: (v) async {
                          await context.read<AppProvider>().setWeeklyReminder(v);
                          if (v) {
                            final p = context.read<AppProvider>();
                            final week = p.allTransactions.where((tx) {
                              final diff = DateTime.now().difference(tx.date).inDays;
                              return diff <= 7;
                            });
                            final income = week
                                .where((t) => t.type.name == 'income')
                                .fold(0.0, (s, t) => s + t.amount);
                            final expenses = week
                                .where((t) => t.type.name != 'income')
                                .fold(0.0, (s, t) => s + t.amount);
                            await NotificationService.instance
                                .scheduleWeeklySummary(
                              weeklyIncome: income,
                              weeklyExpenses: expenses,
                              symbol: p.currencySymbol,
                            );
                          } else {
                            await NotificationService.instance
                                .cancelNotification(10);
                          }
                        }),
                  ]),
                  const SizedBox(height: 10),

                  // ── Export data ─────────────────────────────────────────
                  _SectionHeader('Data & Export'),
                  _Section(children: [
                    GestureDetector(
                      onTap: () async {
                        if (!provider.isPremium) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('CSV export is a Pro feature',
                                style: TextStyle(fontFamily: 'Sora', fontSize: 13)),
                            backgroundColor: AppTheme.of(context).card,
                            behavior: SnackBarBehavior.floating,
                            action: SnackBarAction(
                              label: 'Upgrade',
                              textColor: AppTheme.accent,
                              onPressed: () {},
                            ),
                          ));
                          return;
                        }
                        final csv = provider.buildCsv();
                        final date = DateTime.now();
                        final filename =
                            'sidestacks_${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}.csv';
                        await downloadCsv(csv, filename);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Exported $filename',
                                style: TextStyle(fontFamily: 'Sora', fontSize: 13)),
                            backgroundColor: AppTheme.of(context).card,
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        child: Row(children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                                color: provider.isPremium
                                    ? AppTheme.accentDim
                                    : AppTheme.of(context).cardAlt,
                                borderRadius: BorderRadius.circular(9)),
                            child: Icon(Icons.download_outlined,
                                size: 16,
                                color: provider.isPremium
                                    ? AppTheme.accent
                                    : AppTheme.of(context).textMuted),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.isPremium
                                      ? 'Export all stacks (CSV)'
                                      : 'Export all stacks (CSV) ✦ Pro',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: provider.isPremium
                                          ? AppTheme.of(context).textPrimary
                                          : AppTheme.of(context).textMuted),
                                ),
                                Text(
                                  'Download your full transaction history',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.of(context).textMuted),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              size: 16, color: AppTheme.of(context).textMuted),
                        ]),
                      ),
                    ),
                    // Connect Bank (TrueLayer)
                    Consumer<AppProvider>(
                      builder: (context, provider, _) {
                        final connected = provider.bankConnected;
                        return GestureDetector(
                          onTap: () => showConnectBankSheet(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 13),
                            child: Row(children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                    color: connected
                                        ? AppTheme.greenDim
                                        : AppTheme.accentDim,
                                    borderRadius: BorderRadius.circular(9)),
                                child: Icon(
                                  connected
                                      ? Icons.account_balance_outlined
                                      : Icons.link_outlined,
                                  size: 16,
                                  color: connected
                                      ? AppTheme.green
                                      : AppTheme.accent,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      connected
                                          ? provider.bankInstitution ?? 'Bank connected'
                                          : 'Connect bank account',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      connected
                                          ? 'Tap to manage or sync transactions'
                                          : 'Auto-import income & expenses',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.of(context).textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              if (connected)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.greenDim,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('LIVE',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.green)),
                                )
                              else
                                Icon(Icons.chevron_right,
                                    size: 16,
                                    color: AppTheme.of(context).textMuted),
                            ]),
                          ),
                        );
                      },
                    ),
                    // Import bank CSV
                    GestureDetector(
                      onTap: () => showCsvImportSheet(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        child: Row(children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                                color: AppTheme.greenDim,
                                borderRadius: BorderRadius.circular(9)),
                            child: const Icon(Icons.upload_file_outlined,
                                size: 16, color: AppTheme.green),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Import bank CSV',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500)),
                                Text(
                                  'Bring in transactions from your bank',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.of(context).textMuted),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              size: 16, color: AppTheme.of(context).textMuted),
                        ]),
                      ),
                    ),
                    // Smart auto-assignment rules
                    Consumer<AppProvider>(
                      builder: (context, p, _) {
                        final ruleCount = p.bankRules.length;
                        return GestureDetector(
                          onTap: () => _showBankRulesSheet(context, p),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 13),
                            child: Row(children: [
                              Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(
                                    color: AppTheme.accentDim,
                                    borderRadius: BorderRadius.circular(9)),
                                child: const Icon(
                                    Icons.auto_awesome_outlined,
                                    size: 16,
                                    color: AppTheme.accent),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text('Smart Stack Rules',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500)),
                                    Text(
                                      ruleCount == 0
                                          ? 'No rules yet — auto-learned on import'
                                          : '$ruleCount merchant rule${ruleCount == 1 ? '' : 's'} saved',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.of(context)
                                              .textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right,
                                  size: 16,
                                  color: AppTheme.of(context).textMuted),
                            ]),
                          ),
                        );
                      },
                    ),
                  ]),
                  const SizedBox(height: 10),

                  // ── About / Support ─────────────────────────────────────
                  const SizedBox(height: 10),
                  _SectionHeader('About'),
                  _Section(children: [
                    _Row(
                      icon: Icons.info_outline,
                      iconBg: AppTheme.accentDim,
                      iconColor: AppTheme.accent,
                      label: 'Version',
                      subtitle: 'SideStacks for iOS & Android',
                      trailing: 'v1.0.0',
                    ),
                    _Row(
                      icon: Icons.person_outline,
                      iconBg: AppTheme.of(context).cardAlt,
                      iconColor: AppTheme.of(context).textSecondary,
                      label: 'Account',
                      subtitle: auth.userEmail ?? 'Not signed in',
                      trailing: '',
                    ),
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Email us: support@sidestacks.app'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                                color: AppTheme.greenDim,
                                borderRadius: BorderRadius.circular(9)),
                            child: const Icon(Icons.mail_outline,
                                size: 16, color: AppTheme.green),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Help & Support',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500)),
                                Text('support@sidestacks.app',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.of(context).textMuted)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              size: 16, color: AppTheme.of(context).textMuted),
                        ]),
                      ),
                    ),
                    // Rate the app
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Opening App Store… ⭐'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(9)),
                            child: const Center(
                              child: Text('⭐', style: TextStyle(fontSize: 15)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text('Rate the App',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                          ),
                          Icon(Icons.chevron_right,
                              size: 16, color: AppTheme.of(context).textMuted),
                        ]),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 24),
                  Center(
                    child: Column(
                      children: [
                        Text('Made for hustlers ⚡',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.of(context).textMuted)),
                        const SizedBox(height: 2),
                        Text('SideStacks v1.0.0 · Built with 🖤',
                            style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.of(context).textMuted)),
                      ],
                    ),
                  ),

                  // ── Sign out — destructive, full-width, bottom of screen ──
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Sign out',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor: AppTheme.of(context).card,
                              title: const Text('Sign out?'),
                              content:
                                  const Text('You can sign back in anytime.'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: Text('Cancel',
                                        style: TextStyle(
                                            color: AppTheme.of(context).textSecondary))),
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Sign out',
                                        style:
                                            TextStyle(color: AppTheme.red))),
                              ],
                            ),
                          );
                          if (confirm == true && context.mounted) {
                            await context.read<AuthProvider>().signOut();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}

// ─── Avatar picker ────────────────────────────────────────────────────────────

class _AvatarPicker extends StatefulWidget {
  final String initials;
  final String? pictureUrl;
  final String? userId;
  final ValueChanged<String> onUploaded;

  const _AvatarPicker({
    required this.initials,
    required this.pictureUrl,
    required this.userId,
    required this.onUploaded,
  });

  @override
  State<_AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<_AvatarPicker> {
  bool _uploading = false;
  String? _localPath; // shown immediately before upload completes

  Future<void> _pick() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() {
      _localPath = file.path;
      _uploading = true;
    });

    try {
      if (widget.userId == null) throw Exception('Not signed in');
      final ref = FirebaseStorage.instance
          .ref()
          .child('profilePictures/${widget.userId}.jpg');
      await ref.putFile(File(file.path));
      final url = await ref.getDownloadURL();
      widget.onUploaded(url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Could not upload photo — check your Firebase Storage rules.'),
            backgroundColor: AppTheme.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final picUrl = widget.pictureUrl;
    return GestureDetector(
      onTap: _uploading ? null : _pick,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 82, height: 82,
            decoration: BoxDecoration(
              color: AppTheme.accentDim,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.accent, width: 2),
            ),
            child: ClipOval(
              child: _uploading
                  ? const Center(
                      child: SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(
                          color: AppTheme.accent, strokeWidth: 2),
                      ),
                    )
                  : _localPath != null
                      ? Image.file(File(_localPath!), fit: BoxFit.cover)
                      : picUrl != null
                          ? Image.network(
                              picUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(widget.initials,
                                    style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.accent)),
                              ),
                            )
                          : Center(
                              child: Text(widget.initials,
                                  style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.accent)),
                            ),
            ),
          ),
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              color: AppTheme.accent,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.of(context).background, width: 2),
            ),
            child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// ─── Archived stacks sheet ────────────────────────────────────────────────────

void _showArchivedStacks(BuildContext context, AppProvider provider) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: const Color(0xFF111217),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF353645)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: const Color(0xFF353645),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Text('Archived Stacks',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('These stacks are hidden from the dashboard.',
              style:
                  TextStyle(fontSize: 12, color: AppTheme.of(context).textSecondary)),
          const SizedBox(height: 16),
          ...provider.archivedStacks.map((stack) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.of(context).card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.of(context).border),
                ),
                child: Row(children: [
                  Text(stack.hustleType.emoji,
                      style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stack.name,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        Text('${stack.transactions.length} transactions',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.of(context).textSecondary)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      provider.unarchiveSideStack(stack.id);
                      Navigator.pop(context);
                    },
                    child: const Text('Restore',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              )),
        ],
      ),
    ),
  );
}

// ─── Bank smart rules sheet ───────────────────────────────────────────────────

void _showBankRulesSheet(BuildContext context, AppProvider provider) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) {
        final rules = provider.bankRules;
        final stacks = provider.allStacks;
        return Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          decoration: BoxDecoration(
            color: AppTheme.of(context).surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.of(context).borderLight),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: AppTheme.of(context).borderLight,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(children: [
                const Text('⚡',
                    style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Smart Stack Rules',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ),
                if (rules.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      // Clear all rules
                      for (final merchant in rules.keys.toList()) {
                        await provider.deleteBankRule(merchant);
                      }
                      setModalState(() {});
                    },
                    child: Text('Clear all',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.red)),
                  ),
              ]),
              const SizedBox(height: 4),
              Text(
                'SideStacks automatically learns which stack to assign when you import bank transactions.',
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.of(context).textSecondary,
                    height: 1.4),
              ),
              const SizedBox(height: 16),
              if (rules.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No rules yet.\nImport transactions from your bank and SideStacks will learn the rules automatically.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.of(context).textMuted,
                          height: 1.5),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: rules.length,
                    separatorBuilder: (_, __) => Divider(
                        height: 1, color: AppTheme.of(context).border),
                    itemBuilder: (ctx2, i) {
                      final merchant = rules.keys.elementAt(i);
                      final stackId = rules.values.elementAt(i);
                      final stack = stacks.cast<dynamic>().firstWhere(
                          (s) => s.id == stackId, orElse: () => null);
                      final stackName = stack?.name ?? 'Unknown';
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        title: Text(
                          merchant.isEmpty
                              ? '(empty)'
                              : merchant[0].toUpperCase() +
                                  merchant.substring(1),
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          '→ $stackName',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.of(context).textMuted),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline,
                              size: 18, color: AppTheme.red),
                          onPressed: () async {
                            await provider.deleteBankRule(merchant);
                            setModalState(() {});
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

// ─── ABN dialog ───────────────────────────────────────────────────────────────

void _showAbnDialog(BuildContext context, AppProvider provider) {
  final ctrl = TextEditingController(text: provider.abn ?? '');
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.of(context).card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Australian Business Number',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your ABN will appear on invoices you generate with SideStacks.',
            style: TextStyle(
                fontSize: 12,
                color: AppTheme.of(context).textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontFamily: 'Courier', fontSize: 14),
            decoration: InputDecoration(
              hintText: 'e.g. 12 345 678 901',
              hintStyle: TextStyle(
                  color: AppTheme.of(context).textMuted, fontSize: 13),
              prefixText: 'ABN  ',
              prefixStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.of(context).textMuted),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          onPressed: () {
            provider.setAbn(ctrl.text);
            Navigator.pop(ctx);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

// ─── Mileage rate dialog (non-AU users) ──────────────────────────────────────

void _showMileageRateDialog(BuildContext context, AppProvider provider) {
  final rateCtrl = TextEditingController(
      text: provider.customMileageRate.toStringAsFixed(2));
  bool useKm = provider.mileageUseKm;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => AlertDialog(
        backgroundColor: AppTheme.of(context).card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Mileage Rate',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set your reimbursement or deduction rate per distance unit.',
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.of(context).textSecondary),
            ),
            const SizedBox(height: 16),
            // Unit selector
            Row(children: [
              Text('Unit:',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.of(context).textMuted)),
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text('km'),
                selected: useKm,
                onSelected: (v) => setModalState(() => useKm = true),
                selectedColor: AppTheme.accent.withOpacity(0.2),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('miles'),
                selected: !useKm,
                onSelected: (v) => setModalState(() => useKm = false),
                selectedColor: AppTheme.accent.withOpacity(0.2),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: rateCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontFamily: 'Courier', fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g. 0.67',
                hintStyle: TextStyle(
                    color: AppTheme.of(context).textMuted, fontSize: 13),
                prefixText: '\$ per ${useKm ? 'km' : 'mile'}  ',
                prefixStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.of(context).textMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              final rate = double.tryParse(rateCtrl.text) ?? provider.customMileageRate;
              provider.setCustomMileageRate(rate);
              provider.setMileageUseKm(useKm);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

// ─── Currency picker ──────────────────────────────────────────────────────────

void _showCurrencyPicker(BuildContext context, AppProvider provider) {
  const currencies = [
    ('\$', 'USD — US Dollar'),
    ('£', 'GBP — British Pound'),
    ('€', 'EUR — Euro'),
    ('¥', 'JPY — Japanese Yen'),
    ('₹', 'INR — Indian Rupee'),
    ('₩', 'KRW — Korean Won'),
    ('A\$', 'AUD — Australian Dollar'),
    ('C\$', 'CAD — Canadian Dollar'),
    ('R\$', 'BRL — Brazilian Real'),
    ('₣', 'CHF — Swiss Franc'),
  ];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF111217),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF353645)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: const Color(0xFF353645),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Text('Currency',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Choose the symbol shown on your transactions',
              style:
                  TextStyle(fontSize: 12, color: AppTheme.of(context).textSecondary)),
          const SizedBox(height: 16),
          ...currencies.map((c) {
            final selected = provider.currencySymbol == c.$1;
            return GestureDetector(
              onTap: () {
                provider.setCurrencySymbol(c.$1);
                Navigator.pop(context);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.accentDim : AppTheme.of(context).card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: selected
                          ? AppTheme.accent
                          : AppTheme.of(context).border),
                ),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.accent
                          : AppTheme.of(context).cardAlt,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(
                        child: Text(c.$1,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? Colors.white
                                    : AppTheme.of(context).textSecondary))),
                  ),
                  const SizedBox(width: 12),
                  Text(c.$2,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? AppTheme.accent
                              : AppTheme.of(context).textPrimary)),
                  const Spacer(),
                  if (selected)
                    const Icon(Icons.check_circle,
                        size: 18, color: AppTheme.accent),
                ]),
              ),
            );
          }),
        ],
      ),
    ),
  );
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final List<Widget> children;
  const _Section({required this.children});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: AppTheme.of(context).card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.of(context).border)),
        child: Column(
            children: children
                .expand((w) => [
                      w,
                      if (w != children.last)
                        const Divider(height: 1, indent: 16, endIndent: 16)
                    ])
                .toList()),
      );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconColor;
  final String label, trailing;
  final String? subtitle;
  const _Row(
      {required this.icon,
      required this.iconBg,
      required this.iconColor,
      required this.label,
      required this.trailing,
      this.subtitle});
  @override
  Widget build(BuildContext context) => Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 16, color: iconColor)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.of(context).textMuted)),
              ],
            ),
          ),
          Text(trailing,
              style: TextStyle(
                  fontSize: 12, color: AppTheme.of(context).textSecondary)),
        ]),
      );
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconColor;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  const _ToggleRow(
      {required this.icon,
      required this.iconBg,
      required this.iconColor,
      required this.label,
      required this.value,
      this.subtitle,
      this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 16, color: iconColor)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.of(context).textMuted)),
              ],
            ),
          ),
          Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppTheme.green,
              inactiveThumbColor: AppTheme.of(context).textMuted,
              inactiveTrackColor: AppTheme.of(context).cardAlt),
        ]),
      );
}

/// ALL CAPS section header with an optional subtitle, matching QBSE's
/// settings style of labelled grouped sections.
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionHeader(this.title, {this.subtitle});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.of(context).textMuted,
                letterSpacing: 0.8,
              ),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitle!,
                  style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.of(context).textMuted),
                ),
              ),
          ],
        ),
      );
}
