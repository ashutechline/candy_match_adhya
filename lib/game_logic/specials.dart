import 'models/board.dart';
import 'models/match.dart';
import 'models/position.dart';
import 'models/tile.dart';

/// Which special candy (if any) a completed [match] should spawn, from its
/// shape. Priority: T/L intersection -> color bomb (5+ straight) -> striped (4).
///
/// Convention: a horizontal 4-run makes a [SpecialType.stripedRow] (clears the
/// row); a vertical 4-run makes a [SpecialType.stripedColumn] (clears the
/// column). See [SpecialType] for the rationale.
SpecialType? specialForMatch(Match match) {
  if (match.hasHorizontal && match.hasVertical) return SpecialType.wrapped;
  if (match.longestRun >= 5) return SpecialType.colorBomb;
  if (match.longestRun == 4) {
    final run4 = match.runs.firstWhere((r) => r.length >= 4);
    return run4.horizontal ? SpecialType.stripedRow : SpecialType.stripedColumn;
  }
  return null;
}

/// Where a spawned special should appear.
///
/// Prefers the cell the player actually swapped (feels intentional); otherwise
/// the intersection cell for a T/L, else the middle of the longest run.
Position pivotFor(Match match, Set<Position> swapped) {
  for (final cell in match.cells) {
    if (swapped.contains(cell)) return cell;
  }
  if (match.hasHorizontal && match.hasVertical) {
    final horizontalCells = <Position>{
      for (final r in match.runs)
        if (r.horizontal) ...r.cells,
    };
    for (final r in match.runs) {
      if (!r.horizontal) {
        for (final cell in r.cells) {
          if (horizontalCells.contains(cell)) return cell;
        }
      }
    }
  }
  final longest =
      match.runs.reduce((a, b) => a.length >= b.length ? a : b);
  return longest.cells[longest.length ~/ 2];
}

/// All playable cells in a row.
Set<Position> rowCells(Board board, int row) => {
      for (var c = 0; c < board.cols; c++)
        if (board.isPlayable(Position(row, c))) Position(row, c),
    };

/// All playable cells in a column.
Set<Position> colCells(Board board, int col) => {
      for (var r = 0; r < board.rows; r++)
        if (board.isPlayable(Position(r, col))) Position(r, col),
    };

/// All playable cells within Chebyshev [radius] of [center] (a square blast).
Set<Position> squareCells(Board board, Position center, int radius) => {
      for (var r = center.row - radius; r <= center.row + radius; r++)
        for (var c = center.col - radius; c <= center.col + radius; c++)
          if (board.isPlayable(Position(r, c))) Position(r, c),
    };

/// All playable cells holding a tile of [color].
Set<Position> colorCells(Board board, TileType color) => {
      for (final p in board.playablePositions())
        if (board.tileAt(p)?.type == color) p,
    };

/// The most common matchable colour currently on the board (ties broken by
/// enum order). Used when a color bomb is detonated by a blast rather than a
/// deliberate swap, so the target colour stays deterministic.
TileType dominantColor(Board board) {
  final counts = <TileType, int>{};
  for (final p in board.playablePositions()) {
    final tile = board.tileAt(p);
    if (tile != null && tile.isMatchable) {
      counts[tile.type] = (counts[tile.type] ?? 0) + 1;
    }
  }
  TileType best = TileType.values.firstWhere((t) => t.isMatchable);
  var bestCount = -1;
  for (final type in TileType.values) {
    final count = counts[type] ?? 0;
    if (count > bestCount) {
      bestCount = count;
      best = type;
    }
  }
  return best;
}

/// The cells cleared when a lone special detonates at [at].
Set<Position> specialBlastCells(
  Board board,
  Position at,
  SpecialType type,
  TileType bombColor,
) {
  switch (type) {
    case SpecialType.stripedRow:
      return rowCells(board, at.row);
    case SpecialType.stripedColumn:
      return colCells(board, at.col);
    case SpecialType.wrapped:
      return squareCells(board, at, 1);
    case SpecialType.colorBomb:
      return colorCells(board, bombColor)..add(at);
    case SpecialType.none:
      return {};
  }
}

/// The cells cleared when two special candies are swapped together (the combo
/// matrix), centred on [at]. [color1]/[color2] are the underlying colours,
/// needed for color-bomb combos.
Set<Position> comboBlastCells(
  Board board,
  SpecialType s1,
  SpecialType s2,
  TileType color1,
  TileType color2,
  Position at,
) {
  final bombs = [s1, s2].where((s) => s == SpecialType.colorBomb).length;

  // Color bomb + color bomb: clear the entire board.
  if (bombs == 2) {
    return board.playablePositions().toSet();
  }

  // Color bomb + (striped or wrapped): convert every tile of the partner's
  // colour into that special, then detonate them all.
  if (bombs == 1) {
    final otherType = s1 == SpecialType.colorBomb ? s2 : s1;
    final otherColor = s1 == SpecialType.colorBomb ? color2 : color1;
    final targets = colorCells(board, otherColor);
    final cells = <Position>{at, ...targets};
    if (otherType.isStriped) {
      for (final p in targets) {
        cells.addAll(rowCells(board, p.row));
        cells.addAll(colCells(board, p.col));
      }
    } else if (otherType == SpecialType.wrapped) {
      for (final p in targets) {
        cells.addAll(squareCells(board, p, 1));
      }
    }
    return cells;
  }

  // No color bombs: striped/wrapped combinations.
  final wrappeds = [s1, s2].where((s) => s == SpecialType.wrapped).length;
  final stripeds = [s1, s2].where((s) => s.isStriped).length;

  // Striped + striped: a full row-and-column cross through the swap cell.
  if (stripeds == 2) {
    return {...rowCells(board, at.row), ...colCells(board, at.col)};
  }

  // Wrapped + wrapped: a large 5x5 blast.
  if (wrappeds == 2) {
    return squareCells(board, at, 2);
  }

  // Striped + wrapped: three full rows and three full columns.
  final cells = <Position>{};
  for (var r = at.row - 1; r <= at.row + 1; r++) {
    cells.addAll(rowCells(board, r));
  }
  for (var c = at.col - 1; c <= at.col + 1; c++) {
    cells.addAll(colCells(board, c));
  }
  return cells;
}
