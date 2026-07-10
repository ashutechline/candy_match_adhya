import 'dart:math';

import '../../game_logic/game_logic.dart';
import '../models/level.dart';
import '../models/objective.dart';

const _fiveColors = [
  TileType.red,
  TileType.orange,
  TileType.green,
  TileType.blue,
  TileType.purple,
];

/// The difficulty tier of level [id]. The first 100 levels ramp Easy -> Medium
/// -> Hard with occasional "breather" levels and a Hard boss every 10th level;
/// after 100 the tier keeps cycling through the Medium/Hard band so endless
/// play stays challenging (never drops back to Easy).
LevelDifficulty difficultyFor(int id) {
  final n = id < 1 ? 1 : id;
  if (n % 10 == 0) return LevelDifficulty.hard; // boss levels

  // Position along the ramp. Within the first 100 use the level number; after
  // 100 cycle through the 41..100 band so it stays in Medium/Hard territory.
  final band = n <= 100 ? n : 41 + ((n - 1) % 60);

  if (band <= 25) {
    return (n % 4 == 0) ? LevelDifficulty.medium : LevelDifficulty.easy;
  } else if (band <= 60) {
    if (n % 7 == 0) return LevelDifficulty.hard;
    // An occasional Easy breather, but only inside the first 100 levels — past
    // that, endless play never drops back to Easy (stays Medium/Hard).
    if (n <= 100 && n % 5 == 0) return LevelDifficulty.easy;
    return LevelDifficulty.medium;
  } else {
    if (n % 6 == 0) return LevelDifficulty.medium; // breather
    return LevelDifficulty.hard;
  }
}

/// Deterministically generates level [id] (>= 1). Levels are ENDLESS. The
/// difficulty tier drives the knobs (board size, colours, targets, moves,
/// blockers, jelly) so Easy/Medium/Hard levels feel distinct and — crucially —
/// stay winnable at every tier. The objective type rotates score -> collect ->
/// jelly for variety. Same id always yields the same level (seeded).
LevelDef generateLevel(int id) {
  final n = id < 1 ? 1 : id;
  final tier = difficultyFor(n);
  final rnd = Random(n * 7919);
  // Gentle within-tier scaling that plateaus after level 100.
  final t = ((n < 100 ? n : 100) - 1) / 99.0;

  final size = switch (tier) {
    LevelDifficulty.easy => 7,
    LevelDifficulty.medium => 8,
    LevelDifficulty.hard => 9,
  };
  final palette = tier == LevelDifficulty.easy ? _fiveColors : kDefaultPalette;

  // Blockers scale with tier.
  final blocked = <Position>{};
  final blockerCount = switch (tier) {
    LevelDifficulty.easy => 0,
    LevelDifficulty.medium => (n % 4 == 0) ? 2 : 0,
    LevelDifficulty.hard => 2 + rnd.nextInt(3),
  };
  var guard = 0;
  while (blocked.length < blockerCount && guard++ < 60) {
    blocked.add(Position(1 + rnd.nextInt(size - 2), 1 + rnd.nextInt(size - 2)));
  }

  // Star base for the non-score objectives.
  final base = switch (tier) {
    LevelDifficulty.easy => 800 + (t * 700).round(),
    LevelDifficulty.medium => 1800 + (t * 1500).round(),
    LevelDifficulty.hard => 3500 + (t * 3000).round(),
  };
  final thresholds = <int>[base, (base * 1.7).round(), (base * 2.6).round()];

  Objective objective;
  int moveLimit;
  final jelly = <Position, int>{};

  switch (n % 3) {
    case 1: // reach a score
      final target = switch (tier) {
        LevelDifficulty.easy => 700 + (t * 1000).round(), // 700..1700
        LevelDifficulty.medium => 2200 + (t * 2800).round(), // 2200..5000
        LevelDifficulty.hard => 4500 + (t * 5500).round(), // 4500..10000
      };
      final moves = switch (tier) {
        LevelDifficulty.easy => 26,
        LevelDifficulty.medium => 24,
        LevelDifficulty.hard => 22,
      };
      objective = ReachScore(target);
      moveLimit = moves;
      thresholds[0] = target;
      thresholds[1] = (target * 1.5).round();
      thresholds[2] = (target * 2.1).round();
    case 2: // collect colours (moves scale with quota -> always winnable)
      final colourCount = tier == LevelDifficulty.hard ? 2 : 1;
      final quota = switch (tier) {
        LevelDifficulty.easy => 8 + (t * 8).round(), // 8..16
        LevelDifficulty.medium => 16 + (t * 12).round(), // 16..28
        LevelDifficulty.hard => 24 + (t * 14).round(), // 24..38
      };
      final chosen = (List.of(palette)..shuffle(rnd)).take(colourCount);
      objective = CollectColors({for (final c in chosen) c: quota});
      moveLimit = 18 + quota;
    default: // clear the jelly (moves scale with the jelly -> winnable)
      final rawSpan = switch (tier) {
        LevelDifficulty.easy => 2,
        LevelDifficulty.medium => 3,
        LevelDifficulty.hard => 4 + (t >= 0.5 ? 1 : 0),
      };
      final span = rawSpan.clamp(2, size - 3);
      final start = ((size - span) ~/ 2).clamp(0, size - 1);
      final thickness = tier == LevelDifficulty.hard ? 2 : 1;
      for (var r = start; r < start + span; r++) {
        for (var c = start; c < start + span; c++) {
          final p = Position(r, c);
          if (!blocked.contains(p)) jelly[p] = thickness;
        }
      }
      objective = ClearAllJelly();
      moveLimit = 16 + jelly.length * thickness;
  }

  return LevelDef(
    id: n,
    rows: size,
    cols: size,
    objective: objective,
    moveLimit: moveLimit,
    starThresholds: thresholds,
    blocked: blocked,
    jelly: jelly,
    palette: palette,
    seed: n * 101 + 7,
    difficulty: tier,
  );
}

/// Levels are generated on demand, so any id resolves.
LevelDef levelById(int id) => generateLevel(id);
