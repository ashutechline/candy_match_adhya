import 'package:flutter/material.dart';

import '../audio/audio_service.dart';
import '../theme/candy_theme.dart';
import 'celebration.dart';

/// A row of up to three earned/empty stars.
class StarsRow extends StatelessWidget {
  final int count;
  final double size;
  const StarsRow({super.key, required this.count, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++)
          Icon(
            i < count ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: i < count ? AppColors.gold : Colors.white24,
          ),
      ],
    );
  }
}

/// What the player chose on an end-of-level dialog.
enum EndAction { next, replay, map, extraMoves }

Future<EndAction> showWinDialog(
  BuildContext context, {
  required int stars,
  required int score,
  required bool hasNext,
}) async {
  AudioService.instance.win();
  final action = await showGeneralDialog<EndAction>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'win',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, _, _) => Stack(
      children: [
        const Positioned.fill(child: ConfettiOverlay()),
        Center(
          child: _CandyDialog(
            title: 'Level Complete!',
            children: [
              AnimatedStars(count: stars, size: 56),
              const SizedBox(height: 12),
              Text('$score points',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gold)),
              const SizedBox(height: 20),
              if (hasNext)
                _PrimaryButton(
                  label: 'Next Level',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () => Navigator.of(context).pop(EndAction.next),
                ),
              const SizedBox(height: 8),
              _SecondaryButton(
                label: 'Replay',
                onPressed: () => Navigator.of(context).pop(EndAction.replay),
              ),
              _SecondaryButton(
                label: 'Level Map',
                onPressed: () => Navigator.of(context).pop(EndAction.map),
              ),
            ],
          ),
        ),
      ],
    ),
    transitionBuilder: (context, anim, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: child,
    ),
  );
  return action ?? EndAction.map;
}

Future<EndAction> showLoseDialog(
  BuildContext context, {
  required bool canAddMoves,
}) async {
  AudioService.instance.lose();
  final action = await showDialog<EndAction>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _CandyDialog(
      title: 'Out of Moves',
      children: [
        const Icon(Icons.sentiment_dissatisfied_rounded,
            size: 56, color: Colors.white54),
        const SizedBox(height: 16),
        if (canAddMoves) ...[
          _PrimaryButton(
            label: 'Keep Going  (+5 moves)',
            icon: Icons.add_circle_outline_rounded,
            onPressed: () => Navigator.of(context).pop(EndAction.extraMoves),
          ),
          const SizedBox(height: 8),
        ],
        _SecondaryButton(
          label: 'Retry',
          onPressed: () => Navigator.of(context).pop(EndAction.replay),
        ),
        _SecondaryButton(
          label: 'Level Map',
          onPressed: () => Navigator.of(context).pop(EndAction.map),
        ),
      ],
    ),
  );
  return action ?? EndAction.map;
}

class _CandyDialog extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _CandyDialog({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _PrimaryButton(
      {required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: () {
          AudioService.instance.tap();
          onPressed();
        },
        icon: Icon(icon),
        label: Text(label,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _SecondaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        AudioService.instance.tap();
        onPressed();
      },
      child: Text(label, style: const TextStyle(fontSize: 15)),
    );
  }
}

Future<bool> showColorBombAdDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) => _CandyDialog(
      title: 'Use Color Bomb',
      children: [
        const Icon(Icons.play_circle_outline_rounded, size: 56, color: AppColors.accent),
        const SizedBox(height: 16),
        const Text(
          'Watch a short video ad to use the Color Bomb booster.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 8),
        const Text(
          'The booster will activate immediately after the ad plays.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.white60),
        ),
        const SizedBox(height: 24),
        _PrimaryButton(
          label: 'Watch Ad & Use',
          icon: Icons.play_arrow_rounded,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: 8),
        _SecondaryButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

Future<bool> showExitGameDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) => _CandyDialog(
      title: 'Exit Level?',
      children: [
        const Icon(Icons.exit_to_app_rounded, size: 56, color: AppColors.accent),
        const SizedBox(height: 16),
        const Text(
          'Are you sure you want to quit? Any progress in this level will be lost.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 24),
        _PrimaryButton(
          label: 'Yes, Exit',
          icon: Icons.logout_rounded,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: 8),
        _SecondaryButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

Future<bool> showExitAppDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) => _CandyDialog(
      title: 'Exit Game',
      children: [
        const Icon(Icons.exit_to_app_rounded, size: 56, color: AppColors.accent),
        const SizedBox(height: 16),
        const Text(
          'Are you sure you want to exit the game?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 24),
        _PrimaryButton(
          label: 'Exit',
          icon: Icons.power_settings_new_rounded,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: 8),
        _SecondaryButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

