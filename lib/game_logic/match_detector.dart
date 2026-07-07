import 'models/board.dart';
import 'models/match.dart';
import 'models/position.dart';

/// Scans the whole [board] for all runs of 3+ identical matchable tiles and
/// merges intersecting runs into connected [Match] groups.
///
/// Two linear passes (rows, then columns) find straight runs; a union-find
/// then groups any runs that share a cell so a T/L shape surfaces as a single
/// match with both a horizontal and a vertical run.
List<Match> detectMatches(Board board) {
  final runs = <Run>[
    ..._scanRuns(board, horizontal: true),
    ..._scanRuns(board, horizontal: false),
  ];
  if (runs.isEmpty) return const [];

  // Union-find over run indices; two runs merge when they share any cell.
  final parent = List<int>.generate(runs.length, (i) => i);
  int find(int x) {
    while (parent[x] != x) {
      parent[x] = parent[parent[x]];
      x = parent[x];
    }
    return x;
  }

  void union(int a, int b) {
    final ra = find(a);
    final rb = find(b);
    if (ra != rb) parent[ra] = rb;
  }

  final cellToRun = <Position, int>{};
  for (var i = 0; i < runs.length; i++) {
    for (final cell in runs[i].cells) {
      final existing = cellToRun[cell];
      if (existing != null) {
        union(existing, i);
      } else {
        cellToRun[cell] = i;
      }
    }
  }

  final groups = <int, List<Run>>{};
  for (var i = 0; i < runs.length; i++) {
    groups.putIfAbsent(find(i), () => []).add(runs[i]);
  }

  return [
    for (final group in groups.values)
      Match(type: group.first.type, runs: group),
  ];
}

/// True if the board currently contains at least one match. Cheaper than
/// [detectMatches] when you only need a yes/no.
bool hasAnyMatch(Board board) =>
    _scanRuns(board, horizontal: true).isNotEmpty ||
    _scanRuns(board, horizontal: false).isNotEmpty;

/// True if a straight run of 3+ passes through [p] (used by the move finder
/// after a trial swap, so only the two touched cells need checking).
bool hasMatchThrough(Board board, Position p) {
  final tile = board.tileAt(p);
  if (tile == null || !tile.isMatchable) return false;
  final type = tile.type;

  int runLength(Position step1, Position step2) {
    var count = 1;
    for (final step in [step1, step2]) {
      var cur = Position(p.row + step.row, p.col + step.col);
      while (true) {
        final t = board.tileAt(cur);
        if (t == null || !t.isMatchable || t.type != type) break;
        count++;
        cur = Position(cur.row + step.row, cur.col + step.col);
      }
    }
    return count;
  }

  // Position is reused here purely as an (dRow, dCol) delta.
  final horizontal =
      runLength(const Position(0, -1), const Position(0, 1));
  if (horizontal >= 3) return true;
  final vertical = runLength(const Position(-1, 0), const Position(1, 0));
  return vertical >= 3;
}

/// Finds every straight run of length >= 3 along rows (or columns).
List<Run> _scanRuns(Board board, {required bool horizontal}) {
  final runs = <Run>[];
  final outer = horizontal ? board.rows : board.cols;
  final inner = horizontal ? board.cols : board.rows;

  Position at(int o, int i) => horizontal ? Position(o, i) : Position(i, o);

  for (var o = 0; o < outer; o++) {
    var i = 0;
    while (i < inner) {
      final tile = board.tileAt(at(o, i));
      if (tile == null || !tile.isMatchable) {
        i++;
        continue;
      }
      final type = tile.type;
      var end = i + 1;
      while (end < inner) {
        final t = board.tileAt(at(o, end));
        if (t == null || !t.isMatchable || t.type != type) break;
        end++;
      }
      if (end - i >= 3) {
        runs.add(Run(
          type: type,
          horizontal: horizontal,
          cells: [for (var k = i; k < end; k++) at(o, k)],
        ));
      }
      i = end;
    }
  }
  return runs;
}
