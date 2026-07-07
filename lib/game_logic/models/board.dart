import 'position.dart';
import 'tile.dart';

/// The live, mutable board used during resolution.
///
/// `grid[row][col] == null` means an empty cell mid-cascade. Cells listed in
/// [blocked] are permanent holes/walls that never hold a tile and act as
/// separators for gravity.
class Board {
  final int rows;
  final int cols;
  final List<List<Tile?>> _grid;
  final Set<Position> blocked;

  Board._(this.rows, this.cols, this._grid, this.blocked);

  factory Board.empty(
    int rows,
    int cols, {
    Set<Position> blocked = const {},
  }) {
    final grid = List.generate(rows, (_) => List<Tile?>.filled(cols, null));
    return Board._(rows, cols, grid, Set.unmodifiable(blocked));
  }

  bool inBounds(Position p) =>
      p.row >= 0 && p.row < rows && p.col >= 0 && p.col < cols;

  bool isBlocked(Position p) => blocked.contains(p);

  /// In bounds and not a permanent hole. Blocked cells are never playable.
  bool isPlayable(Position p) => inBounds(p) && !isBlocked(p);

  Tile? tileAt(Position p) => inBounds(p) ? _grid[p.row][p.col] : null;

  void setTile(Position p, Tile? tile) {
    assert(inBounds(p), 'setTile out of bounds: $p');
    _grid[p.row][p.col] = tile;
  }

  /// Every playable cell, in row-major order.
  Iterable<Position> playablePositions() sync* {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final p = Position(r, c);
        if (!isBlocked(p)) yield p;
      }
    }
  }

  /// The current location of the tile with the given [id], or null.
  Position? positionOfTileId(int id) {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (_grid[r][c]?.id == id) return Position(r, c);
      }
    }
    return null;
  }

  /// True when every playable cell holds a tile (no gaps mid-cascade).
  bool get isFull =>
      playablePositions().every((p) => _grid[p.row][p.col] != null);

  Board clone() {
    final grid = List.generate(
      rows,
      (r) => List<Tile?>.generate(cols, (c) => _grid[r][c]?.clone()),
    );
    return Board._(rows, cols, grid, blocked);
  }

  /// Compact debug rendering: colour initial for tiles, `.` empty, `#` blocked.
  /// Special candies are shown lower-case.
  String render() {
    final buffer = StringBuffer();
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final p = Position(r, c);
        if (isBlocked(p)) {
          buffer.write('#');
          continue;
        }
        final tile = _grid[r][c];
        if (tile == null) {
          buffer.write('.');
          continue;
        }
        final ch = tile.type.name[0].toUpperCase();
        buffer.write(tile.isSpecial ? ch.toLowerCase() : ch);
      }
      if (r != rows - 1) buffer.write('\n');
    }
    return buffer.toString();
  }
}
