import 'package:candy_crush/game_app/audio/audio_service.dart';
import 'package:candy_crush/game_app/data/progress_store.dart';
import 'package:candy_crush/game_app/game/app_state.dart';
import 'package:candy_crush/game_app/models/player_progress.dart';
import 'package:candy_crush/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => AudioService.instance.enabled = false);

  testWidgets('launch splash shows, then navigates to the landing',
      (tester) async {
    // Portrait phone viewport (matches the reference aspect).
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final appState = AppState(InMemoryProgressStore(), const PlayerProgress());
    await tester.pumpWidget(CandyMatchApp(appState: appState));

    // The launch splash is shown first, no overflow.
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    expect(find.text('Candy Match'), findsOneWidget);

    // It auto-advances to the landing screen.
    await tester.pump(const Duration(milliseconds: 2000)); // finish + navigate
    await tester.pump(const Duration(milliseconds: 600)); // fade transition
    expect(tester.takeException(), isNull);
    expect(find.text('MATCH 3 PUZZLE'), findsOneWidget);
    expect(find.text('PLAY NOW'), findsOneWidget);
  });
}
