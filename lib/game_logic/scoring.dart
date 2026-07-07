/// Tunable scoring parameters. Kept as plain data so difficulty/economy tuning
/// (e.g. via remote config) can swap it without touching the resolver.
class ScoreConfig {
  /// Base points awarded per cleared tile.
  final int perTile;

  /// One-off bonus for spawning a special candy (striped/wrapped/color bomb).
  final int specialCreationBonus;

  const ScoreConfig({
    this.perTile = 60,
    this.specialCreationBonus = 120,
  });
}

/// Pure scoring functions. The cascade [level] is the combo multiplier: the
/// first clear of a move scores x1, the next cascade x2, and so on — this is
/// what makes long chains feel rewarding.
class Scorer {
  final ScoreConfig config;

  const Scorer(this.config);

  int scoreClear(int tilesCleared, int level) =>
      tilesCleared * config.perTile * level;

  int scoreSpecials(int specialsCreated) =>
      specialsCreated * config.specialCreationBonus;
}
