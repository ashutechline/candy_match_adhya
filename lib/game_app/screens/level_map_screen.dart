import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../analytics/analytics_service.dart';
import '../audio/audio_service.dart';
import '../data/levels.dart';
import '../game/app_state.dart';
import '../models/level.dart';
import '../theme/candy_theme.dart';
import '../widgets/level_detail_sheet.dart';
import '../widgets/settings.dart';
import 'game_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';

/// Information about a themed world zone on the level map.
class WorldInfo {
  final String name;
  final String description;
  final Color primaryColor;
  final Color secondaryColor;
  final String landmarkEmoji;

  const WorldInfo({
    required this.name,
    required this.description,
    required this.primaryColor,
    required this.secondaryColor,
    required this.landmarkEmoji,
  });
}

/// Dynamic world lookup based on the level ID.
WorldInfo getWorldInfo(int levelId) {
  if (levelId <= 15) {
    return const WorldInfo(
      name: 'Lollipop Lane',
      description: 'A sweet start with soft candy fields',
      primaryColor: Color(0xFFFF5CA8),
      secondaryColor: Color(0xFFB44BD6),
      landmarkEmoji: '🍭',
    );
  } else if (levelId <= 35) {
    return const WorldInfo(
      name: 'Peppermint Forest',
      description: 'Chilly mints and twisting candy canes',
      primaryColor: Color(0xFF00BFA5),
      secondaryColor: Color(0xFF00796B),
      landmarkEmoji: '🍬',
    );
  } else if (levelId <= 55) {
    return const WorldInfo(
      name: 'Chocolate Mountains',
      description: 'Fudgy slopes and golden caramel rivers',
      primaryColor: Color(0xFFFF8C42),
      secondaryColor: Color(0xFFD32F2F),
      landmarkEmoji: '🌋',
    );
  } else if (levelId <= 75) {
    return const WorldInfo(
      name: 'Soda Springs',
      description: 'Bubbly rivers of sweet fizzy drink',
      primaryColor: Color(0xFF0288D1),
      secondaryColor: Color(0xFF01579B),
      landmarkEmoji: '🥤',
    );
  } else if (levelId <= 95) {
    return const WorldInfo(
      name: 'Cotton Candy Meadow',
      description: 'Soft pink skies and fluffy sugar clouds',
      primaryColor: Color(0xFFEC407A),
      secondaryColor: Color(0xFF880E4F),
      landmarkEmoji: '🌲',
    );
  } else {
    return const WorldInfo(
      name: 'Candy Castle Peak',
      description: 'The royal crown of matches',
      primaryColor: Color(0xFFFFB300),
      secondaryColor: Color(0xFFFF6F00),
      landmarkEmoji: '🏰',
    );
  }
}

/// A winding candy-path world map: level nodes threaded along a sine curve,
/// coloured/starred when cleared, locked ahead, with a resource header and a
/// decorative candy background. Shows 100 levels from bottom to top.
class LevelMapScreen extends StatefulWidget {
  final AppState appState;
  const LevelMapScreen({super.key, required this.appState});

  @override
  State<LevelMapScreen> createState() => _LevelMapScreenState();
}

class _LevelMapScreenState extends State<LevelMapScreen>
    with SingleTickerProviderStateMixin {
  static const double _spacing = 118;
  static const double _topPad = 140;
  static const double _bottomPad = 160;
  static const int _totalLevelsCount = 100;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView('LevelMapScreen');
    widget.appState.addListener(_onProgressChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  void _onProgressChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onProgressChanged);
    _pulse.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToCurrent() {
    if (!_scroll.hasClients) return;
    final progressVal = widget.appState.progress.highestUnlocked;
    final currentLevel = math.min(progressVal, _totalLevelsCount);
    final index = currentLevel - 1; // 0-indexed representation
    if (index < 0) return;
    
    final viewportHeight = _scroll.position.viewportDimension;
    final nodeY = _topPad + (_totalLevelsCount - 1 - index) * _spacing;
    final target = (nodeY - (viewportHeight > 0 ? viewportHeight / 2 : 300))
        .clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.jumpTo(target);
  }

  double _nodeX(int i, double width) {
    final centerX = width / 2;
    final amplitude = width * 0.26;
    // Uses 0.6 for a smoother, gentler winding curve down the map screen
    return centerX + amplitude * math.sin(i * 0.6);
  }

  void _openLevel(LevelDef level) {
    AudioService.instance.tap();
    showLevelDetailSheet(
      context,
      level: level,
      bestStars: widget.appState.progress.starsFor(level.id),
      onPlay: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => GameScreen(appState: widget.appState, level: level),
      )),
    );
  }

  Widget _positionedDecoration(int i, double width) {
    final y = _topPad + (_totalLevelsCount - 1 - i) * _spacing;
    final onLeft = math.sin(i * 0.6) > 0;
    final x = _nodeX(i, width) + (onLeft ? -75.0 : 75.0);
    
    final decorations = ['🍪', '🍩', '🍬', '⭐', '☁️', '🍒', '🍯', '🧁'];
    final emoji = decorations[i % decorations.length];
    
    return Positioned(
      left: x - 15,
      top: y - 15,
      child: Opacity(
        opacity: 0.35,
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }

  List<Widget> _buildWorldBanners(double width) {
    final worlds = [
      (0, getWorldInfo(1)),
      (15, getWorldInfo(16)),
      (35, getWorldInfo(36)),
      (55, getWorldInfo(56)),
      (75, getWorldInfo(76)),
      (95, getWorldInfo(96)),
    ];
    
    return worlds.map((entry) {
      final startIndex = entry.$1;
      final world = entry.$2;
      
      final double y;
      if (startIndex == 0) {
        y = _topPad + (_totalLevelsCount - 0.3) * _spacing;
      } else {
        y = _topPad + (_totalLevelsCount - 1 - (startIndex - 0.5)) * _spacing;
      }
      
      return Positioned(
        left: 24,
        right: 24,
        top: y - 35,
        child: Center(
          child: _WorldBanner(world: world),
        ),
      );
    }).toList();
  }

  List<Widget> _buildLandmarks(double width) {
    final landmarks = [
      (14, '🍭', 'Sweet Gate'),
      (34, '🍬', 'Mint Arch'),
      (54, '🌋', 'Choco Vent'),
      (74, '🥤', 'Soda Fountain'),
      (94, '🌲', 'Candy Wood'),
    ];
    
    final list = landmarks.map((entry) {
      final index = entry.$1;
      final emoji = entry.$2;
      final label = entry.$3;
      
      final y = _topPad + (_totalLevelsCount - 1 - index) * _spacing;
      final onLeft = math.sin(index * 0.6) > 0;
      final x = _nodeX(index, width) + (onLeft ? -76.0 : 76.0);
      
      return Positioned(
        left: x - 40,
        top: y - 25,
        width: 80,
        child: Center(
          child: _Landmark(emoji: emoji, label: label),
        ),
      );
    }).toList();
    
    // Castle Landmark at the top
    list.add(
      Positioned(
        left: width / 2 - 60,
        top: _topPad - 95,
        width: 120,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '🏰',
                style: TextStyle(
                  fontSize: 48,
                  shadows: [
                    Shadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFCC4D),
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                child: const Text(
                  'CANDY CASTLE',
                  style: TextStyle(
                    color: Color(0xFF17103A),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: AppColors.background,
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  _MapHeader(appState: widget.appState),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final width = c.maxWidth;
                        final count = _totalLevelsCount;
                        final height =
                            _topPad + count * _spacing + _bottomPad;
                        final centers = [
                          for (var i = 0; i < count; i++)
                            Offset(_nodeX(i, width), _topPad + (count - 1 - i) * _spacing),
                        ];
                        return SingleChildScrollView(
                          controller: _scroll,
                          child: SizedBox(
                            width: width,
                            height: height,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: CustomPaint(
                                      painter: _WorldBackgroundPainter()),
                                ),
                                Positioned.fill(
                                  child: CustomPaint(
                                      painter: _PathPainter(centers)),
                                ),
                                // Decor elements along the path
                                for (var i = 2; i < count - 2; i += 4)
                                  _positionedDecoration(i, width),
                                  
                                // World banners between worlds
                                ..._buildWorldBanners(width),
                                
                                // Landmarks next to path
                                ..._buildLandmarks(width),

                                // Level nodes themselves
                                for (var i = 0; i < count; i++)
                                  _positionedNode(i, centers[i]),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 32,
              right: 32,
              bottom: 24,
              child: SafeArea(
                top: false,
                bottom: true,
                left: false,
                right: false,
                child: _FloatingPlayButton(
                  appState: widget.appState,
                  onTap: () {
                    final currentLevelId = math.min(widget.appState.progress.highestUnlocked, _totalLevelsCount);
                    final currentLevel = levelById(currentLevelId);
                    _openLevel(currentLevel);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _positionedNode(int i, Offset center) {
    final level = levelById(i + 1);
    final progress = widget.appState.progress;
    final unlocked = progress.isUnlocked(level.id);
    final stars = progress.starsFor(level.id);
    final isCurrent = level.id == progress.highestUnlocked;
    const nodeW = 68.0;
    const circle = 58.0;
    const starsH = 18.0;
    const gap = 4.0;
    final totalH = starsH + gap + circle;
    return Positioned(
      left: center.dx - nodeW / 2,
      top: center.dy - (starsH + gap + circle / 2),
      width: nodeW,
      height: totalH,
      child: _LevelNode(
        level: level,
        unlocked: unlocked,
        stars: stars,
        isCurrent: isCurrent,
        pulse: _pulse,
        onTap: unlocked ? () => _openLevel(level) : null,
      ),
    );
  }
}

// --- header -----------------------------------------------------------------
class _MapHeader extends StatelessWidget {
  final AppState appState;
  const _MapHeader({required this.appState});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Tooltip(
          message: 'Back',
          child: GestureDetector(
            onTap: () {
              AudioService.instance.tap();
              Navigator.of(context).maybePop();
            },
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF5A499E),
                    Color(0xFF382B70),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                size: 24,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class _WorldBanner extends StatelessWidget {
  final WorldInfo world;
  const _WorldBanner({required this.world});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [world.primaryColor, world.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  world.landmarkEmoji,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 8),
                Text(
                  world.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1.0,
                    shadows: [
                      Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1.5)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  world.landmarkEmoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              world.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Landmark extends StatelessWidget {
  final String emoji;
  final String label;
  const _Landmark({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.95),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.gold, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 24),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

// --- level node -------------------------------------------------------------
class _LevelNode extends StatelessWidget {
  final LevelDef level;
  final bool unlocked;
  final int stars;
  final bool isCurrent;
  final Animation<double> pulse;
  final VoidCallback? onTap;

  const _LevelNode({
    required this.level,
    required this.unlocked,
    required this.stars,
    required this.isCurrent,
    required this.pulse,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final world = getWorldInfo(level.id);
    
    final List<Color> gradientColors;
    if (unlocked) {
      gradientColors = [world.primaryColor, world.secondaryColor];
    } else {
      gradientColors = [
        const Color(0xFF2D2345),
        const Color(0xFF1B152B),
      ];
    }

    Widget nodeContent;
    if (unlocked) {
      nodeContent = Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              width: 18,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.4),
                borderRadius: const BorderRadius.all(Radius.elliptical(9, 5)),
              ),
            ),
          ),
          Text(
            '${level.id}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black45,
                  offset: Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      nodeContent = const Icon(
        Icons.lock_outline_rounded,
        size: 20,
        color: Colors.white38,
      );
    }

    Widget circle = Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        border: Border.all(
          color: unlocked
              ? Colors.white.withValues(alpha: 0.9)
              : Colors.white12,
          width: 3.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: unlocked ? 0.45 : 0.25),
            blurRadius: unlocked ? 10 : 4,
            offset: const Offset(0, 5),
          ),
          if (unlocked)
            BoxShadow(
              color: world.primaryColor.withValues(alpha: 0.5),
              blurRadius: 12,
              spreadRadius: 1,
            ),
        ],
      ),
      child: nodeContent,
    );

    if (isCurrent && unlocked) {
      circle = AnimatedBuilder(
        animation: pulse,
        child: circle,
        builder: (context, child) {
          final scale = 1.0 + 0.12 * Curves.easeInOut.transform(pulse.value);
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Transform.scale(
                scale: scale * 1.15,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: world.primaryColor.withValues(alpha: 0.5),
                      width: 3,
                    ),
                  ),
                ),
              ),
              Transform.scale(
                scale: scale,
                child: child,
              ),
              const Positioned(
                top: -24,
                child: Text(
                  '👑',
                  style: TextStyle(
                    fontSize: 20,
                    shadows: [
                      Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 18,
            child: stars > 0
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 3; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: Icon(
                            Icons.star_rounded,
                            size: i == 1 ? 16 : 12,
                            color: i < stars ? AppColors.gold : Colors.white12,
                            shadows: i < stars
                                ? const [
                                    Shadow(
                                      color: Colors.orange,
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    )
                                  ]
                                : null,
                          ),
                        ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 4),
          circle,
        ],
      ),
    );
  }
}

// --- painters ---------------------------------------------------------------
class _PathPainter extends CustomPainter {
  final List<Offset> centers;
  const _PathPainter(this.centers);

  @override
  void paint(Canvas canvas, Size size) {
    if (centers.length < 2) return;
    
    for (var i = 0; i < centers.length - 1; i++) {
      final levelId = i + 1;
      final world = getWorldInfo(levelId);
      final a = centers[i];
      final b = centers[i + 1];
      
      final segmentPath = Path()..moveTo(a.dx, a.dy);
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      segmentPath.quadraticBezierTo(a.dx, (a.dy + b.dy) / 2, mid.dx, mid.dy);
      segmentPath.quadraticBezierTo(b.dx, (a.dy + b.dy) / 2, b.dx, b.dy);
      
      // Shadow
      canvas.drawPath(
        segmentPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.round
          ..color = Colors.black.withValues(alpha: 0.15),
      );
      
      // Outer border of path
      canvas.drawPath(
        segmentPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round
          ..color = world.secondaryColor.withValues(alpha: 0.8),
      );

      // Inner glow
      canvas.drawPath(
        segmentPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..color = world.primaryColor.withValues(alpha: 0.9),
      );

      // Center dashed line
      final dashPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.8);
      
      final metrics = segmentPath.computeMetrics();
      for (final m in metrics) {
        var d = 0.0;
        while (d < m.length) {
          final seg = m.extractPath(d, d + 6);
          canvas.drawPath(seg, dashPaint);
          d += 16;
        }
      }
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) => old.centers != centers;
}

class _WorldBackgroundPainter extends CustomPainter {
  const _WorldBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    
    // Gradient colors from top (Level 100) to bottom (Level 1)
    final colors = [
      const Color(0xFF2C104D), // Castle Peak (top)
      const Color(0xFF1E103A), 
      const Color(0xFF320824), // Cotton Candy Meadow
      const Color(0xFF072138), // Soda Springs
      const Color(0xFF2E1705), // Chocolate Mountains
      const Color(0xFF03261C), // Peppermint Forest
      const Color(0xFF240E2C), // Lollipop Lane
      const Color(0xFF160B24), // Bottom
    ];
    
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
    );
    
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
    
    final rnd = math.Random(12345);
    final paintSparkle = Paint()..color = Colors.white.withValues(alpha: 0.08);
    
    for (int i = 0; i < 160; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final radius = 2 + rnd.nextDouble() * 8;
      canvas.drawCircle(Offset(x, y), radius, paintSparkle);
    }
  }

  @override
  bool shouldRepaint(_WorldBackgroundPainter old) => false;
}

class _FloatingPlayButton extends StatelessWidget {
  final AppState appState;
  final VoidCallback onTap;

  const _FloatingPlayButton({required this.appState, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final currentLevelId = math.min(appState.progress.highestUnlocked, 100);
        return GestureDetector(
          onTap: onTap,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD93B), Color(0xFFFF9E00)],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF9E00).withValues(alpha: 0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.8),
                width: 2.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 28,
                  shadows: [
                    Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 1)),
                  ],
                ),
                const SizedBox(width: 8),
                Text(
                  'PLAY LEVEL $currentLevelId',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
