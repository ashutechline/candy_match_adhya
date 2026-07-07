import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../game_logic/game_logic.dart';
import '../analytics/analytics_service.dart';
import '../audio/audio_service.dart';
import '../data/levels.dart';
import '../game/app_state.dart';
import '../game/game_controller.dart';
import '../models/level.dart';
import '../models/objective.dart';
import '../theme/candy_theme.dart';
import '../widgets/board_view.dart';
import '../widgets/dialogs.dart';
import '../widgets/tile_widget.dart';
import 'how_to_play_screen.dart';
import 'settings_screen.dart';

/// Formats an int with thousands separators, e.g. 3120 -> "3,120".
String _fmt(int n) {
  final digits = n.abs().toString();
  final buffer = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// The play screen: a Candy-Crush-style HUD (score/moves/target, progress,
/// goals) above the animated board, with a booster bar and a hint banner below.
class GameScreen extends StatefulWidget {
  final AppState appState;
  final LevelDef level;

  const GameScreen({super.key, required this.appState, required this.level});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameController _controller;
  final GlobalKey<BoardViewState> _boardKey = GlobalKey<BoardViewState>();
  bool _ended = false;
  bool _usedExtraMoves = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView('GameScreen');
    AnalyticsService.instance.logLevelStart(widget.level.id);
    _controller = GameController.forLevel(widget.level)
      ..addListener(_onControllerChange);
  }

  @override
  void dispose() {
    if (!_ended) {
      AnalyticsService.instance.logLevelEnd(widget.level.id, false, _controller.score, 0);
    }
    _controller.removeListener(_onControllerChange);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChange() {
    if (!_ended && _controller.status != GameStatus.playing) {
      _ended = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleEnd());
    }
  }

  Future<void> _handleEnd() async {
    if (!mounted) return;
    if (_controller.status == GameStatus.won) {
      final stars = _controller.starsEarned;
      AnalyticsService.instance.logLevelEnd(widget.level.id, true, _controller.score, stars);
      await widget.appState.recordLevelResult(widget.level.id, stars);
      if (!mounted) return;
      final action = await showWinDialog(
        context,
        stars: stars,
        score: _controller.score,
        hasNext: true, // levels are endless — always a next one
      );
      _dispatch(action);
    } else {
      final action =
          await showLoseDialog(context, canAddMoves: !_usedExtraMoves);
      if (action == EndAction.extraMoves) {
        _usedExtraMoves = true;
        _ended = false;
        _controller.grantExtraMoves(5);
        return;
      }
      AnalyticsService.instance.logLevelEnd(widget.level.id, false, _controller.score, 0);
      _dispatch(action);
    }
  }

  void _dispatch(EndAction action) {
    if (!mounted) return;
    switch (action) {
      case EndAction.next:
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => GameScreen(
            appState: widget.appState,
            level: levelById(widget.level.id + 1),
          ),
        ));
      case EndAction.replay:
        _restart();
      case EndAction.map:
        Navigator.of(context).pop();
      case EndAction.extraMoves:
        break;
    }
  }

  void _restart() {
    AnalyticsService.instance.logLevelEnd(widget.level.id, false, _controller.score, 0);
    AnalyticsService.instance.logLevelStart(widget.level.id);
    setState(() {
      _controller.removeListener(_onControllerChange);
      _controller.dispose();
      _controller = GameController.forLevel(widget.level)
        ..addListener(_onControllerChange);
      _ended = false;
      _usedExtraMoves = false;
    });
  }

  void _useBooster(BoosterId id) {
    AudioService.instance.tap();
    final board = _boardKey.currentState;
    switch (id) {
      case BoosterId.lollipop:
        if (_controller.canUseBooster(id)) board?.armLollipop();
      case BoosterId.colorBomb:
        final result = _controller.useColorBomb();
        if (result != null) board?.playResult(result);
      case BoosterId.extraMoves:
        _controller.useExtraMoves();
      case BoosterId.shuffle:
        final shuffle = _controller.useShuffle();
        if (shuffle != null) board?.playShuffle(shuffle);
    }
  }

  int get _coins => 1000 + widget.appState.progress.totalStars * 40;

  Future<void> _openPauseMenu() async {
    AudioService.instance.tap();
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('Paused',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.play_arrow_rounded),
                title: const Text('Resume'),
                onTap: () => Navigator.of(ctx).pop('resume'),
              ),
              ListTile(
                leading: const Icon(Icons.settings_rounded),
                title: const Text('Settings'),
                onTap: () => Navigator.of(ctx).pop('settings'),
              ),
              ListTile(
                leading: const Icon(Icons.help_outline_rounded),
                title: const Text('How to play'),
                onTap: () => Navigator.of(ctx).pop('help'),
              ),
              ListTile(
                leading: const Icon(Icons.replay_rounded),
                title: const Text('Restart level'),
                onTap: () => Navigator.of(ctx).pop('restart'),
              ),
              ListTile(
                leading: const Icon(Icons.home_rounded),
                title: const Text('Quit to map'),
                onTap: () => Navigator.of(ctx).pop('quit'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'settings':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SettingsScreen(appState: widget.appState),
        ));
      case 'help':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const HowToPlayScreen(),
        ));
      case 'restart':
        _restart();
      case 'quit':
        Navigator.of(context).maybePop();
    }
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
        child: SafeArea(
          child: Column(
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: Column(
                    children: [
                      _TopBar(
                        controller: _controller,
                        coins: _coins,
                        onQuit: () => Navigator.of(context).maybePop(),
                        onSettings: _openPauseMenu,
                      ),
                      const SizedBox(height: 10),
                      _StatCards(controller: _controller),
                      const SizedBox(height: 8),
                      _ProgressBar(controller: _controller),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _GoalsRow(controller: _controller),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: BoardView(key: _boardKey, controller: _controller),
                ),
              ),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => _BoosterBar(
                  controller: _controller,
                  onUse: _useBooster,
                ),
              ),
              _BottomBar(onMenu: _openPauseMenu),
            ],
          ),
        ),
      ),
    );
  }
}

// --- cute monster painter for level pill -------------------------------------
class CuteMonsterPainter extends CustomPainter {
  const CuteMonsterPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2;

    // Body (purple circle)
    paint.color = const Color(0xFF813BFC);
    canvas.drawCircle(center, r, paint);

    // Darker outline
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = r * 0.08;
    paint.color = const Color(0xFF5E20C7);
    canvas.drawCircle(center, r - paint.strokeWidth / 2, paint);
    paint.style = PaintingStyle.fill;

    // Ears/horns
    final earR = r * 0.22;
    paint.color = const Color(0xFF813BFC);
    canvas.drawCircle(Offset(center.dx - r * 0.7, center.dy - r * 0.6), earR, paint);
    canvas.drawCircle(Offset(center.dx + r * 0.7, center.dy - r * 0.6), earR, paint);
    paint.style = PaintingStyle.stroke;
    paint.color = const Color(0xFF5E20C7);
    canvas.drawCircle(Offset(center.dx - r * 0.7, center.dy - r * 0.6), earR - paint.strokeWidth / 2, paint);
    canvas.drawCircle(Offset(center.dx + r * 0.7, center.dy - r * 0.6), earR - paint.strokeWidth / 2, paint);
    paint.style = PaintingStyle.fill;

    // Eyes
    paint.color = Colors.black;
    final eyeRadius = r * 0.12;
    final eyeY = center.dy - r * 0.1;
    final leftEyeCenter = Offset(center.dx - r * 0.35, eyeY);
    final rightEyeCenter = Offset(center.dx + r * 0.35, eyeY);
    canvas.drawCircle(leftEyeCenter, eyeRadius, paint);
    canvas.drawCircle(rightEyeCenter, eyeRadius, paint);

    // Eye highlights (white dots)
    paint.color = Colors.white;
    canvas.drawCircle(leftEyeCenter - Offset(eyeRadius * 0.3, eyeRadius * 0.3), eyeRadius * 0.35, paint);
    canvas.drawCircle(rightEyeCenter - Offset(eyeRadius * 0.3, eyeRadius * 0.3), eyeRadius * 0.35, paint);

    // Blushing cheeks (pink)
    paint.color = const Color(0xFFFF69B4).withValues(alpha: 0.8);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx - r * 0.55, center.dy + r * 0.15), width: r * 0.3, height: r * 0.18),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx + r * 0.55, center.dy + r * 0.15), width: r * 0.3, height: r * 0.18),
      paint,
    );

    // Mouth (cute smile)
    paint.color = Colors.black;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = r * 0.08;
    paint.strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(center.dx - r * 0.18, center.dy + r * 0.1)
      ..quadraticBezierTo(center.dx, center.dy + r * 0.28, center.dx + r * 0.18, center.dy + r * 0.1);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- bullseye target painter -------------------------------------------------
class BullseyePainter extends CustomPainter {
  const BullseyePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2;

    final redPaint = Paint()..color = const Color(0xFFE5484D)..style = PaintingStyle.fill;
    final whitePaint = Paint()..color = Colors.white..style = PaintingStyle.fill;

    canvas.drawCircle(center, r, redPaint);
    canvas.drawCircle(center, r * 0.7, whitePaint);
    canvas.drawCircle(center, r * 0.4, redPaint);
    canvas.drawCircle(center, r * 0.15, whitePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- curved arrow painter ----------------------------------------------------
class CurvedArrowPainter extends CustomPainter {
  const CurvedArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFC53D)
      ..style = PaintingStyle.fill
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2;

    final path = Path()
      ..moveTo(center.dx + r * 0.6, center.dy + r * 0.3)
      ..quadraticBezierTo(center.dx, center.dy + r * 0.4, center.dx - r * 0.4, center.dy)
      ..lineTo(center.dx - r * 0.1, center.dy - r * 0.3)
      ..lineTo(center.dx - r * 0.7, center.dy - r * 0.1)
      ..lineTo(center.dx - r * 0.3, center.dy + r * 0.5)
      ..lineTo(center.dx - r * 0.2, center.dy + r * 0.2)
      ..quadraticBezierTo(center.dx + r * 0.1, center.dy + r * 0.5, center.dx + r * 0.6, center.dy + r * 0.3)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- bomb icon painter -------------------------------------------------------
class BombIconPainter extends CustomPainter {
  const BombIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2;

    final fusePaint = Paint()
      ..color = const Color(0xFFBCAAA4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final fusePath = Path()
      ..moveTo(center.dx, center.dy - r * 0.8)
      ..quadraticBezierTo(center.dx + r * 0.2, center.dy - r * 1.1, center.dx + r * 0.4, center.dy - r * 1.2);
    canvas.drawPath(fusePath, fusePaint);

    final sparkPaint = Paint()..color = const Color(0xFFFFD54F)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx + r * 0.4, center.dy - r * 1.2), 3, sparkPaint);

    final bombPaint = Paint()
      ..color = const Color(0xFF1E1E24)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, r * 0.75, bombPaint);

    final collarPaint = Paint()..color = const Color(0xFF37474F)..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(center.dx - r * 0.2, center.dy - r * 0.9, r * 0.4, r * 0.25), collarPaint);

    final dotColors = [
      const Color(0xFFFF2D55),
      const Color(0xFFFF9500),
      const Color(0xFFFFCC00),
      const Color(0xFF4CD964),
      const Color(0xFF5AC8FA),
      const Color(0xFF5856D6),
    ];
    final dotPaint = Paint()..style = PaintingStyle.fill;
    final dotRadius = r * 0.12;

    final dotOffsets = [
      Offset(-r * 0.35, -r * 0.2),
      Offset(r * 0.3, -r * 0.3),
      Offset(-r * 0.2, r * 0.3),
      Offset(r * 0.25, r * 0.25),
      Offset(0, -r * 0.4),
      Offset(0, r * 0.05),
      Offset(-r * 0.4, r * 0.1),
      Offset(r * 0.4, -r * 0.05),
    ];

    for (var i = 0; i < dotOffsets.length; i++) {
      dotPaint.color = dotColors[i % dotColors.length];
      canvas.drawCircle(center + dotOffsets[i], dotRadius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- peppermint candy painter ------------------------------------------------
class PeppermintCandyPainter extends CustomPainter {
  const PeppermintCandyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2;

    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = Colors.white;
    canvas.drawCircle(center, r, paint);

    paint.color = const Color(0xFFFF2D55);
    const segments = 12;
    for (var i = 0; i < segments; i += 2) {
      final startAngle = i * (2 * math.pi / segments);
      final sweepAngle = 2 * math.pi / segments;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
    }

    paint.color = Colors.white24;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -math.pi / 2,
      math.pi,
      true,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- top bar ----------------------------------------------------------------
class _TopBar extends StatelessWidget {
  final GameController controller;
  final int coins;
  final VoidCallback onQuit;
  final VoidCallback onSettings;

  const _TopBar({
    required this.controller,
    required this.coins,
    required this.onQuit,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(child: _LevelPill(level: controller.level.id, onTap: onQuit)),
        const Spacer(),
        _ResourceChip(
          icon: Icons.favorite_rounded,
          iconColor: const Color(0xFFFF5C7A),
          label: '5',
          onAdd: () {},
        ),
        const SizedBox(width: 8),
        _ResourceChip(
          icon: Icons.stars_rounded,
          iconColor: AppColors.gold,
          label: _fmt(coins),
          onAdd: () {},
        ),
        const SizedBox(width: 8),
        _SettingsButton(onTap: onSettings),
      ],
    );
  }
}

class _SettingsButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SettingsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF8E36FF), Color(0xFF5200C5)],
          ),
          border: Border.all(color: const Color(0xFFC49CFF), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5200C5).withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.settings_rounded, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

class _LevelPill extends StatelessWidget {
  final int level;
  final VoidCallback onTap;
  const _LevelPill({required this.level, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.fromLTRB(4, 2, 10, 2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF8E36FF), Color(0xFF5200C5)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFC49CFF), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5200C5).withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 34,
                height: 34,
                child: CustomPaint(painter: CuteMonsterPainter()),
              ),
              const SizedBox(width: 6),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Level $level',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black45,
                          offset: Offset(0, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 8, color: Color(0xFFFFD93B)),
                      const SizedBox(width: 1),
                      Container(
                        width: 36,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: 24,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFF5C7A), Color(0xFFFF2E93)],
                                  ),
                                  borderRadius: BorderRadius.circular(2.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 1),
                      const Icon(Icons.star_rounded, size: 8, color: Color(0xFF32285A)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResourceChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback? onAdd;

  const _ResourceChip({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.fromLTRB(6, 2, 4, 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B1B54), Color(0xFF0F0E38)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4C428E), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF3DE07B), Color(0xFF1EAB55)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.add_rounded, size: 10, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- stat cards -------------------------------------------------------------
class _StatCards extends StatelessWidget {
  final GameController controller;
  const _StatCards({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'SCORE',
            value: _fmt(controller.score),
            valueColor: const Color(0xFFFFD93B),
            icon: const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD93B), size: 20),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _StatCard(
            label: 'MOVES',
            value: '${controller.movesLeft}',
            icon: const SizedBox(
              width: 18,
              height: 18,
              child: CustomPaint(painter: CurvedArrowPainter()),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _StatCard(
            label: 'TARGET',
            value: _fmt(controller.targetScore),
            icon: Image.asset(
              'assets/images/target.png',
              width: 22,
              height: 22,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final Widget icon;

  const _StatCard({
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2633C6), Color(0xFF0F1556)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6B8EFF), width: 1.8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332633C6),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black26,
              border: Border.all(color: const Color(0xFF4C5AEF), width: 1.5),
            ),
            child: Center(child: icon),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: valueColor,
                      shadows: const [
                        Shadow(
                          color: Colors.black38,
                          offset: Offset(0, 1),
                          blurRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- progress bar -----------------------------------------------------------
class _ProgressBar extends StatelessWidget {
  final GameController controller;
  const _ProgressBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final target = controller.targetScore;
    final thresholds = controller.level.starThresholds;
    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        return Container(
          height: 18,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B54),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: const Color(0xFF4C428E), width: 1.5),
                ),
              ),
              Positioned(
                left: 2,
                child: Container(
                  width: ((width - 4) * controller.scoreProgress).clamp(0.0, width - 4),
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD93B), Color(0xFFFF9E00)],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              for (final t in thresholds)
                if (target > 0)
                  Positioned(
                    left: ((width - 8) * (t / target).clamp(0.0, 1.0)) - 6,
                    child: Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: controller.score >= t
                          ? const Color(0xFFFFD93B)
                          : const Color(0xFF32285A),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

// --- goals ------------------------------------------------------------------
class _GoalsRow extends StatelessWidget {
  final GameController controller;
  const _GoalsRow({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B54),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD93B), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'GOALS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: Color(0xFFFFD93B),
            ),
          ),
          const SizedBox(width: 12),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: _chips(),
          ),
        ],
      ),
    );
  }

  List<Widget> _chips() {
    final objective = controller.objective;
    switch (objective) {
      case ReachScore(:final target):
        return [
          _GoalChip(
              icon: Icons.flag_rounded,
              iconColor: AppColors.gold,
              text: '$target',
              done: controller.score >= target),
        ];
      case CollectColors(:final quotas):
        return [
          for (final entry in quotas.entries)
            _GoalChip(
              candy: entry.key,
              text: '${(entry.value - (controller.collected[entry.key] ?? 0)).clamp(0, entry.value)}',
              done: (controller.collected[entry.key] ?? 0) >= entry.value,
            ),
        ];
      case ClearAllJelly():
        return [
          _GoalChip(
            icon: Icons.grid_view_rounded,
            iconColor: const Color(0xFF3FD0E0),
            text: '${controller.jellyRemaining}',
            done: controller.jellyRemaining == 0,
          ),
        ];
    }
  }
}

class _GoalChip extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final TileType? candy;
  final String text;
  final bool done;

  const _GoalChip({
    this.icon,
    this.iconColor,
    this.candy,
    required this.text,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (candy != null)
          SizedBox(width: 22, height: 22, child: TileWidget(type: candy!))
        else
          Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 4),
        if (done)
          const Icon(Icons.check_circle_rounded,
              size: 16, color: AppColors.gold)
        else
          Text(text,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}

// --- booster bar ------------------------------------------------------------
class _BoosterBar extends StatelessWidget {
  final GameController controller;
  final void Function(BoosterId) onUse;
  const _BoosterBar({required this.controller, required this.onUse});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _BoosterButton(
            id: BoosterId.lollipop,
            label: 'Lollipop',
            color: const Color(0xFFFF5CA8),
            content: const Icon(Icons.icecream_rounded, color: Colors.white, size: 24),
            count: controller.boosterCount(BoosterId.lollipop),
            enabled: controller.canUseBooster(BoosterId.lollipop),
            onTap: () => onUse(BoosterId.lollipop),
          ),
          _BoosterButton(
            id: BoosterId.colorBomb,
            label: 'Color Bomb',
            color: const Color(0xFF2A2340),
            content: const SizedBox(
              width: 24,
              height: 24,
              child: CustomPaint(painter: BombIconPainter()),
            ),
            count: controller.boosterCount(BoosterId.colorBomb),
            enabled: controller.canUseBooster(BoosterId.colorBomb),
            onTap: () => onUse(BoosterId.colorBomb),
          ),
          _BoosterButton(
            id: BoosterId.extraMoves,
            label: '+5 Moves',
            color: const Color(0xFF0072FF),
            content: const Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
            count: controller.boosterCount(BoosterId.extraMoves),
            enabled: controller.canUseBooster(BoosterId.extraMoves),
            onTap: () => onUse(BoosterId.extraMoves),
          ),
          _BoosterButton(
            id: BoosterId.shuffle,
            label: 'Magic',
            color: const Color(0xFF9F00FF),
            content: const Icon(Icons.auto_fix_high_rounded, color: Colors.white, size: 24),
            count: controller.boosterCount(BoosterId.shuffle),
            enabled: controller.canUseBooster(BoosterId.shuffle),
            onTap: () => onUse(BoosterId.shuffle),
          ),
        ],
      ),
    );
  }
}

class _BoosterButton extends StatelessWidget {
  final BoosterId id;
  final String label;
  final Color color;
  final Widget content;
  final int count;
  final bool enabled;
  final VoidCallback onTap;

  const _BoosterButton({
    required this.id,
    required this.label,
    required this.color,
    required this.content,
    required this.count,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.lerp(color, Colors.white, 0.45)!,
                        color,
                        Color.lerp(color, Colors.black, 0.25)!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFBCA6FF), width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(child: content),
                ),
                Positioned(
                  top: 2,
                  left: 2,
                  right: 2,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Container(
                      height: 18,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.4),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3DE07B),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF12331F),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black87,
                    offset: Offset(0, 1.5),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- bottom bar (menu + hint banner) ----------------------------------------
class _BottomBar extends StatelessWidget {
  final VoidCallback onMenu;
  const _BottomBar({required this.onMenu});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onMenu,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF221F55), Color(0xFF0F0E38)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFD93B), width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.menu_rounded, size: 28, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: _HintBanner()),
        ],
      ),
    );
  }
}

class _HintBanner extends StatelessWidget {
  const _HintBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF221F55), Color(0xFF0F0E38)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD93B), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CustomPaint(painter: PeppermintCandyPainter()),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Sugar Crush nearby!',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: Color(0xFFFFD93B),
                    ),
                  ),
                  Text(
                    'Match 5 to activate',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
