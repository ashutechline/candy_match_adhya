import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'game_app/analytics/analytics_service.dart';
import 'game_app/notifications/notification_service.dart';

import 'game_app/audio/audio_service.dart';
import 'game_app/data/progress_store.dart';
import 'game_app/game/app_state.dart';
import 'game_app/game/settings_service.dart';
import 'game_app/screens/launch_screen.dart';
import 'game_app/theme/candy_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Register background messaging handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Pass all uncaught "fatal" errors from the framework to Crashlytics
      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      };

      // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } catch (e) {
      debugPrint('Firebase initialization failed: $e');
    }
  }
  AnalyticsService.instance.init();
  await NotificationService.instance.init();

  await AudioService.instance.init();
  await SettingsService.instance.init();

  // Prefer local persistence; fall back to in-memory if storage is unavailable
  // (e.g. an unsupported platform) so the game still runs.
  ProgressStore store;
  try {
    store = SharedPrefsProgressStore();
    await store.load();
  } catch (_) {
    store = InMemoryProgressStore();
  }
  final appState = await AppState.load(store);

  runApp(CandyMatchApp(appState: appState));
}

class CandyMatchApp extends StatefulWidget {
  final AppState appState;
  const CandyMatchApp({super.key, required this.appState});

  @override
  State<CandyMatchApp> createState() => _CandyMatchAppState();
}

class _CandyMatchAppState extends State<CandyMatchApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      AudioService.instance.pauseMusic();
    } else if (state == AppLifecycleState.resumed) {
      AudioService.instance.resumeMusic();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Candy Match',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: LaunchScreen(appState: widget.appState),
    );
  }
}
