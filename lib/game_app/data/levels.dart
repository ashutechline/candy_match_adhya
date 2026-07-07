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

/// Deterministically generates level [id] (>= 1). Levels are ENDLESS — there is
/// no fixed list. Difficulty ramps with the number (bigger boards, more
/// colours, larger targets, occasional blockers) and the objective type rotates
/// score -> collect -> jelly. Same id always yields the same level (seeded), so
/// a level plays and re-plays identically.
LevelDef generateLevel(int id) {
  final n = id < 1 ? 1 : id;
  // Difficulty plateaus after level 60 so endless play stays winnable forever
  // (targets/quota/jelly stop growing; only the board/colour count already
  // capped earlier keep the later levels varied).
  final d = n < 60 ? n : 60;
  final rnd = Random(n * 7919);

  final size = n < 4 ? 7 : (n < 12 ? 8 : 9);
  final palette = n < 5 ? _fiveColors : kDefaultPalette;

  // Base score used for star thresholds on the non-score objectives.
  final base = 1000 + (d - 1) * 300;
  final thresholds = <int>[base, (base * 1.8).round(), (base * 2.8).round()];

  // A few interior blockers on later multiples of four.
  final blocked = <Position>{};
  if (n >= 6 && n % 4 == 0) {
    final count = 2 + rnd.nextInt(2);
    var guard = 0;
    while (blocked.length < count && guard++ < 50) {
      final r = 1 + rnd.nextInt(size - 2);
      final c = 1 + rnd.nextInt(size - 2);
      blocked.add(Position(r, c));
    }
  }

  Objective objective;
  int moveLimit;
  final jelly = <Position, int>{};

  switch (n % 3) {
    case 1: // reach a score
      final target = 1000 + (d - 1) * 350;
      objective = ReachScore(target);
      moveLimit = 20 + d ~/ 2;
      thresholds[0] = target;
      thresholds[1] = (target * 1.5).round();
      thresholds[2] = (target * 2.2).round();
    case 2: // collect colours — quota capped, moves scale with it so it's winnable
      final colourCount = n < 8 ? 1 : 2;
      final quota = 12 + d ~/ 2; // 12..42
      final chosen = (List.of(palette)..shuffle(rnd)).take(colourCount);
      objective = CollectColors({for (final c in chosen) c: quota});
      moveLimit = 22 + quota;
    default: // clear the jelly (n % 3 == 0) — moves scale with jelly amount
      final span = (2 + d ~/ 8).clamp(2, size - 3);
      final start = ((size - span) ~/ 2).clamp(0, size - 1);
      final thickness = n >= 12 ? 2 : 1;
      for (var r = start; r < start + span; r++) {
        for (var c = start; c < start + span; c++) {
          final p = Position(r, c);
          if (!blocked.contains(p)) jelly[p] = thickness;
        }
      }
      objective = ClearAllJelly();
      moveLimit = 20 + jelly.length * thickness;
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
  );
}

/// Levels are generated on demand, so any id resolves.
LevelDef levelById(int id) => generateLevel(id);
