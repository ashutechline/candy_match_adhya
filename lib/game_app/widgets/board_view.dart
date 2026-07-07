import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game_logic/game_logic.dart';
import '../audio/audio_service.dart';
import '../effects/board_timeline.dart';
import '../effects/particles.dart';
import '../game/game_controller.dart';
import '../game/settings_service.dart';
import '../theme/candy_theme.dart';
import 'tile_widget.dart';

/// Static on-screen tile when the board is idle (between moves).
class _Static {
  final int id;
  TileType type;
  SpecialType special;
  int row;
  int col;
  _Static(this.id, this.type, this.special, this.row, this.col);
}

/// Renders and animates the board with plain Flutter widgets.
///
/// Playback is driven by a SINGLE [AnimationController] sampling a pure
/// [BoardTimeline] every vsync frame (swap → pop → staggered collapse →
/// cascading refill), so motion is frame-synced and jitter-free — never
/// `Future.delayed`. Particle bursts, floating text and screen shake fire from
/// timeline cues. Idle-frame concerns (selection, hint) live on the static
/// layer. Drives the [GameController] and gates input for the whole playback.
class BoardView extends StatefulWidget {
  final GameController controller;

  const BoardView({super.key, required this.controller});

  @override
  State<BoardView> createState() => BoardViewState();
}

class BoardViewState extends State<BoardView> with TickerProviderStateMixin {
  final Map<int, _Static> _statics = {};
  late final EffectsController _effects;
  late final AnimationController _playback;
  late final AnimationController _hintController;

  BoardTimeline? _timeline;
  bool _playbackValid = false;
  bool _shuffling = false;
  bool _armedLollipop = false;

  Timer? _hintTimer;
  Set<Position> _hint = {};

  double _cell = 0;
  Position? _selected;
  Offset _panDelta = Offset.zero;
  Position? _panStart;

  GameController get _c => widget.controller;
  int get _rows => _c.level.rows;
  int get _cols => _c.level.cols;

  @override
  void initState() {
    super.initState();
    _effects = EffectsController(this);
    _playback = AnimationController(vsync: this)
      ..addListener(_onTick)
      ..addStatusListener(_onStatus);
    _hintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
    _syncStatics(_c.board);
    _bumpHint();
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _playback.dispose();
    _hintController.dispose();
    _effects.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _timeline = null;
      _playback.stop();
      _statics.clear();
      _selected = null;
      _syncStatics(_c.board);
      _bumpHint();
    }
  }

  bool get _playing => _timeline != null;

  // --- playback --------------------------------------------------------------

  Future<void> _handleSwap(Position a, Position b) async {
    if (_playing) return;
    _bumpHint();

    // Snapshot the current on-screen positions BEFORE the engine mutates tiles.
    final seeds = _seedsFromStatics();

    final result = _c.trySwap(a, b);
    if (result == null) return;

    final timeline =
        buildBoardTimeline(rows: _rows, seeds: seeds, result: result);
    setState(() {
      _selected = null;
      _timeline = timeline;
      _playbackValid = result.valid;
    });
    _startPlayback(timeline);
  }

  Map<int, SpriteSeed> _seedsFromStatics() => {
        for (final s in _statics.values)
          s.id: SpriteSeed(s.type, s.special,
              Offset(s.col.toDouble(), s.row.toDouble())),
      };

  // --- public booster API (called from the game screen's booster bar) --------

  /// Arms the lollipop hammer: the next tap smashes that candy.
  void armLollipop() {
    if (_playing || _c.status != GameStatus.playing) return;
    setState(() {
      _armedLollipop = true;
      _selected = null;
    });
    _bumpHint();
  }

  bool get isArmed => _armedLollipop;

  /// Plays a booster/engine [ResolutionResult] (lollipop, color bomb) with the
  /// full clear/cascade animation.
  void playResult(ResolutionResult result) {
    if (_playing) return;
    final timeline =
        buildBoardTimeline(rows: _rows, seeds: _seedsFromStatics(), result: result);
    setState(() {
      _selected = null;
      _armedLollipop = false;
      _timeline = timeline;
      _playbackValid = true;
      _shuffling = false;
    });
    _startPlayback(timeline);
  }

  /// Plays an animated reshuffle from a [ShuffleResult].
  void playShuffle(ShuffleResult shuffle) {
    if (_playing || shuffle.moves.isEmpty) return;
    final timeline = buildShuffleTimeline(
        rows: _rows, seeds: _seedsFromStatics(), moves: shuffle.moves);
    setState(() {
      _timeline = timeline;
      _playbackValid = false;
      _shuffling = true;
    });
    _startPlayback(timeline);
  }

  void _startPlayback(BoardTimeline timeline) {
    _playback
      ..duration =
          Duration(milliseconds: timeline.totalMs.round().clamp(1, 60000))
      ..forward(from: 0);
  }

  void _onTick() {
    final timeline = _timeline;
    if (timeline == null) return;
    final ms = _playback.value * timeline.totalMs;
    for (final cue in timeline.cues) {
      if (!cue.fired && ms >= cue.ms) {
        cue.fired = true;
        _fireCue(cue);
      }
    }
  }

  void _fireCue(TimelineCue cue) {
    final reducedMotion = SettingsService.instance.reducedMotion.value;
    final haptics = SettingsService.instance.haptics.value;
    switch (cue.kind) {
      case CueKind.swapSound:
        AudioService.instance.swap();
        if (haptics) HapticFeedback.selectionClick();
      case CueKind.invalidSound:
        AudioService.instance.invalid();
      case CueKind.popSound:
        AudioService.instance.pop(cue.level);
      case CueKind.special:
        AudioService.instance.special();
        if (haptics) HapticFeedback.mediumImpact();
      case CueKind.burst:
        if (!reducedMotion && cue.at != null && cue.color != null) {
          _effects.burst(_pixel(cue.at!), cue.color!,
              count: 8, speed: _cell * 2.6, baseSize: _cell * 0.14);
        }
      case CueKind.score:
        if (cue.at != null && cue.text != null) {
          _effects.floater(_pixel(cue.at!), cue.text!, AppColors.gold,
              size: _cell * 0.44);
        }
      case CueKind.combo:
        _effects.floater(Offset(_cell * _cols / 2, _cell * 1.6),
            _comboWord(cue.level), AppColors.accent,
            size: _cell * 0.66);
      case CueKind.shake:
        if (!reducedMotion) _effects.addShake(cue.amount);
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _timeline == null) return;
    final wasShuffle = _shuffling;
    _timeline = null;
    _shuffling = false;

    if (!wasShuffle && _playbackValid) _c.onAnimationComplete();
    _syncStatics(_c.board);

    // Rescue a dead board with an animated reshuffle instead of a teleport.
    if (!wasShuffle && _c.status == GameStatus.playing) {
      final shuffle = _c.maybeShuffle();
      if (shuffle != null && shuffle.moves.isNotEmpty) {
        final timeline = buildShuffleTimeline(
            rows: _rows, seeds: _seedsFromStatics(), moves: shuffle.moves);
        setState(() {
          _shuffling = true;
          _timeline = timeline;
        });
        _startPlayback(timeline);
        return;
      }
    }

    _c.clearBusy(); // release input after a booster shuffle
    if (mounted) setState(() {});
    _bumpHint();
  }

  Offset _pixel(Offset cell) =>
      Offset((cell.dx + 0.5) * _cell, (cell.dy + 0.5) * _cell);

  String _comboWord(int level) => switch (level) {
        2 => 'Sweet!',
        3 => 'Tasty!',
        4 => 'Delicious!',
        5 => 'Divine!',
        _ => 'Insane!',
      };

  void _syncStatics(Board board) {
    final ids = <int>{};
    for (final p in board.playablePositions()) {
      final tile = board.tileAt(p);
      if (tile == null) continue;
      ids.add(tile.id);
      final s = _statics[tile.id];
      if (s == null) {
        _statics[tile.id] =
            _Static(tile.id, tile.type, tile.special, p.row, p.col);
      } else {
        s
          ..type = tile.type
          ..special = tile.special
          ..row = p.row
          ..col = p.col;
      }
    }
    _statics.removeWhere((id, _) => !ids.contains(id));
  }

  // --- idle hint --------------------------------------------------------------

  void _bumpHint() {
    _hintTimer?.cancel();
    final had = _hint.isNotEmpty;
    _hint = {};
    if (_c.status == GameStatus.playing) {
      _hintTimer = Timer(const Duration(seconds: 5), _showHint);
    }
    if (had && mounted) setState(() {});
  }

  void _showHint() {
    if (!mounted || _playing || _c.status != GameStatus.playing) {
      _bumpHint();
      return;
    }
    final move = _findHintMove();
    if (move != null) setState(() => _hint = {move.$1, move.$2});
  }

  (Position, Position)? _findHintMove() {
    for (final p in _c.board.playablePositions()) {
      for (final q in [p.right, p.down]) {
        if (_c.board.isPlayable(q) &&
            _c.engine.resolveSwap(_c.board, p, q).valid) {
          return (p, q);
        }
      }
    }
    return null;
  }

  // --- input ------------------------------------------------------------------

  bool get _inputLocked =>
      _playing || _c.isBusy || _c.status != GameStatus.playing;

  Position? _cellAt(Offset local) {
    if (_cell <= 0) return null;
    final p = Position((local.dy / _cell).floor(), (local.dx / _cell).floor());
    return _c.board.isPlayable(p) ? p : null;
  }

  void _onTapUp(TapUpDetails d) {
    _bumpHint();
    if (_inputLocked) return;
    final cell = _cellAt(d.localPosition);
    if (cell == null) {
      if (_armedLollipop) setState(() => _armedLollipop = false);
      return;
    }
    AudioService.instance.tap();
    if (_armedLollipop) {
      final result = _c.useLollipop(cell);
      setState(() => _armedLollipop = false);
      if (result != null) playResult(result);
      return;
    }
    if (_selected == null) {
      setState(() => _selected = cell);
    } else if (_selected == cell) {
      setState(() => _selected = null);
    } else if (_c.engine.areAdjacent(_selected!, cell)) {
      _handleSwap(_selected!, cell);
    } else {
      setState(() => _selected = cell);
    }
  }

  void _onPanStart(DragStartDetails d) {
    _bumpHint();
    if (_inputLocked) return;
    _panStart = _cellAt(d.localPosition);
    _panDelta = Offset.zero;
  }

  void _onPanUpdate(DragUpdateDetails d) => _panDelta += d.delta;

  void _onPanEnd(DragEndDetails d) {
    if (_inputLocked || _panStart == null) return;
    final start = _panStart!;
    _panStart = null;
    if (_panDelta.distance < _cell * 0.35) return;
    final Position target;
    if (_panDelta.dx.abs() > _panDelta.dy.abs()) {
      target = _panDelta.dx > 0 ? start.right : start.left;
    } else {
      target = _panDelta.dy > 0 ? start.down : start.up;
    }
    if (_c.board.isPlayable(target)) _handleSwap(start, target);
  }

  // --- build ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double boardPadding = 8.0;
        _cell = math.min(
          (constraints.maxWidth - boardPadding * 2) / _cols,
          (constraints.maxHeight - boardPadding * 2) / _rows,
        );
        final width = _cell * _cols + boardPadding * 2;
        final height = _cell * _rows + boardPadding * 2;

        final board = Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _BoardBackgroundPainter(
                  rows: _rows,
                  cols: _cols,
                  blocked: _c.board.blocked,
                  jelly: _c.jelly,
                  cell: _cell,
                ),
              ),
            ),
            _playing ? _buildTimelineLayer() : _buildStaticLayer(),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: EffectsPainter(_effects)),
              ),
            ),
            if (_armedLollipop)
              Positioned(
                left: 0,
                right: 0,
                top: 8,
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF2E93), Color(0xFFFF007F)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFFB2D6), width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.icecream_rounded, size: 16, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Tap a candy to smash!',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );

        return Center(
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_cell * 0.28 + boardPadding),
              color: const Color(0x660F0C2C),
              border: Border.all(color: const Color(0xFF8B36FF), width: 3.5),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _effects,
              builder: (context, child) =>
                  Transform.translate(offset: _effects.shake, child: child),
              child: Padding(
                padding: const EdgeInsets.all(boardPadding),
                child: GestureDetector(
                  onTapUp: _onTapUp,
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: board,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimelineLayer() {
    return AnimatedBuilder(
      animation: _playback,
      builder: (context, _) {
        final timeline = _timeline;
        if (timeline == null) return const SizedBox.shrink();
        final ms = _playback.value * timeline.totalMs;
        final children = <Widget>[];
        for (final sprite in timeline.sprites.values) {
          final s = sprite.sampleAt(ms);
          if (!s.alive) continue;
          children.add(Positioned(
            key: ValueKey(sprite.id),
            left: s.cell.dx * _cell,
            top: s.cell.dy * _cell,
            width: _cell,
            height: _cell,
            child: Opacity(
              opacity: s.opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scaleX: s.scaleX,
                scaleY: s.scaleY,
                child: Padding(
                  padding: EdgeInsets.all(_cell * 0.04),
                  child: TileWidget(type: sprite.type, special: sprite.special),
                ),
              ),
            ),
          ));
        }
        return Stack(clipBehavior: Clip.none, children: children);
      },
    );
  }

  Widget _buildStaticLayer() {
    final children = <Widget>[];
    for (final s in _statics.values) {
      final selected =
          _selected != null && _selected!.row == s.row && _selected!.col == s.col;
      final isHint = _hint.any((p) => p.row == s.row && p.col == s.col);

      Widget tile = Padding(
        padding: EdgeInsets.all(_cell * 0.04),
        child: TileWidget(
            type: s.type, special: s.special, selected: selected),
      );
      if (isHint) {
        tile = AnimatedBuilder(
          animation: _hintController,
          child: tile,
          builder: (context, child) => Transform.scale(
            scale: 1 + 0.12 * Curves.easeInOut.transform(_hintController.value),
            child: child,
          ),
        );
      }

      children.add(Positioned(
        key: ValueKey(s.id),
        left: s.col * _cell,
        top: s.row * _cell,
        width: _cell,
        height: _cell,
        child: tile,
      ));
    }
    return Stack(clipBehavior: Clip.none, children: children);
  }
}

class _BoardBackgroundPainter extends CustomPainter {
  final int rows;
  final int cols;
  final Set<Position> blocked;
  final Map<Position, int> jelly;
  final double cell;

  _BoardBackgroundPainter({
    required this.rows,
    required this.cols,
    required this.blocked,
    required this.jelly,
    required this.cell,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final slot = Paint()..color = const Color(0x33000000);
    final slotStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.02
      ..color = const Color(0x1F8B36FF);
    final blockedPaint = Paint()..color = const Color(0xFF0F0E2C);
    final blockedStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.03
      ..color = const Color(0x33FFFFFF);
    final radius = Radius.circular(cell * 0.18);

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final rect = Rect.fromLTWH(c * cell, r * cell, cell, cell)
            .deflate(cell * 0.04);
        final rrect = RRect.fromRectAndRadius(rect, radius);
        final pos = Position(r, c);
        if (blocked.contains(pos)) {
          canvas.drawRRect(rrect, blockedPaint);
          canvas.drawRRect(rrect.deflate(cell * 0.03), blockedStroke);
          continue;
        }
        canvas.drawRRect(rrect, slot);
        canvas.drawRRect(rrect, slotStroke);
        final thickness = jelly[pos] ?? 0;
        if (thickness > 0) {
          final jellyPaint = Paint()
            ..color = AppColors.jelly
                .withValues(alpha: 0.28 + 0.22 * math.min(thickness, 2));
          canvas.drawRRect(rrect, jellyPaint);
          if (thickness > 1) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(rect.deflate(cell * 0.16), radius),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = cell * 0.04
                ..color = Colors.white.withValues(alpha: 0.5),
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(_BoardBackgroundPainter old) => true;
}
