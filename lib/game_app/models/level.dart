import '../../game_logic/game_logic.dart';
import 'objective.dart';

/// The difficulty tier a level belongs to.
enum LevelDifficulty {
  easy,
  medium,
  hard;

  String get label => switch (this) {
        LevelDifficulty.easy => 'Easy',
        LevelDifficulty.medium => 'Medium',
        LevelDifficulty.hard => 'Hard',
      };
}

/// An immutable level definition. Levels are procedurally generated (see
/// `data/levels.dart`) with a difficulty tier so the ramp reads clearly.
class LevelDef {
  final int id;
  final int rows;
  final int cols;
  final Set<Position> blocked;
  final LevelDifficulty difficulty;

  /// Initial jelly thickness per cell (only meaningful for jelly levels).
  final Map<Position, int> jelly;

  /// The subset of colours this level spawns.
  final List<TileType> palette;
  final Objective objective;
  final int moveLimit;

  /// Score cutoffs for [1★, 2★, 3★], ascending.
  final List<int> starThresholds;

  /// Optional fixed seed for a reproducible board.
  final int? seed;

  const LevelDef({
    required this.id,
    required this.rows,
    required this.cols,
    required this.objective,
    required this.moveLimit,
    required this.starThresholds,
    this.blocked = const {},
    this.jelly = const {},
    this.palette = kDefaultPalette,
    this.seed,
    this.difficulty = LevelDifficulty.easy,
  });

  /// Stars earned for a given [score] (0..3).
  int starsFor(int score) {
    var stars = 0;
    for (final threshold in starThresholds) {
      if (score >= threshold) stars++;
    }
    return stars;
  }
}
