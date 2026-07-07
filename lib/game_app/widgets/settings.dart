import 'package:flutter/material.dart';

import '../audio/audio_service.dart';
import '../game/app_state.dart';
import '../screens/settings_screen.dart';

/// A round settings button that opens the full [SettingsScreen].
class SettingsButton extends StatelessWidget {
  final AppState appState;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;

  const SettingsButton({
    super.key,
    required this.appState,
    this.padding,
    this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Settings',
      padding: padding,
      constraints: constraints,
      icon: const Icon(Icons.settings_rounded),
      onPressed: () {
        AudioService.instance.tap();
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SettingsScreen(appState: appState),
        ));
      },
    );
  }
}
