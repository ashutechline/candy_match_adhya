/// A cell coordinate on the board.
///
/// Immutable value type with structural equality so it can be used as a
/// `Set`/`Map` key. `row` grows downward, `col` grows to the right.
class Position {
  final int row;
  final int col;

  const Position(this.row, this.col);

  Position get up => Position(row - 1, col);
  Position get down => Position(row + 1, col);
  Position get left => Position(row, col - 1);
  Position get right => Position(row, col + 1);

  /// The four orthogonally-adjacent neighbours (no bounds checking).
  List<Position> get neighbours => [up, down, left, right];

  @override
  bool operator ==(Object other) =>
      other is Position && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => '($row,$col)';
}
