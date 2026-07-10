import 'package:candy_crush/game_app/data/levels.dart';
import 'package:candy_crush/game_app/game/game_controller.dart';
import 'package:candy_crush/game_app/models/level.dart';
import 'package:candy_crush/game_app/models/objective.dart';
import 'package:candy_crush/game_app/models/player_progress.dart';
import 'package:candy_crush/game_logic/game_logic.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixed levels so the controller tests don't depend on the level generator.
LevelDef _reach({int target = 1500, int moves = 20}) => LevelDef(
      id: 1,
      rows: 7,
      cols: 7,
      objective: ReachScore(target),
      moveLimit: moves,
      starThresholds: [target, target * 2, target * 3],
      seed: 42,
    );

LevelDef _jelly() => LevelDef(
      id: 3,
      rows: 7,
      cols: 7,
      objective: ClearAllJelly(),
      moveLimit: 25,
      starThresholds: const [1000, 2000, 3000],
      jelly: {
        for (var r = 2; r <= 4; r++)
          for (var c = 2; c <= 4; c++) Position(r, c): 1,
      },
      seed: 42,
    );

(Position, Position)? _firstValidSwap(GameController c) {
  for (final p in c.board.playablePositions()) {
    for (final q in [p.right, p.down]) {
      if (c.board.isPlayable(q) && c.engine.resolveSwap(c.board, p, q).valid) {
        return (p, q);
      }
    }
  }
  return null;
}

void main() {
  group('GameController', () {
    test('initializes a full board with the level move limit', () {
      final level = _reach();
      final c = GameController.forLevel(level);
      expect(c.board.isFull, isTrue);
      expect(c.movesLeft, level.moveLimit);
      expect(c.status, GameStatus.playing);
      expect(c.score, 0);
    });

    test('a valid swap spends a move, adds score and gates input', () {
      final level = _reach();
      final c = GameController.forLevel(level);
      final swap = _firstValidSwap(c)!;

      final result = c.trySwap(swap.$1, swap.$2);
      expect(result, isNotNull);
      expect(result!.valid, isTrue);
      expect(c.movesLeft, level.moveLimit - 1);
      expect(c.score, greaterThan(0));
      expect(c.isBusy, isTrue);

      c.onAnimationComplete();
      expect(c.isBusy, isFalse);
    });

    test('an invalid swap changes nothing and is ignored while busy', () {
      final level = _reach();
      final c = GameController.forLevel(level);
      final result = c.trySwap(const Position(0, 0), const Position(4, 4));
      expect(result!.valid, isFalse);
      expect(c.movesLeft, level.moveLimit);
      expect(c.score, 0);

      final swap = _firstValidSwap(c)!;
      c.trySwap(swap.$1, swap.$2);
      expect(c.isBusy, isTrue);
      expect(c.trySwap(swap.$1, swap.$2), isNull);
    });

    test('ReachScore objective completes when the target is reached', () {
      final c = GameController.forLevel(_reach(target: 1500));
      expect(c.objectiveMet, isFalse);
      c.score = 1500;
      expect(c.objectiveMet, isTrue);
    });

    test('jelly objective tracks remaining cells and completes at zero', () {
      final c = GameController.forLevel(_jelly());
      expect(c.jellyRemaining, greaterThan(0));
      expect(c.objectiveMet, isFalse);
      for (final key in c.jelly.keys.toList()) {
        c.jelly[key] = 0;
      }
      expect(c.jellyRemaining, 0);
      expect(c.objectiveMet, isTrue);
    });

    test('running out of moves without meeting the objective is a loss', () {
      final c = GameController.forLevel(_reach());
      c.movesLeft = 0;
      c.onAnimationComplete();
      expect(c.status, GameStatus.lost);
    });

    test('meeting the score objective does NOT win immediately with moves left, wins at zero moves', () {
      final c = GameController.forLevel(_reach());
      c.score = 99999;
      c.onAnimationComplete();
      expect(c.status, GameStatus.playing);

      c.movesLeft = 0;
      c.onAnimationComplete();
      expect(c.status, GameStatus.won);
    });

    test('meeting non-score objective wins immediately even with moves left', () {
      final c = GameController.forLevel(_jelly());
      expect(c.jellyRemaining, greaterThan(0));
      for (final key in c.jelly.keys.toList()) {
        c.jelly[key] = 0;
      }
      c.onAnimationComplete();
      expect(c.status, GameStatus.won);
    });

    test('grantExtraMoves resumes a lost level', () {
      final c = GameController.forLevel(_reach());
      c.movesLeft = 0;
      c.onAnimationComplete();
      expect(c.status, GameStatus.lost);

      c.grantExtraMoves(5);
      expect(c.status, GameStatus.playing);
      expect(c.movesLeft, 5);
    });

    test('objective progress is a clamped fraction', () {
      final c = GameController.forLevel(_reach(target: 1500));
      c.score = 750;
      expect(c.objectiveProgress, closeTo(0.5, 0.001));
      c.score = 999999;
      expect(c.objectiveProgress, 1.0);
    });
  });

  group('boosters', () {
    test('extra-moves adds 5 and decrements the booster', () {
      final c = GameController.forLevel(_reach());
      final before = c.boosterCount(BoosterId.extraMoves);
      c.useExtraMoves();
      expect(c.movesLeft, _reach().moveLimit + 5);
      expect(c.boosterCount(BoosterId.extraMoves), before - 1);
    });

    test('a booster cannot be used once exhausted', () {
      final c = GameController.forLevel(_reach());
      while (c.canUseBooster(BoosterId.extraMoves)) {
        c.useExtraMoves();
      }
      expect(c.boosterCount(BoosterId.extraMoves), 0);
      final moves = c.movesLeft;
      c.useExtraMoves();
      expect(c.movesLeft, moves);
    });

    test('lollipop smashes a tile, consumes a charge and gates input', () {
      final c = GameController.forLevel(_reach());
      final pos = c.board.playablePositions().first;
      final before = c.boosterCount(BoosterId.lollipop);

      final result = c.useLollipop(pos);
      expect(result, isNotNull);
      expect(result!.valid, isTrue);
      expect(c.boosterCount(BoosterId.lollipop), before - 1);
      expect(c.isBusy, isTrue);

      c.clearBusy();
      expect(c.isBusy, isFalse);
      expect(hasAnyMatch(c.board), isFalse);
    });

    test('color bomb clears a colour and consumes a charge', () {
      final c = GameController.forLevel(_reach());
      final before = c.boosterCount(BoosterId.colorBomb);
      final result = c.useColorBomb();
      expect(result, isNotNull);
      expect(c.boosterCount(BoosterId.colorBomb), before - 1);
      expect(hasAnyMatch(c.board), isFalse);
    });

    test('shuffle keeps the board live and match-free', () {
      final c = GameController.forLevel(_reach());
      final result = c.useShuffle();
      expect(result, isNotNull);
      expect(hasAnyMatch(c.board), isFalse);
      expect(c.engine.hasAnyMove(c.board), isTrue);
    });
  });

  group('generated levels', () {
    test('every generated level makes a solvable board', () {
      for (var id = 1; id <= 30; id++) {
        final c = GameController.forLevel(generateLevel(id));
        expect(c.board.isFull, isTrue, reason: 'level $id not full');
        expect(hasAnyMatch(c.board), isFalse, reason: 'level $id starts matched');
        expect(c.engine.hasAnyMove(c.board), isTrue,
            reason: 'level $id is a dead board');
      }
    });

    test('jelly levels place jelly; star thresholds ascend', () {
      for (var id = 1; id <= 30; id++) {
        final level = generateLevel(id);
        if (level.objective is ClearAllJelly) {
          expect(level.jelly, isNotEmpty, reason: 'level $id has no jelly');
        }
        final t = level.starThresholds;
        expect(t, hasLength(3));
        expect(t[0] < t[1] && t[1] < t[2], isTrue,
            reason: 'level $id thresholds not ascending');
      }
    });

    test('level id is stable and the same id reproduces the same board', () {
      final a = generateLevel(7);
      final b = generateLevel(7);
      expect(a.id, 7);
      expect(b.rows, a.rows);
      expect(b.objective.runtimeType, a.objective.runtimeType);
      // Same seed -> identical generated board.
      final boardA = GameController.forLevel(a).board.render();
      final boardB = GameController.forLevel(b).board.render();
      expect(boardA, boardB);
    });

    test('collect levels stay winnable (moves scale with quota)', () {
      for (var id = 1; id <= 80; id++) {
        final o = generateLevel(id).objective;
        if (o is CollectColors) {
          final maxQuota = o.quotas.values.reduce((a, b) => a > b ? a : b);
          expect(generateLevel(id).moveLimit, greaterThanOrEqualTo(maxQuota),
              reason: 'level $id: quota $maxQuota vs '
                  '${generateLevel(id).moveLimit} moves');
        }
      }
    });

    test('levels stay valid and endless well past level 100', () {
      // No wall at 100: 101..140 must still generate solvable, live boards.
      for (var id = 100; id <= 140; id++) {
        final level = generateLevel(id);
        expect(level.id, id);
        final c = GameController.forLevel(level);
        expect(c.board.isFull, isTrue, reason: 'level $id not full');
        expect(hasAnyMatch(c.board), isFalse,
            reason: 'level $id starts matched');
        expect(c.engine.hasAnyMove(c.board), isTrue,
            reason: 'level $id is a dead board');
        expect(level.moveLimit, greaterThan(0));
      }
    });

    test('every objective type is winnable in moves across 1..140', () {
      for (var id = 1; id <= 140; id++) {
        final level = generateLevel(id);
        final o = level.objective;
        if (o is CollectColors) {
          final maxQuota = o.quotas.values.reduce((a, b) => a > b ? a : b);
          expect(level.moveLimit, greaterThanOrEqualTo(maxQuota),
              reason: 'level $id collect: $maxQuota quota vs '
                  '${level.moveLimit} moves');
        } else if (o is ClearAllJelly) {
          // Need at least ~1 move per jelly layer to have a shot at clearing.
          final layers =
              level.jelly.values.fold<int>(0, (sum, v) => sum + v);
          expect(level.moveLimit, greaterThanOrEqualTo(layers),
              reason: 'level $id jelly: $layers layers vs '
                  '${level.moveLimit} moves');
        }
      }
    });

    test('difficulty tiers are deterministic and cover the ramp', () {
      // difficultyFor matches the tier baked into the generated level.
      for (var id = 1; id <= 140; id++) {
        expect(generateLevel(id).difficulty, difficultyFor(id),
            reason: 'level $id tier mismatch');
      }

      // All three tiers appear within the first 100 levels.
      final tiers = [for (var id = 1; id <= 100; id++) difficultyFor(id)];
      expect(tiers.contains(LevelDifficulty.easy), isTrue);
      expect(tiers.contains(LevelDifficulty.medium), isTrue);
      expect(tiers.contains(LevelDifficulty.hard), isTrue);

      // The ramp gets harder: more Hard levels in the back half than the front.
      int hardIn(int lo, int hi) => [
            for (var id = lo; id <= hi; id++) difficultyFor(id)
          ].where((t) => t == LevelDifficulty.hard).length;
      expect(hardIn(51, 100), greaterThan(hardIn(1, 50)),
          reason: 'difficulty should ramp up over the first 100 levels');

      // Every 10th level is a Hard boss.
      for (final boss in [10, 20, 50, 90, 100]) {
        expect(difficultyFor(boss), LevelDifficulty.hard,
            reason: 'level $boss should be a boss');
      }

      // Endless play never drops back to Easy after level 100.
      for (var id = 101; id <= 200; id++) {
        expect(difficultyFor(id), isNot(LevelDifficulty.easy),
            reason: 'level $id fell back to Easy');
      }
    });

    test('board size grows with difficulty tier', () {
      for (var id = 1; id <= 100; id++) {
        final level = generateLevel(id);
        final expected = switch (level.difficulty) {
          LevelDifficulty.easy => 7,
          LevelDifficulty.medium => 8,
          LevelDifficulty.hard => 9,
        };
        expect(level.rows, expected, reason: 'level $id size');
        expect(level.cols, expected, reason: 'level $id size');
      }
    });
  });

  group('progression', () {
    test('a 0-star win still unlocks the next level and counts as cleared', () {
      var p = const PlayerProgress();
      expect(p.highestUnlocked, 1);

      p = p.recordResult(1, 0); // won level 1 with 0 stars
      expect(p.highestUnlocked, 2);
      expect(p.isUnlocked(2), isTrue);
      expect(p.levelsCleared, 1);
      expect(p.totalStars, 0);
    });

    test('replaying a cleared level does not move the frontier back', () {
      var p = const PlayerProgress().recordResult(1, 1).recordResult(2, 0);
      expect(p.highestUnlocked, 3);
      expect(p.levelsCleared, 2);

      p = p.recordResult(1, 3); // replay level 1 for 3 stars
      expect(p.highestUnlocked, 3);
      expect(p.starsFor(1), 3);
    });
  });
}
