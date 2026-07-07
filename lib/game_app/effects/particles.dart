import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class Particle {
  Offset pos;
  Offset vel;
  final Color color;
  double life;
  final double maxLife;
  final double size;
  double rotation;
  final double spin;

  Particle({
    required this.pos,
    required this.vel,
    required this.color,
    required this.life,
    required this.size,
    required this.rotation,
    required this.spin,
  }) : maxLife = life;
}

/// Rising, fading text (combo words, score numbers).
class Floater {
  Offset pos;
  final String text;
  final Color color;
  double life;
  final double maxLife;
  final double size;
  double vy;

  Floater({
    required this.pos,
    required this.text,
    required this.color,
    required this.life,
    required this.size,
    required this.vy,
  }) : maxLife = life;
}

/// Ticker-driven pool of particles, floaters and a decaying screen-shake
/// offset. Notifies listeners each frame (only while something is alive, then
/// the ticker stops to stay idle-cheap). Painted by [EffectsPainter]; the shake
/// offset is applied by the board's `Transform.translate`.
class EffectsController extends ChangeNotifier {
  final TickerProvider vsync;
  final List<Particle> particles = [];
  final List<Floater> floaters = [];
  Offset shake = Offset.zero;

  final Random _rnd = Random();
  Ticker? _ticker;
  Duration _last = Duration.zero;
  double _shakeTime = 0;
  double _shakeStrength = 0;

  EffectsController(this.vsync);

  void burst(
    Offset center,
    Color color, {
    int count = 7,
    double speed = 200,
    double baseSize = 6,
  }) {
    for (var i = 0; i < count; i++) {
      final angle = _rnd.nextDouble() * 2 * pi;
      final s = speed * (0.35 + _rnd.nextDouble());
      particles.add(Particle(
        pos: center,
        vel: Offset(cos(angle) * s, sin(angle) * s - speed * 0.3),
        color: color,
        life: 0.5 + _rnd.nextDouble() * 0.35,
        size: baseSize * (0.6 + _rnd.nextDouble() * 0.8),
        rotation: _rnd.nextDouble() * pi,
        spin: (_rnd.nextDouble() - 0.5) * 12,
      ));
    }
    _start();
  }

  void floater(Offset pos, String text, Color color, {double size = 22}) {
    floaters.add(Floater(
      pos: pos,
      text: text,
      color: color,
      life: 0.95,
      size: size,
      vy: -70,
    ));
    _start();
  }

  void addShake(double strength) {
    _shakeStrength = max(_shakeStrength, strength);
    _shakeTime = 0.35;
    _start();
  }

  void _start() {
    _ticker ??= vsync.createTicker(_tick);
    if (!_ticker!.isActive) {
      _last = Duration.zero;
      _ticker!.start();
    }
  }

  void _tick(Duration elapsed) {
    final dt =
        _last == Duration.zero ? 0.016 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    const gravity = 620.0;

    for (final p in particles) {
      p.pos += p.vel * dt;
      p.vel = Offset(p.vel.dx * (1 - 1.6 * dt), p.vel.dy + gravity * dt);
      p.rotation += p.spin * dt;
      p.life -= dt;
    }
    particles.removeWhere((p) => p.life <= 0);

    for (final f in floaters) {
      f.pos = Offset(f.pos.dx, f.pos.dy + f.vy * dt);
      f.vy *= (1 - 0.9 * dt);
      f.life -= dt;
    }
    floaters.removeWhere((f) => f.life <= 0);

    if (_shakeTime > 0) {
      _shakeTime -= dt;
      final decay = (_shakeTime / 0.35).clamp(0.0, 1.0);
      final mag = _shakeStrength * decay;
      shake = Offset(
        (_rnd.nextDouble() * 2 - 1) * mag,
        (_rnd.nextDouble() * 2 - 1) * mag,
      );
    } else {
      shake = Offset.zero;
      _shakeStrength = 0;
    }

    notifyListeners();

    if (particles.isEmpty && floaters.isEmpty && _shakeTime <= 0) {
      _ticker!.stop();
      shake = Offset.zero;
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }
}

/// Paints the live particles and floaters. Repaints are driven by the
/// controller's notifications (via `super(repaint:)`), not widget rebuilds.
class EffectsPainter extends CustomPainter {
  final EffectsController controller;
  EffectsPainter(this.controller) : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in controller.particles) {
      final alpha = (p.life / p.maxLife).clamp(0.0, 1.0);
      paint.color = p.color.withValues(alpha: alpha);
      canvas.save();
      canvas.translate(p.pos.dx, p.pos.dy);
      canvas.rotate(p.rotation);
      final s = p.size * (0.4 + 0.6 * alpha);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: s, height: s),
            Radius.circular(s * 0.3)),
        paint,
      );
      canvas.restore();
    }

    for (final f in controller.floaters) {
      final alpha = (f.life / f.maxLife).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: f.text,
          style: TextStyle(
            fontSize: f.size,
            fontWeight: FontWeight.w900,
            color: f.color.withValues(alpha: alpha),
            shadows: [
              Shadow(
                  color: Colors.black.withValues(alpha: alpha * 0.6),
                  blurRadius: 4,
                  offset: const Offset(0, 2)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, f.pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(EffectsPainter oldDelegate) => false;
}
