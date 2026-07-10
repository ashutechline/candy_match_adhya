import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'firebase_options.dart';
import 'ads/ad_service.dart';
import 'ads/controller/ads_response_service.dart';
import 'game_app/analytics/analytics_service.dart';
import 'game_app/notifications/notification_service.dart';

import 'game_app/audio/audio_service.dart';
import 'game_app/data/progress_store.dart';
import 'game_app/game/app_state.dart';
import 'game_app/game/settings_service.dart';
import 'game_app/screens/launch_screen.dart';
import 'game_app/theme/candy_theme.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await GetStorage.init();

      final isMobile = !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);

      if (isMobile) {
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
          Get.put(FirebaseAnalytics.instance);

          // Register background messaging handler
          FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

          await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
          FlutterError.onError = (FlutterErrorDetails details) {
            final msg = details.exception.toString();
            final isGmaJsEngineError = msg.contains('LoadAdError') &&
                msg.contains('com.google.android.gms.ads') &&
                msg.contains('Unable to obtain a JavascriptEngine');
            final isPlatformViewAlreadyAdded =
                msg.contains('PlatformView#getView') && msg.contains('already added to a parent view');
            final isAdMobInternalError = msg.contains('LoadAdError') &&
                msg.contains('com.google.android.gms.ads') &&
                msg.contains('Internal error.');
            if (isGmaJsEngineError || isPlatformViewAlreadyAdded || isAdMobInternalError) {
              FirebaseCrashlytics.instance.recordFlutterError(details);
            } else {
              FirebaseCrashlytics.instance.recordFlutterFatalError(details);
            }
          };
        } catch (e) {
          debugPrint('Firebase initialization failed: $e');
        }
      }

      Get.put(AdsResponseService(), permanent: true);
      final adService = Get.put(AdService(), permanent: true);
      await adService.initializeAds();

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
    },
    (error, stack) {
      final msg = error.toString();
      final isGmaJsEngineError = msg.contains('LoadAdError') &&
          msg.contains('com.google.android.gms.ads') &&
          msg.contains('Unable to obtain a JavascriptEngine');
      final isPlatformViewAlreadyAdded =
          msg.contains('PlatformView#getView') && msg.contains('already added to a parent view');
      final isAdMobInternalError =
          msg.contains('LoadAdError') && msg.contains('com.google.android.gms.ads') && msg.contains('Internal error.');
      final isNonFatal = isGmaJsEngineError || isPlatformViewAlreadyAdded || isAdMobInternalError;

      final isMobile = !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);

      if (isMobile) {
        FirebaseCrashlytics.instance.recordError(
          error,
          stack,
          fatal: !isNonFatal,
        );
      } else {
        debugPrint('Zoned error: $error\n$stack');
      }
    },
  );
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
    return GetMaterialApp(
      title: 'Candy Match',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      navigatorObservers: [
        if (Get.isRegistered<FirebaseAnalytics>())
          FirebaseAnalyticsObserver(analytics: Get.find<FirebaseAnalytics>()),
      ],
      home: LaunchScreen(appState: widget.appState),
    );
  }
}

