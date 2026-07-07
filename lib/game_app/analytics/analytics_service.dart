import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._();

  AnalyticsService._();

  bool _isInitialized = false;
  FirebaseAnalytics? _analytics;

  void init() {
    try {
      if (Firebase.apps.isNotEmpty) {
        _analytics = FirebaseAnalytics.instance;
        _isInitialized = true;
        debugPrint('AnalyticsService: Firebase Analytics initialized successfully.');
      } else {
        debugPrint('AnalyticsService: Firebase Core not initialized. Running in mock mode.');
      }
    } catch (e) {
      debugPrint('AnalyticsService: Failed to initialize Firebase Analytics: $e. Running in mock mode.');
    }
  }

  void logEvent(String name, {Map<String, Object?>? parameters}) {
    if (_isInitialized && _analytics != null) {
      try {
        Map<String, Object>? cleanParams;
        if (parameters != null) {
          cleanParams = {};
          for (final entry in parameters.entries) {
            final val = entry.value;
            if (val != null) {
              cleanParams[entry.key] = val;
            }
          }
        }
        _analytics!.logEvent(name: name, parameters: cleanParams);
        debugPrint('AnalyticsService: Logged event "$name" with parameters: $cleanParams');
      } catch (e) {
        debugPrint('AnalyticsService: Failed to log event "$name": $e');
      }
    } else {
      debugPrint('AnalyticsService [MOCK]: Event "$name" with parameters: $parameters');
    }
  }

  void logScreenView(String screenName) {
    if (_isInitialized && _analytics != null) {
      try {
        _analytics!.logScreenView(screenName: screenName);
        debugPrint('AnalyticsService: Logged screen view: "$screenName"');
      } catch (e) {
        debugPrint('AnalyticsService: Failed to log screen view "$screenName": $e');
        logEvent('screen_view', parameters: {'screen_name': screenName});
      }
    } else {
      debugPrint('AnalyticsService [MOCK]: Screen View: "$screenName"');
    }
  }

  void logLevelStart(int levelId) {
    logEvent('level_start', parameters: {
      'level_id': levelId,
    });
  }

  void logLevelEnd(int levelId, bool won, int score, int stars) {
    logEvent('level_end', parameters: {
      'level_id': levelId,
      'won': won ? 1 : 0,
      'score': score,
      'stars': stars,
    });
  }

  void logBoosterUsed(String boosterId, int levelId) {
    logEvent('booster_used', parameters: {
      'booster_id': boosterId,
      'level_id': levelId,
    });
  }

  void logResetProgress() {
    logEvent('reset_progress');
  }

  void logShopClick(String itemId, String price) {
    logEvent('shop_click', parameters: {
      'item_id': itemId,
      'price': price,
    });
  }

  void logSettingChanged(String settingName, bool value) {
    logEvent('setting_changed', parameters: {
      'setting': settingName,
      'value': value ? 1 : 0,
    });
  }
}
