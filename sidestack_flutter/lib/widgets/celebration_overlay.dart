import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../theme/app_theme.dart';

// ─── Entry point ──────────────────────────────────────────────────────────────

void showMilestoneCelebration(
  BuildContext context, {
  required double amount,
  required String symbol,
}) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.65),
    builder: (_) => _CelebrationDialog(amount: amount, symbol: symbol),
  );
}

// ─── Share helper ─────────────────────────────────────────────────────────────

Future<void> _shareMilestoneCard(
    BuildContext context, String milestoneLabel, GlobalKey shareCardKey) async {
  try {
    // Capture the card widget as PNG bytes
    final boundary = shareCardKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;
    final bytes = byteData.buffer.asUint8List();

    // Write to a temp file
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/milestone.png');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      text:
          'Just hit $milestoneLabel in side hustle profit 🚀 Tracked with SideStacks — sidestacks.app #SideHustle #SideStacks',
    );
  } catch (e) {
    debugPrint('shareMilestoneCard error: $e');
  }
}

// ─── Dialog ───────────────────────────────────────────────────────────────────

class _CelebrationDialog extends StatefulWidget {
  final double amount;
  final String symbol;
  const _CelebrationDialog({required this.amount, required this.symbol});
  @override
  State<_CelebrationDialog> createState() => _CelebrationDialogState();
}

class _CelebrationDialogState extends State<_CelebrationDialog>
    with TickerProviderStateMixin {
  // Key lives here so each dialog instance gets its own — prevents
  // "Multiple widgets used the same GlobalKey" when the dialog fires twice.
  final _shareCardKey = GlobalKey();
  late AnimationController _confettiCtrl;
  late AnimationController _cardCtrl;
  late Animation<double> _cardScale;
  late Animation<double> _cardFade;
  final _random = math.Random();
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();

    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..forward();

    _cardCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    _cardScale = CurvedAnimation(parent: _cardCtrl, curve: Curves.elasticOut);
    _cardFade = CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOut);

    _particles = List.generate(60, (_) => _Particle(_random));

    // Auto-dismiss after 4 s
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    _cardCtrl.dispose();
    super.dispose();
  }

  String get _milestoneLabel {
    final v = widget.amount;
    if (v >= 10000) return '${widget.symbol}${(v / 1000).toStringAsFixed(0)}k';
    if (v >= 1000) return '${widget.symbol}${(v / 1000).toStringAsFixed(1)}k';
    return '${widget.symbol}${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Confetti layer
            AnimatedBuilder(
              animation: _confettiCtrl,
              builder: (_, __) => CustomPaint(
                painter: _ConfettiPainter(
                  particles: _particles,
                  progress: _confettiCtrl.value,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            // Celebration card
            Center(
              child: FadeTransition(
                opacity: _cardFade,
                child: ScaleTransition(
                  scale: _cardScale,
                  child: RepaintBoundary(
                    key: _shareCardKey, // instance key — safe for multiple dialogs
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 32),
                      decoration: BoxDecoration(
                        color: const Color(0xFF18191F),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                            color: AppTheme.accent.withOpacity(0.4),
                            width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accent.withOpacity(0.15),
                            blurRadius: 40,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.celebration_outlined, size: 52, color: AppTheme.accent),
                          const SizedBox(height: 14),
                          const Text(
                            'Milestone unlocked',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF8B8FA8),
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _milestoneLabel,
                            style: const TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 44,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accent,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'total profit from side hustles',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF8B8FA8),
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Divider line
                          Container(
                            height: 1,
                            width: 160,
                            color: AppTheme.accent.withOpacity(0.18),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Keep stacking',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFEEF0F8),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // App attribution — drives organic installs when shared
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF6C6FFF),
                                      Color(0xFF9B6FFF)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Center(
                                  child: Icon(Icons.bolt_outlined,
                                      size: 10, color: AppTheme.accent),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'sidestacks.app',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.accent,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () =>
                                    Navigator.of(context).maybePop(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentDim,
                                    borderRadius:
                                        BorderRadius.circular(20),
                                    border: Border.all(
                                        color: AppTheme.accent
                                            .withOpacity(0.3)),
                                  ),
                                  child: const Text(
                                    'Dismiss',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.accent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: () => _shareMilestoneCard(
                                    context, _milestoneLabel, _shareCardKey),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accent,
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.share_outlined,
                                          size: 13,
                                          color: Colors.white),
                                      SizedBox(width: 6),
                                      Text(
                                        'Share',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Particle model ───────────────────────────────────────────────────────────

class _Particle {
  final double x; // 0..1 horizontal start
  final double yStart;
  final double speed; // 0..1 relative fall speed
  final double size;
  final Color color;
  final double rotation;
  final double rotationSpeed;
  final bool isCircle;

  _Particle(math.Random r)
      : x = r.nextDouble(),
        yStart = -0.05 - r.nextDouble() * 0.15,
        speed = 0.4 + r.nextDouble() * 0.6,
        size = 5 + r.nextDouble() * 7,
        color = _kConfettiColors[r.nextInt(_kConfettiColors.length)],
        rotation = r.nextDouble() * math.pi * 2,
        rotationSpeed = (r.nextDouble() - 0.5) * 8,
        isCircle = r.nextBool();
}

const _kConfettiColors = [
  Color(0xFF6C6FFF), // accent
  Color(0xFF3DD68C), // green
  Color(0xFFF1496B), // red
  Color(0xFFFFB547), // amber
  Color(0xFF4FC3F7), // sky
  Color(0xFFE040FB), // purple
  Colors.white,
];

// ─── Confetti painter ─────────────────────────────────────────────────────────

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress; // 0..1

  const _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    // Fade out confetti in last 30% of animation
    final opacity = progress > 0.7
        ? (1 - (progress - 0.7) / 0.3).clamp(0.0, 1.0)
        : 1.0;

    for (final p in particles) {
      final t = (progress * p.speed).clamp(0.0, 1.0);
      final x = p.x * size.width + math.sin(t * math.pi * 2) * 30;
      final y = (p.yStart + t * 1.2) * size.height;
      if (y < -20 || y > size.height + 20) continue;

      final rotation = p.rotation + t * p.rotationSpeed;
      paint.color = p.color.withOpacity(opacity);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);

      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 0.5),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => progress != old.progress;
}
