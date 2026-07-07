import 'package:shared_preferences/shared_preferences.dart';

import '../models/player_progress.dart';

/// Persists [PlayerProgress]. Abstracted behind an interface so it can be
/// swapped for a cloud/repository implementation later, and mocked in tests.
abstract class ProgressStore {
  Future<PlayerProgress> load();
  Future<void> save(PlayerProgress progress);
}

/// Local persistence via `shared_preferences`.
class SharedPrefsProgressStore implements ProgressStore {
  static const _key = 'player_progress_v1';

  @override
  Future<PlayerProgress> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const PlayerProgress();
    try {
      return PlayerProgress.fromJsonString(raw);
    } catch (_) {
      return const PlayerProgress();
    }
  }

  @override
  Future<void> save(PlayerProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, progress.toJsonString());
  }
}

/// Non-persistent fallback (used if platform storage is unavailable).
class InMemoryProgressStore implements ProgressStore {
  PlayerProgress _progress = const PlayerProgress();

  @override
  Future<PlayerProgress> load() async => _progress;

  @override
  Future<void> save(PlayerProgress progress) async => _progress = progress;
}
