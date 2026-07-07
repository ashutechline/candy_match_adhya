import 'package:flutter/material.dart';

import '../../game_logic/game_logic.dart';

/// Distinct silhouettes so the game is playable without relying on colour
/// alone (accessibility requirement for a colour-matching game).
enum CandyShape { circle, roundedSquare, triangle, diamond, star, hexagon }

class CandyStyle {
  final Color color;
  final CandyShape shape;

  const CandyStyle(this.color, this.shape);
}

/// Colour + shape for every tile type.
///
/// "Jewel Confectionery" palette: bright gel tones tuned to read on the dark
/// board. Accessibility rests primarily on the unique SHAPE per colour — play
/// never depends on colour alone. Most fills also clear ~3:1 against the board
/// slot; the warm low-luminance candies (red) lean more on their silhouette +
/// gloss + rim than on raw fill contrast. Luminance rises roughly
/// red/purple < blue < orange < green < yellow.
const Map<TileType, CandyStyle> kCandyStyles = {
  TileType.red: CandyStyle(Color(0xFFFF4D6A), CandyShape.circle),
  TileType.orange: CandyStyle(Color(0xFFFF8C42), CandyShape.roundedSquare),
  TileType.yellow: CandyStyle(Color(0xFFFFD93B), CandyShape.star),
  TileType.green: CandyStyle(Color(0xFF3DE07B), CandyShape.triangle),
  TileType.blue: CandyStyle(Color(0xFF3EA8FF), CandyShape.diamond),
  TileType.purple: CandyStyle(Color(0xFFC46BFF), CandyShape.hexagon),
  TileType.ingredient: CandyStyle(Color(0xFFB07B4F), CandyShape.circle),
};

CandyStyle styleFor(TileType type) =>
    kCandyStyles[type] ?? const CandyStyle(Colors.grey, CandyShape.circle);

/// The fruit shown on each tile — chosen so the fruit's natural colour matches
/// the tile's colour (so colour matching still reads at a glance).
const Map<TileType, String> kFruitEmoji = {
  TileType.red: '🍎',
  TileType.orange: '🍊',
  TileType.yellow: '🍋',
  TileType.green: '🍏',
  TileType.blue: '🫐',
  TileType.purple: '🍇',
  TileType.ingredient: '🍒',
};

String fruitFor(TileType type) => kFruitEmoji[type] ?? '🍓';

/// App-wide colours (Jewel Confectionery).
class AppColors {
  static const background = Color(0xFF17103A);
  static const backgroundGradient = [
    Color(0xFF17103A),
    Color(0xFF241452),
    Color(0xFF3A1B63),
  ];
  static const surface = Color(0xFF2C1E5C);
  static const surfaceLight = Color(0xFF413178);
  static const accent = Color(0xFFFF5CA8);
  static const gold = Color(0xFFFFCC4D);
  static const boardFrame = [Color(0xFF4B3A8F), Color(0xFF2A1C5E)];
  static const boardSlot = Color(0x33FFFFFF);
  static const slotStroke = Color(0x22FFFFFF);
  static const blockedCell = Color(0xFF0A0620);
  static const blockedStroke = Color(0x33FFFFFF);
  static const jelly = Color(0x553FD0E0);

  /// Off-white body text on dark surfaces (reduces halation, keeps >12:1).
  static const textOnDark = Color(0xFFF3ECFF);
}

ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.accent,
      secondary: AppColors.gold,
      surface: AppColors.surface,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textOnDark,
      displayColor: AppColors.textOnDark,
      fontFamilyFallback: const ['Roboto'],
    ),
  );
}
