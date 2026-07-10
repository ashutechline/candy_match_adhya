import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:get/get.dart';

import '../../ads/banner_ad_builder.dart';
import '../../ads/mixins/banner_ad_mixin.dart';
import '../../ads/ad_service.dart';
import '../analytics/analytics_service.dart';
import '../audio/audio_service.dart';
import '../game/app_state.dart';
import '../widgets/dialogs.dart';
import '../widgets/settings.dart';
import 'how_to_play_screen.dart';
import 'launch_screen.dart';
import 'level_map_screen.dart';

/// Candy-shop landing / splash screen (styled after the classic match-3
/// start screen). Pure Flutter — gradient + painted bokeh background, a
/// swirl-lollipop mark, a gradient stacked wordmark, a candy showcase and the
/// primary actions, all animated in with a staggered entrance.
class SplashScreen extends StatefulWidget {
  final AppState appState;
  const SplashScreen({super.key, required this.appState});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final SplashAdController _adController;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView('SplashScreen');
    _adController = Get.put(SplashAdController());

    // Show background loaded ad if openAdFirstStart is true but splashAppOpan is false
    final adService = Get.find<AdService>();
    final adData = adService.adsResponseService.getCreditEducationData();
    if (adData != null &&
        adData.adStart &&
        adData.openAdFirstStart &&
        !adData.splashAppOpan) {
      adService.showBackgroundLoadedAd();
    }
  }

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  @override
  void dispose() {
    _intro.dispose();
    _spin.dispose();
    Get.delete<SplashAdController>();
    super.dispose();
  }

  void _play() {
    AudioService.instance.tap();
    Get.find<AdService>().showInterstitialAd(
      onAdDismissed: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => LevelMapScreen(appState: widget.appState),
        ));
      },
      onAdFailed: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => LevelMapScreen(appState: widget.appState),
        ));
      },
    );
  }

  /// Staggered fade + rise driven by the shared intro controller.
  Widget _in(double start, double end, Widget child) {
    final anim = CurvedAnimation(
      parent: _intro,
      curve: Interval(start, end, curve: Curves.easeOutBack),
    );
    return AnimatedBuilder(
      animation: anim,
      child: child,
      builder: (context, c) => Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 26 * (1 - anim.value)),
          child: c,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await showExitAppDialog(context);
        if (shouldExit && context.mounted) {
          Get.find<AdService>().showInterstitialAd(
            force: true,
            onAdDismissed: () {
              SystemNavigator.pop();
            },
            onAdFailed: () {
              SystemNavigator.pop();
            },
          );
        }
      },
      child: Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: _SplashBackground()),
          _Decorations(spin: _spin),
          Obx(() {
            final adActive = !_adController.isBannerAdFailed.value;
            return SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxHeight < 720;
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(24, isCompact ? 10 : 20, 24, adActive ? 84 : 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - (isCompact ? 34 : 44),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: isCompact ? 4 : 8),
                          _in(0.0, 0.45, const _MatchPill()),
                          SizedBox(height: isCompact ? 10 : 22),
                          _in(0.1, 0.6, CandyMatchLogo(width: isCompact ? 210 : 290)),
                          SizedBox(height: isCompact ? 8 : 14),
                          _in(0.25, 0.7, const _StarsRow()),
                          SizedBox(height: isCompact ? 12 : 26),
                          _in(0.35, 0.85, const _CandyShowcase()),
                          SizedBox(height: isCompact ? 20 : 40),
                          _in(0.5, 0.95, _PlayButton(onTap: _play)),
                          SizedBox(height: isCompact ? 12 : 24),
                          _in(0.7, 1.0, const _FooterCredit()),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          }),
          // Top-right controls are the LAST (topmost) layer so they reliably
          // receive taps — above the full-screen scroll view.
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: _in(
                  0.0,
                  0.4,
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.help_outline_rounded),
                        tooltip: 'How to play',
                        onPressed: () {
                          AudioService.instance.tap();
                          Get.find<AdService>().showInterstitialAd(
                            onAdDismissed: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const HowToPlayScreen(),
                              ));
                            },
                            onAdFailed: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const HowToPlayScreen(),
                              ));
                            },
                          );
                        },
                      ),
                      SettingsButton(appState: widget.appState),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Obx(() {
              if (_adController.isBannerAdFailed.value) {
                return const SizedBox.shrink();
              }
              return Container(
                color: Colors.transparent,
                alignment: Alignment.center,
                child: SafeArea(
                  top: false,
                  child: BannerAdBuilder.buildBannerAd(_adController, isAlwaysShow: true),
                ),
              );
            }),
          ),
        ],
      ),
    ),
  );
}
}

// --- palette ----------------------------------------------------------------
class _Sk {
  static const bgTop = Color(0xFF4A1385);
  static const bgMid = Color(0xFF6A1E9C);
  static const bgBottom = Color(0xFF230A3E);
  static const pinkA = Color(0xFFFF4FA3);
  static const pinkB = Color(0xFFFF86C6);
  static const goldA = Color(0xFFFFD93B);
  static const goldB = Color(0xFFFF9E00);
  static const blue = Color(0xFF74D0FF);
}

// --- background -------------------------------------------------------------
class _SplashBackground extends StatelessWidget {
  const _SplashBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/background.png'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _BokehPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final circles = <(double, double, double, double)>[
      (0.18, 0.30, 0.42, 0.10),
      (0.85, 0.22, 0.30, 0.10),
      (0.75, 0.55, 0.5, 0.08),
      (0.15, 0.72, 0.4, 0.08),
      (0.5, 0.9, 0.55, 0.06),
      (0.9, 0.85, 0.28, 0.07),
    ];
    for (final (fx, fy, fr, a) in circles) {
      canvas.drawCircle(
        Offset(size.width * fx, size.height * fy),
        size.width * fr,
        Paint()..color = Colors.white.withValues(alpha: a),
      );
    }
    // A soft magenta glow behind the logo.
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.32),
      size.width * 0.6,
      Paint()
        ..shader = RadialGradient(colors: [
          _Sk.pinkA.withValues(alpha: 0.28),
          _Sk.pinkA.withValues(alpha: 0.0),
        ]).createShader(Rect.fromCircle(
            center: Offset(size.width * 0.5, size.height * 0.32),
            radius: size.width * 0.6)),
    );
  }

  @override
  bool shouldRepaint(_BokehPainter oldDelegate) => false;
}

/// Scattered decorative candies + stars that drift with the spin controller.
class _Decorations extends StatelessWidget {
  final Animation<double> spin;
  const _Decorations({required this.spin});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // Candies are now built into background.png!
  }
}

// --- header pieces ----------------------------------------------------------
class _MatchPill extends StatelessWidget {
  const _MatchPill();

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_Sk.pinkA, _Sk.pinkB]),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
              color: _Sk.pinkA.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 14, color: Colors.white),
          SizedBox(width: 8),
          Text('MATCH 3 PUZZLE',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 1.5)),
          SizedBox(width: 8),
          Icon(Icons.auto_awesome, size: 14, color: Colors.white),
        ],
      ),
      ),
    );
  }
}

class _LollipopMark extends StatelessWidget {
  final Animation<double> spin;
  const _LollipopMark({required this.spin});

  @override
  Widget build(BuildContext context) => _Lollipop(size: 64, spin: spin);
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  Widget _grad(String text, List<Color> colors, double size) {
    return ShaderMask(
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ).createShader(rect),
      child: Text(
        text,
        style: TextStyle(
          fontSize: size,
          height: 0.98,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.5,
          shadows: const [
            Shadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        children: [
          _grad('Candy', const [Color(0xFFFF8AC4), _Sk.pinkA], 52),
          _grad('Match', const [_Sk.goldA, _Sk.goldB], 52),
          const SizedBox(height: 6),
          const Text(
            'S A G A',
            style: TextStyle(
              color: _Sk.blue,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 8,
            ),
          ),
        ],
      ),
    );
  }
}

class _StarsRow extends StatelessWidget {
  const _StarsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final s in const [26.0, 34.0, 26.0])
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Icon(Icons.star_rounded, size: s, color: _Sk.goldA, shadows: const [
              Shadow(color: Color(0x66FF9E00), blurRadius: 10),
            ]),
          ),
      ],
    );
  }
}

class _CandyShowcase extends StatelessWidget {
  const _CandyShowcase();

  static const _row1 = [
    (Color(0xFFFF4D6A), Icons.card_giftcard),
    (Color(0xFF2ED3C6), Icons.diamond),
    (Color(0xFFFF8C42), Icons.circle),
    (Color(0xFF3EA8FF), Icons.view_week),
    (Color(0xFFFF4D6A), Icons.card_giftcard),
  ];
  static const _row2 = [
    (Color(0xFF3DE07B), Icons.local_florist),
    (Color(0xFFFFC93C), Icons.star_rounded),
    (Color(0xFFFF5C7A), Icons.favorite),
    (Color(0xFF3EA8FF), Icons.view_week),
  ];

  @override
  Widget build(BuildContext context) {
    Widget row(List<(Color, IconData)> items) => FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final (color, icon) in items)
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: _MiniCandy(color: color, icon: icon),
                ),
            ],
          ),
        );
    return Column(
      children: [row(_row1), const SizedBox(height: 8), row(_row2)],
    );
  }
}

class _MiniCandy extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _MiniCandy({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, Colors.white, 0.35)!,
            color,
            Color.lerp(color, Colors.black, 0.2)!,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Icon(icon, color: Colors.white.withValues(alpha: 0.95), size: 24),
    );
  }
}

// --- buttons ----------------------------------------------------------------
class _PlayButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PlayButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _PressableScale(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_Sk.goldA, _Sk.goldB]),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
                color: _Sk.goldB.withValues(alpha: 0.55),
                blurRadius: 20,
                offset: const Offset(0, 6)),
          ],
        ),
        child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
              SizedBox(width: 8),
              Text('PLAY NOW',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterCredit extends StatelessWidget {
  const _FooterCredit();

  @override
  Widget build(BuildContext context) {
    final faint = Colors.white.withValues(alpha: 0.45);
    return Column(
      children: [
        Text('🍬  CANDY MATCH  🍭',
            style: TextStyle(
                color: faint, fontSize: 12, letterSpacing: 2)),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkWell(
                onTap: () async {
                  final url = Uri.parse('https://sites.google.com/view/candymatchterms/home');
                  try {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } catch (_) {}
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'Terms & Conditions',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              Text(
                '•',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 12,
                ),
              ),
              InkWell(
                onTap: () async {
                  final url = Uri.parse('https://sites.google.com/view/candymatchprivacy/home');
                  try {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } catch (_) {}
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'Privacy Policy',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A button wrapper that scales down slightly while pressed.
class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _PressableScale({required this.child, required this.onTap});

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) => setState(() => _scale = 1),
      onTapCancel: () => setState(() => _scale = 1),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 90),
        child: widget.child,
      ),
    );
  }
}

// --- little painted candies -------------------------------------------------
class _Lollipop extends StatelessWidget {
  final double size;
  final Animation<double> spin;
  const _Lollipop({required this.size, required this.spin});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: spin,
      builder: (context, _) => CustomPaint(
        size: Size(size, size * 1.35),
        painter: _LollipopPainter(spin.value * 2 * math.pi),
      ),
    );
  }
}

class _LollipopPainter extends CustomPainter {
  final double angle;
  _LollipopPainter(this.angle);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);

    // stick
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(r - size.width * 0.05, r, size.width * 0.1, size.height - r),
        Radius.circular(size.width * 0.05),
      ),
      Paint()..color = const Color(0xFFFFF3D6),
    );

    // candy disc with a sweep-gradient swirl
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0xFFFF4FA3),
            Color(0xFFFFC93C),
            Color(0xFF3DE07B),
            Color(0xFF3EA8FF),
            Color(0xFFC46BFF),
            Color(0xFFFF4FA3),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
    );
    canvas.restore();

    // gloss
    canvas.drawCircle(
      Offset(center.dx - r * 0.3, center.dy - r * 0.35),
      r * 0.22,
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_LollipopPainter old) => old.angle != angle;
}

class _WrappedCandy extends StatelessWidget {
  final double size;
  const _WrappedCandy({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(size, size), painter: _WrappedPainter());
  }
}

class _WrappedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final body = Paint()
      ..shader = const LinearGradient(colors: [Color(0xFFFF6FA0), Color(0xFFFF3D6E)])
          .createShader(Offset.zero & size);
    final wrap = Paint()..color = const Color(0xFFFF9FC0);
    // wrappers (triangles) left/right
    final left = Path()
      ..moveTo(0, size.height * 0.2)
      ..lineTo(size.width * 0.3, size.height * 0.5)
      ..lineTo(0, size.height * 0.8)
      ..close();
    final right = Path()
      ..moveTo(size.width, size.height * 0.2)
      ..lineTo(size.width * 0.7, size.height * 0.5)
      ..lineTo(size.width, size.height * 0.8)
      ..close();
    canvas.drawPath(left, wrap);
    canvas.drawPath(right, wrap);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: c, width: size.width * 0.56, height: size.height * 0.56),
        Radius.circular(size.width * 0.14),
      ),
      body,
    );
  }

  @override
  bool shouldRepaint(_WrappedPainter old) => false;
}

class _Star extends StatelessWidget {
  final double size;
  const _Star({required this.size});
  @override
  Widget build(BuildContext context) =>
      Icon(Icons.star_rounded, size: size, color: _Sk.goldA);
}

class _Sparkle extends StatelessWidget {
  final double size;
  const _Sparkle({required this.size});
  @override
  Widget build(BuildContext context) => Icon(Icons.auto_awesome,
      size: size, color: Colors.white.withValues(alpha: 0.85));
}

class SplashAdController extends GetxController with BannerAdMixin {
  @override
  void onInit() {
    super.onInit();
    loadBannerAdAlways();
  }
}
