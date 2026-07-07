import 'dart:math';

import 'package:candy_crush/game_logic/game_logic.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// High startId so engine refill ids never collide with buildBoard ids.
MatchEngine _engine() => MatchEngine(random: Random(1), startId: 100000);

void main() {
  group('applyLollipop', () {
    test('smashes a normal tile and settles the board', () {
      final engine = _engine();
      final board = buildBoard(['RGBY', 'GBYR', 'BYRG']);
      final target = const Position(1, 1);
      final targetId = board.tileAt(target)!.id;

      final result = engine.applyLollipop(board, target);

      expect(result.valid, isTrue);
      expect(result.board.isFull, isTrue);
      expect(hasAnyMatch(result.board), isFalse);
      expect(result.allClearedTiles.any((t) => t.id == targetId), isTrue);
      // Never mutates the input.
      expect(board.tileAt(target)!.id, targetId);
    });

    test('detonates a special it lands on (striped clears the row)', () {
      final engine = _engine();
      final board = buildBoard(['RGBYP', 'GBYRG', 'BYRGB']);
      board.tileAt(const Position(1, 1))!.special = SpecialType.stripedRow;

      final result = engine.applyLollipop(board, const Position(1, 1));
      expect(result.valid, isTrue);
      for (var c = 0; c < 5; c++) {
        expect(result.phases.first.cleared, contains(Position(1, c)));
      }
    });
  });

  group('applyClearColor', () {
    test('clears every tile of the colour', () {
      final engine = _engine();
      final board = buildBoard(['RGRGB', 'GRBYG', 'BGRGR']);
      final reds = [
        const Position(0, 0),
        const Position(0, 2),
        const Position(1, 1),
        const Position(2, 2),
        const Position(2, 4),
      ];

      final result = engine.applyClearColor(board, TileType.red);
      expect(result.valid, isTrue);
      expect(result.phases.first.cleared, containsAll(reds));
      expect(result.board.isFull, isTrue);
      expect(hasAnyMatch(result.board), isFalse);
    });

    test('is invalid when no tile of the colour exists', () {
      final engine = _engine();
      final board = buildBoard(['GBGB', 'BGBG', 'GBGB']);
      final result = engine.applyClearColor(board, TileType.red);
      expect(result.valid, isFalse);
      expect(result.phases, isEmpty);
    });
  });
}
