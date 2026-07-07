import 'dart:math';

import 'package:candy_crush/game_app/effects/board_timeline.dart';
import 'package:candy_crush/game_logic/game_logic.dart';
import 'package:flutter_test/flutter_test.dart';

import '../game_logic/test_helpers.dart';

/// Snapshots the current board as timeline seeds (id -> type/special/cell).
Map<int, SpriteSeed> _seeds(Board board) {
  final seeds = <int, SpriteSeed>{};
  for (final p in board.playablePositions()) {
    final t = board.tileAt(p);
    if (t != null) {
      seeds[t.id] =
          SpriteSeed(t.type, t.special, Offset(p.col.toDouble(), p.row.toDouble()));
    }
  }
  return seeds;
}

void main() {
  group('buildBoardTimeline (valid swap)', () {
    // Bottom-row horizontal 3-match so tiles above genuinely fall.
    Board makeBoard() => buildBoard([
          'GBYO',
          'BYGO',
          'OGYG',
          'RRBR',
        ]);

    test('produces sprites, a positive duration and cues', () {
      final engine = MatchEngine(random: Random(3), startId: 100000);
      final board = makeBoard();
      final seeds = _seeds(board);
      final result =
          engine.resolveSwap(board, const Position(3, 2), const Position(3, 3));
      expect(result.valid, isTrue);
      expect(result.phases.first.moves, isNotEmpty);

      final timeline =
          buildBoardTimeline(rows: 4, seeds: seeds, result: result);

      expect(timeline.totalMs, greaterThan(kSwapMs));
      expect(timeline.sprites, isNotEmpty);
      expect(
        timeline.cues.any((c) => c.kind == CueKind.swapSound),
        isTrue,
      );
      expect(
        timeline.cues.any((c) => c.kind == CueKind.burst),
        isTrue,
      );
    });

    test('a falling tile is strictly between its endpoints mid-slide', () {
      final engine = MatchEngine(random: Random(3), startId: 100000);
      final board = makeBoard();
      final seeds = _seeds(board);
      final result =
          engine.resolveSwap(board, const Position(3, 2), const Position(3, 3));

      final timeline =
          buildBoardTimeline(rows: 4, seeds: seeds, result: result);

      // Pick a real vertical move and its sprite.
      final move = result.phases
          .expand((p) => p.moves)
          .firstWhere((m) => m.to.row != m.from.row);
      final sprite = timeline.sprites[move.tileId]!;
      final fall = sprite.segs.firstWhere((s) => s.from.dy != s.to.dy);

      // Sample a quarter into the fall (before any easeOutBack overshoot).
      final ms = fall.startMs + (fall.endMs - fall.startMs) * 0.25;
      final sample = sprite.sampleAt(ms);

      final lo = min(fall.from.dy, fall.to.dy);
      final hi = max(fall.from.dy, fall.to.dy);
      expect(sample.cell.dy, greaterThan(lo),
          reason: 'tile snapped to start instead of animating');
      expect(sample.cell.dy, lessThan(hi),
          reason: 'tile snapped to end instead of animating');
      expect(sample.alive, isTrue);
    });

    test('endpoints are exact: hold at "from" before, settle at "to" after', () {
      final engine = MatchEngine(random: Random(3), startId: 100000);
      final board = makeBoard();
      final seeds = _seeds(board);
      final result =
          engine.resolveSwap(board, const Position(3, 2), const Position(3, 3));
      final timeline =
          buildBoardTimeline(rows: 4, seeds: seeds, result: result);

      final move = result.phases
          .expand((p) => p.moves)
          .firstWhere((m) => m.to.row != m.from.row);
      final sprite = timeline.sprites[move.tileId]!;
      final fall = sprite.segs.firstWhere((s) => s.from.dy != s.to.dy);

      final before = sprite.sampleAt(fall.startMs);
      final after = sprite.sampleAt(fall.endMs);
      expect(before.cell.dy, moreOrLessEquals(fall.from.dy, epsilon: 0.001));
      expect(after.cell.dy, moreOrLessEquals(fall.to.dy, epsilon: 0.001));
    });

    test('refills in a fully-cleared column start at distinct rows above the board',
        () {
      // Vertical 3-match empties an entire column -> 3 refills in one column.
      final engine = MatchEngine(random: Random(5), startId: 100000);
      final board = buildBoard(['RBRY', 'RYGB', 'GRBG']);
      final seeds = _seeds(board);
      final result =
          engine.resolveSwap(board, const Position(2, 0), const Position(2, 1));
      expect(result.valid, isTrue);

      // Within a single phase, a column's refills must not overlap.
      final spawns =
          result.phases.first.spawns.where((s) => s.at.col == 0).toList();
      expect(spawns.length, greaterThanOrEqualTo(2));

      final timeline =
          buildBoardTimeline(rows: 3, seeds: seeds, result: result);
      final startRows = [
        for (final s in spawns) timeline.sprites[s.tileId]!.segs.first.from.dy,
      ];
      // Distinct start rows (no overlap) and all above the top edge.
      expect(startRows.toSet().length, startRows.length,
          reason: 'refill tiles overlap at the same start row');
      for (final y in startRows) {
        expect(y, lessThan(0), reason: 'refill should enter from above');
      }
    });

    test('a cleared tile fades out (not alive) by the end', () {
      final engine = MatchEngine(random: Random(3), startId: 100000);
      final board = makeBoard();
      final seeds = _seeds(board);
      final result =
          engine.resolveSwap(board, const Position(3, 2), const Position(3, 3));
      final timeline =
          buildBoardTimeline(rows: 4, seeds: seeds, result: result);

      final clearedId = result.phases.first.clearedTiles.first.id;
      final sprite = timeline.sprites[clearedId]!;
      final end = sprite.segs.last.endMs;
      expect(sprite.sampleAt(end).alive, isFalse);
    });
  });

  group('buildShuffleTimeline', () {
    test('slides moved tiles to their new cells and holds the rest', () {
      final seeds = {
        1: const SpriteSeed(TileType.red, SpecialType.none, Offset(0, 0)),
        2: const SpriteSeed(TileType.blue, SpecialType.none, Offset(1, 0)),
      };
      final moves = [
        const TileMove(
            tileId: 1, from: Position(0, 0), to: Position(2, 3)), // -> (col3,row2)
      ];

      final tl = buildShuffleTimeline(rows: 8, seeds: seeds, moves: moves);
      expect(tl.totalMs, kShuffleMs);

      final moved = tl.sprites[1]!;
      expect(moved.sampleAt(0).cell, const Offset(0, 0));
      final end = moved.sampleAt(kShuffleMs);
      expect(end.cell.dx, moreOrLessEquals(3, epsilon: 0.01));
      expect(end.cell.dy, moreOrLessEquals(2, epsilon: 0.01));
      // Mid-slide it is strictly between the two cells (genuinely animating).
      final mid = moved.sampleAt(kShuffleMs / 2);
      expect(mid.cell.dx, greaterThan(0));
      expect(mid.cell.dx, lessThan(3));

      final held = tl.sprites[2]!;
      expect(held.sampleAt(kShuffleMs / 2).cell, const Offset(1, 0));
    });
  });

  group('buildBoardTimeline (invalid swap)', () {
    test('swap tiles animate out then return home', () {
      final engine = MatchEngine(random: Random(3), startId: 100000);
      final board = buildBoard(['RGR', 'GRG', 'RGR']);
      final seeds = _seeds(board);
      final result =
          engine.resolveSwap(board, const Position(0, 0), const Position(0, 1));
      expect(result.valid, isFalse);

      final timeline =
          buildBoardTimeline(rows: 3, seeds: seeds, result: result);
      expect(timeline.totalMs,
          moreOrLessEquals(kInvalidOutMs + kInvalidBackMs, epsilon: 0.001));

      // idA starts at (0,0); mid-animation it has moved toward (0,1); at the
      // end it returns home to (0,0).
      final a = timeline.sprites[result.swap.idA]!;
      final mid = a.sampleAt(kInvalidOutMs); // fully out
      expect(mid.cell.dx, moreOrLessEquals(1.0, epsilon: 0.05));
      final home = a.sampleAt(timeline.totalMs);
      expect(home.cell.dx, moreOrLessEquals(0.0, epsilon: 0.05));
    });
  });
}
