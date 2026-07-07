import 'package:flutter/foundation.dart';

import '../data/progress_store.dart';
import '../models/player_progress.dart';

/// Root, app-wide state: the persisted [PlayerProgress] and the store behind
/// it. Lives above the navigation tree and is loaded once at startup.
class AppState extends ChangeNotifier {
  final ProgressStore store;
  PlayerProgress progress;

  AppState(this.store, this.progress);

  static Future<AppState> load(ProgressStore store) async {
    final progress = await store.load();
    return AppState(store, progress);
  }

  /// Records the outcome of a level and persists it. Returns whether this
  /// beat the previous best for that level.
  Future<bool> recordLevelResult(int levelId, int stars) async {
    final previousBest = progress.starsFor(levelId);
    progress = progress.recordResult(levelId, stars);
    notifyListeners();
    await store.save(progress);
    return stars > previousBest;
  }

  /// Wipes all saved progress back to a fresh account.
  Future<void> resetProgress() async {
    progress = const PlayerProgress();
    notifyListeners();
    await store.save(progress);
  }
}
