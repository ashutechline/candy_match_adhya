import 'dart:math';

import 'match_detector.dart';
import 'models/board.dart';
import 'models/match.dart';
import 'models/position.dart';
import 'models/steps.dart';
import 'models/tile.dart';
import 'scoring.dart';
import 'specials.dart';

/// Result of a board shuffle (used when no moves remain).
class ShuffleResult {
  final Board board;
  final List<TileMove> moves;

  /// True when no valid, match-free arrangement could be found.
  final bool failed;

  const ShuffleResult({
    required this.board,
    required this.moves,
    this.failed = false,
  });
}

/// A queued special detonation carried through phase 1 from the swap itself.
class _Trigger {
  final Set<Position> cells;
  final Set<Position> origins;
  final SpecialActivation activation;

  const _Trigger({
    required this.cells,
    required this.origins,
    required this.activation,
  });
}

/// Everything a single clear step produces (before gravity/refill).
class _ClearResult {
  final List<Match> matches;
  final List<SpecialCreation> created;
  final List<SpecialActivation> activations;
  final Set<Position> cleared;
  final int score;

  const _ClearResult({
    required this.matches,
    required this.created,
    required this.activations,
    required this.cleared,
    required this.score,
  });
}

/// The pure match-3 rules engine.
///
/// Owns the RNG and the tile-id counter so board generation, refills and
/// shuffles are all deterministic for a given seed — no Flutter or Flame
/// imports anywhere in this layer. Feed it a [Board] and a swap; it returns a
/// settled board plus an ordered list of [CascadePhase]s for a renderer to
/// play back.
class MatchEngine {
  final Random random;
  final List<TileType> palette;
  final ScoreConfig scoreConfig;
  late final Scorer _scorer = Scorer(scoreConfig);

  int _nextId;

  MatchEngine({
    Random? random,
    List<TileType>? palette,
    this.scoreConfig = const ScoreConfig(),
    int startId = 0,
  })  : random = random ?? Random(),
        palette = palette ?? kDefaultPalette,
        _nextId = startId;

  int _id() => _nextId++;

  TileType _randomType() => palette[random.nextInt(palette.length)];

  // ---------------------------------------------------------------------------
  // Board generation
  // ---------------------------------------------------------------------------

  /// Generates a full board with no pre-existing matches and at least one valid
  /// move. Uses the greedy exclusion rule (never repeat the two cells to the
  /// left or above), then verifies playability; retries on the rare failure.
  Board generateBoard(
    int rows,
    int cols, {
    Set<Position> blocked = const {},
  }) {
    Board? last;
    for (var attempt = 0; attempt < 200; attempt++) {
      final board = Board.empty(rows, cols, blocked: blocked);
      for (final p in board.playablePositions()) {
        board.setTile(p, Tile(id: _id(), type: _pickNonMatching(board, p)));
      }
      last = board;
      if (!hasAnyMatch(board) && hasAnyMove(board)) return board;
    }
    return last!;
  }

  TileType _pickNonMatching(Board board, Position p) {
    final excluded = <TileType>{};
    final left1 = board.tileAt(p.left);
    final left2 = board.tileAt(Position(p.row, p.col - 2));
    if (left1 != null && left2 != null && left1.type == left2.type) {
      excluded.add(left1.type);
    }
    final up1 = board.tileAt(p.up);
    final up2 = board.tileAt(Position(p.row - 2, p.col));
    if (up1 != null && up2 != null && up1.type == up2.type) {
      excluded.add(up1.type);
    }
    final choices = palette.where((t) => !excluded.contains(t)).toList();
    if (choices.isEmpty) return _randomType();
    return choices[random.nextInt(choices.length)];
  }

  // ---------------------------------------------------------------------------
  // Swap resolution
  // ---------------------------------------------------------------------------

  /// True if [a] and [b] are orthogonally adjacent playable cells.
  bool areAdjacent(Position a, Position b) =>
      (a.row - b.row).abs() + (a.col - b.col).abs() == 1;

  /// Resolves the player swapping [a] and [b]. Never mutates [input].
  ///
  /// A swap is valid if it forms a match OR either swapped tile is a special
  /// candy (which can always be detonated by a swap). An invalid swap returns
  /// `valid: false` with the board unchanged (the renderer bounces it back).
  ResolutionResult resolveSwap(Board input, Position a, Position b) {
    final ta0 = input.tileAt(a);
    final tb0 = input.tileAt(b);
    if (!areAdjacent(a, b) ||
        !input.isPlayable(a) ||
        !input.isPlayable(b) ||
        ta0 == null ||
        tb0 == null) {
      return ResolutionResult(
        valid: false,
        swap: SwapEvent(
          a: a,
          b: b,
          idA: ta0?.id ?? -1,
          idB: tb0?.id ?? -1,
          reverted: true,
        ),
        phases: const [],
        score: 0,
        board: input,
      );
    }

    final board = input.clone();
    final ta = board.tileAt(a)!;
    final tb = board.tileAt(b)!;
    board.setTile(a, tb);
    board.setTile(b, ta);

    final triggers = _swapTriggers(board, a, b);
    final firstMatches = detectMatches(board);

    if (triggers.isEmpty && firstMatches.isEmpty) {
      return ResolutionResult(
        valid: false,
        swap: SwapEvent(a: a, b: b, idA: ta.id, idB: tb.id, reverted: true),
        phases: const [],
        score: 0,
        board: input,
      );
    }

    final (phases, totalScore) =
        _cascade(board, firstMatches, triggers, {a, b});

    return ResolutionResult(
      valid: true,
      swap: SwapEvent(a: a, b: b, idA: ta.id, idB: tb.id, reverted: false),
      phases: phases,
      score: totalScore,
      board: board,
    );
  }

  /// Runs clear -> collapse -> refill until the board stabilises, returning the
  /// ordered phases and total score. Shared by swaps and boosters.
  (List<CascadePhase>, int) _cascade(
    Board board,
    List<Match> firstMatches,
    List<_Trigger> firstTriggers,
    Set<Position> firstSwapped,
  ) {
    final phases = <CascadePhase>[];
    var totalScore = 0;
    var level = 1;
    var matches = firstMatches;
    var trig = firstTriggers;
    var swapped = firstSwapped;

    while (true) {
      final clear = _resolveClears(board, matches, trig, level, swapped);
      final clearedTiles = <ClearedTile>[];
      for (final p in clear.cleared) {
        final tile = board.tileAt(p);
        if (tile != null) {
          clearedTiles.add(ClearedTile(
            id: tile.id,
            type: tile.type,
            special: tile.special,
            at: p,
          ));
        }
        board.setTile(p, null);
      }
      final moves = _applyGravity(board);
      final spawns = _refill(board);
      phases.add(CascadePhase(
        level: level,
        matches: clear.matches,
        created: clear.created,
        activations: clear.activations,
        cleared: clear.cleared,
        clearedTiles: clearedTiles,
        score: clear.score,
        moves: moves,
        spawns: spawns,
      ));
      totalScore += clear.score;

      matches = detectMatches(board);
      trig = const [];
      swapped = const {};
      if (matches.isEmpty) break;
      level++;
    }
    return (phases, totalScore);
  }

  /// Booster (lollipop hammer): smash the tile at [at] — detonating it if it is
  /// a special — then let the board cascade. Never mutates [input].
  ResolutionResult applyLollipop(Board input, Position at) {
    final target = input.tileAt(at);
    if (!input.isPlayable(at) || target == null) {
      return ResolutionResult(
        valid: false,
        swap: SwapEvent(a: at, b: at, idA: -1, idB: -1, reverted: true),
        phases: const [],
        score: 0,
        board: input,
      );
    }
    final board = input.clone();
    final color = dominantColor(board);
    final cells = target.isSpecial
        ? specialBlastCells(board, at, target.special, color)
        : <Position>{at};
    final trigger = _Trigger(
      cells: cells,
      origins: {at},
      activation: SpecialActivation(
        at: at,
        type: target.special,
        targetColor: target.special == SpecialType.colorBomb ? color : null,
        affected: cells,
      ),
    );
    final (phases, total) = _cascade(board, const [], [trigger], const {});
    return ResolutionResult(
      valid: phases.isNotEmpty,
      swap: SwapEvent(
          a: at, b: at, idA: target.id, idB: target.id, reverted: false),
      phases: phases,
      score: total,
      board: board,
    );
  }

  /// Booster (color bomb): clear every tile of [color], then cascade.
  ResolutionResult applyClearColor(Board input, TileType color) {
    final board = input.clone();
    final cells = colorCells(board, color);
    if (cells.isEmpty) {
      return ResolutionResult(
        valid: false,
        swap: const SwapEvent(
            a: Position(0, 0), b: Position(0, 0), idA: -1, idB: -1, reverted: true),
        phases: const [],
        score: 0,
        board: input,
      );
    }
    final anchor = cells.first;
    final trigger = _Trigger(
      cells: cells,
      origins: {anchor},
      activation: SpecialActivation(
        at: anchor,
        type: SpecialType.colorBomb,
        targetColor: color,
        affected: cells,
      ),
    );
    final (phases, total) = _cascade(board, const [], [trigger], const {});
    return ResolutionResult(
      valid: phases.isNotEmpty,
      swap: SwapEvent(a: anchor, b: anchor, idA: -1, idB: -1, reverted: false),
      phases: phases,
      score: total,
      board: board,
    );
  }

  /// Special detonations driven by the swap itself (read from the post-swap
  /// board): a two-special combo, a color-bomb-on-colour, or a lone special.
  List<_Trigger> _swapTriggers(Board board, Position a, Position b) {
    final tA = board.tileAt(a)!;
    final tB = board.tileAt(b)!;

    if (tA.isSpecial && tB.isSpecial) {
      final cells =
          comboBlastCells(board, tA.special, tB.special, tA.type, tB.type, a);
      return [
        _Trigger(
          cells: cells,
          origins: {a, b},
          activation: SpecialActivation(
            at: a,
            type: tA.special,
            targetColor: null,
            affected: cells,
          ),
        ),
      ];
    }

    if (tA.isSpecial || tB.isSpecial) {
      final spPos = tA.isSpecial ? a : b;
      final sp = tA.isSpecial ? tA : tB;
      final other = tA.isSpecial ? tB : tA;

      if (sp.special == SpecialType.colorBomb) {
        final color = other.type;
        final cells = colorCells(board, color)..add(spPos);
        return [
          _Trigger(
            cells: cells,
            origins: {spPos},
            activation: SpecialActivation(
              at: spPos,
              type: SpecialType.colorBomb,
              targetColor: color,
              affected: cells,
            ),
          ),
        ];
      }

      final cells =
          specialBlastCells(board, spPos, sp.special, dominantColor(board));
      return [
        _Trigger(
          cells: cells,
          origins: {spPos},
          activation: SpecialActivation(
            at: spPos,
            type: sp.special,
            targetColor: null,
            affected: cells,
          ),
        ),
      ];
    }

    return const [];
  }

  /// Resolves a single clear step: spawn specials from match shapes, then
  /// detonate any pre-existing specials caught in the clear (with chain
  /// reactions). Newly-created specials are immune this phase — they survive
  /// onto the board.
  _ClearResult _resolveClears(
    Board board,
    List<Match> matches,
    List<_Trigger> triggers,
    int level,
    Set<Position> swapped,
  ) {
    final created = <SpecialCreation>[];
    final createdPositions = <Position>{};

    // Pass 1: spawn specials at pivots (upgrade the tile in place).
    for (final m in matches) {
      final special = specialForMatch(m);
      if (special == null) continue;
      final pivot = pivotFor(m, swapped);
      final tile = board.tileAt(pivot);
      if (tile == null || tile.isSpecial) continue; // don't overwrite
      tile.special = special;
      created.add(
          SpecialCreation(at: pivot, type: special, tileId: tile.id));
      createdPositions.add(pivot);
    }

    final cleared = <Position>{};
    void addCleared(Position p) {
      if (!createdPositions.contains(p)) cleared.add(p);
    }

    // Base clear: every matched cell except the just-created specials.
    for (final m in matches) {
      for (final c in m.cells) {
        addCleared(c);
      }
    }

    // Chain-reaction detonation.
    final activations = <SpecialActivation>[];
    final blasted = <Position>{};
    final pending = <Set<Position>>[];

    void detonateTile(Position p) {
      if (blasted.contains(p) || createdPositions.contains(p)) return;
      final tile = board.tileAt(p);
      if (tile == null || !tile.isSpecial) return;
      blasted.add(p);
      final color = dominantColor(board);
      final cells = specialBlastCells(board, p, tile.special, color);
      activations.add(SpecialActivation(
        at: p,
        type: tile.special,
        targetColor:
            tile.special == SpecialType.colorBomb ? color : null,
        affected: cells,
      ));
      pending.add(cells);
    }

    // Seed with swap-driven triggers.
    for (final t in triggers) {
      activations.add(t.activation);
      blasted.addAll(t.origins);
      for (final o in t.origins) {
        addCleared(o);
      }
      pending.add(t.cells);
    }
    // Seed with pre-existing specials caught in the base clear.
    for (final p in cleared.toList()) {
      detonateTile(p);
    }

    while (pending.isNotEmpty) {
      final cells = pending.removeLast();
      for (final c in cells) {
        addCleared(c);
        final tile = board.tileAt(c);
        if (tile != null && tile.isSpecial) detonateTile(c);
      }
    }

    final score = _scorer.scoreClear(cleared.length, level) +
        _scorer.scoreSpecials(created.length);

    return _ClearResult(
      matches: matches,
      created: created,
      activations: activations,
      cleared: cleared,
      score: score,
    );
  }

  // ---------------------------------------------------------------------------
  // Gravity & refill
  // ---------------------------------------------------------------------------

  /// Applies gravity in place and returns the resulting tile moves. Exposed so
  /// callers (e.g. after a booster) and tests can collapse a board directly.
  List<TileMove> collapse(Board board) => _applyGravity(board);

  /// Collapses tiles downward column by column. Blocked cells split a column
  /// into independent segments (tiles never fall through a wall). Returns the
  /// moves for animation.
  List<TileMove> _applyGravity(Board board) {
    final moves = <TileMove>[];
    for (var c = 0; c < board.cols; c++) {
      var writeRow = board.rows - 1;
      for (var r = board.rows - 1; r >= 0; r--) {
        final p = Position(r, c);
        if (board.isBlocked(p)) {
          writeRow = r - 1; // start a fresh segment above the wall
          continue;
        }
        final tile = board.tileAt(p);
        if (tile == null) continue;
        if (writeRow != r) {
          final dest = Position(writeRow, c);
          board.setTile(p, null);
          board.setTile(dest, tile);
          moves.add(TileMove(tileId: tile.id, from: p, to: dest));
        }
        writeRow--;
      }
    }
    return moves;
  }

  /// Fills every empty playable cell with a fresh random tile. Refills may form
  /// matches — that is exactly what drives cascades.
  List<SpawnedTile> _refill(Board board) {
    final spawns = <SpawnedTile>[];
    for (final p in board.playablePositions()) {
      if (board.tileAt(p) == null) {
        final tile = Tile(id: _id(), type: _randomType());
        board.setTile(p, tile);
        spawns.add(SpawnedTile(tileId: tile.id, type: tile.type, at: p));
      }
    }
    return spawns;
  }

  // ---------------------------------------------------------------------------
  // Dead-board detection & shuffle
  // ---------------------------------------------------------------------------

  /// True if any legal move exists: any special candy on the board (always
  /// detonatable via a swap) or any adjacent swap that forms a match.
  bool hasAnyMove(Board board) {
    for (final p in board.playablePositions()) {
      if (board.tileAt(p)?.isSpecial ?? false) return true;
    }
    for (final p in board.playablePositions()) {
      for (final q in [p.right, p.down]) {
        if (board.isPlayable(q) && _swapCreatesMatch(board, p, q)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _swapCreatesMatch(Board board, Position a, Position b) {
    final ta = board.tileAt(a);
    final tb = board.tileAt(b);
    if (ta == null || tb == null) return false;
    board.setTile(a, tb);
    board.setTile(b, ta);
    final formed = hasMatchThrough(board, a) || hasMatchThrough(board, b);
    board.setTile(a, ta); // restore
    board.setTile(b, tb);
    return formed;
  }

  /// Reshuffles the existing tiles into a match-free arrangement that has at
  /// least one move. Keeps the same tile multiset (ids preserved). Returns the
  /// original board with `failed: true` if no arrangement is found.
  ShuffleResult shuffle(Board input) {
    final positions = input
        .playablePositions()
        .where((p) => input.tileAt(p) != null)
        .toList();
    final tiles = [for (final p in positions) input.tileAt(p)!];

    for (var attempt = 0; attempt < 200; attempt++) {
      final shuffled = [...tiles];
      _fisherYates(shuffled);
      final board = input.clone();
      for (var i = 0; i < positions.length; i++) {
        board.setTile(positions[i], shuffled[i]);
      }
      if (!hasAnyMatch(board) && hasAnyMove(board)) {
        return ShuffleResult(board: board, moves: _diffMoves(input, board));
      }
    }
    return ShuffleResult(board: input, moves: const [], failed: true);
  }

  void _fisherYates<T>(List<T> list) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
  }

  List<TileMove> _diffMoves(Board before, Board after) {
    final moves = <TileMove>[];
    for (final p in before.playablePositions()) {
      final tile = before.tileAt(p);
      if (tile == null) continue;
      final now = after.positionOfTileId(tile.id);
      if (now != null && now != p) {
        moves.add(TileMove(tileId: tile.id, from: p, to: now));
      }
    }
    return moves;
  }
}
