// ignore_for_file: deprecated_member_use

import 'dart:math' as math;

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:cpu_analyser_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  DESIGN TOKENS
// ═══════════════════════════════════════════════════════════════════════════
const _bg     = Color(0xFFF5F8FE);   // off-white canvas
const _navy   = Color(0xFF0A1628);   // deep ink for text
const _cyan   = Color(0xFF0094C6);   // primary accent
const _teal   = Color(0xFF00A896);   // secondary accent
const _green  = Color(0xFF00B074);   // success green
const _amber  = Color(0xFFD4930A);   // warning amber

// ═══════════════════════════════════════════════════════════════════════════
//  SPLASH SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // ── Animation controllers ─────────────────────────────────────────────────
  late final AnimationController _enter;    // 2.8 s one-shot – drives all entry
  late final AnimationController _pulse;    // ∞ – expanding rings
  late final AnimationController _spin;     // ∞ – halo rotation
  late final AnimationController _scan;     // ∞ – icon scan-line
  late final AnimationController _shimmer;  // ∞ – bottom bar shimmer
  late final AnimationController _particle; // ∞ – floating dots
  late final AnimationController _breathe;  // ∞ – logo subtle scale pulse

  // ── Entry sub-animations (all driven by _enter 0→1) ──────────────────────
  late final Animation<double> _bgScale;        // 0.00–0.30  radial bloom
  late final Animation<double> _logoFade;       // 0.05–0.38
  late final Animation<double> _logoReveal;     // 0.08–0.46  clip reveal
  late final Animation<double> _logoSpring;     // 0.08–0.50  spring scale
  late final Animation<double> _circuitDraw;    // 0.32–0.68  circuit lines
  late final Animation<double> _titleFade;      // 0.44–0.66
  late final Animation<Offset>  _titleSlide;   // 0.44–0.66
  late final Animation<double> _divider;        // 0.58–0.74  horizontal rule
  late final Animation<double> _badgeFade;      // 0.64–0.80
  late final Animation<Offset>  _badgeSlide;   // 0.64–0.80
  late final Animation<double> _subtitleFade;   // 0.72–0.88
  late final Animation<double> _barFade;        // 0.86–1.00

  bool _showTitle    = false;
  bool _showSubtitle = false;
  bool _showBadges   = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    // Release native splash immediately – our Flutter splash takes over
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: _bg,
    ));

    // ── Master entrance controller (2.8 s) ────────────────────────────────
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    // ── Infinite loops ────────────────────────────────────────────────────
    _pulse    = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();
    _spin     = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _scan     = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();
    _shimmer  = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700))..repeat();
    _particle = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
    _breathe  = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat(reverse: true);

    // ── Helper: build a curved interval off _enter ────────────────────────
    CurvedAnimation iv(double from, double to, Curve c) =>
        CurvedAnimation(parent: _enter, curve: Interval(from, to, curve: c));

    // ── Sub-animations ────────────────────────────────────────────────────
    _bgScale = iv(0.00, 0.30, Curves.easeOut);

    _logoFade   = iv(0.05, 0.38, Curves.easeIn);
    _logoReveal = iv(0.08, 0.46, Curves.easeOutCubic);
    _logoSpring = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.45, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 65,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.12, end: 1.00)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 15),
    ]).animate(CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.08, 0.52),
    ));

    _circuitDraw = iv(0.32, 0.70, Curves.easeInOut);

    _titleFade  = iv(0.44, 0.66, Curves.easeOut);
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.55),
      end: Offset.zero,
    ).animate(iv(0.44, 0.66, Curves.easeOutCubic));

    _divider = iv(0.58, 0.76, Curves.easeOutCubic);

    _badgeFade  = iv(0.64, 0.82, Curves.easeOut);
    _badgeSlide = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(iv(0.64, 0.82, Curves.easeOutCubic));

    _subtitleFade = iv(0.72, 0.90, Curves.easeOut);
    _barFade      = iv(0.86, 1.00, Curves.easeOut);

    // ── Fire master ───────────────────────────────────────────────────────
    _enter.forward();

    // Staggered text triggers (keeps widget tree simple)
    _delay(1250, () => setState(() => _showTitle    = true));
    _delay(1850, () => setState(() => _showBadges   = true));
    _delay(2100, () => setState(() => _showSubtitle = true));

    // Navigate after exactly 5 s
    _delay(5000, () {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MonitorScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 550),
        ),
      );
    });
  }

  void _delay(int ms, VoidCallback fn) =>
      Future.delayed(Duration(milliseconds: ms), () {
        if (mounted) fn();
      });

  @override
  void dispose() {
    _enter.dispose();
    _pulse.dispose();
    _spin.dispose();
    _scan.dispose();
    _shimmer.dispose();
    _particle.dispose();
    _breathe.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(
          children: [

            //  ①  Grid dot background (static custom paint — no rebuild)
            Positioned.fill(
              child: CustomPaint(painter: _DotGridPainter()),
            ),

            //  ②  Radial colour bloom
            AnimatedBuilder(
              animation: _bgScale,
              builder: (_, __) => Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.28),
                    radius: 0.3 + _bgScale.value * 1.0,
                    colors: const [
                      Color(0xFFCDE8F8),
                      Color(0xFFE4F2FB),
                      _bg,
                    ],
                    stops: const [0.0, 0.42, 1.0],
                  ),
                ),
              ),
            ),

            //  ③  Floating particles
            AnimatedBuilder(
              animation: _particle,
              builder: (_, __) => CustomPaint(
                painter: _ParticlePainter(_particle.value),
                size: size,
              ),
            ),

            //  ④  Pulsing rings  (3 staggered)
            Center(
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => SizedBox(
                  width: 360, height: 360,
                  child: CustomPaint(painter: _RingsPainter(_pulse.value)),
                ),
              ),
            ),

            //  ⑤  Outer rotating dashed halo
            Center(
              child: AnimatedBuilder(
                animation: _spin,
                builder: (_, __) => Transform.rotate(
                  angle: _spin.value * math.pi * 2,
                  child: SizedBox(
                    width: 256, height: 256,
                    child: CustomPaint(
                      painter: _DashedRingPainter(
                        color: _cyan.withOpacity(0.22),
                        dashCount: 36,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            //  ⑥  Inner counter-rotating halo
            Center(
              child: AnimatedBuilder(
                animation: _spin,
                builder: (_, __) => Transform.rotate(
                  angle: -_spin.value * math.pi * 2 * 0.55,
                  child: SizedBox(
                    width: 185, height: 185,
                    child: CustomPaint(
                      painter: _DashedRingPainter(
                        color: _teal.withOpacity(0.18),
                        dashCount: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            //  ⑦  Circuit lines
            Center(
              child: AnimatedBuilder(
                animation: _circuitDraw,
                builder: (_, __) => SizedBox(
                  width: 340, height: 340,
                  child: CustomPaint(
                    painter: _CircuitPainter(_circuitDraw.value),
                  ),
                ),
              ),
            ),

            //  ⑧  Logo card  (clip-reveal + spring + scan + breathe)
            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge(
                    [_logoFade, _logoReveal, _logoSpring, _scan, _breathe]),
                builder: (_, __) {
                  // subtle breathe adds ±1% scale after entry
                  final breatheScale = 1.0 +
                      Tween<double>(begin: -0.008, end: 0.008)
                          .evaluate(_breathe);
                  return FadeTransition(
                    opacity: _logoFade,
                    child: Transform.scale(
                      scale: _logoSpring.value * breatheScale,
                      child: _LogoCard(
                        revealT: _logoReveal.value,
                        scanT:   _scan.value,
                      ),
                    ),
                  );
                },
              ),
            ),

            //  ⑨  Text block – sits in lower half
            Positioned(
              left: 0, right: 0,
              bottom: size.height * 0.155,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // ── "PROBE IT" typewriter ───────────────────────────────
                  SlideTransition(
                    position: _titleSlide,
                    child: FadeTransition(
                      opacity: _titleFade,
                      child: _showTitle
                          ? AnimatedTextKit(
                              animatedTexts: [
                                TyperAnimatedText(
                                  'PROBE IT',
                                  textStyle: const TextStyle(
                                    fontSize: 46,
                                    fontWeight: FontWeight.w900,
                                    color: _navy,
                                    letterSpacing: 9,
                                    height: 1,
                                  ),
                                  speed: const Duration(milliseconds: 72),
                                ),
                              ],
                              totalRepeatCount: 1,
                            )
                          : const SizedBox(height: 55),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── Expanding gradient rule ─────────────────────────────
                  AnimatedBuilder(
                    animation: _divider,
                    builder: (_, __) => SizedBox(
                      width: 230 * _divider.value,
                      height: 1.5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          gradient: const LinearGradient(
                            colors: [
                              Colors.transparent,
                              _cyan,
                              _teal,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Chip badges ─────────────────────────────────────────
                  SlideTransition(
                    position: _badgeSlide,
                    child: FadeTransition(
                      opacity: _badgeFade,
                      child: _showBadges
                          ? const _BadgeRow()
                          : const SizedBox(height: 30),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Subtitle (FadeAnimatedText) ─────────────────────────
                  FadeTransition(
                    opacity: _subtitleFade,
                    child: _showSubtitle
                        ? AnimatedTextKit(
                            animatedTexts: [
                              FadeAnimatedText(
                                'Deep CPU Analyser  |  Data · Calculations · Insights',
                                textStyle: TextStyle(
                                  fontSize: 12,
                                  color: _navy.withOpacity(0.45),
                                  letterSpacing: 1.6,
                                  fontWeight: FontWeight.w500,
                                ),
                                duration: const Duration(milliseconds: 2800),
                              ),
                            ],
                            totalRepeatCount: 1,
                          )
                        : const SizedBox(height: 20),
                  ),
                ],
              ),
            ),

            //  ⑩  Shimmer progress bar
            Positioned(
              left: 0, right: 0, bottom: 42,
              child: FadeTransition(
                opacity: _barFade,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 52),
                      child: AnimatedBuilder(
                        animation: _shimmer,
                        builder: (_, __) => SizedBox(
                          height: 3,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: CustomPaint(
                              painter: _ShimmerPainter(_shimmer.value),
                              size: const Size(double.infinity, 3),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Initialising sensors…',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 2.2,
                        color: _navy.withOpacity(0.24),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  LOGO CARD
// ═══════════════════════════════════════════════════════════════════════════
class _LogoCard extends StatelessWidget {
  final double revealT; // 0→1  top-to-bottom clip reveal
  final double scanT;   // 0→1  scan-line sweep (looping)

  const _LogoCard({required this.revealT, required this.scanT});

  @override
  Widget build(BuildContext context) {
    const d = 120.0; // card diameter

    return ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: revealT.clamp(0.0, 1.0),
        child: Stack(
          alignment: Alignment.center,
          children: [

            // Soft glow corona
            Container(
              width: d + 52, height: d + 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _cyan.withOpacity(0.20),
                    blurRadius: 60,
                    spreadRadius: 10,
                  ),
                  BoxShadow(
                    color: _teal.withOpacity(0.14),
                    blurRadius: 36,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),

            // Card shell
            Container(
              width: d, height: d,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _cyan.withOpacity(0.16),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: _cyan.withOpacity(0.10),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipOval(
                child: Stack(
                  children: [
                    // App icon
                    Image.asset(
                      'assets/app_icon.png',
                      width: d, height: d,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.memory_rounded,
                        size: 64,
                        color: _cyan,
                      ),
                    ),

                    // Scan line (top → bottom sweep, repeating)
                    Positioned(
                      top: d * ((scanT * 1.20) - 0.10).clamp(0.0, 1.0),
                      left: 0, right: 0,
                      child: Container(
                        height: 2,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Color(0x990094C6),
                              Color(0x990094C6),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Glossy top-sheen
                    Positioned(
                      top: 0, left: 0, right: 0,
                      child: Container(
                        height: d * 0.38,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.22),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  BADGE ROW
// ═══════════════════════════════════════════════════════════════════════════
class _BadgeRow extends StatelessWidget {
  const _BadgeRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        _Badge(label: 'CPU',  icon: Icons.developer_board_rounded, color: _cyan),
        SizedBox(width: 9),
        _Badge(label: 'RAM',  icon: Icons.memory_rounded,          color: _green),
        SizedBox(width: 9),
        _Badge(label: 'SWAP', icon: Icons.sync_alt_rounded,        color: _amber),
        SizedBox(width: 9),
        _Badge(label: 'VIRT', icon: Icons.layers_rounded,          color: _teal),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _Badge({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.30), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CUSTOM PAINTERS
// ═══════════════════════════════════════════════════════════════════════════

/// Subtle dot-grid background (painted once, never repaints)
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _cyan.withOpacity(0.055);
    const step = 28.0;
    const r = 1.3;
    for (double x = step; x < size.width; x += step) {
      for (double y = step; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

/// 3 staggered expanding rings
class _RingsPainter extends CustomPainter {
  final double t;
  _RingsPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < 3; i++) {
      final phase = (t + i / 3) % 1.0;
      final eased = Curves.easeOut.transform(phase);
      canvas.drawCircle(
        c, 170 * eased,
        Paint()
          ..color = _cyan.withOpacity((1 - eased) * 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter o) => o.t != t;
}

/// Dashed ring (used for rotating halos)
class _DashedRingPainter extends CustomPainter {
  final Color color;
  final int dashCount;
  _DashedRingPainter({required this.color, required this.dashCount});

  @override
  void paint(Canvas canvas, Size size) {
    final c   = Offset(size.width / 2, size.height / 2);
    final r   = size.width / 2 - 1;
    final gap = (2 * math.pi) / dashCount;
    const dl  = 0.10; // dash arc length in radians
    final p   = Paint()
      ..color      = color
      ..strokeWidth = 1.2
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;
    for (int i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        i * gap, dl, false, p,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

/// CPU circuit lines radiating outward with L-bends + dots
class _CircuitPainter extends CustomPainter {
  final double t; // 0→1
  _CircuitPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final c   = Offset(size.width / 2, size.height / 2);
    final max = size.width * 0.42;

    // 8 arms at 45° increments, rotated 22.5°
    final angles = List.generate(8, (i) => i * math.pi / 4 + math.pi / 8);

    for (int i = 0; i < angles.length; i++) {
      final a   = angles[i];
      final len = max * t;
      final end = Offset(c.dx + math.cos(a) * len, c.dy + math.sin(a) * len);

      // Main arm
      canvas.drawLine(
        c, end,
        Paint()
          ..color      = _cyan.withOpacity(0.18 * t)
          ..strokeWidth = 0.85
          ..style       = PaintingStyle.stroke
          ..strokeCap   = StrokeCap.round,
      );

      // L-bend at 58% — alternate teal/cyan
      if (t > 0.35) {
        final bendT   = (t - 0.35) / 0.65;
        final bendPt  = Offset(c.dx + math.cos(a) * len * 0.58, c.dy + math.sin(a) * len * 0.58);
        final perpA   = a + math.pi / 2;
        final bendEnd = Offset(
          bendPt.dx + math.cos(perpA) * 16 * bendT,
          bendPt.dy + math.sin(perpA) * 16 * bendT,
        );
        canvas.drawLine(
          bendPt, bendEnd,
          Paint()
            ..color      = (i % 2 == 0 ? _teal : _cyan).withOpacity(0.14 * bendT)
            ..strokeWidth = 0.75
            ..style       = PaintingStyle.stroke
            ..strokeCap   = StrokeCap.round,
        );
      }

      // Tip cross-tick
      final perp = a + math.pi / 2;
      final tick = 10.0 * t;
      canvas.drawLine(
        Offset(end.dx + math.cos(perp) * tick / 2, end.dy + math.sin(perp) * tick / 2),
        Offset(end.dx - math.cos(perp) * tick / 2, end.dy - math.sin(perp) * tick / 2),
        Paint()
          ..color      = _cyan.withOpacity(0.20 * t)
          ..strokeWidth = 0.85
          ..strokeCap   = StrokeCap.round,
      );

      // Endpoint dot (appears late)
      if (t > 0.58) {
        final r = 2.8 * ((t - 0.58) / 0.42);
        canvas.drawCircle(
          end, r,
          Paint()..color = (i % 3 == 0 ? _teal : _cyan).withOpacity(0.55 * t),
        );
      }
    }

    // Ghost concentric rings at 50% and 80% of arm length
    for (final frac in [0.50, 0.80]) {
      if (t >= frac) {
        canvas.drawCircle(
          c, max * frac,
          Paint()
            ..color      = _cyan.withOpacity(0.07 * t)
            ..strokeWidth = 0.65
            ..style       = PaintingStyle.stroke,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CircuitPainter o) => o.t != t;
}

/// Cyan→teal shimmer sweep on a track
class _ShimmerPainter extends CustomPainter {
  final double t;
  _ShimmerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Track
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = _cyan.withOpacity(0.10),
    );
    // Shimmer spot
    final x = -size.width * 0.4 + size.width * 1.8 * t;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = LinearGradient(
          colors: const [
            Colors.transparent,
            _cyan,
            _teal,
            Colors.transparent,
          ],
          stops: const [0.0, 0.42, 0.58, 1.0],
          begin: Alignment((x / size.width) * 2 - 1, 0),
          end:   Alignment((x / size.width) * 2 + 0.65, 0),
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..colorFilter = ColorFilter.mode(
          _cyan.withOpacity(0.65), BlendMode.modulate,
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _ShimmerPainter o) => o.t != t;
}

/// Softly drifting background dots
class _ParticlePainter extends CustomPainter {
  final double t;
  static final List<_Dot> _dots = List.generate(24, (i) => _Dot(i));
  _ParticlePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in _dots) {
      final phase   = (t + d.off) % 1.0;
      final opacity = math.sin(phase * math.pi) * 0.18 * d.alpha;
      final x = d.x * size.width;
      final y = d.y0 * size.height
          - phase * d.rise * size.height
          + math.sin(phase * math.pi * 2 + d.phase) * d.wobble * size.width;

      canvas.drawCircle(
        Offset(x, y),
        d.radius,
        Paint()..color = d.isTeal
            ? _teal.withOpacity(opacity)
            : _cyan.withOpacity(opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter o) => o.t != t;
}

class _Dot {
  final double x, y0, rise, wobble, off, phase, radius, alpha;
  final bool isTeal;

  _Dot(int s)
      : x      = _r(s, 0),
        y0     = 0.60 + _r(s, 1) * 0.50,
        rise   = 0.30 + _r(s, 2) * 0.50,
        wobble = 0.015 + _r(s, 3) * 0.04,
        off    = _r(s, 4),
        phase  = _r(s, 5) * math.pi * 2,
        radius = 1.6 + _r(s, 6) * 3.4,
        alpha  = 0.3 + _r(s, 7) * 0.7,
        isTeal = s % 5 == 0;

  static double _r(int s, int salt) =>
      ((s * 7 + salt * 13 + s * salt * 3 + 1) % 97) / 97.0;
}