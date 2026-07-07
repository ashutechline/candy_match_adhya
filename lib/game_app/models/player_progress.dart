import 'dart:convert';

/// Persisted player account: how far they've unlocked and their best stars per
/// level. Kept tiny and JSON-serializable for `shared_preferences`.
class PlayerProgress {
  final int highestUnlocked;
  final Map<int, int> starsByLevel;

  const PlayerProgress({
    this.highestUnlocked = 1,
    this.starsByLevel = const {},
  });

  int starsFor(int levelId) => starsByLevel[levelId] ?? 0;

  bool isUnlocked(int levelId) => levelId <= highestUnlocked;

  int get totalStars =>
      starsByLevel.values.fold(0, (sum, s) => sum + s);

  /// Levels cleared so far. The frontier advances one step per win, so every
  /// level below [highestUnlocked] has been beaten (even 0-star clears).
  int get levelsCleared => highestUnlocked - 1;

  /// Returns a copy recording a WON level: never downgrades best stars, and
  /// always unlocks the next level — a clear counts even with 0 stars (some
  /// objectives can be met below the 1-star score).
  PlayerProgress recordResult(int levelId, int stars) {
    final updatedStars = Map<int, int>.from(starsByLevel);
    final best = updatedStars[levelId] ?? 0;
    if (stars > best) updatedStars[levelId] = stars;

    final unlocked =
        levelId >= highestUnlocked ? levelId + 1 : highestUnlocked;
    return PlayerProgress(
      highestUnlocked: unlocked,
      starsByLevel: updatedStars,
    );
  }

  String toJsonString() => jsonEncode({
        'highestUnlocked': highestUnlocked,
        'stars': starsByLevel.map((k, v) => MapEntry(k.toString(), v)),
      });

  factory PlayerProgress.fromJsonString(String source) {
    final map = jsonDecode(source) as Map<String, dynamic>;
    final rawStars = (map['stars'] as Map?) ?? const {};
    return PlayerProgress(
      highestUnlocked: (map['highestUnlocked'] as int?) ?? 1,
      starsByLevel: {
        for (final entry in rawStars.entries)
          int.parse(entry.key as String): entry.value as int,
      },
    );
  }
}
