import 'package:candy_crush/game_logic/game_logic.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('detectMatches', () {
    test('finds a horizontal run of 3', () {
      final board = buildBoard([
        'RRRGB',
        'GBGBG',
        'BGBGB',
      ]);
      final matches = detectMatches(board);
      expect(matches, hasLength(1));
      expect(matches.first.type, TileType.red);
      expect(matches.first.cells, {
        const Position(0, 0),
        const Position(0, 1),
        const Position(0, 2),
      });
      expect(matches.first.hasHorizontal, isTrue);
      expect(matches.first.hasVertical, isFalse);
    });

    test('finds a vertical run of 3', () {
      final board = buildBoard([
        'RGB',
        'RBG',
        'RGB',
      ]);
      final matches = detectMatches(board);
      expect(matches, hasLength(1));
      expect(matches.first.type, TileType.red);
      expect(matches.first.longestRun, 3);
      expect(matches.first.hasVertical, isTrue);
    });

    test('merges an L shape into one intersection match', () {
      final board = buildBoard([
        'RGB',
        'RGB',
        'RRR',
      ]);
      final matches = detectMatches(board);
      expect(matches, hasLength(1));
      final m = matches.first;
      expect(m.isIntersection, isTrue);
      expect(m.cells, hasLength(5)); // 3 vertical + 3 horizontal - 1 shared
    });

    test('a run of 4 reports longestRun 4', () {
      final board = buildBoard([
        'RRRRB',
        'GBGBG',
        'BGBGB',
      ]);
      final matches = detectMatches(board);
      expect(matches, hasLength(1));
      expect(matches.first.longestRun, 4);
    });

    test('a straight run of 5 reports longestRun 5', () {
      final board = buildBoard([
        'RRRRR',
        'GBGBG',
        'BGBGB',
      ]);
      final matches = detectMatches(board);
      expect(matches.single.longestRun, 5);
    });

    test('ingredients never match', () {
      final board = buildBoard([
        'III',
        'GBG',
        'BGB',
      ]);
      expect(detectMatches(board), isEmpty);
    });

    test('a blocked cell breaks a run', () {
      final board = buildBoard([
        'RR#RR',
        'GBGBG',
        'BGBGB',
      ]);
      expect(detectMatches(board), isEmpty);
    });

    test('an empty cell breaks a run', () {
      final board = buildBoard([
        'RR.RR',
        'GBGBG',
        'BGBGB',
      ]);
      expect(detectMatches(board), isEmpty);
    });

    test('two disjoint runs are two matches', () {
      final board = buildBoard([
        'RRRGG',
        'BGBGB',
        'GGGBB',
      ]);
      final matches = detectMatches(board);
      expect(matches, hasLength(2));
    });

    test('hasAnyMatch agrees with detectMatches', () {
      final matchy = buildBoard(['RRR', 'GBG', 'BGB']);
      final clean = buildBoard(['RGB', 'GBG', 'BGB']);
      expect(hasAnyMatch(matchy), isTrue);
      expect(hasAnyMatch(clean), isFalse);
    });
  });
}
