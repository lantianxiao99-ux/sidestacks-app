import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../services/csv_export_service.dart';
import 'package:url_launcher/url_launcher.dart';

const _kPrivacyUrl = 'https://lantianxiao99-ux.github.io/sidestacks-legal/privacy.html';
const _kTermsUrl   = 'https://lantianxiao99-ux.github.io/sidestacks-legal/terms.html';

Future<void> _openLegalUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

// ─── Theme helpers ─────────────────────────────────────────────────────────────
const _kThemeModes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];
const _kThemeLabels = ['System', 'Light', 'Dark'];
const _kThemeIcons = [
  Icons.brightness_auto_outlined,
  Icons.light_mode_outlined,
  Icons.dark_mode_outlined,
];

/// Slide-in settings panel from the right edge of the screen.
void showSettingsPanel(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'settings',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, anim, _) => const _SettingsPanelContent(),
    transitionBuilder: (ctx, anim, _, child) {
      final curved =
          CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

class _SettingsPanelContent extends StatelessWidget {
  const _SettingsPanelContent();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = (screenWidth * 0.88).clamp(0.0, 360.0);

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: AppTheme.of(context).surface,
        child: SizedBox(
          width: panelWidth,
          height: double.infinity,
          child: const _SettingsPanelBody(),
        ),
      ),
    );
  }
}

class _SettingsPanelBody extends StatelessWidget {
  const _SettingsPanelBody();

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

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────
            Row(
              children: [
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.of(context).card,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppTheme.of(context).border),
                    ),
                    child: Icon(Icons.close,
                        size: 14,
                        color: AppTheme.of(context).textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Avatar + name ──────────────────────────────────────────
            Row(
              children: [
                _AvatarPicker(
                  initials: initials,
                  pictureUrl: provider.profilePictureUrl,
                  userId: auth.userId,
                  size: 60,
                  onUploaded: (url) =>
                      context.read<AppProvider>().updateProfilePicture(url),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.userName ?? 'Hustler',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        auth.userEmail ?? '',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.of(context).textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Premium banner ─────────────────────────────────────────
            if (!provider.isPremium) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.accentDim,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: AppTheme.accent.withOpacity(0.35)),
                ),
                child: Row(children: [
                  const Icon(Icons.bolt_outlined, size: 22, color: AppTheme.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Upgrade to Pro',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('Unlimited stacks · CSV export',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.of(context)
                                    .textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('PRO',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
            ],

            // ── Account stats ──────────────────────────────────────────
            _Section(children: [
              _Row(
                icon: Icons.layers_outlined,
                iconBg: AppTheme.accentDim,
                iconColor: AppTheme.accent,
                label: 'Active Stacks',
                trailing: '${provider.stacks.length}',
              ),
              _Row(
                icon: Icons.receipt_long_outlined,
                iconBg: AppTheme.greenDim,
                iconColor: AppTheme.green,
                label: 'Total Transactions',
                trailing: '$txCount',
              ),
              if (archivedCount > 0)
                GestureDetector(
                  onTap: () => _showArchivedStacks(context, provider),
                  child: _RowWidget(
                    icon: Icons.archive_outlined,
                    iconBg: AppTheme.of(context).cardAlt,
                    iconColor: AppTheme.of(context).textMuted,
                    label: 'Archived Stacks',
                    trailing: '$archivedCount',
                    showChevron: true,
                  ),
                ),
            ]),
            const SizedBox(height: 10),

            // ── Appearance ─────────────────────────────────────────────
            _Section(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppTheme.accentDim,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.palette_outlined,
                        size: 15, color: AppTheme.accent),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Appearance',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                  Container(
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppTheme.of(context).cardAlt,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: AppTheme.of(context).border),
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
                                horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppTheme.accent
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_kThemeIcons[i],
                                    size: 12,
                                    color: selected
                                        ? Colors.white
                                        : AppTheme.of(context).textMuted),
                                const SizedBox(width: 3),
                                Text(_kThemeLabels[i],
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: selected
                                            ? Colors.white
                                            : AppTheme.of(context)
                                                .textMuted)),
                              ],
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

            // ── Currency ───────────────────────────────────────────────
            _Section(children: [
              GestureDetector(
                onTap: () => _showCurrencyPicker(context, provider),
                child: _RowWidget(
                  icon: null,
                  iconBg: AppTheme.accentDim,
                  iconColor: AppTheme.accent,
                  label: 'Currency',
                  trailing: provider.currencySymbol,
                  showChevron: true,
                  customIcon: Center(
                    child: Text(provider.currencySymbol,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accent)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),

            // ── Notifications ──────────────────────────────────────────
            _Section(children: [
              _ToggleRow(
                icon: Icons.notifications_outlined,
                iconBg: AppTheme.accentDim,
                iconColor: AppTheme.accent,
                label: 'Daily reminders',
                value: true,
              ),
              _ToggleRow(
                icon: Icons.bar_chart_outlined,
                iconBg: AppTheme.greenDim,
                iconColor: AppTheme.green,
                label: 'Weekly summary',
                value: false,
              ),
            ]),
            const SizedBox(height: 10),

            // ── Export ─────────────────────────────────────────────────
            _Section(children: [
              GestureDetector(
                onTap: () async {
                  if (!provider.isPremium) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('CSV export is a Pro perk — unlock it to get your data out anytime.',
                          style: TextStyle(
                              fontFamily: 'Sora', fontSize: 13)),
                      backgroundColor: AppTheme.of(context).card,
                      behavior: SnackBarBehavior.floating,
                      action: SnackBarAction(
                          label: 'Upgrade',
                          textColor: AppTheme.accent,
                          onPressed: () {}),
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
                      backgroundColor: AppTheme.of(context).card,
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                },
                child: _RowWidget(
                  icon: Icons.download_outlined,
                  iconBg: provider.isPremium
                      ? AppTheme.accentDim
                      : AppTheme.of(context).cardAlt,
                  iconColor: provider.isPremium
                      ? AppTheme.accent
                      : AppTheme.of(context).textMuted,
                  label: provider.isPremium
                      ? 'Export all stacks (CSV)'
                      : 'Export all stacks ✦ Pro',
                  trailing: '',
                  showChevron: true,
                  labelColor: provider.isPremium
                      ? null
                      : AppTheme.of(context).textMuted,
                ),
              ),
            ]),
            const SizedBox(height: 10),

            // ── Sign out ───────────────────────────────────────────────
            _Section(children: [
              GestureDetector(
                onTap: () async {
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
                                  color: AppTheme.of(context)
                                      .textSecondary)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Sign out',
                              style: TextStyle(color: AppTheme.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    Navigator.pop(context); // close panel first
                    await context.read<AuthProvider>().signOut();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  child: Row(children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                          color: AppTheme.redDim,
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.logout,
                          size: 15, color: AppTheme.red),
                    ),
                    const SizedBox(width: 10),
                    const Text('Sign out',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.red)),
                  ]),
                ),
              ),
            ]),

            const SizedBox(height: 10),

            // ── Legal ──────────────────────────────────────────────────
            _Section(children: [
              GestureDetector(
                onTap: () => _openLegalUrl(_kPrivacyUrl),
                child: _RowWidget(
                  icon: Icons.shield_outlined,
                  iconBg: AppTheme.accentDim,
                  iconColor: AppTheme.accent,
                  label: 'Privacy Policy',
                  trailing: '',
                  showChevron: true,
                ),
              ),
              GestureDetector(
                onTap: () => _openLegalUrl(_kTermsUrl),
                child: _RowWidget(
                  icon: Icons.description_outlined,
                  iconBg: AppTheme.accentDim,
                  iconColor: AppTheme.accent,
                  label: 'Terms of Service',
                  trailing: '',
                  showChevron: true,
                ),
              ),
            ]),

            const SizedBox(height: 20),
            Center(
              child: Text('SideStacks v1.0',
                  style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.of(context).textMuted)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable section + row widgets ──────────────────────────────────────────

class _Section extends StatelessWidget {
  final List<Widget> children;
  const _Section({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.of(context).card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.of(context).border),
      ),
      child: Column(
        children: children.indexed.map((entry) {
          final (i, child) = entry;
          return Column(
            children: [
              child,
              if (i < children.length - 1)
                Divider(
                    height: 1,
                    thickness: 1,
                    color: AppTheme.of(context).border,
                    indent: 14,
                    endIndent: 14),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String trailing;
  const _Row({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) => _RowWidget(
        icon: icon,
        iconBg: iconBg,
        iconColor: iconColor,
        label: label,
        trailing: trailing,
      );
}

class _RowWidget extends StatelessWidget {
  final IconData? icon;
  final Widget? customIcon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final Color? labelColor;
  final String trailing;
  final bool showChevron;
  const _RowWidget({
    this.icon,
    this.customIcon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    this.labelColor,
    required this.trailing,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
              color: iconBg, borderRadius: BorderRadius.circular(8)),
          child: customIcon ??
              Icon(icon, size: 15, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: labelColor ?? AppTheme.of(context).textPrimary)),
        ),
        if (trailing.isNotEmpty)
          Text(trailing,
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.of(context).textSecondary)),
        if (showChevron) ...[
          const SizedBox(width: 4),
          Icon(Icons.chevron_right,
              size: 15, color: AppTheme.of(context).textMuted),
        ],
      ]),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final bool value;
  const _ToggleRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
              color: iconBg, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 15, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500)),
        ),
        Switch(
          value: value,
          onChanged: (_) {},
          activeColor: AppTheme.accent,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]),
    );
  }
}

// ─── Avatar picker ────────────────────────────────────────────────────────────

class _AvatarPicker extends StatefulWidget {
  final String initials;
  final String? pictureUrl;
  final String? userId;
  final double size;
  final ValueChanged<String> onUploaded;
  const _AvatarPicker({
    required this.initials,
    required this.pictureUrl,
    required this.userId,
    required this.onUploaded,
    this.size = 60,
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
        imageQuality: 85);
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Photo upload didn\'t work — check your connection and try again.'),
          backgroundColor: AppTheme.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final picUrl = widget.pictureUrl;
    return GestureDetector(
      onTap: _uploading ? null : _pick,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              color: AppTheme.accentDim,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.accent, width: 2),
            ),
            child: ClipOval(
              child: _uploading
                  ? const Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: AppTheme.accent, strokeWidth: 2)))
                  : _localPath != null
                      ? Image.file(File(_localPath!), fit: BoxFit.cover)
                      : picUrl != null
                          ? Image.network(picUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                    child: Text(widget.initials,
                                        style: TextStyle(
                                            fontSize: s * 0.32,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.accent)),
                                  ))
                          : Center(
                              child: Text(widget.initials,
                                  style: TextStyle(
                                      fontSize: s * 0.32,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.accent))),
            ),
          ),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: AppTheme.accent,
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppTheme.of(context).surface, width: 1.5),
            ),
            child: const Icon(Icons.camera_alt,
                size: 10, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// ─── Archived stacks sheet ─────────────────────────────────────────────────────

void _showArchivedStacks(BuildContext context, AppProvider provider) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: AppTheme.of(context).surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.of(context).border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: AppTheme.of(context).border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Text('Archived Stacks',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Hidden from the dashboard — data intact.',
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
                  Icon(stack.hustleType.icon, size: 20,
                      color: AppTheme.of(context).textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stack.name,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        Text(
                            '${stack.transactions.length} transactions',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.of(context)
                                    .textSecondary)),
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
        color: AppTheme.of(context).surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.of(context).border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: AppTheme.of(context).border,
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
                margin: const EdgeInsets.only(bottom: 8),
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
                  Text(c.$1,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? AppTheme.accent
                              : AppTheme.of(context).textPrimary)),
                  const SizedBox(width: 12),
                  Text(c.$2,
                      style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.of(context).textSecondary)),
                  const Spacer(),
                  if (selected)
                    const Icon(Icons.check_circle,
                        size: 16, color: AppTheme.accent),
                ]),
              ),
            );
          }),
        ],
      ),
    ),
  );
}
