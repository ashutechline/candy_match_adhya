import 'dart:math' as math;

import 'package:candy_crush/game_app/audio/audio_service.dart';
import 'package:candy_crush/game_app/data/levels.dart';
import 'package:candy_crush/game_app/game/game_controller.dart';
import 'package:candy_crush/game_app/widgets/board_view.dart';
import 'package:candy_crush/game_logic/game_logic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

(Position, Position)? _firstValidSwap(GameController c) {
  for (final p in c.board.playablePositions()) {
    for (final q in [p.right, p.down]) {
      if (c.board.isPlayable(q) && c.engine.resolveSwap(c.board, p, q).valid) {
        return (p, q);
      }
    }
  }
  return null;
}

void main() {
  setUp(() => AudioService.instance.enabled = false);

  testWidgets('tapping two adjacent tiles animates and resolves a swap',
      (tester) async {
    final level = levelById(1); // 7x7, seeded -> deterministic board
    final controller = GameController.forLevel(level);
    final swap = _firstValidSwap(controller)!;

    const boardBox = 420.0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: boardBox,
          height: boardBox,
          child: BoardView(controller: controller),
        ),
      ),
    ));
    await tester.pump();

    final cell = math.min(boardBox / level.cols, boardBox / level.rows);
    Offset center(Position p) =>
        Offset((p.col + 0.5) * cell, (p.row + 0.5) * cell);

    // Tap-then-tap on adjacent cells.
    await tester.tapAt(center(swap.$1));
    await tester.pump();
    await tester.tapAt(center(swap.$2));

    // Mid-playback: logic already applied, but the board is still animating
    // (proving it does not snap to the final state instantly).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(controller.movesLeft, level.moveLimit - 1);
    expect(controller.isBusy, isTrue,
        reason: 'board should still be animating, not snapped');

    // Advance through the whole resolution animation.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    expect(controller.movesLeft, level.moveLimit - 1);
    expect(controller.score, greaterThan(0));
    expect(controller.isBusy, isFalse);
    expect(hasAnyMatch(controller.board), isFalse);
  });
}
