import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../analytics/analytics_service.dart';
import '../data/levels.dart';
import '../game/app_state.dart';
import '../models/player_progress.dart';
import '../theme/candy_theme.dart';
import '../widgets/dialogs.dart';
import '../widgets/section_card.dart';

/// Player profile: aggregate stats, achievements and a per-level breakdown —
/// all derived from [PlayerProgress]. No auth; the player is a "Guest".
class ProfileScreen extends StatefulWidget {
  final AppState appState;
  const ProfileScreen({super.key, required this.appState});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView('ProfileScreen');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        final p = widget.appState.progress;
        final cleared = p.levelsCleared;
        final threeStars = p.starsByLevel.values.where((s) => s == 3).length;
        // Show the most recent cleared/unlocked levels (endless — cap the list).
        final currentLevel = math.min(p.highestUnlocked, 100);
        final firstShown = math.max(1, currentLevel - 29);

        return ThemedPage(
          title: 'Profile',
          children: [
            _Header(stars: p.totalStars),
            const SizedBox(height: 8),
            SectionCard(
              title: 'Stats',
              padding: const EdgeInsets.all(12),
              children: [
                Row(
                  children: [
                    Expanded(
                        child:
                            _Stat(label: 'Stars', value: '${p.totalStars}')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _Stat(label: 'Cleared', value: '$cleared')),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: _Stat(
                            label: 'Current level',
                            value: '${p.highestUnlocked}')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _Stat(
                            label: '3-star levels', value: '$threeStars')),
                  ],
                ),
              ],
            ),
            _Achievements(progress: p),
            SectionCard(
              title: 'Levels',
              children: [
                for (var id = currentLevel; id >= firstShown; id--)
                  _LevelRow(
                    level: id,
                    label: levelById(id).objective.label,
                    stars: p.starsFor(id),
                    locked: !p.isUnlocked(id),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final int stars;
  const _Header({required this.stars});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(colors: [
              Color(0xFFFF4FA3),
              Color(0xFFFFC93C),
              Color(0xFF3DE07B),
              Color(0xFF3EA8FF),
              Color(0xFFC46BFF),
              Color(0xFFFF4FA3),
            ]),
          ),
          child: const Icon(Icons.person_rounded, size: 34),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Guest Player',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.star_rounded, color: AppColors.gold, size: 18),
                const SizedBox(width: 4),
                Text('$stars total stars',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7))),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.gold)),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}

class _Achievements extends StatelessWidget {
  final PlayerProgress progress;
  const _Achievements({required this.progress});

  @override
  Widget build(BuildContext context) {
    final cleared = progress.levelsCleared;
    final threeStars = progress.starsByLevel.values.where((s) => s == 3).length;

    final badges = <(IconData, String, String, bool)>[
      (Icons.emoji_events_rounded, 'First Win', 'Clear a level', cleared >= 1),
      (Icons.cake_rounded, 'Sweet Tooth', 'Clear 5 levels', cleared >= 5),
      (Icons.star_rounded, 'Star Collector', '15+ stars',
          progress.totalStars >= 15),
      (Icons.workspace_premium_rounded, 'Perfectionist', 'Any 3-star level',
          threeStars >= 1),
      (Icons.military_tech_rounded, 'Marathon', 'Clear 20 levels',
          cleared >= 20),
      (Icons.diamond_rounded, 'Star Hoarder', '50+ stars',
          progress.totalStars >= 50),
    ];

    return SectionCard(
      title: 'Achievements',
      padding: const EdgeInsets.all(12),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (icon, name, req, unlocked) in badges)
              _Badge(icon: icon, name: name, req: req, unlocked: unlocked),
          ],
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String name;
  final String req;
  final bool unlocked;
  const _Badge({
    required this.icon,
    required this.name,
    required this.req,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: unlocked ? 1 : 0.4,
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: unlocked
              ? Border.all(color: AppColors.gold, width: 1.5)
              : null,
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 28, color: unlocked ? AppColors.gold : Colors.white54),
            const SizedBox(height: 6),
            Text(name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(req,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 9,
                    color: Colors.white.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  final int level;
  final String label;
  final int stars;
  final bool locked;
  const _LevelRow({
    required this.level,
    required this.label,
    required this.stars,
    required this.locked,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: locked ? 0.45 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: locked
                  ? const Icon(Icons.lock, size: 18, color: Colors.white54)
                  : Text('$level',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            const SizedBox(width: 8),
            Expanded(
                child: Text(label, style: const TextStyle(fontSize: 13))),
            StarsRow(count: stars, size: 16),
          ],
        ),
      ),
    );
  }
}
