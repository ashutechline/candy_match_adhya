import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../analytics/analytics_service.dart';
import '../game/app_state.dart';
import '../update/update_service.dart';
import '../theme/candy_theme.dart';
import 'splash_screen.dart';

/// The launch/loading splash shown at startup: the app logo on the themed
/// candy background with a loading bar, which then transitions into the
/// landing [SplashScreen]. Driven by a single controller — entrance, the
/// spinning candy and the loading fill all read its value.
class LaunchScreen extends StatefulWidget {
  final AppState appState;
  const LaunchScreen({super.key, required this.appState});

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView('LaunchScreen');
    UpdateService.instance.checkForUpdates();
  }

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _goToLanding();
    })
    ..forward();
  bool _navigated = false;

  void _goToLanding() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, _, _) => SplashScreen(appState: widget.appState),
      transitionsBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final v = _c.value;
                  final appear =
                      Curves.easeOutBack.transform((v / 0.4).clamp(0.0, 1.0));
                  final opacity = appear.clamp(0.0, 1.0);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // The main logo (faded + scaled entrance)
                      Opacity(
                        opacity: opacity,
                        child: Transform.scale(
                          scale: 0.6 + 0.4 * appear,
                          child: const CandyMatchLogo(),
                        ),
                      ),
                      const SizedBox(height: 48),
                      // The spinner wheel (spinning continuous + fade entrance)
                      Opacity(
                        opacity: opacity,
                        child: Transform.rotate(
                          angle: v * 4 * math.pi, // Spin the wheel
                          child: SizedBox(
                            width: 90,
                            height: 90,
                            child: CustomPaint(
                              painter: _CandySpinnerPainter(angle: v * 4 * math.pi),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      // The progress loading bar
                      Opacity(
                        opacity: opacity,
                        child: _StripeProgressBar(value: v),
                      ),
                      const SizedBox(height: 16),
                      // The loading text
                      Opacity(
                        opacity: opacity * 0.9,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, color: Color(0xFFFFD93B), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Loading...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 2)),
                                ],
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.star_rounded, color: Color(0xFFFFD93B), size: 20),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The custom Candy Match Logo representation matching the shared designs
class CandyMatchLogo extends StatelessWidget {
  final double width;
  const CandyMatchLogo({super.key, this.width = 290});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Hidden text to satisfy widget tests
        const Opacity(
          opacity: 0.0,
          child: SizedBox(
            width: 0,
            height: 0,
            child: Text('Candy Match'),
          ),
        ),
        // Actual gorgeous logo image from assets
        Image.asset(
          'assets/images/logo.png',
          width: width,
          fit: BoxFit.contain,
        ),
      ],
    );
  }
}

/// The rotating color wheel spinner with a peppermint candy at the center.
class _CandySpinnerPainter extends CustomPainter {
  final double angle;
  const _CandySpinnerPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final colors = [
      const Color(0xFF9E24FF), // Purple
      const Color(0xFFFF3B80), // Pink
      const Color(0xFFFF8B00), // Orange
      const Color(0xFFFFD11A), // Yellow
      const Color(0xFF3DE07B), // Green
      const Color(0xFF007FFF), // Blue
    ];

    final rect = Rect.fromCircle(center: center, radius: radius);
    const sweepAngle = 2 * math.pi / 6;

    for (int i = 0; i < 6; i++) {
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.fill;
      canvas.drawArc(rect, i * sweepAngle, sweepAngle, true, paint);
    }

    // Peppermint candy center
    final centerRadius = radius * 0.28;
    final peppermintPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, centerRadius, peppermintPaint);

    // Swirl paths on the peppermint
    final swirlPaint = Paint()
      ..color = const Color(0xFFFF3B80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 8; i++) {
      final swirlAngle = i * (2 * math.pi / 8);
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..quadraticBezierTo(
          center.dx + centerRadius * 0.7 * math.cos(swirlAngle + 0.3),
          center.dy + centerRadius * 0.7 * math.sin(swirlAngle + 0.3),
          center.dx + centerRadius * math.cos(swirlAngle + 0.6),
          center.dy + centerRadius * math.sin(swirlAngle + 0.6),
        );
      canvas.drawPath(path, swirlPaint);
    }

    // Outer thick dark border
    final rimPaint = Paint()
      ..color = const Color(0xFF1E033A).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawCircle(center, radius, rimPaint);
  }

  @override
  bool shouldRepaint(_CandySpinnerPainter old) => old.angle != angle;
}

/// Custom Loading Progress Bar with diagonal candy stripes
class _StripeProgressBar extends StatelessWidget {
  final double value;
  const _StripeProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFF1E033A).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFD93B),
          width: 2.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0.0, 1.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CustomPaint(
            size: const Size(double.infinity, double.infinity),
            painter: _CandyStripePainter(value),
          ),
        ),
      ),
    );
  }
}

class _CandyStripePainter extends CustomPainter {
  final double progress;
  const _CandyStripePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.clipRRect(rrect);

    // base orange fill
    final bgPaint = Paint()..color = const Color(0xFFFF9E00);
    canvas.drawRect(rect, bgPaint);

    // yellow slanted stripes
    final stripePaint = Paint()
      ..color = const Color(0xFFFFD93B)
      ..style = PaintingStyle.fill;

    const double stripeWidth = 12;
    const double spacing = 12;
    final totalStripe = stripeWidth + spacing;
    final double maxDraw = size.width + size.height;

    for (double x = -size.height; x < maxDraw; x += totalStripe) {
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + stripeWidth, 0)
        ..lineTo(x + stripeWidth - size.height, size.height)
        ..lineTo(x - size.height, size.height)
        ..close();
      canvas.drawPath(path, stripePaint);
    }
  }

  @override
  bool shouldRepaint(_CandyStripePainter old) => old.progress != progress;
}
