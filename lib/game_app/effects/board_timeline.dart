import 'package:flutter/widgets.dart';

import '../../game_logic/game_logic.dart';
import '../theme/candy_theme.dart';

/// Frame-synced board animation as a *pure keyframe timeline*.
///
/// The engine hands us a fully-resolved [ResolutionResult]; playback is then a
/// deterministic function of a single clock (milliseconds). Each tile's whole
/// life during one playback is a list of [BoardSeg]ments; [BoardSprite.sampleAt]
/// returns its geometry at any ms. One `AnimationController` samples every
/// sprite each vsync — no `Future.delayed`, no per-tile implicit animations, no
/// `setState` churn. Because it's pure, a widget test can seek to any ms and
/// assert a tile sits strictly between its endpoints (genuinely animating).

// --- tuning -----------------------------------------------------------------
const double kSwapMs = 200;
const double kInvalidOutMs = 170;
const double kInvalidBackMs = 190;
const double kPopMs = 280;
const double kFallMs = 300;
const double kFallPerRowMs = 16; // extra fall time per row of distance
const double kColStaggerMs = 24; // ripple across columns
const double kSpawnStaggerMs = 55; // successive refills in a column
const double kOverlapMs = 50; // blend pop tail into the fall

/// A curve that pulls slightly *backward* before easing forward — anticipation.
class AnticipateCurve extends Curve {
  final double tension;
  const AnticipateCurve([this.tension = 1.6]);

  @override
  double transformInternal(double t) =>
      t * t * ((tension + 1) * t - tension);
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// What `build()` consumes for one tile at one instant. [cell] is fractional
/// (col, row) space; multiply by the current cell size in pixels.
class TileSample {
  final Offset cell;
  final double scaleX;
  final double scaleY;
  final double opacity;
  final bool alive;

  const TileSample(
      this.cell, this.scaleX, this.scaleY, this.opacity, this.alive);
}

class BoardSeg {
  final double startMs;
  final double endMs;
  final Offset from;
  final Offset to;
  final double scaleFrom;
  final double scaleTo;
  final double opacityFrom;
  final double opacityTo;
  final Curve posCurve;
  final Curve scaleCurve;
  final Curve opacityCurve;
  final bool land; // apply squash-stretch on arrival

  const BoardSeg({
    required this.startMs,
    required this.endMs,
    required this.from,
    required this.to,
    this.scaleFrom = 1,
    this.scaleTo = 1,
    this.opacityFrom = 1,
    this.opacityTo = 1,
    this.posCurve = Curves.linear,
    this.scaleCurve = Curves.linear,
    this.opacityCurve = Curves.linear,
    this.land = false,
  });
}

/// One tile's timeline. Holds its endpoints before/after/between segments so
/// there is never a teleport or a gap.
class BoardSprite {
  final int id;
  final TileType type;
  final SpecialType special;
  final Offset home;
  final List<BoardSeg> segs;

  const BoardSprite({
    required this.id,
    required this.type,
    required this.special,
    required this.home,
    required this.segs,
  });

  TileSample sampleAt(double ms) {
    if (segs.isEmpty) return TileSample(home, 1, 1, 1, true);
    final first = segs.first;
    if (ms <= first.startMs) {
      return TileSample(
          first.from, first.scaleFrom, first.scaleFrom, first.opacityFrom,
          first.opacityFrom > 0.02);
    }
    BoardSeg? lastBefore;
    for (final s in segs) {
      if (ms >= s.startMs && ms <= s.endMs) return _within(s, ms);
      if (s.endMs < ms) lastBefore = s;
    }
    final s = lastBefore ?? segs.last;
    return TileSample(s.to, s.scaleTo, s.scaleTo, s.opacityTo, s.opacityTo > 0.02);
  }

  TileSample _within(BoardSeg s, double ms) {
    final raw = ((ms - s.startMs) / (s.endMs - s.startMs)).clamp(0.0, 1.0);
    final pos = Offset.lerp(s.from, s.to, s.posCurve.transform(raw))!;
    final scale = _lerp(s.scaleFrom, s.scaleTo, s.scaleCurve.transform(raw));
    final opacity =
        _lerp(s.opacityFrom, s.opacityTo, s.opacityCurve.transform(raw));
    var sx = scale, sy = scale;
    if (s.land) {
      // squash-stretch during the last 40% of the slide (0 -> peak -> 0).
      final k = ((raw - 0.6) / 0.4).clamp(0.0, 1.0);
      final squash = (k <= 0 || k >= 1) ? 0.0 : _bump(k) * 0.16;
      sy = scale * (1 - squash);
      sx = scale * (1 + squash);
    }
    return TileSample(pos, sx, sy, opacity, opacity > 0.02);
  }

  // 0 -> 1 -> 0 over [0,1].
  double _bump(double k) => 1 - (2 * k - 1).abs();
}

/// A frame-synced side effect (particle burst, sound, shake, floating text).
enum CueKind { burst, popSound, score, combo, shake, special, swapSound, invalidSound }

class TimelineCue {
  final double ms;
  final CueKind kind;
  final Offset? at; // cell-space center
  final Color? color;
  final String? text;
  final int level;
  final double amount;
  bool fired = false;

  TimelineCue(this.kind, this.ms,
      {this.at, this.color, this.text, this.level = 1, this.amount = 0});
}

class BoardTimeline {
  final Map<int, BoardSprite> sprites;
  final double totalMs;
  final List<TimelineCue> cues;

  const BoardTimeline(this.sprites, this.totalMs, this.cues);
}

/// The initial on-screen state of a tile (before the swap is played).
class SpriteSeed {
  final TileType type;
  final SpecialType special;
  final Offset cell;
  const SpriteSeed(this.type, this.special, this.cell);
}

Offset _c(Position p) => Offset(p.col.toDouble(), p.row.toDouble());

/// Builds a [BoardTimeline] from the pre-swap [seeds] and the resolved
/// [result]. Pure and deterministic — no Flutter state.
BoardTimeline buildBoardTimeline({
  required int rows,
  required Map<int, SpriteSeed> seeds,
  required ResolutionResult result,
}) {
  final tracks = <int, List<BoardSeg>>{};
  final home = <int, Offset>{};
  final cues = <TimelineCue>[];

  for (final entry in seeds.entries) {
    home[entry.key] = entry.value.cell;
    tracks[entry.key] = [];
  }

  void seg(int id, BoardSeg s) => tracks.putIfAbsent(id, () => []).add(s);

  void move(int id, Offset to, double start, double end,
      {required Curve posCurve, bool land = false}) {
    final from = home[id] ?? to;
    seg(id, BoardSeg(startMs: start, endMs: end, from: from, to: to,
        posCurve: posCurve, land: land));
    home[id] = to;
  }

  void pop(int id, double start) {
    final at = home[id] ?? Offset.zero;
    seg(id, BoardSeg(startMs: start, endMs: start + 90, from: at, to: at,
        scaleFrom: 1, scaleTo: 1.28, scaleCurve: Curves.easeOutBack));
    seg(id, BoardSeg(startMs: start + 90, endMs: start + kPopMs, from: at, to: at,
        scaleFrom: 1.28, scaleTo: 0, opacityFrom: 1, opacityTo: 0,
        scaleCurve: Curves.easeIn, opacityCurve: Curves.easeIn));
  }

  var cursor = 0.0;

  if (!result.valid) {
    final a = _c(result.swap.a), b = _c(result.swap.b);
    cues.add(TimelineCue(CueKind.invalidSound, 0));
    move(result.swap.idA, b, 0, kInvalidOutMs, posCurve: Curves.easeOut);
    move(result.swap.idB, a, 0, kInvalidOutMs, posCurve: Curves.easeOut);
    final back = kInvalidOutMs;
    move(result.swap.idA, a, back, back + kInvalidBackMs,
        posCurve: Curves.easeOutBack);
    move(result.swap.idB, b, back, back + kInvalidBackMs,
        posCurve: Curves.easeOutBack);
    cursor = back + kInvalidBackMs;
    return _finish(rows, seeds, result, tracks, home, cursor, cues);
  }

  // Valid swap — skip the swap leg for boosters, whose swap.a == swap.b.
  if (result.swap.a != result.swap.b) {
    cues.add(TimelineCue(CueKind.swapSound, 0));
    move(result.swap.idA, _c(result.swap.b), 0, kSwapMs,
        posCurve: const AnticipateCurve());
    move(result.swap.idB, _c(result.swap.a), 0, kSwapMs,
        posCurve: const AnticipateCurve());
    cursor = kSwapMs;
  }

  for (final phase in result.phases) {
    final clearStart = cursor;

    // Clear / pop.
    for (final ct in phase.clearedTiles) {
      pop(ct.id, clearStart);
      cues.add(TimelineCue(CueKind.burst, clearStart,
          at: _c(ct.at), color: styleFor(ct.type).color));
    }
    // Created specials render with their new look for the whole playback:
    // identity is resolved from the settled board in _finish.
    if (phase.clearedTiles.isNotEmpty) {
      cues.add(TimelineCue(CueKind.popSound, clearStart, level: phase.level));
      final centroid = _centroid(phase.clearedTiles.map((t) => _c(t.at)));
      cues.add(TimelineCue(CueKind.score, clearStart,
          at: centroid, text: '+${phase.score}'));
    }
    if (phase.level >= 2) {
      cues.add(TimelineCue(CueKind.combo, clearStart, level: phase.level));
    }
    if (phase.created.isNotEmpty || phase.activations.isNotEmpty) {
      cues.add(TimelineCue(CueKind.special, clearStart));
    }
    final clearedCount = phase.cleared.length;
    if (clearedCount >= 6 || phase.level >= 2 || phase.activations.isNotEmpty) {
      cues.add(TimelineCue(CueKind.shake, clearStart,
          amount: (clearedCount * 0.25 + phase.level * 1.5).clamp(2.0, 14.0)));
    }
    cursor = clearStart + (phase.clearedTiles.isEmpty ? 0 : kPopMs);

    // Collapse + refill.
    final fallStart = (cursor - kOverlapMs).clamp(clearStart, cursor);
    var maxEnd = fallStart;

    for (final m in phase.moves) {
      final dist = (m.to.row - m.from.row).abs();
      final start = fallStart + m.to.col * kColStaggerMs;
      final end = start + kFallMs + dist * kFallPerRowMs;
      move(m.tileId, _c(m.to), start, end,
          posCurve: Curves.easeOutBack, land: true);
      if (end > maxEnd) maxEnd = end;
    }

    // Refills arrive top-first (ascending row). Give each a DISTINCT start row
    // above the board so a column's spawns form a contiguous falling stack:
    // the topmost destination (k=0) starts highest (-total), the lowest empty
    // (k=total-1) starts just above the top edge (-1). Using `at.row - k - 1`
    // would collapse them all to the same cell and let them pass through.
    final perColTotal = <int, int>{};
    for (final sp in phase.spawns) {
      perColTotal.update(sp.at.col, (v) => v + 1, ifAbsent: () => 1);
    }
    final perCol = <int, int>{};
    for (final sp in phase.spawns) {
      final total = perColTotal[sp.at.col]!;
      final k = perCol.update(sp.at.col, (v) => v + 1, ifAbsent: () => 0);
      final startCell = Offset(sp.at.col.toDouble(), (k - total).toDouble());
      tracks.putIfAbsent(sp.tileId, () => []);
      final dist = sp.at.row - (k - total);
      final start = fallStart + sp.at.col * kColStaggerMs + k * kSpawnStaggerMs;
      final end = start + kFallMs + dist * kFallPerRowMs;
      seg(sp.tileId, BoardSeg(startMs: start, endMs: end, from: startCell,
          to: _c(sp.at), posCurve: Curves.easeOutBack, land: true));
      home[sp.tileId] = _c(sp.at);
      if (end > maxEnd) maxEnd = end;
    }

    cursor = maxEnd;
  }

  return _finish(rows, seeds, result, tracks, home, cursor, cues);
}

const double kShuffleMs = 460;

/// A timeline for an auto-shuffle: every relocated tile slides from its current
/// cell to its new one (ids preserved). Non-moved tiles hold in place.
BoardTimeline buildShuffleTimeline({
  required int rows,
  required Map<int, SpriteSeed> seeds,
  required List<TileMove> moves,
}) {
  final sprites = <int, BoardSprite>{};
  final moved = <int, TileMove>{for (final m in moves) m.tileId: m};

  seeds.forEach((id, seed) {
    final m = moved[id];
    final segs = <BoardSeg>[];
    if (m != null) {
      segs.add(BoardSeg(
        startMs: 0,
        endMs: kShuffleMs,
        from: seed.cell,
        to: _c(m.to),
        posCurve: Curves.easeInOutCubic,
      ));
    }
    sprites[id] = BoardSprite(
      id: id,
      type: seed.type,
      special: seed.special,
      home: seed.cell,
      segs: segs,
    );
  });

  final cues = [
    TimelineCue(CueKind.swapSound, 0),
    TimelineCue(CueKind.shake, 0, amount: 6),
  ];
  return BoardTimeline(sprites, kShuffleMs, cues);
}

BoardTimeline _finish(
  int rows,
  Map<int, SpriteSeed> seeds,
  ResolutionResult result,
  Map<int, List<BoardSeg>> tracks,
  Map<int, Offset> home,
  double totalMs,
  List<TimelineCue> cues,
) {
  // Resolve each sprite's final identity: surviving tiles from the settled
  // board, removed tiles from their clear snapshot.
  final identity = <int, (TileType, SpecialType)>{};
  for (final p in result.board.playablePositions()) {
    final t = result.board.tileAt(p);
    if (t != null) identity[t.id] = (t.type, t.special);
  }
  for (final phase in result.phases) {
    for (final ct in phase.clearedTiles) {
      identity[ct.id] = (ct.type, ct.special);
    }
  }

  final sprites = <int, BoardSprite>{};
  tracks.forEach((id, segs) {
    final ident = identity[id] ??
        (seeds[id] != null
            ? (seeds[id]!.type, seeds[id]!.special)
            : (TileType.red, SpecialType.none));
    final firstFrom = segs.isNotEmpty ? segs.first.from : (home[id] ?? Offset.zero);
    sprites[id] = BoardSprite(
      id: id,
      type: ident.$1,
      special: ident.$2,
      home: seeds[id]?.cell ?? firstFrom,
      segs: segs,
    );
  });

  return BoardTimeline(sprites, totalMs <= 0 ? 1 : totalMs, cues);
}

Offset _centroid(Iterable<Offset> cells) {
  var sx = 0.0, sy = 0.0, n = 0;
  for (final c in cells) {
    sx += c.dx;
    sy += c.dy;
    n++;
  }
  return n == 0 ? Offset.zero : Offset(sx / n, sy / n);
}
