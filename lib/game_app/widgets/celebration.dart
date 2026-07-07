import 'dart:math';

import 'package:flutter/material.dart';

import '../audio/audio_service.dart';
import '../theme/candy_theme.dart';

/// Full-screen confetti burst that rains down once (used behind the win card).
class ConfettiOverlay extends StatefulWidget {
  final int pieces;
  const ConfettiOverlay({super.key, this.pieces = 90});

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  static const _seconds = 3.5;
  late final AnimationController _controller;
  late final List<_Confetto> _confetti;

  static const _colors = [
    Color(0xFFE5484D),
    Color(0xFFF76B15),
    Color(0xFFFFC53D),
    Color(0xFF46A758),
    Color(0xFF2E90FA),
    Color(0xFF8E4EC6),
    AppColors.accent,
  ];

  @override
  void initState() {
    super.initState();
    final rnd = Random();
    _confetti = List.generate(widget.pieces, (i) {
      return _Confetto(
        x0: rnd.nextDouble(),
        y0: -0.1 - rnd.nextDouble() * 0.3,
        vx: (rnd.nextDouble() - 0.5) * 0.15,
        vy: 0.25 + rnd.nextDouble() * 0.35,
        sway: 0.02 + rnd.nextDouble() * 0.05,
        swayPhase: rnd.nextDouble() * pi * 2,
        size: 6 + rnd.nextDouble() * 8,
        color: _colors[rnd.nextInt(_colors.length)],
        rotSpeed: (rnd.nextDouble() - 0.5) * 12,
      );
    });
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ConfettiPainter(_confetti, _controller, _seconds),
        size: Size.infinite,
      ),
    );
  }
}

class _Confetto {
  final double x0, y0, vx, vy, sway, swayPhase, size, rotSpeed;
  final Color color;
  const _Confetto({
    required this.x0,
    required this.y0,
    required this.vx,
    required this.vy,
    required this.sway,
    required this.swayPhase,
    required this.size,
    required this.color,
    required this.rotSpeed,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Confetto> confetti;
  final Animation<double> anim;
  final double seconds;

  _ConfettiPainter(this.confetti, this.anim, this.seconds)
      : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value * seconds;
    final paint = Paint();
    for (final c in confetti) {
      final x = (c.x0 + c.vx * t + sin(t * 3 + c.swayPhase) * c.sway) * size.width;
      final y = (c.y0 + c.vy * t + 0.16 * t * t) * size.height;
      if (y > size.height + 20) continue;
      paint.color = c.color.withValues(alpha: (1 - anim.value * 0.4));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(c.rotSpeed * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset.zero, width: c.size, height: c.size * 0.6),
          Radius.circular(c.size * 0.2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => false;
}

/// Reveals up to three stars one-by-one with an elastic pop, chiming on each
/// earned star.
class AnimatedStars extends StatefulWidget {
  final int count;
  final double size;
  const AnimatedStars({super.key, required this.count, this.size = 54});

  @override
  State<AnimatedStars> createState() => _AnimatedStarsState();
}

class _AnimatedStarsState extends State<AnimatedStars>
    with SingleTickerProviderStateMixin {
  static const _step = 0.42; // seconds between reveals
  static const _pop = 0.4; // seconds per pop
  late final AnimationController _controller;
  int _chimed = 0;

  double get _total => widget.count * _step + _pop + 0.1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_total * 1000).toInt()),
    )
      ..addListener(_maybeChime)
      ..forward();
  }

  void _maybeChime() {
    final t = _controller.value * _total;
    final revealed = ((t) / _step).floor().clamp(0, widget.count);
    if (revealed > _chimed) {
      _chimed = revealed;
      AudioService.instance.star();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_maybeChime);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * _total;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              _star(i, ((t - i * _step) / _pop).clamp(0.0, 1.0)),
          ],
        );
      },
    );
  }

  Widget _star(int index, double progress) {
    final earned = index < widget.count;
    final scale =
        earned ? Curves.elasticOut.transform(progress).clamp(0.0, 1.4) : 1.0;
    return Transform.scale(
      scale: earned ? scale : 1.0,
      child: Icon(
        earned && progress > 0
            ? Icons.star_rounded
            : Icons.star_outline_rounded,
        size: widget.size,
        color: earned && progress > 0 ? AppColors.gold : Colors.white24,
      ),
    );
  }
}
