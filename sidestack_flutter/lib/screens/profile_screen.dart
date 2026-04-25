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

// ─── Theme mode helpers ───────────────────────────────────────────────────────
const _kThemeModes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];
const _kThemeIcons = [
  Icons.brightness_auto_outlined,
  Icons.light_mode_outlined,
  Icons.dark_mode_outlined,
];

// ─────────────────────────────────────────────────────────────────────────────
// ProfileScreen
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _upgradeBannerDismissed = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final auth = context.watch<AuthProvider>();
    final colors = AppTheme.of(context);
    final txCount = provider.allTransactions.length;
    final archivedCount = provider.archivedStacks.length;
    final initials = (auth.userName ?? auth.userEmail ?? 'U')
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return Scaffold(
      backgroundColor: colors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: colors.surface,
            title: Text('Profile',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: colors.textPrimary)),
          ),

          // ── Upgrade banner (free users only) ──────────────────────────────
          if (!provider.isPremium && !_upgradeBannerDismissed)
            SliverToBoxAdapter(
              child: GestureDetector(
                onTap: () => showPaywallSheet(context),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF6C6FFF),
                        Color(0xFF9B59B6),
                        AppTheme.accent,
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    const Icon(Icons.bolt_outlined,
                        size: 20, color: Colors.white),
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
                                color: Colors.white),
                          ),
                          SizedBox(height: 1),
                          Text(
                            'Advanced analytics · Unlimited stacks · Exports',
                            style:
                                TextStyle(fontSize: 10, color: Colors.white70),
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
                      child: const Text('Go Pro',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6C6FFF))),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // ── Compact profile header ──────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _AvatarPicker(
                        initials: initials,
                        pictureUrl: provider.profilePictureUrl,
                        userId: auth.userId,
                        onUploaded: (url) =>
                            context.read<AppProvider>().updateProfilePicture(url),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider.useRealName
                                  ? (auth.userName ?? provider.firestoreDisplayName ?? 'Hustler')
                                  : (provider.username ?? auth.userName ?? provider.firestoreDisplayName ?? 'Hustler'),
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              auth.userEmail ?? '',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // PRO badge or Go Pro chip
                      if (provider.isPremium)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6C6FFF), Color(0xFFFFB347)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('PRO',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        )
                      else
                        GestureDetector(
                          onTap: () => showPaywallSheet(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.accentDim,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color:
                                      AppTheme.accent.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.bolt,
                                    size: 13, color: AppTheme.accent),
                                SizedBox(width: 4),
                                Text('Go Pro',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.accent)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── My SideStacks ───────────────────────────────────────
                  _SectionHeader('My SideStacks'),
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
                      _NavRow(
                        icon: Icons.archive_outlined,
                        iconBg: colors.cardAlt,
                        iconColor: colors.textMuted,
                        label: 'Archived Stacks',
                        subtitle: 'Restore previously archived stacks',
                        trailing: '$archivedCount',
                        onTap: () =>
                            _showArchivedStacks(context, provider),
                      ),
                    _Row(
                        icon: Icons.receipt_long_outlined,
                        iconBg: AppTheme.greenDim,
                        iconColor: AppTheme.green,
                        label: 'Total Transactions',
                        subtitle: 'Logged across all stacks',
                        trailing: '$txCount'),
                  ]),
                  const SizedBox(height: 4),

                  // ── Settings ────────────────────────────────────────────
                  _SectionHeader('Settings'),
                  _Section(children: [
                    _NavRow(
                      icon: Icons.tune_outlined,
                      iconBg: AppTheme.accentDim,
                      iconColor: AppTheme.accent,
                      label: 'Preferences',
                      subtitle:
                          'Currency, appearance, notifications & more',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const _PreferencesPage()),
                      ),
                    ),
                    _NavRow(
                      icon: Icons.person_outline,
                      iconBg: colors.cardAlt,
                      iconColor: colors.textSecondary,
                      label: 'Account',
                      subtitle: auth.userEmail ?? 'Manage your account',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const _AccountPage()),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),

                  // ── Resources ───────────────────────────────────────────
                  _SectionHeader('Resources'),
                  _Section(children: [
                    _NavRow(
                      icon: Icons.mail_outline,
                      iconBg: AppTheme.greenDim,
                      iconColor: AppTheme.green,
                      label: 'Help & Support',
                      subtitle: 'support@sidestacks.app',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Email us: support@sidestacks.app'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    _NavRow(
                      icon: Icons.lock_outline,
                      iconBg: colors.cardAlt,
                      iconColor: colors.textSecondary,
                      label: 'Privacy Policy',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Visit sidestacks.app/privacy'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    _NavRow(
                      icon: Icons.article_outlined,
                      iconBg: colors.cardAlt,
                      iconColor: colors.textSecondary,
                      label: 'Terms of Use',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Visit sidestacks.app/terms'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    _NavRow(
                      icon: Icons.star_outline,
                      iconBg: const Color(0xFFFFFBEB),
                      iconColor: const Color(0xFFF59E0B),
                      label: 'Rate the App',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Opening App Store… ⭐'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ]),

                  // ── Footer ──────────────────────────────────────────────
                  const SizedBox(height: 28),
                  Center(
                    child: Text(
                      'SideStacks v1.0.0 · Made with 🖤',
                      style: TextStyle(
                          fontSize: 11, color: colors.textMuted),
                    ),
                  ),

                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Preferences page (full-screen push)
// ─────────────────────────────────────────────────────────────────────────────

class _PreferencesPage extends StatelessWidget {
  const _PreferencesPage();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final colors = AppTheme.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: Text('Preferences',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              size: 18, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // ── Name ──────────────────────────────────────────────────────
          _SectionHeader('Name'),
          _Section(children: [
            _NameEditRow(),
          ]),

          // ── Display name ───────────────────────────────────────────────
          _SectionHeader('Display Name'),
          _Section(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.badge_outlined, size: 17, color: AppTheme.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Show as',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.of(context).textPrimary)),
                          Text('What appears in greetings and the profile header',
                              style: TextStyle(fontSize: 11, color: AppTheme.of(context).textSecondary)),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.read<AppProvider>().setUseRealName(true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: provider.useRealName ? AppTheme.accent : AppTheme.of(context).card,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: provider.useRealName ? AppTheme.accent : AppTheme.of(context).border),
                          ),
                          child: Center(
                            child: Text('Real name',
                                style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                  color: provider.useRealName ? Colors.white : AppTheme.of(context).textSecondary,
                                )),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.read<AppProvider>().setUseRealName(false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !provider.useRealName ? AppTheme.accent : AppTheme.of(context).card,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: !provider.useRealName ? AppTheme.accent : AppTheme.of(context).border),
                          ),
                          child: Center(
                            child: Text('Username',
                                style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                  color: !provider.useRealName ? Colors.white : AppTheme.of(context).textSecondary,
                                )),
                          ),
                        ),
                      ),
                    ),
                  ]),
                  if (!provider.useRealName) ...[
                    const SizedBox(height: 12),
                    _UsernameField(current: provider.username ?? ''),
                  ],
                ],
              ),
            ),
          ]),

          // ── Your Stacks ────────────────────────────────────────────────
          _SectionHeader('Your Stacks'),
          _Section(children: [
            _NavRow(
              icon: Icons.monetization_on_outlined,
              iconBg: AppTheme.accentDim,
              iconColor: AppTheme.accent,
              label: 'Currency',
              subtitle:
                  'Symbol shown on all transactions',
              trailing: provider.currencySymbol,
              onTap: () => _showCurrencyPicker(context, provider),
            ),
          ]),

          // ── Region ────────────────────────────────────────────────────
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
                      child: Icon(Icons.language,
                          size: 17, color: AppTheme.accent)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Australia mode',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                      Text(
                        provider.isAustraliaMode
                            ? 'GST, BAS, ABN & ATO mileage rate enabled'
                            : 'Generic tax rate & custom mileage rate',
                        style: TextStyle(
                            fontSize: 11, color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: provider.isAustraliaMode,
                  onChanged: (v) => provider.setIsAustraliaMode(v),
                  activeColor: AppTheme.accent,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ]),
            ),
            if (!provider.isAustraliaMode) ...[
              Divider(height: 1, color: colors.border),
              _NavRow(
                icon: Icons.directions_car_outlined,
                iconBg: const Color(0xFF8B5CF6).withOpacity(0.12),
                iconColor: const Color(0xFF8B5CF6),
                label: 'Mileage rate',
                subtitle:
                    '\$${provider.customMileageRate.toStringAsFixed(2)} per ${provider.mileageUseKm ? 'km' : 'mile'}',
                onTap: () => _showMileageRateDialog(context, provider),
              ),
            ],
          ]),

          // ── Australian Tax ────────────────────────────────────────────
          if (provider.isAustraliaMode) ...[
            _SectionHeader('Australian Tax'),
            _Section(children: [
              _NavRow(
                icon: Icons.flag_outlined,
                iconBg: const Color(0xFF0F766E).withOpacity(0.12),
                iconColor: const Color(0xFF0F766E),
                label: 'ABN',
                subtitle: provider.abn?.isNotEmpty == true
                    ? 'ABN ${provider.abn}'
                    : 'Add your Australian Business Number',
                onTap: () => _showAbnDialog(context, provider),
              ),
            ]),
          ],

          // ── Appearance ────────────────────────────────────────────────
          _SectionHeader('Appearance'),
          _Section(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 32, height: 32,
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
                  Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: colors.cardAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.border),
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
                            child: Icon(_kThemeIcons[i],
                                size: 14,
                                color: selected
                                    ? Colors.white
                                    : colors.textMuted),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ]),

          // ── Notifications ─────────────────────────────────────────────
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
                      final diff =
                          DateTime.now().difference(tx.date).inDays;
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

          // ── Data & Export ─────────────────────────────────────────────
          _SectionHeader('Data & Export'),
          _Section(children: [
            // Export CSV
            GestureDetector(
              onTap: () async {
                if (!provider.isPremium) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('CSV export is a Pro feature',
                        style: TextStyle(
                            fontFamily: 'Sora', fontSize: 13)),
                    backgroundColor: colors.card,
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
                        style: TextStyle(
                            fontFamily: 'Sora', fontSize: 13)),
                    backgroundColor: colors.card,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 13),
                child: Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                        color: provider.isPremium
                            ? AppTheme.accentDim
                            : colors.cardAlt,
                        borderRadius: BorderRadius.circular(9)),
                    child: Icon(Icons.download_outlined,
                        size: 16,
                        color: provider.isPremium
                            ? AppTheme.accent
                            : colors.textMuted),
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
                                  ? colors.textPrimary
                                  : colors.textMuted),
                        ),
                        Text('Download your full transaction history',
                            style: TextStyle(
                                fontSize: 11, color: colors.textMuted)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      size: 16, color: colors.textMuted),
                ]),
              ),
            ),
            // Import CSV
            _NavRow(
              icon: Icons.upload_file_outlined,
              iconBg: AppTheme.greenDim,
              iconColor: AppTheme.green,
              label: 'Import CSV',
              subtitle: 'Bring in transactions from a CSV file',
              onTap: () => showCsvImportSheet(context),
            ),
          ]),

          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Account page (full-screen push)
// ─────────────────────────────────────────────────────────────────────────────

class _AccountPage extends StatefulWidget {
  const _AccountPage();

  @override
  State<_AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<_AccountPage> {
  bool _loading = false;

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.of(context).card,
        title: const Text('Sign out?'),
        content: const Text('You can sign back in anytime.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel',
                  style: TextStyle(
                      color: AppTheme.of(context).textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign out',
                  style: TextStyle(color: AppTheme.red))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<AuthProvider>().signOut();
      // Pop everything off the navigator so the sign-in screen is shown
      // immediately — no need to swipe back through Profile → Account.
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  Future<void> _deleteAccount() async {
    final auth = context.read<AuthProvider>();
    final colors = AppTheme.of(context);

    // Step 1 — confirm intent
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.card,
        title: const Text('Delete account?',
            style: TextStyle(color: AppTheme.red)),
        content: const Text(
            'This permanently deletes your SideStacks account and all data. '
            'This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel',
                  style:
                      TextStyle(color: colors.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue',
                  style: TextStyle(color: AppTheme.red))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Step 2 — re-auth if email user
    if (auth.isEmailUser) {
      final password = await _promptPassword(
          title: 'Confirm your password',
          subtitle: 'Enter your password to delete your account.');
      if (password == null || !mounted) return;

      setState(() => _loading = true);
      final reAuthErr =
          await auth.reauthenticateWithEmail(password);
      if (!mounted) return;
      if (reAuthErr != null) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(reAuthErr),
          backgroundColor: AppTheme.red,
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
    } else {
      setState(() => _loading = true);
    }

    // Step 3 — delete
    final err = await auth.deleteAccount();
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err),
        backgroundColor: AppTheme.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
    // If deletion succeeded, Firebase auth state changes and the app
    // routes back to the sign-in screen automatically via auth listener.
  }

  Future<void> _deactivateAccount() async {
    final colors = AppTheme.of(context);
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.card,
        title: const Text('Deactivate account'),
        content: const Text(
            'Account deactivation is not yet available in this version. '
            'Please contact support@sidestacks.app and we\'ll take care of it.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it')),
        ],
      ),
    );
  }

  /// Shows a password prompt bottom sheet; returns the entered password or null.
  Future<String?> _promptPassword(
      {required String title, String? subtitle}) async {
    final ctrl = TextEditingController();
    String? result;
    final colors = AppTheme.of(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setS) {
            bool obscure = true;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                          color: colors.border,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Text(title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary)),
                  ],
                  const SizedBox(height: 16),
                  StatefulBuilder(
                    builder: (ctx2, setO) => TextField(
                      controller: ctrl,
                      obscureText: obscure,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Your password',
                        hintStyle: TextStyle(
                            color: colors.textMuted, fontSize: 13),
                        suffixIcon: IconButton(
                          icon: Icon(
                              obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 18,
                              color: colors.textMuted),
                          onPressed: () =>
                              setO(() => obscure = !obscure),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      onPressed: () {
                        result = ctrl.text.trim().isEmpty
                            ? null
                            : ctrl.text;
                        Navigator.of(sheetCtx).pop();
                      },
                      child: const Text('Confirm',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final colors = AppTheme.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: Text('Account',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              size: 18, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // ── Account info ───────────────────────────────────────
                _SectionHeader('Account Info'),
                _Section(children: [
                  _Row(
                      icon: Icons.person_outline,
                      iconBg: AppTheme.accentDim,
                      iconColor: AppTheme.accent,
                      label: auth.userName ?? 'User',
                      subtitle: auth.userEmail ?? '',
                      trailing: ''),
                ]),

                // ── Security ──────────────────────────────────────────
                _SectionHeader('Security'),
                if (auth.isEmailUser) ...[
                  _Section(children: [
                    _NavRow(
                      icon: Icons.lock_reset_outlined,
                      iconBg: AppTheme.accentDim,
                      iconColor: AppTheme.accent,
                      label: 'Change Password',
                      subtitle: 'Update your login password',
                      onTap: () =>
                          _showChangePasswordSheet(context, auth),
                    ),
                    _NavRow(
                      icon: Icons.email_outlined,
                      iconBg: AppTheme.accentDim,
                      iconColor: AppTheme.accent,
                      label: 'Send Reset Email',
                      subtitle: 'Get a password reset link in your inbox',
                      onTap: () => _sendResetEmail(context, auth),
                    ),
                  ]),
                ] else ...[
                  _Section(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                              color: colors.cardAlt,
                              borderRadius: BorderRadius.circular(9)),
                          child: Icon(
                            auth.signInProvider == 'Apple'
                                ? Icons.apple
                                : Icons.g_mobiledata,
                            size: 20,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Signed in with ${auth.signInProvider}',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: colors.textPrimary),
                              ),
                              Text(
                                'Your password is managed by ${auth.signInProvider}. '
                                'There\'s no separate SideStacks password to reset.',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: colors.textMuted,
                                    height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ]),
                ],

                // ── Danger zone ────────────────────────────────────────
                _SectionHeader('Danger Zone'),
                _Section(children: [
                  GestureDetector(
                    onTap: _deactivateAccount,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 13),
                      child: Row(children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(9)),
                          child: const Icon(Icons.pause_circle_outline,
                              size: 16,
                              color: Color(0xFFF59E0B)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text('Deactivate Account',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                              Text('Temporarily disable your account',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: colors.textMuted)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            size: 16, color: colors.textMuted),
                      ]),
                    ),
                  ),
                  GestureDetector(
                    onTap: _deleteAccount,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 13),
                      child: Row(children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                              color: AppTheme.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(9)),
                          child: Icon(Icons.delete_forever_outlined,
                              size: 16, color: AppTheme.red),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text('Delete Account',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.red)),
                              Text(
                                  'Permanently delete account & all data',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: colors.textMuted)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            size: 16, color: colors.textMuted),
                      ]),
                    ),
                  ),
                ]),

                // ── Sign out ───────────────────────────────────────────
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Sign out',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.red,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _signOut,
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
    );
  }
}

// ─── Send password reset email (from within the app) ─────────────────────────

Future<void> _sendResetEmail(
    BuildContext context, AuthProvider auth) async {
  final email = auth.userEmail;
  if (email == null) return;
  final success = await auth.resetPassword(email);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success
          ? 'Reset email sent to $email — check your inbox.'
          : (auth.error ?? 'Something went wrong.')),
      backgroundColor: success ? AppTheme.green : AppTheme.red,
      behavior: SnackBarBehavior.floating,
    ));
  }
}

// ─── Change password sheet ────────────────────────────────────────────────────

void _showChangePasswordSheet(
    BuildContext context, AuthProvider auth) {
  final currentCtrl = TextEditingController();
  final newCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  String? errorMsg;
  bool loading = false;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.of(context).surface,
    shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetCtx) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
      child: StatefulBuilder(
        builder: (ctx, setS) {
          Future<void> save() async {
            final current = currentCtrl.text;
            final newPass = newCtrl.text;
            final confirm = confirmCtrl.text;

            if (newPass.length < 6) {
              setS(() => errorMsg =
                  'New password must be at least 6 characters.');
              return;
            }
            if (newPass != confirm) {
              setS(() => errorMsg = 'Passwords do not match.');
              return;
            }

            setS(() {
              errorMsg = null;
              loading = true;
            });

            final reErr =
                await auth.reauthenticateWithEmail(current);
            if (!ctx.mounted) return;
            if (reErr != null) {
              setS(() {
                errorMsg = reErr;
                loading = false;
              });
              return;
            }

            final changeErr =
                await auth.changePassword(newPass);
            if (!ctx.mounted) return;
            setS(() => loading = false);

            if (changeErr != null) {
              setS(() => errorMsg = changeErr);
            } else {
              Navigator.of(sheetCtx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password updated successfully'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }

          final colors = AppTheme.of(context);
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Text('Change Password',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary)),
                const SizedBox(height: 4),
                Text('Enter your current password, then your new one.',
                    style: TextStyle(
                        fontSize: 12, color: colors.textSecondary)),
                const SizedBox(height: 16),
                TextField(
                  controller: currentCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Current password',
                    labelStyle:
                        TextStyle(fontSize: 13, color: colors.textMuted),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'New password',
                    labelStyle:
                        TextStyle(fontSize: 13, color: colors.textMuted),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirm new password',
                    labelStyle:
                        TextStyle(fontSize: 13, color: colors.textMuted),
                  ),
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 10),
                  Text(errorMsg!,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.red)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    onPressed: loading ? null : save,
                    child: loading
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Update Password',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
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
  String? _localPath;

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
          .child('profile_pictures/${widget.userId}/avatar.jpg');
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
            width: 68, height: 68,
            decoration: BoxDecoration(
              color: AppTheme.accentDim,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.accent, width: 2),
            ),
            child: ClipOval(
              child: _uploading
                  ? const Center(
                      child: SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: AppTheme.accent, strokeWidth: 2)))
                  : _localPath != null
                      ? Image.file(File(_localPath!), fit: BoxFit.cover)
                      : picUrl != null
                          ? Image.network(
                              picUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(widget.initials,
                                    style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.accent)),
                              ),
                            )
                          : Center(
                              child: Text(widget.initials,
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.accent)),
                            ),
            ),
          ),
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: AppTheme.accent,
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppTheme.of(context).background, width: 2),
            ),
            child:
                const Icon(Icons.camera_alt, size: 10, color: Colors.white),
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
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.of(context).textSecondary)),
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
                  Icon(stack.hustleType.icon,
                      size: 20,
                      color: AppTheme.of(context).textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stack.name,
                            style: const TextStyle(
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

// ─── ABN dialog ───────────────────────────────────────────────────────────────

void _showAbnDialog(BuildContext context, AppProvider provider) {
  final ctrl = TextEditingController(text: provider.abn ?? '');
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.of(context).card,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
            child: const Text('Cancel')),
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

// ─── Mileage rate dialog ──────────────────────────────────────────────────────

void _showMileageRateDialog(BuildContext context, AppProvider provider) {
  final rateCtrl = TextEditingController(
      text: provider.customMileageRate.toStringAsFixed(2));
  bool useKm = provider.mileageUseKm;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => AlertDialog(
        backgroundColor: AppTheme.of(context).card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
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
            Row(children: [
              Text('Unit:',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.of(context).textMuted)),
              const SizedBox(width: 12),
              ChoiceChip(
                  label: const Text('km'),
                  selected: useKm,
                  onSelected: (_) => setModalState(() => useKm = true),
                  selectedColor:
                      AppTheme.accent.withOpacity(0.2)),
              const SizedBox(width: 8),
              ChoiceChip(
                  label: const Text('miles'),
                  selected: !useKm,
                  onSelected: (_) => setModalState(() => useKm = false),
                  selectedColor:
                      AppTheme.accent.withOpacity(0.2)),
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
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              final rate = double.tryParse(rateCtrl.text) ??
                  provider.customMileageRate;
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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Choose the symbol shown on your transactions',
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.of(context).textSecondary)),
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
                  color: selected
                      ? AppTheme.accentDim
                      : AppTheme.of(context).card,
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
                        borderRadius: BorderRadius.circular(9)),
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
                        Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                            color: AppTheme.of(context).border)
                    ])
                .toList()),
      );
}

/// Static display row (icon + label + optional subtitle + trailing text).
class _Row extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconColor;
  final String label, trailing;
  final String? subtitle;

  const _Row({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.trailing,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
              width: 32, height: 32,
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
          if (trailing.isNotEmpty)
            Text(trailing,
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.of(context).textSecondary)),
        ]),
      );
}

/// Tappable navigation row (icon + label + optional subtitle + chevron).
class _NavRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconColor;
  final String label;
  final String? subtitle;
  final String? trailing;
  final VoidCallback? onTap;

  const _NavRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 16, color: iconColor)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.textPrimary)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: TextStyle(
                          fontSize: 11, color: colors.textMuted)),
              ],
            ),
          ),
          if (trailing != null) ...[
            Text(trailing!,
                style: TextStyle(
                    fontSize: 12, color: colors.textSecondary)),
            const SizedBox(width: 4),
          ],
          Icon(Icons.chevron_right, size: 16, color: colors.textMuted),
        ]),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconColor;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _ToggleRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
    this.subtitle,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Container(
              width: 32, height: 32,
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

// ─── Name editor ─────────────────────────────────────────────────────────────

class _NameEditRow extends StatefulWidget {
  const _NameEditRow();
  @override
  State<_NameEditRow> createState() => _NameEditRowState();
}

class _NameEditRowState extends State<_NameEditRow> {
  late TextEditingController _ctrl;
  bool _editing = false;
  bool _saving = false;
  bool _saved = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_editing) {
      final name = context.read<AuthProvider>().userName ?? '';
      _ctrl = TextEditingController(text: name);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name cannot be empty.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    final error = await context.read<AuthProvider>().changeDisplayName(name);
    if (!mounted) return;
    if (error != null) {
      setState(() { _saving = false; _error = error; });
    } else {
      setState(() { _saving = false; _saved = true; _editing = false; });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _saved = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final currentName = context.watch<AuthProvider>().userName ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.person_outline, size: 17, color: AppTheme.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _editing
                  ? TextField(
                      controller: _ctrl,
                      autofocus: true,
                      style: TextStyle(fontSize: 13, color: colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'First Last',
                        errorText: _error,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                      onSubmitted: (_) => _saving ? null : _save(),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(currentName.isNotEmpty ? currentName : 'Not set',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.textPrimary)),
                        Text('Shown in greetings', style: TextStyle(fontSize: 11, color: colors.textMuted)),
                      ],
                    ),
            ),
            const SizedBox(width: 8),
            if (_editing) ...[
              GestureDetector(
                onTap: () => setState(() { _editing = false; _error = null; }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text('Cancel', style: TextStyle(fontSize: 12, color: colors.textMuted)),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: _saving ? null : _save,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _saved ? AppTheme.green : AppTheme.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _saving
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_saved ? 'Saved ✓' : 'Save',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ] else
              GestureDetector(
                onTap: () {
                  _ctrl.text = currentName;
                  setState(() { _editing = true; _saved = false; });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.cardAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.border),
                  ),
                  child: Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colors.textSecondary)),
                ),
              ),
          ]),
        ],
      ),
    );
  }
}

// ─── Username inline editor ───────────────────────────────────────────────────

class _UsernameField extends StatefulWidget {
  final String current;
  const _UsernameField({required this.current});
  @override
  State<_UsernameField> createState() => _UsernameFieldState();
}

class _UsernameFieldState extends State<_UsernameField> {
  late final TextEditingController _ctrl;
  bool _saving = false;
  bool _saved = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.current);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newUsername = _ctrl.text.trim();
    if (newUsername == widget.current) return;
    setState(() { _saving = true; _error = null; });

    final auth = context.read<AuthProvider>();
    final app = context.read<AppProvider>();

    final error = await auth.changeUsername(newUsername);
    if (!mounted) return;

    if (error != null) {
      setState(() { _saving = false; _error = error; });
    } else {
      // Keep local prefs in sync
      await app.setUsername(newUsername);
      if (mounted) {
        setState(() { _saving = false; _saved = true; _error = null; });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _saved = false);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: TextStyle(fontSize: 13, color: AppTheme.of(context).textPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g. jordandawes',
                  prefixText: '@',
                  hintStyle: TextStyle(color: AppTheme.of(context).textMuted),
                  errorText: _error,
                ),
                autocorrect: false,
                keyboardType: TextInputType.visiblePassword,
                onChanged: (_) { if (_error != null) setState(() => _error = null); },
                onSubmitted: (_) => _saving ? null : _save(),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _saving ? null : _save,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _saved ? AppTheme.green : AppTheme.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _saving
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        _saved ? 'Saved ✓' : 'Save',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

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
                child: Text(subtitle!,
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.of(context).textMuted)),
              ),
          ],
        ),
      );
}
