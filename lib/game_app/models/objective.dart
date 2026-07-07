import '../../game_logic/game_logic.dart';

/// A level win condition. Sealed so the controller can evaluate progress with
/// an exhaustive `switch`.
sealed class Objective {
  const Objective();

  /// Short HUD label, e.g. "Reach 2000 pts" or "Clear the jelly".
  String get label;
}

/// Reach a target score before running out of moves.
class ReachScore extends Objective {
  final int target;
  const ReachScore(this.target);

  @override
  String get label => 'Reach $target pts';
}

/// Collect a quota of specific candy colours (order-independent).
class CollectColors extends Objective {
  final Map<TileType, int> quotas;
  const CollectColors(this.quotas);

  @override
  String get label => 'Collect fruit';
}

/// Clear every jellied cell on the board.
class ClearAllJelly extends Objective {
  const ClearAllJelly();

  @override
  String get label => 'Clear the jelly';
}
