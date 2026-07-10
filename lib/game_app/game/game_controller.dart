import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../game_logic/game_logic.dart';
import '../analytics/analytics_service.dart';
import '../models/level.dart';
import '../models/objective.dart';

enum GameStatus { playing, won, lost }

/// The four in-level boosters shown on the booster bar.
enum BoosterId { lollipop, colorBomb, extraMoves, shuffle }

/// Per-level session state. Owns the authoritative [Board] and drives the pure
/// [MatchEngine], translating each resolved swap into HUD/objective updates.
///
/// The UI applies logic instantly on a valid swap (moves/score/objective) and
/// then animates the visuals to catch up; input is gated on [isBusy] until the
/// board settles — the classic "never accept input while resolving" rule.
class GameController extends ChangeNotifier {
  final LevelDef level;
  final MatchEngine engine;

  Board board;
  int movesLeft;
  int score = 0;
  GameStatus status = GameStatus.playing;

  /// True while the board is animating a resolution; input is ignored.
  bool isBusy = false;

  /// Colours collected so far (only tracked for [CollectColors] levels).
  final Map<TileType, int> collected = {};

  /// Live jelly thickness per cell (only meaningful for [ClearAllJelly]).
  final Map<Position, int> jelly;
  final int _jellyInitialCells;

  /// Session booster inventory (not persisted).
  final Map<BoosterId, int> boosters = {
    BoosterId.lollipop: 3,
    BoosterId.colorBomb: 2,
    BoosterId.extraMoves: 3,
    BoosterId.shuffle: 3,
  };

  GameController._({
    required this.level,
    required this.engine,
    required this.board,
    required this.movesLeft,
    required this.jelly,
  }) : _jellyInitialCells =
            jelly.values.where((t) => t > 0).length;

  factory GameController.forLevel(LevelDef level) {
    final engine = MatchEngine(
      random: level.seed != null ? Random(level.seed) : Random(),
      palette: level.palette,
    );
    final board = engine.generateBoard(
      level.rows,
      level.cols,
      blocked: level.blocked,
    );
    return GameController._(
      level: level,
      engine: engine,
      board: board,
      movesLeft: level.moveLimit,
      jelly: Map<Position, int>.from(level.jelly),
    );
  }

  Objective get objective => level.objective;

  int get jellyRemaining => jelly.values.where((t) => t > 0).length;
  int get jellyInitial => _jellyInitialCells;

  bool get objectiveMet {
    switch (objective) {
      case ReachScore(:final target):
        return score >= target;
      case CollectColors(:final quotas):
        return quotas.entries
            .every((e) => (collected[e.key] ?? 0) >= e.value);
      case ClearAllJelly():
        return jellyRemaining == 0;
    }
  }

  /// Fractional objective progress in [0, 1] for a HUD bar.
  double get objectiveProgress {
    switch (objective) {
      case ReachScore(:final target):
        return (score / target).clamp(0.0, 1.0);
      case CollectColors(:final quotas):
        var done = 0;
        var total = 0;
        for (final e in quotas.entries) {
          total += e.value;
          done += min(collected[e.key] ?? 0, e.value);
        }
        return total == 0 ? 1 : done / total;
      case ClearAllJelly():
        if (_jellyInitialCells == 0) return 1;
        return (_jellyInitialCells - jellyRemaining) / _jellyInitialCells;
    }
  }

  /// Attempts the swap. Returns the [ResolutionResult] for the board to
  /// animate (including invalid swaps, which the board bounces back). Applies
  /// all game-logic side effects immediately for a valid swap.
  ResolutionResult? trySwap(Position a, Position b) {
    if (isBusy || status != GameStatus.playing) return null;

    final result = engine.resolveSwap(board, a, b);
    if (!result.valid) return result;

    isBusy = true;
    board = result.board;
    score += result.score;
    movesLeft -= 1;
    _applyProgress(result);
    notifyListeners();
    return result;
  }

  void _applyProgress(ResolutionResult result) {
    if (objective is CollectColors) {
      for (final tile in result.allClearedTiles) {
        if (tile.type.isMatchable) {
          collected[tile.type] = (collected[tile.type] ?? 0) + 1;
        }
      }
    }
    if (objective is ClearAllJelly) {
      for (final phase in result.phases) {
        for (final pos in phase.cleared) {
          final thickness = jelly[pos];
          if (thickness != null && thickness > 0) {
            jelly[pos] = thickness - 1;
          }
        }
      }
    }
  }

  /// Called by the board when the resolution animation finishes. Evaluates
  /// win/lose. Dead-board shuffling is handled separately via [maybeShuffle] so
  /// the board can *animate* the reshuffle instead of teleporting tiles.
  void onAnimationComplete() {
    isBusy = false;
    final met = objectiveMet;
    if (objective is ReachScore) {
      if (movesLeft <= 0) {
        status = met ? GameStatus.won : GameStatus.lost;
      }
    } else {
      if (met) {
        status = GameStatus.won;
      } else if (movesLeft <= 0) {
        status = GameStatus.lost;
      }
    }
    notifyListeners();
  }

  /// If the board is still playable-but-dead (no legal moves), reshuffles it in
  /// place and returns the [ShuffleResult] so the caller can animate the moves.
  /// Returns null when no shuffle is needed or possible.
  ShuffleResult? maybeShuffle() {
    if (status != GameStatus.playing || engine.hasAnyMove(board)) return null;
    final shuffled = engine.shuffle(board);
    if (shuffled.failed) return null;
    board = shuffled.board;
    notifyListeners();
    return shuffled;
  }

  int get starsEarned => level.starsFor(score);

  /// The "one more try" rescue: adds moves and resumes a lost level.
  void grantExtraMoves(int n) {
    movesLeft += n;
    if (status == GameStatus.lost) status = GameStatus.playing;
    notifyListeners();
  }

  /// Clears the busy flag once a booster animation with no win/lose evaluation
  /// (e.g. a shuffle) finishes.
  void clearBusy() {
    if (isBusy) {
      isBusy = false;
      notifyListeners();
    }
  }

  // --- boosters --------------------------------------------------------------

  int boosterCount(BoosterId id) => boosters[id] ?? 0;

  bool canUseBooster(BoosterId id) =>
      status == GameStatus.playing && !isBusy && boosterCount(id) > 0;

  /// The score used for the TARGET card and the progress bar — the level's
  /// score objective, or its top star threshold otherwise.
  int get targetScore {
    final objective = level.objective;
    if (objective is ReachScore) return objective.target;
    return level.starThresholds.last;
  }

  double get scoreProgress =>
      targetScore == 0 ? 1 : (score / targetScore).clamp(0.0, 1.0);

  /// Smash a tapped tile. Returns the result to animate, or null if unavailable
  /// or the tile could not be smashed (booster is refunded in that case).
  ResolutionResult? useLollipop(Position at) {
    if (!canUseBooster(BoosterId.lollipop)) return null;
    final result = engine.applyLollipop(board, at);
    if (!result.valid) return null;
    boosters[BoosterId.lollipop] = boosterCount(BoosterId.lollipop) - 1;
    AnalyticsService.instance.logBoosterUsed('lollipop', level.id);
    _commitBoosterResult(result);
    return result;
  }

  /// Clear every tile of the board's most common colour.
  ResolutionResult? useColorBomb() {
    if (!canUseBooster(BoosterId.colorBomb)) return null;
    final color = dominantColor(board);
    final result = engine.applyClearColor(board, color);
    if (!result.valid) return null;
    boosters[BoosterId.colorBomb] = boosterCount(BoosterId.colorBomb) - 1;
    AnalyticsService.instance.logBoosterUsed('color_bomb', level.id);
    _commitBoosterResult(result);
    return result;
  }

  /// Clear every tile of the board's most common colour using a rewarded ad (no charges consumed).
  ResolutionResult? useColorBombFree() {
    if (isBusy) return null;
    final color = dominantColor(board);
    final result = engine.applyClearColor(board, color);
    if (!result.valid) return null;
    AnalyticsService.instance.logBoosterUsed('color_bomb_free_ad', level.id);
    _commitBoosterResult(result);
    return result;
  }

  void _commitBoosterResult(ResolutionResult result) {
    isBusy = true;
    board = result.board;
    score += result.score;
    _applyProgress(result);
    notifyListeners();
  }

  /// +5 moves (instant, no board animation).
  void useExtraMoves() {
    if (!canUseBooster(BoosterId.extraMoves)) return;
    boosters[BoosterId.extraMoves] = boosterCount(BoosterId.extraMoves) - 1;
    AnalyticsService.instance.logBoosterUsed('extra_moves', level.id);
    movesLeft += 5;
    notifyListeners();
  }

  /// Reshuffle the board. Returns the [ShuffleResult] to animate, or null.
  ShuffleResult? useShuffle() {
    if (!canUseBooster(BoosterId.shuffle)) return null;
    final result = engine.shuffle(board);
    if (result.failed) return null;
    boosters[BoosterId.shuffle] = boosterCount(BoosterId.shuffle) - 1;
    AnalyticsService.instance.logBoosterUsed('shuffle', level.id);
    isBusy = true;
    board = result.board;
    notifyListeners();
    return result;
  }
}
