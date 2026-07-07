import 'package:flutter/material.dart';

import '../../game_logic/game_logic.dart';
import '../analytics/analytics_service.dart';
import '../audio/audio_service.dart';
import '../game/app_state.dart';
import '../theme/candy_theme.dart';
import '../widgets/section_card.dart';
import '../widgets/tile_widget.dart';

/// A mock store. The coins/hearts shown around the app are cosmetic (derived
/// from stars), so purchases here are display-only — every buy shows a
/// friendly "coming soon". Gives the coin chips a home without real IAP.
class ShopScreen extends StatefulWidget {
  final AppState appState;
  const ShopScreen({super.key, required this.appState});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int get _coins => 1000 + widget.appState.progress.totalStars * 40;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView('ShopScreen');
  }

  @override
  Widget build(BuildContext context) {
    return ThemedPage(
      title: 'Shop',
      children: [
        _Balance(coins: _coins),
        const SizedBox(height: 8),
        SectionCard(
          title: 'Boosters',
          children: [
            _Item(
              leading: const Icon(Icons.icecream_rounded,
                  color: Color(0xFFFF5CA8)),
              title: '3× Lollipop',
              price: '900',
              onBuy: () => _soon(context, '3x_lollipop', '900'),
            ),
            _Item(
              leading: const SizedBox(
                width: 26,
                height: 26,
                child: TileWidget(
                    type: TileType.purple, special: SpecialType.colorBomb),
              ),
              title: '2× Color Bomb',
              price: '1,400',
              onBuy: () => _soon(context, '2x_color_bomb', '1400'),
            ),
            _Item(
              leading:
                  const Icon(Icons.bolt_rounded, color: Color(0xFF2E90FA)),
              title: '5× +5 Moves',
              price: '1,200',
              onBuy: () => _soon(context, '5x_plus_5_moves', '1200'),
            ),
            _Item(
              leading: const Icon(Icons.auto_fix_high_rounded,
                  color: Color(0xFF8E4EC6)),
              title: '3× Magic shuffle',
              price: '700',
              onBuy: () => _soon(context, '3x_magic_shuffle', '700'),
            ),
          ],
        ),
        SectionCard(
          title: 'Coins & lives',
          children: [
            _Item(
              leading: const Icon(Icons.stars_rounded,
                  color: AppColors.gold),
              title: 'Bag of 2,500 coins',
              price: '\$1.99',
              onBuy: () => _soon(context, 'bag_of_2500_coins', '1.99'),
            ),
            _Item(
              leading: const Icon(Icons.favorite_rounded,
                  color: Color(0xFFFF5C7A)),
              title: 'Refill lives',
              price: '600',
              onBuy: () => _soon(context, 'refill_lives', '600'),
            ),
          ],
        ),
        SectionCard(
          title: 'Specials',
          children: [
            _Item(
              leading: const Icon(Icons.lock_open_rounded,
                  color: Color(0xFF3DE07B)),
              title: 'Unlock all levels',
              price: '\$4.99',
              onBuy: () => _soon(context, 'unlock_all_levels', '4.99'),
            ),
            _Item(
              leading: const Icon(Icons.block_rounded, color: Colors.white70),
              title: 'Remove ads',
              price: '\$2.99',
              onBuy: () => _soon(context, 'remove_ads', '2.99'),
            ),
          ],
        ),
      ],
    );
  }

  void _soon(BuildContext context, String itemId, String price) {
    AudioService.instance.tap();
    AnalyticsService.instance.logShopClick(itemId, price);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Store coming soon 🍬'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 1),
    ));
  }
}

class _Balance extends StatelessWidget {
  final int coins;
  const _Balance({required this.coins});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_rounded,
              color: AppColors.gold),
          const SizedBox(width: 10),
          const Text('Your balance',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          const Icon(Icons.stars_rounded,
              color: AppColors.gold, size: 20),
          const SizedBox(width: 6),
          Text('$coins',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final Widget leading;
  final String title;
  final String price;
  final VoidCallback onBuy;
  const _Item({
    required this.leading,
    required this.title,
    required this.price,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 30, child: Center(child: leading)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(title, style: const TextStyle(fontSize: 14))),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: onBuy,
            child: Text(price,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
