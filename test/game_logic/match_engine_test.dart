import 'dart:math';

import 'package:candy_crush/game_logic/game_logic.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

/// A fixed-seed engine so generation/refill/shuffle are reproducible.
MatchEngine seededEngine([int seed = 42]) =>
    MatchEngine(random: Random(seed), startId: 100000);

void main() {
  group('generateBoard', () {
    test('produces a full board with no matches and a valid move', () {
      final engine = seededEngine();
      final board = engine.generateBoard(8, 8);
      expect(board.isFull, isTrue);
      expect(hasAnyMatch(board), isFalse);
      expect(engine.hasAnyMove(board), isTrue);
    });

    test('is deterministic for a given seed', () {
      final a = MatchEngine(random: Random(7)).generateBoard(8, 8);
      final b = MatchEngine(random: Random(7)).generateBoard(8, 8);
      expect(a.render(), b.render());
    });

    test('fills around blocked holes', () {
      final engine = seededEngine();
      final blocked = {const Position(0, 0), const Position(4, 4)};
      final board = engine.generateBoard(8, 8, blocked: blocked);
      expect(board.tileAt(const Position(0, 0)), isNull);
      expect(board.isFull, isTrue); // isFull ignores blocked holes
      expect(hasAnyMatch(board), isFalse);
    });
  });

  group('resolveSwap validity', () {
    test('a non-matching swap is invalid and leaves the board untouched', () {
      final engine = seededEngine();
      final board = buildBoard(['RGR', 'GRG', 'RGR']);
      final result = engine.resolveSwap(board, const Position(0, 0), const Position(0, 1));
      expect(result.valid, isFalse);
      expect(result.phases, isEmpty);
      expect(result.swap.reverted, isTrue);
      expect(identical(result.board, board), isTrue);
    });

    test('a non-adjacent swap is invalid', () {
      final engine = seededEngine();
      final board = buildBoard(['RGR', 'GRG', 'RGR']);
      final result = engine.resolveSwap(board, const Position(0, 0), const Position(2, 2));
      expect(result.valid, isFalse);
    });
  });

  group('resolveSwap clearing & scoring', () {
    test('a simple 3-match clears three tiles and scores level 1', () {
      final engine = seededEngine();
      final board = buildBoard([
        'RBRY',
        'RYGB',
        'GRBG',
      ]);
      final result = engine.resolveSwap(board, const Position(2, 0), const Position(2, 1));
      expect(result.valid, isTrue);
      final first = result.phases.first;
      expect(first.cleared, {
        const Position(0, 0),
        const Position(1, 0),
        const Position(2, 0),
      });
      expect(first.created, isEmpty);
      expect(first.score, 3 * 60 * 1);
      // Board is always settled and full afterwards.
      expect(hasAnyMatch(result.board), isFalse);
      expect(result.board.isFull, isTrue);
    });

    test('a 4-match spawns a striped candy at the swapped cell', () {
      final engine = seededEngine();
      final board = buildBoard([
        'RRBRG',
        'GYRYB',
        'BGYGR',
        'YBGBY',
      ]);
      final result = engine.resolveSwap(board, const Position(0, 2), const Position(1, 2));
      expect(result.valid, isTrue);
      final created = result.phases.first.created;
      expect(created, hasLength(1));
      expect(created.single.type, SpecialType.stripedRow);
      expect(created.single.at, const Position(0, 2));
    });

    test('a 5-match spawns a color bomb', () {
      final engine = seededEngine();
      final board = buildBoard([
        'RRBRR',
        'GYRYG',
        'BGYGB',
        'YBGBY',
      ]);
      final result = engine.resolveSwap(board, const Position(0, 2), const Position(1, 2));
      final created = result.phases.first.created;
      expect(created, hasLength(1));
      expect(created.single.type, SpecialType.colorBomb);
    });

    test('a T/L match spawns a wrapped candy at the corner', () {
      final engine = seededEngine();
      final board = buildBoard([
        'RBGY',
        'RBGO',
        'BRRY',
        'RGYG',
      ]);
      final result = engine.resolveSwap(board, const Position(2, 0), const Position(3, 0));
      final created = result.phases.first.created;
      expect(created, hasLength(1));
      expect(created.single.type, SpecialType.wrapped);
      expect(created.single.at, const Position(2, 0));
    });
  });

  group('special activation', () {
    test('swapping a lone striped detonates it (row clear)', () {
      final engine = seededEngine();
      final board = buildBoard([
        'RGYBP',
        'GRYGB',
        'BGRBG',
      ]);
      board.tileAt(const Position(0, 0))!.special = SpecialType.stripedRow;

      final result = engine.resolveSwap(board, const Position(0, 0), const Position(0, 1));
      expect(result.valid, isTrue);
      final first = result.phases.first;
      expect(first.activations, hasLength(1));
      expect(first.activations.single.type, SpecialType.stripedRow);
      // The entire top row is cleared.
      for (var c = 0; c < 5; c++) {
        expect(first.cleared, contains(Position(0, c)));
      }
    });

    test('color bomb + normal clears every tile of that colour', () {
      final engine = seededEngine();
      final board = buildBoard([
        'RGRGB',
        'RPBYG',
        'BGRGR',
      ]);
      board.tileAt(const Position(1, 1))!.special = SpecialType.colorBomb;

      final result = engine.resolveSwap(board, const Position(1, 0), const Position(1, 1));
      expect(result.valid, isTrue);
      final first = result.phases.first;
      expect(first.activations.single.type, SpecialType.colorBomb);
      expect(first.activations.single.targetColor, TileType.red);
      // Post-swap the red tiles sit at these cells, plus the bomb's cell (1,0).
      expect(first.cleared, containsAll(<Position>[
        const Position(0, 0),
        const Position(0, 2),
        const Position(1, 1),
        const Position(2, 2),
        const Position(2, 4),
        const Position(1, 0),
      ]));
    });

    test('striped + striped combo clears a full row-and-column cross', () {
      final engine = seededEngine();
      final board = buildBoard([
        'RGBYP',
        'OGBRO',
        'YBRGP',
      ]);
      board.tileAt(const Position(1, 1))!.special = SpecialType.stripedRow;
      board.tileAt(const Position(1, 2))!.special = SpecialType.stripedColumn;

      final result = engine.resolveSwap(board, const Position(1, 1), const Position(1, 2));
      expect(result.valid, isTrue);
      final cleared = result.phases.first.cleared;
      // Full row 1 ...
      for (var c = 0; c < 5; c++) {
        expect(cleared, contains(Position(1, c)));
      }
      // ... and full column 1.
      for (var r = 0; r < 3; r++) {
        expect(cleared, contains(Position(r, 1)));
      }
    });
  });

  group('gravity', () {
    test('tiles do not fall through a blocked cell', () {
      final engine = seededEngine();
      final board = buildBoard([
        'RGB',
        'RGB',
        'R#B',
        'RGB',
      ]);
      final top = board.tileAt(const Position(0, 1))!;
      // Empty the cell above the wall and the cell below it.
      board.setTile(const Position(1, 1), null);
      board.setTile(const Position(3, 1), null);

      final moves = engine.collapse(board);

      // The top tile slides down only to just above the wall, never past it.
      expect(board.tileAt(const Position(1, 1))?.id, top.id);
      expect(board.tileAt(const Position(0, 1)), isNull);
      expect(board.tileAt(const Position(3, 1)), isNull);
      expect(
        moves.any((m) =>
            m.tileId == top.id &&
            m.from == const Position(0, 1) &&
            m.to == const Position(1, 1)),
        isTrue,
      );
    });
  });

  group('dead boards & shuffle', () {
    test('a single row of distinct colours has no moves', () {
      final engine = seededEngine();
      final board = buildBoard(['RGBOY']);
      expect(engine.hasAnyMove(board), isFalse);
    });

    test('shuffle preserves the tile multiset and yields a live board', () {
      final engine = seededEngine();
      final board = engine.generateBoard(8, 8);
      final before = _idMultiset(board);

      final result = engine.shuffle(board);
      expect(result.failed, isFalse);
      expect(hasAnyMatch(result.board), isFalse);
      expect(engine.hasAnyMove(result.board), isTrue);
      expect(_idMultiset(result.board), before);
    });

    test('shuffle reports failure when no live arrangement exists', () {
      final engine = seededEngine();
      // One row of distinct colours can never host a 3-match.
      final result = engine.shuffle(buildBoard(['RGBOY']));
      expect(result.failed, isTrue);
    });
  });

  group('invariants (fuzz)', () {
    test('every valid swap leaves a full, settled board', () {
      for (final seed in [1, 2, 3, 7, 13, 99]) {
        final engine = MatchEngine(random: Random(seed), startId: seed * 1000);
        var board = engine.generateBoard(8, 8);

        var movesApplied = 0;
        var guard = 0;
        while (movesApplied < 12 && guard < 400) {
          guard++;
          final swap = _firstValidSwap(engine, board);
          if (swap == null) break;
          final result = engine.resolveSwap(board, swap.$1, swap.$2);
          expect(result.valid, isTrue);
          expect(result.board.isFull, isTrue,
              reason: 'seed $seed left a gap');
          expect(hasAnyMatch(result.board), isFalse,
              reason: 'seed $seed left an unresolved match');
          expect(result.score, greaterThanOrEqualTo(0));
          board = result.board;
          movesApplied++;
        }
        expect(movesApplied, greaterThan(0), reason: 'seed $seed made no move');
      }
    });
  });
}

Map<int, int> _idMultiset(Board board) {
  final counts = <int, int>{};
  for (final p in board.playablePositions()) {
    final tile = board.tileAt(p);
    if (tile != null) counts[tile.id] = (counts[tile.id] ?? 0) + 1;
  }
  return counts;
}

/// Finds the first adjacent pair whose swap is valid (scanning right/down).
(Position, Position)? _firstValidSwap(MatchEngine engine, Board board) {
  for (final p in board.playablePositions()) {
    for (final q in [p.right, p.down]) {
      if (!board.isPlayable(q)) continue;
      if (engine.resolveSwap(board, p, q).valid) return (p, q);
    }
  }
  return null;
}
