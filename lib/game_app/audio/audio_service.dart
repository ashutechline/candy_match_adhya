import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small game-audio layer over `audioplayers`.
///
/// * A round-robin pool of players lets rapid-fire pops overlap without cutting
///   each other off (the classic cascade-audio problem).
/// * Cascade depth raises the pop pitch via pre-rendered `pop_0..pop_5`.
/// * Every call is wrapped so a missing platform plugin (e.g. under
///   `flutter test`) silently no-ops instead of throwing.
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  static const _poolSize = 6;
  static const _popCount = 6;

  /// Master switch. Tests set this false so no platform channels are touched.
  bool enabled = true;

  final ValueNotifier<bool> sfxOn = ValueNotifier(true);
  final ValueNotifier<bool> musicOn = ValueNotifier(true);

  final List<AudioPlayer> _pool = [];
  int _next = 0;
  AudioPlayer? _music;

  Future<void> init() async {
    if (!enabled) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      sfxOn.value = prefs.getBool('audio_sfx') ?? true;
      musicOn.value = prefs.getBool('audio_music') ?? true;
    } catch (_) {
      // Preferences unavailable — keep defaults.
    }
    if (musicOn.value) startMusic();
  }

  // --- public SFX ------------------------------------------------------------

  void tap() => _sfx('audio/tap.wav', volume: 0.6);
  void swap() => _sfx('audio/swap.wav', volume: 0.7);
  void invalid() => _sfx('audio/invalid.wav', volume: 0.7);
  void special() => _sfx('audio/special.wav', volume: 0.8);
  void star() => _sfx('audio/star.wav', volume: 0.9);
  void win() => _sfx('audio/win.wav', volume: 0.9);
  void lose() => _sfx('audio/lose.wav', volume: 0.8);

  /// Pop whose pitch rises with the cascade [level] (1-based).
  void pop(int level) {
    final index = (level - 1).clamp(0, _popCount - 1);
    _sfx('audio/pop_$index.wav', volume: 0.7);
  }

  // --- settings --------------------------------------------------------------

  Future<void> toggleSfx() async {
    sfxOn.value = !sfxOn.value;
    if (sfxOn.value) tap();
    await _persist('audio_sfx', sfxOn.value);
  }

  Future<void> toggleMusic() async {
    musicOn.value = !musicOn.value;
    musicOn.value ? startMusic() : stopMusic();
    await _persist('audio_music', musicOn.value);
  }

  void startMusic() {
    if (!enabled) return;
    _safe(() async {
      _music ??= AudioPlayer()..setReleaseMode(ReleaseMode.loop);
      await _music!.setVolume(0.35);
      await _music!.play(AssetSource('audio/music.wav'));
    });
  }

  void stopMusic() {
    _safe(() async => _music?.stop());
  }

  void pauseMusic() {
    _safe(() async => _music?.pause());
  }

  void resumeMusic() {
    if (!enabled || !musicOn.value) return;
    _safe(() async => _music?.resume());
  }

  // --- internals -------------------------------------------------------------

  void _sfx(String asset, {double volume = 1.0}) {
    if (!enabled || !sfxOn.value) return;
    _safe(() async {
      final player = _acquire();
      await player.stop();
      await player.play(AssetSource(asset), volume: volume);
    });
  }

  AudioPlayer _acquire() {
    if (_pool.length < _poolSize) {
      final player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      _pool.add(player);
      return player;
    }
    final player = _pool[_next % _pool.length];
    _next++;
    return player;
  }

  Future<void> _persist(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }

  void _safe(Future<void> Function() action) {
    if (!enabled) return;
    try {
      unawaited(action().catchError((_) {}));
    } catch (_) {}
  }
}
