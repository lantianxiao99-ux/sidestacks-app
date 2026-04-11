import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../providers/mileage_provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

const _uuid = Uuid();

// ─── Entry point ──────────────────────────────────────────────────────────────

void showMileageScreen(BuildContext context) {
  Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => const MileageScreen(),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: FadeTransition(opacity: anim, child: child),
      ),
      transitionDuration: const Duration(milliseconds: 260),
    ),
  );
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class MileageScreen extends StatefulWidget {
  const MileageScreen({super.key});

  @override
  State<MileageScreen> createState() => _MileageScreenState();
}

class _MileageScreenState extends State<MileageScreen> {
  @override
  void initState() {
    super.initState();
    // Load mileage data on first open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MileageProvider>().load();
    });
  }

  void _showLogTrip() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => const _LogTripSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mileage = context.watch<MileageProvider>();
    final symbol = context.watch<AppProvider>().currencySymbol;
    final trips = mileage.trips;
    final totalKm = mileage.totalKmThisYear;
    final deduction = mileage.taxDeductionThisYear;
    final totalMiles = totalKm / 1.60934;
    final year = DateTime.now().year;

    return Scaffold(
      backgroundColor: AppTheme.of(context).background,
      appBar: AppBar(
        backgroundColor: AppTheme.of(context).surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mileage',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // ── Year summary banner ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.accent.withOpacity(0.15),
                      AppTheme.green.withOpacity(0.10),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.accent.withOpacity(0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('🚗',
                            style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$year Mileage',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.of(context).textMuted),
                            ),
                            Text(
                              '${totalMiles.toStringAsFixed(1)} miles  ·  ${totalKm.toStringAsFixed(1)} km',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _StatPill(
                            label: 'Trips logged',
                            value: '${trips.where((t) => t.date.year == year).length}',
                            color: AppTheme.accent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatPill(
                            label: 'Est. tax deduction',
                            value: '$symbol${deduction.toStringAsFixed(0)}',
                            color: AppTheme.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Based on HMRC 45p/mile rate. Consult a tax professional.',
                      style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.of(context).textMuted,
                          fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Trips list ──────────────────────────────────────────────────
          if (trips.isEmpty) ...[
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.accent.withOpacity(0.2),
                            AppTheme.accent.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text('🗺️',
                            style: TextStyle(fontSize: 28)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No trips logged yet',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Log your first business trip to start\ntracking mileage for tax purposes.',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.of(context).textSecondary,
                          height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Log first trip',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _showLogTrip,
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final trip = trips[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _TripCard(trip: trip),
                    );
                  },
                  childCount: trips.length,
                ),
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: trips.isNotEmpty
          ? FloatingActionButton(
              onPressed: _showLogTrip,
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              elevation: 4,
              child: const Icon(Icons.add, size: 24),
            )
          : null,
    );
  }
}

// ─── Trip card ────────────────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  final MileageTrip trip;
  const _TripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final miles = trip.distanceKm / 1.60934;
    final deduction = miles * 0.45;

    return Dismissible(
      key: ValueKey(trip.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.red.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: AppTheme.red),
      ),
      onDismissed: (_) {
        context.read<MileageProvider>().deleteTrip(trip.id);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.of(context).card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.of(context).border),
        ),
        child: Row(
          children: [
            // Date + purpose col
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🚗', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Text(
                        trip.purpose,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat('d MMM yyyy').format(trip.date)} · ${trip.from} → ${trip.to}',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.of(context).textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Distance + deduction col
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${miles.toStringAsFixed(1)} mi',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Courier',
                      color: AppTheme.accent),
                ),
                Text(
                  '£${deduction.toStringAsFixed(2)} deductible',
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.green,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stat pill ────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatPill(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.of(context).textMuted,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Courier',
                  color: color)),
        ],
      ),
    );
  }
}

// ─── Log trip sheet ───────────────────────────────────────────────────────────

class _LogTripSheet extends StatefulWidget {
  const _LogTripSheet();

  @override
  State<_LogTripSheet> createState() => _LogTripSheetState();
}

class _LogTripSheetState extends State<_LogTripSheet> {
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  final _distanceCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _useKm = true; // toggle km / miles

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _distanceCtrl.dispose();
    _purposeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppTheme.accent,
            surface: AppTheme.of(context).card,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  bool get _canSave =>
      _fromCtrl.text.trim().isNotEmpty &&
      _toCtrl.text.trim().isNotEmpty &&
      (double.tryParse(_distanceCtrl.text) ?? 0) > 0 &&
      _purposeCtrl.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_canSave) return;
    final raw = double.parse(_distanceCtrl.text);
    // Convert to km if input was miles
    final distanceKm = _useKm ? raw : raw * 1.60934;
    final trip = MileageTrip(
      id: _uuid.v4(),
      date: _date,
      from: _fromCtrl.text.trim(),
      to: _toCtrl.text.trim(),
      distanceKm: distanceKm,
      purpose: _purposeCtrl.text.trim(),
    );
    await context.read<MileageProvider>().addTrip(trip);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).viewInsets.bottom;
    final estimatedMiles = () {
      final raw = double.tryParse(_distanceCtrl.text) ?? 0;
      return _useKm ? raw / 1.60934 : raw;
    }();
    final estimatedDeduction = estimatedMiles * 0.45;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + padding),
      decoration: BoxDecoration(
        color: AppTheme.of(context).surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.of(context).borderLight),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.of(context).borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Log a trip',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),

            // Date
            _Label('Date'),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: AppTheme.of(context).card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.of(context).border),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 14, color: AppTheme.of(context).textMuted),
                  const SizedBox(width: 10),
                  Text(
                    DateFormat('d MMMM yyyy').format(_date),
                    style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.of(context).textPrimary),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 14),

            // From / To
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label('From'),
                    TextField(
                      controller: _fromCtrl,
                      style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.of(context).textPrimary),
                      decoration: const InputDecoration(
                          hintText: 'Starting point'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label('To'),
                    TextField(
                      controller: _toCtrl,
                      style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.of(context).textPrimary),
                      decoration:
                          const InputDecoration(hintText: 'Destination'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 14),

            // Distance + unit toggle
            _Label('Distance'),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _distanceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                      fontSize: 20,
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.w600,
                      color: AppTheme.of(context).textPrimary),
                  decoration: InputDecoration(
                    hintText: '0.0',
                    suffixText: _useKm ? 'km' : 'mi',
                    suffixStyle: TextStyle(
                        fontSize: 12,
                        color: AppTheme.of(context).textMuted),
                  ),
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              // km / miles toggle
              GestureDetector(
                onTap: () => setState(() => _useKm = !_useKm),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentDim,
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: AppTheme.accent.withOpacity(0.4)),
                  ),
                  child: Text(
                    _useKm ? 'km' : 'mi',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accent),
                  ),
                ),
              ),
            ]),

            // Live deduction preview
            if (estimatedDeduction > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.greenDim,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.savings_outlined,
                      size: 13, color: AppTheme.green),
                  const SizedBox(width: 6),
                  Text(
                    'Est. deduction: £${estimatedDeduction.toStringAsFixed(2)}  (${estimatedMiles.toStringAsFixed(1)} mi × 45p)',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.green),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 14),

            // Purpose
            _Label('Purpose'),
            TextField(
              controller: _purposeCtrl,
              style: TextStyle(
                  fontSize: 13, color: AppTheme.of(context).textPrimary),
              decoration: const InputDecoration(
                  hintText: 'e.g. Client meeting, site visit…'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _canSave ? _save : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.of(context).border,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Save trip',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppTheme.of(context).textMuted,
            letterSpacing: 0.8,
          ),
        ),
      );
}
