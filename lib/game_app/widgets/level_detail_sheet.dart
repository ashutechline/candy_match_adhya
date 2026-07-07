import 'package:flutter/material.dart';

import '../audio/audio_service.dart';
import '../models/level.dart';
import '../theme/candy_theme.dart';
import 'dialogs.dart';

/// A pre-play preview shown when a level node is tapped on the map: objective,
/// move limit, best stars, and a Play button. Replaces the old in-game
/// pre-level dialog so the info appears before you enter.
Future<void> showLevelDetailSheet(
  BuildContext context, {
  required LevelDef level,
  required int bestStars,
  required VoidCallback onPlay,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: [Color(0xFFFF5CA8), Color(0xFFB44BD6)]),
              ),
              child: Text('${level.id}',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 12),
            Text('Level ${level.id}',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(level.objective.label,
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text('${level.moveLimit} moves',
                style:
                    TextStyle(color: Colors.white.withValues(alpha: 0.7))),
            const SizedBox(height: 14),
            Column(
              children: [
                StarsRow(count: bestStars, size: 34),
                const SizedBox(height: 2),
                Text(bestStars > 0 ? 'Your best' : 'Not cleared yet',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6))),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  AudioService.instance.tap();
                  Navigator.of(ctx).pop();
                  onPlay();
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Play',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    ),
  );
}
