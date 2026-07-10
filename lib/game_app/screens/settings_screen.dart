import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:get/get.dart';

import '../../ads/ad_service.dart';

import '../analytics/analytics_service.dart';
import '../audio/audio_service.dart';
import '../game/app_state.dart';
import '../game/settings_service.dart';
import '../theme/candy_theme.dart';
import 'how_to_play_screen.dart';

/// Full settings page: audio, accessibility, progress and about.
class SettingsScreen extends StatefulWidget {
  final AppState appState;
  const SettingsScreen({super.key, required this.appState});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView('SettingsScreen');
  }

  @override
  Widget build(BuildContext context) {
    final audio = AudioService.instance;
    final settings = SettingsService.instance;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.backgroundGradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () {
                        AudioService.instance.tap();
                        Get.find<AdService>().showInterstitialAd(
                          onAdDismissed: () {
                            Navigator.of(context).maybePop();
                          },
                          onAdFailed: () {
                            Navigator.of(context).maybePop();
                          },
                        );
                      },
                    ),
                    const Text('Settings',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    _Section(
                      title: 'Audio',
                      children: [
                        ValueListenableBuilder<bool>(
                          valueListenable: audio.musicOn,
                          builder: (context, on, _) => _SwitchRow(
                            icon: Icons.music_note_rounded,
                            label: 'Music',
                            value: on,
                            onChanged: (_) {
                              audio.toggleMusic();
                              AnalyticsService.instance.logSettingChanged('music', !on);
                            },
                          ),
                        ),
                        ValueListenableBuilder<bool>(
                          valueListenable: audio.sfxOn,
                          builder: (context, on, _) => _SwitchRow(
                            icon: Icons.graphic_eq_rounded,
                            label: 'Sound effects',
                            value: on,
                            onChanged: (_) {
                              audio.toggleSfx();
                              AnalyticsService.instance.logSettingChanged('sfx', !on);
                            },
                          ),
                        ),
                      ],
                    ),
                    _Section(
                      title: 'Accessibility',
                      children: [
                        ValueListenableBuilder<bool>(
                          valueListenable: settings.reducedMotion,
                          builder: (context, on, _) => _SwitchRow(
                            icon: Icons.motion_photos_off_rounded,
                            label: 'Reduced motion',
                            subtitle: 'Fewer particles and no screen shake',
                            value: on,
                            onChanged: (val) {
                              settings.setReducedMotion(val);
                              AnalyticsService.instance.logSettingChanged('reduced_motion', val);
                            },
                          ),
                        ),
                        ValueListenableBuilder<bool>(
                          valueListenable: settings.haptics,
                          builder: (context, on, _) => _SwitchRow(
                            icon: Icons.vibration_rounded,
                            label: 'Haptics',
                            subtitle: 'Vibrate on matches',
                            value: on,
                            onChanged: (val) {
                              settings.setHaptics(val);
                              AnalyticsService.instance.logSettingChanged('haptics', val);
                            },
                          ),
                        ),
                      ],
                    ),
                    _Section(
                      title: 'Help',
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.help_outline_rounded),
                          title: const Text('How to play'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            AudioService.instance.tap();
                            Get.find<AdService>().showInterstitialAd(
                              onAdDismissed: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => const HowToPlayScreen(),
                                ));
                              },
                              onAdFailed: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => const HowToPlayScreen(),
                                ));
                              },
                            );
                          },
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.privacy_tip_rounded),
                          title: const Text('Privacy Policy'),
                          trailing: const Icon(Icons.open_in_new_rounded),
                          onTap: () async {
                            AudioService.instance.tap();
                            final url = Uri.parse('https://sites.google.com/view/candymatchprivacy/home');
                            try {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            } catch (_) {}
                          },
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.description_rounded),
                          title: const Text('Terms & Conditions'),
                          trailing: const Icon(Icons.open_in_new_rounded),
                          onTap: () async {
                            AudioService.instance.tap();
                            final url = Uri.parse('https://sites.google.com/view/candymatchterms/home');
                            try {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            } catch (_) {}
                          },
                        ),
                      ],
                    ),
                    _Section(
                      title: 'Progress',
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.restart_alt_rounded,
                              color: Color(0xFFFF5C7A)),
                          title: const Text('Reset progress'),
                          subtitle: Text('Clears all stars and locks levels',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6))),
                          onTap: () => _confirmReset(context),
                        ),
                      ],
                    ),
                    _Section(
                      title: 'About',
                      children: [
                        const _InfoRow(label: 'Candy Match', value: 'v1.0.0'),
                        const _InfoRow(
                            label: 'Made with', value: 'Flutter 💙'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    AudioService.instance.tap();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Reset progress?'),
        content: const Text(
            'This wipes every earned star and re-locks all levels. This '
            'cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF5C7A)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      AnalyticsService.instance.logResetProgress();
      await widget.appState.resetProgress();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Progress reset'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(title.toUpperCase(),
                style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.2,
                    color: Colors.white.withValues(alpha: 0.6))),
          ),
          Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(children: children),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.accent,
      secondary: Icon(icon),
      title: Text(label),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!,
              style:
                  TextStyle(color: Colors.white.withValues(alpha: 0.6))),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}
