import 'position.dart';
import 'tile.dart';

/// A single straight run of 3+ identical tiles found by the detector.
class Run {
  final TileType type;

  /// True for a left-to-right run, false for a top-to-bottom run.
  final bool horizontal;

  /// Cells in reading order (left->right or top->bottom).
  final List<Position> cells;

  const Run({
    required this.type,
    required this.horizontal,
    required this.cells,
  });

  int get length => cells.length;

  @override
  String toString() =>
      'Run(${type.name}, ${horizontal ? 'H' : 'V'}, ${cells.length})';
}

/// A connected group of matched cells of the same [type].
///
/// One or more [runs] that share cells are merged into a single match so the
/// special-generation rules can inspect the overall shape (a horizontal run
/// plus an intersecting vertical run = a T/L shape).
class Match {
  final TileType type;
  final List<Run> runs;

  Match({required this.type, required this.runs});

  /// All distinct cells across every run in the group.
  Set<Position> get cells => {for (final r in runs) ...r.cells};

  bool get hasHorizontal => runs.any((r) => r.horizontal);
  bool get hasVertical => runs.any((r) => !r.horizontal);

  /// A group with both a horizontal and a vertical run is a T/L shape.
  bool get isIntersection => hasHorizontal && hasVertical;

  int get longestRun =>
      runs.fold(0, (m, r) => r.length > m ? r.length : m);

  int get size => cells.length;

  @override
  String toString() => 'Match(${type.name}, ${cells.length} cells)';
}
