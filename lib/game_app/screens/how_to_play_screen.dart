import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../analytics/analytics_service.dart';
import '../../game_logic/game_logic.dart';
import '../theme/candy_theme.dart';
import '../widgets/dialogs.dart';
import '../widgets/section_card.dart';
import '../widgets/tile_widget.dart';
import '../../ads/native_ad_builder.dart';
import '../../ads/mixins/native_ad_mixin.dart';

class HowToPlayController extends GetxController with NativeAdMixin {
  @override
  void onInit() {
    super.onInit();
    loadSmallNativeAdAlways();
  }
}

/// A static rules / help page: how to play, objective types, boosters, stars.
class HowToPlayScreen extends StatefulWidget {
  const HowToPlayScreen({super.key});

  @override
  State<HowToPlayScreen> createState() => _HowToPlayScreenState();
}

class _HowToPlayScreenState extends State<HowToPlayScreen> {
  late final HowToPlayController _adController;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView('HowToPlayScreen');
    _adController = Get.put(HowToPlayController());
  }

  @override
  void dispose() {
    Get.delete<HowToPlayController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemedPage(
      title: 'How to Play',
      children: [
        const SectionCard(
          title: 'Basics',
          children: [
            _Row(
              icon: Icons.swap_horiz_rounded,
              title: 'Swap to match',
              text: 'Swap two neighbouring fruits to line up 3 or more of '
                  'the same colour. Matches clear and new fruits drop in.',
            ),
            _Row(
              icon: Icons.auto_awesome_rounded,
              title: 'Make specials',
              text: 'Match 4 for a striped fruit, an L/T shape for a wrapped '
                  'fruit, and 5 in a line for a Color Bomb.',
            ),
            _Row(
              icon: Icons.swap_horiz_rounded,
              title: 'Watch your moves',
              text: 'Every level gives you a limited number of moves — reach '
                  'the goal before they run out.',
            ),
          ],
        ),
        NativeAdBuilder.buildSmallAdWithSpacing(_adController, topSpacing: 0, bottomSpacing: 16),
        SectionCard(
          title: 'Objectives',
          children: [
            const _Row(
              icon: Icons.flag_rounded,
              iconColor: AppColors.gold,
              title: 'Reach a score',
              text: 'Score enough points before you run out of moves.',
            ),
            _Row(
              leading: const SizedBox(
                  width: 26, height: 26, child: TileWidget(type: TileType.red)),
              title: 'Collect fruit',
              text: 'Clear a set number of specific colours.',
            ),
            const _Row(
              icon: Icons.grid_view_rounded,
              iconColor: Color(0xFF3FD0E0),
              title: 'Clear the jelly',
              text: 'Make matches over every jellied cell to remove it.',
            ),
          ],
        ),
        const SectionCard(
          title: 'Boosters',
          children: [
            _Row(
              icon: Icons.icecream_rounded,
              iconColor: Color(0xFFFF5CA8),
              title: 'Lollipop',
              text: 'Arm it, then tap any fruit to smash it.',
            ),
            _Row(
              leading: SizedBox(
                width: 26,
                height: 26,
                child: TileWidget(
                    type: TileType.purple, special: SpecialType.colorBomb),
              ),
              title: 'Color Bomb',
              text: 'Clears every fruit of the board’s most common colour.',
            ),
            _Row(
              icon: Icons.bolt_rounded,
              iconColor: Color(0xFF2E90FA),
              title: '+5 Moves',
              text: 'Adds five moves instantly.',
            ),
            _Row(
              icon: Icons.auto_fix_high_rounded,
              iconColor: Color(0xFF8E4EC6),
              title: 'Magic',
              text: 'Reshuffles the whole board.',
            ),
          ],
        ),
        SectionCard(
          title: 'Stars',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  const StarsRow(count: 3, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Beat a level to earn 1–3 stars — the higher your '
                      'score, the more stars. Collect them all!',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final Widget? leading;
  final String title;
  final String text;

  const _Row({
    this.icon,
    this.iconColor,
    this.leading,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30,
            child: leading ??
                Icon(icon, color: iconColor ?? Colors.white, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text(text,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                        height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
