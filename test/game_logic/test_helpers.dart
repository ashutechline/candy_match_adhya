import 'package:candy_crush/game_logic/game_logic.dart';

/// Maps a single character to a [TileType] for readable board fixtures.
///  R O Y G B P = colours, I = ingredient, `.` = empty, `#` = blocked.
TileType? _charType(String ch) {
  switch (ch) {
    case 'R':
      return TileType.red;
    case 'O':
      return TileType.orange;
    case 'Y':
      return TileType.yellow;
    case 'G':
      return TileType.green;
    case 'B':
      return TileType.blue;
    case 'P':
      return TileType.purple;
    case 'I':
      return TileType.ingredient;
    default:
      return null; // '.' empty, '#' blocked
  }
}

/// Builds a [Board] from ASCII rows. Cells marked `#` become [blocked] holes;
/// `.` are empty. Tiles get sequential ids starting at 0.
Board buildBoard(List<String> rows) {
  final height = rows.length;
  final width = rows.first.length;
  final blocked = <Position>{};
  for (var r = 0; r < height; r++) {
    for (var c = 0; c < width; c++) {
      if (rows[r][c] == '#') blocked.add(Position(r, c));
    }
  }
  final board = Board.empty(height, width, blocked: blocked);
  var id = 0;
  for (var r = 0; r < height; r++) {
    for (var c = 0; c < width; c++) {
      final type = _charType(rows[r][c]);
      if (type != null) {
        board.setTile(Position(r, c), Tile(id: id++, type: type));
      }
    }
  }
  return board;
}
