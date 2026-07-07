import 'board.dart';
import 'match.dart';
import 'position.dart';
import 'tile.dart';

/// The player's swap, recorded so a renderer can animate it (and a bounce-back
/// when [reverted] is true).
class SwapEvent {
  final Position a;
  final Position b;
  final int idA;
  final int idB;
  final bool reverted;

  const SwapEvent({
    required this.a,
    required this.b,
    required this.idA,
    required this.idB,
    required this.reverted,
  });
}

/// A special candy that was spawned this phase and now lives on the board.
class SpecialCreation {
  final Position at;
  final SpecialType type;
  final int tileId;

  const SpecialCreation({
    required this.at,
    required this.type,
    required this.tileId,
  });
}

/// A special candy detonating: the [affected] cells it cleared.
///
/// [targetColor] is set only for a [SpecialType.colorBomb] (the colour it wiped).
class SpecialActivation {
  final Position at;
  final SpecialType type;
  final TileType? targetColor;
  final Set<Position> affected;

  const SpecialActivation({
    required this.at,
    required this.type,
    required this.targetColor,
    required this.affected,
  });
}

/// A snapshot of a tile at the moment it was cleared. Lets objectives count
/// collected colours and lets a renderer pop the correct candy, since the
/// tile is removed from the board immediately afterwards.
class ClearedTile {
  final int id;
  final TileType type;
  final SpecialType special;
  final Position at;

  const ClearedTile({
    required this.id,
    required this.type,
    required this.special,
    required this.at,
  });
}

/// A tile sliding from [from] to [to] during the gravity/collapse step.
/// Tracked by stable [tileId] so the animation is continuous.
class TileMove {
  final int tileId;
  final Position from;
  final Position to;

  const TileMove({required this.tileId, required this.from, required this.to});
}

/// A freshly-spawned refill tile that dropped in at [at].
class SpawnedTile {
  final int tileId;
  final TileType type;
  final Position at;

  const SpawnedTile({
    required this.tileId,
    required this.type,
    required this.at,
  });
}

/// One iteration of the resolution loop: clear -> collapse -> refill.
///
/// [level] is the cascade depth (1 = the player's move, 2+ = chained clears),
/// which also drives the scoring multiplier.
class CascadePhase {
  final int level;
  final List<Match> matches;
  final List<SpecialCreation> created;
  final List<SpecialActivation> activations;
  final Set<Position> cleared;

  /// Snapshots of every tile removed this phase (same membership as [cleared]).
  final List<ClearedTile> clearedTiles;
  final int score;
  final List<TileMove> moves;
  final List<SpawnedTile> spawns;

  const CascadePhase({
    required this.level,
    required this.matches,
    required this.created,
    required this.activations,
    required this.cleared,
    required this.clearedTiles,
    required this.score,
    required this.moves,
    required this.spawns,
  });
}

/// The full outcome of a swap: the board is settled (no matches remain) and
/// every [CascadePhase] is ordered for playback by a renderer.
class ResolutionResult {
  final bool valid;
  final SwapEvent swap;
  final List<CascadePhase> phases;
  final int score;

  /// The settled board. For an invalid swap this is the original board,
  /// unchanged.
  final Board board;

  const ResolutionResult({
    required this.valid,
    required this.swap,
    required this.phases,
    required this.score,
    required this.board,
  });

  /// Number of cascade iterations (0 for an invalid/no-op swap).
  int get cascadeCount => phases.length;

  int get tilesCleared =>
      phases.fold(0, (sum, p) => sum + p.cleared.length);

  /// Every tile removed across all phases, in play order.
  Iterable<ClearedTile> get allClearedTiles =>
      phases.expand((p) => p.clearedTiles);
}
