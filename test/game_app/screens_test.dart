import 'package:candy_crush/game_app/audio/audio_service.dart';
import 'package:candy_crush/game_app/data/levels.dart';
import 'package:candy_crush/game_app/data/progress_store.dart';
import 'package:candy_crush/game_app/game/app_state.dart';
import 'package:candy_crush/game_app/models/player_progress.dart';
import 'package:candy_crush/game_app/screens/game_screen.dart';
import 'package:candy_crush/game_app/screens/how_to_play_screen.dart';
import 'package:candy_crush/game_app/screens/level_map_screen.dart';
import 'package:candy_crush/game_app/screens/profile_screen.dart';
import 'package:candy_crush/game_app/screens/settings_screen.dart';
import 'package:candy_crush/game_app/screens/shop_screen.dart';
import 'package:candy_crush/game_app/screens/splash_screen.dart';
import 'package:candy_crush/game_app/theme/candy_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AppState _appState() => AppState(InMemoryProgressStore(), const PlayerProgress());

void main() {
  setUp(() {
    AudioService.instance.enabled = false;
  });

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('level map renders at phone size without overflow',
      (tester) async {
    await phone(tester);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: LevelMapScreen(appState: _appState()),
    ));
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.text('Lollipop Lane'), findsOneWidget);
  });

  testWidgets('game screen renders at phone size without overflow',
      (tester) async {
    await phone(tester);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: GameScreen(appState: _appState(), level: levelById(1)),
    ));
    await tester.pump(); // build board
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.text('SCORE'), findsOneWidget);
    expect(find.text('TARGET'), findsOneWidget);
    expect(find.text('Lollipop'), findsOneWidget); // booster label
  });

  testWidgets('settings page renders its sections', (tester) async {
    await phone(tester);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: SettingsScreen(appState: _appState()),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Sound effects'), findsOneWidget);
    expect(find.text('Reduced motion'), findsOneWidget);
    expect(find.text('Reset progress'), findsOneWidget);
  });

  test('resetProgress wipes stars and re-locks levels', () async {
    final app = AppState(InMemoryProgressStore(), const PlayerProgress());
    await app.recordLevelResult(1, 3);
    expect(app.progress.totalStars, 3);
    expect(app.progress.highestUnlocked, 2);

    await app.resetProgress();
    expect(app.progress.totalStars, 0);
    expect(app.progress.highestUnlocked, 1);
  });

  testWidgets('how-to-play page renders', (tester) async {
    await phone(tester);
    await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(), home: const HowToPlayScreen()));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('How to Play'), findsOneWidget); // page title
    expect(find.text('Lollipop'), findsOneWidget); // a booster row
  });

  testWidgets('profile page renders stats and achievements', (tester) async {
    await phone(tester);
    await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(), home: ProfileScreen(appState: _appState())));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Guest Player'), findsOneWidget);
    expect(find.text('First Win'), findsOneWidget); // an achievement badge
  });

  testWidgets('shop page renders', (tester) async {
    await phone(tester);
    await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(), home: ShopScreen(appState: _appState())));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Shop'), findsOneWidget);
    expect(find.text('Your balance'), findsOneWidget);
  });

  testWidgets('landing has no facebook/guest and its settings gear opens',
      (tester) async {
    await phone(tester);
    await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(), home: SplashScreen(appState: _appState())));
    await tester.pump(const Duration(seconds: 1)); // let the intro settle

    expect(find.text('PLAY NOW'), findsOneWidget);
    expect(find.text('Continue as Guest  →'), findsNothing);
    expect(find.text('Sign In with Facebook'), findsNothing);

    // The settings gear must actually reach the settings page.
    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Settings'), findsOneWidget);
  });
}
