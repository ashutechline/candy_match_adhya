import 'package:candy_crush/game_logic/game_logic.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('specialForMatch', () {
    test('3-run makes no special', () {
      final m = detectMatches(buildBoard(['RRR', 'GBG', 'BGB'])).single;
      expect(specialForMatch(m), isNull);
    });

    test('horizontal 4-run makes a row-clearing striped', () {
      final m = detectMatches(buildBoard(['RRRR', 'GBGB', 'BGBG'])).single;
      expect(specialForMatch(m), SpecialType.stripedRow);
    });

    test('vertical 4-run makes a column-clearing striped', () {
      final m = detectMatches(buildBoard([
        'RGB',
        'RGB',
        'RBG',
        'RGB',
      ])).single;
      expect(specialForMatch(m), SpecialType.stripedColumn);
    });

    test('straight 5-run makes a color bomb', () {
      final m = detectMatches(buildBoard(['RRRRR', 'GBGBG', 'BGBGB'])).single;
      expect(specialForMatch(m), SpecialType.colorBomb);
    });

    test('T/L intersection makes a wrapped', () {
      final m = detectMatches(buildBoard(['RGB', 'RGB', 'RRR'])).single;
      expect(specialForMatch(m), SpecialType.wrapped);
    });
  });

  group('blast helpers', () {
    final board = buildBoard([
      'RGBYP',
      'GRBYG',
      'BGRYB',
    ]);

    test('rowCells / colCells span playable cells only', () {
      expect(rowCells(board, 0), hasLength(5));
      expect(colCells(board, 2), hasLength(3));
    });

    test('squareCells is a Chebyshev radius clipped to the board', () {
      // radius 1 around a corner -> 2x2 = 4 cells.
      expect(squareCells(board, const Position(0, 0), 1), hasLength(4));
      // radius 1 around an interior cell -> 3x3 = 9 cells.
      expect(squareCells(board, const Position(1, 2), 1), hasLength(9));
    });

    test('colorCells finds all tiles of a colour', () {
      // column 3 is all Y plus none elsewhere.
      expect(colorCells(board, TileType.yellow), hasLength(3));
    });

    test('squareCells skips blocked holes', () {
      final holed = buildBoard(['RGB', 'G#B', 'BGR']);
      expect(
        squareCells(holed, const Position(1, 1), 1),
        isNot(contains(const Position(1, 1))),
      );
      expect(squareCells(holed, const Position(1, 1), 1), hasLength(8));
    });
  });

  group('dominantColor', () {
    test('returns the most frequent matchable colour', () {
      final board = buildBoard([
        'RRR',
        'RRG',
        'BGP',
      ]);
      expect(dominantColor(board), TileType.red);
    });
  });
}
