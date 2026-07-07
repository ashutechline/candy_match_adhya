/// The colour/identity of a tile.
///
/// [ingredient] is a non-matching payload tile (e.g. a cherry that must be
/// routed to the bottom row); it falls with gravity but never participates in
/// a colour match.
enum TileType {
  red,
  orange,
  yellow,
  green,
  blue,
  purple,
  ingredient;

  /// Ingredients (and any future inert tiles) never form colour matches.
  bool get isMatchable => this != TileType.ingredient;
}

/// The six matchable colours, in a stable order. The default board palette.
const List<TileType> kDefaultPalette = [
  TileType.red,
  TileType.orange,
  TileType.yellow,
  TileType.green,
  TileType.blue,
  TileType.purple,
];

/// A special-candy upgrade layered on top of a tile's colour.
///
/// A special candy keeps its underlying [TileType] (so a striped red still
/// matches with reds) but gains a detonation effect. Orientation is named by
/// the *line it clears* to avoid the classic "which way do the stripes point?"
/// ambiguity:
///   * [stripedRow]    — created by a horizontal match of 4; clears its row.
///   * [stripedColumn] — created by a vertical match of 4; clears its column.
///   * [wrapped]       — created by a T/L match of 5; clears the 3x3 around it.
///   * [colorBomb]     — created by a straight match of 5+; clears one colour.
///
/// (The horizontal-match -> row-clear mapping is a documented convention, not a
/// physical law; flip [specialForMatch] if you prefer King's exact behaviour.)
enum SpecialType {
  none,
  stripedRow,
  stripedColumn,
  wrapped,
  colorBomb;

  bool get isSpecial => this != SpecialType.none;
  bool get isStriped => this == stripedRow || this == stripedColumn;
}

/// A single candy on the board.
///
/// Mutable by design: the resolver rewrites [type]/[special] in place during a
/// cascade for performance. The [id] is stable for the tile's lifetime so an
/// animation layer can track a candy's *identity* as it slides between cells
/// (see [TileMove]) instead of teleporting.
class Tile {
  final int id;
  TileType type;
  SpecialType special;

  Tile({
    required this.id,
    required this.type,
    this.special = SpecialType.none,
  });

  bool get isMatchable => type.isMatchable;
  bool get isSpecial => special.isSpecial;

  Tile clone() => Tile(id: id, type: type, special: special);

  @override
  String toString() =>
      'Tile#$id(${type.name}${special.isSpecial ? ',${special.name}' : ''})';
}
