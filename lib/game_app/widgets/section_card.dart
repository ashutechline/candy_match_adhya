import 'package:flutter/material.dart';

import '../theme/candy_theme.dart';

/// A titled card of rows — the shared section style used across the settings,
/// how-to-play, profile and shop screens. A [Material] (not a plain coloured
/// box) so any `ListTile`/`SwitchListTile` inside has an ink surface.
class SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  const SectionCard({
    super.key,
    required this.title,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
  });

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
              padding: padding,
              child: Column(children: children),
            ),
          ),
        ],
      ),
    );
  }
}

/// A themed full-screen scaffold with the app gradient, a back arrow and a
/// title — the common chrome for the secondary pages.
class ThemedPage extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final EdgeInsetsGeometry listPadding;

  const ThemedPage({
    super.key,
    required this.title,
    required this.children,
    this.listPadding = const EdgeInsets.fromLTRB(16, 4, 16, 24),
  });

  @override
  Widget build(BuildContext context) {
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
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Text(title,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(padding: listPadding, children: children),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
