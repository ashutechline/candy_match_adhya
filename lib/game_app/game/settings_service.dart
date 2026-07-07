import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted non-audio preferences (accessibility). Audio toggles live on
/// [AudioService]; this holds reduced-motion and haptics. Safe to touch under
/// `flutter test` — a missing platform plugin just falls back to defaults.
class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  /// Dials back particles + screen shake for motion-sensitive players.
  final ValueNotifier<bool> reducedMotion = ValueNotifier(false);

  /// Haptic feedback on swaps/clears.
  final ValueNotifier<bool> haptics = ValueNotifier(true);

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      reducedMotion.value = prefs.getBool('reduced_motion') ?? false;
      haptics.value = prefs.getBool('haptics') ?? true;
    } catch (_) {
      // Preferences unavailable — keep defaults.
    }
  }

  Future<void> setReducedMotion(bool value) async {
    reducedMotion.value = value;
    await _persist('reduced_motion', value);
  }

  Future<void> setHaptics(bool value) async {
    haptics.value = value;
    await _persist('haptics', value);
  }

  Future<void> _persist(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }
}
