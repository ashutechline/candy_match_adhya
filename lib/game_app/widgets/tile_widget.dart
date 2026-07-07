import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game_logic/game_logic.dart';
import '../theme/candy_theme.dart';

/// A single game piece: a glossy rounded gel tile in its colour with a FRUIT on
/// it (apple, orange, lemon, green apple, blueberry, grapes…). Special candies
/// add stripes / a wrapper / a colour bomb. Pure paint — no per-tile widgets.
class TileWidget extends StatelessWidget {
  final TileType type;
  final SpecialType special;
  final bool selected;

  const TileWidget({
    super.key,
    required this.type,
    this.special = SpecialType.none,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FruitPainter(type: type, special: special, selected: selected),
      size: Size.infinite,
    );
  }
}

class _FruitPainter extends CustomPainter {
  final TileType type;
  final SpecialType special;
  final bool selected;

  _FruitPainter({
    required this.type,
    required this.special,
    required this.selected,
  });

  /// Emoji laid out once per fruit at a reference size, then scaled at draw
  /// time — avoids re-laying-out text every frame during cascades.
  static final Map<String, TextPainter> _fruitCache = {};

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final body = rect.deflate(size.shortestSide * 0.05);
    final style = styleFor(type);
    final radius = Radius.circular(body.shortestSide * 0.28);
    final rrect = RRect.fromRectAndRadius(body, radius);

    if (special == SpecialType.colorBomb) {
      _paintColorBomb(canvas, body, rrect);
    } else {
      _paintGel(canvas, body, rrect, style.color);
      _paintFruit(canvas, body, fruitFor(type));
      if (special.isStriped) {
        _paintStripes(canvas, rrect, body,
            vertical: special == SpecialType.stripedColumn);
      }
      if (special == SpecialType.wrapped) {
        _paintWrapped(canvas, body);
      }
    }

    if (selected) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(body.inflate(size.shortestSide * 0.02), radius),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.shortestSide * 0.06
          ..color = Colors.white,
      );
    }
  }

  // Glossy rounded-square gel base.
  void _paintGel(Canvas canvas, Rect body, RRect rrect, Color color) {
    canvas.drawRRect(
      rrect.shift(Offset(0, body.height * 0.06)),
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.lerp(color, Colors.white, 0.5)!,
        color,
        Color.lerp(color, Colors.black, 0.22)!,
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    canvas.drawRRect(rrect, Paint()..shader = gradient.createShader(body));

    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawOval(
      Rect.fromLTWH(body.left + body.width * 0.14, body.top + body.height * 0.08,
          body.width * 0.72, body.height * 0.3),
      Paint()..color = Colors.white.withValues(alpha: 0.25),
    );
    canvas.restore();

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = body.shortestSide * 0.05
        ..color = Color.lerp(color, Colors.black, 0.32)!,
    );
  }

  // The fruit emoji, centred with a soft spotlight so it reads on the tile.
  void _paintFruit(Canvas canvas, Rect body, String emoji) {
    canvas.drawCircle(
      body.center,
      body.shortestSide * 0.34,
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );

    final tp = _fruitCache.putIfAbsent(emoji, () {
      final painter = TextPainter(
        text: TextSpan(text: emoji, style: const TextStyle(fontSize: 100)),
        textDirection: TextDirection.ltr,
      );
      painter.layout();
      return painter;
    });

    final scale = (body.shortestSide * 0.7) / tp.height;
    canvas.save();
    canvas.translate(body.center.dx, body.center.dy);
    canvas.scale(scale);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  void _paintStripes(Canvas canvas, RRect rrect, Rect body,
      {required bool vertical}) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = body.shortestSide * 0.07
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.clipRRect(rrect);
    for (var i = -2; i <= 2; i++) {
      if (vertical) {
        final x = body.center.dx + i * body.width * 0.24;
        canvas.drawLine(Offset(x, body.top), Offset(x, body.bottom), paint);
      } else {
        final y = body.center.dy + i * body.height * 0.24;
        canvas.drawLine(Offset(body.left, y), Offset(body.right, y), paint);
      }
    }
    canvas.restore();
  }

  void _paintWrapped(Canvas canvas, Rect body) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          body.deflate(body.width * 0.1), Radius.circular(body.width * 0.16)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = body.shortestSide * 0.1
        ..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  void _paintColorBomb(Canvas canvas, Rect body, RRect rrect) {
    canvas.drawRRect(
      rrect.shift(Offset(0, body.height * 0.06)),
      Paint()..color = Colors.black.withValues(alpha: 0.3),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF3A3358), Color(0xFF12101F)],
        ).createShader(body),
    );

    const sparkleColors = [
      Color(0xFFE5484D),
      Color(0xFFF76B15),
      Color(0xFFFFC53D),
      Color(0xFF46A758),
      Color(0xFF2E90FA),
      Color(0xFF8E4EC6),
    ];
    final center = body.center;
    final r = body.shortestSide * 0.26;
    for (var i = 0; i < sparkleColors.length; i++) {
      final angle = i * 2 * math.pi / sparkleColors.length;
      final p = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
      canvas.drawCircle(
          p, body.shortestSide * 0.07, Paint()..color = sparkleColors[i]);
    }
    canvas.drawCircle(
        center, body.shortestSide * 0.11, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_FruitPainter old) =>
      old.type != type || old.special != special || old.selected != selected;
}
