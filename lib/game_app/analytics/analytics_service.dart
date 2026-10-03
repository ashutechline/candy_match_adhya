import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._();

  AnalyticsService._();

  FirebaseAnalytics? _analytics;
  static final _facebookAppEvents = FacebookAppEvents();

  /// Set to false once AdMob is linked to this Firebase project: the Mobile
  /// Ads SDK then logs `ad_impression` (with revenue) to Firebase by itself,
  /// and logging it here too would double-count ad revenue.
  static const bool logAdImpressionToFirebase = true;

  /// Set to false once Google Play is linked to this Firebase project: the SDK
  /// then logs `in_app_purchase` by itself and does NOT de-duplicate it
  /// against a manual `purchase`, so revenue would be counted twice.
  static const bool logPurchaseToFirebase = true;

  bool get isFirebaseReady => _analytics != null;

  /// Must run after `Firebase.initializeApp()`. Safe to call when Firebase is
  /// unavailable (desktop/web/tests): events are then only printed.
  Future<void> init() async {
    try {
      if (Firebase.apps.isEmpty) {
        debugPrint('AnalyticsService: Firebase Core not initialized. Running in mock mode.');
        return;
      }
      _analytics = FirebaseAnalytics.instance;
      // Collection can be switched off by a native flag or an earlier call;
      // force it on so events actually leave the device.
      await _analytics!.setAnalyticsCollectionEnabled(true);
      debugPrint('AnalyticsService: Firebase Analytics initialized successfully.');
      _send('app_open', () => _analytics!.logAppOpen());
    } catch (e) {
      debugPrint('AnalyticsService: Failed to initialize Firebase Analytics: $e. Running in mock mode.');
    }
  }

  /// Runs a fire-and-forget analytics call. The plugins validate inside
  /// `async` bodies, so failures arrive as a failed Future — a plain try/catch
  /// around an un-awaited call never sees them, and they used to escape to the
  /// zone handler (reported to Crashlytics as fatal crashes).
  void _send(String label, Future<void> Function() call) {
    try {
      call().then(
        (_) => debugPrint('AnalyticsService: Sent $label'),
        onError: (Object e) => debugPrint('AnalyticsService: Failed to send $label: $e'),
      );
    } catch (e) {
      debugPrint('AnalyticsService: Failed to send $label: $e');
    }
  }

  /// Firebase only accepts String or num parameter values (strings up to 100
  /// chars); anything else fails the whole event.
  static Map<String, Object>? _cleanParams(Map<String, Object?>? parameters) {
    if (parameters == null) return null;
    final clean = <String, Object>{};
    parameters.forEach((key, value) {
      if (value == null) return;
      if (value is num) {
        clean[key] = value;
      } else if (value is bool) {
        clean[key] = value ? 1 : 0;
      } else {
        final text = value.toString();
        clean[key] = text.length > 100 ? text.substring(0, 100) : text;
      }
    });
    return clean;
  }

  void logEvent(String name, {Map<String, Object?>? parameters}) {
    final cleanParams = _cleanParams(parameters);

    final analytics = _analytics;
    if (analytics != null) {
      _send('Firebase event "$name" $cleanParams',
          () => analytics.logEvent(name: name, parameters: cleanParams));
    } else {
      debugPrint('AnalyticsService [MOCK]: Event "$name" with parameters: $cleanParams');
    }

    _send('Facebook event "$name"',
        () => _facebookAppEvents.logEvent(name: name, parameters: cleanParams));
  }

  void logScreenView(String screenName) {
    final analytics = _analytics;
    if (analytics != null) {
      _send('Firebase screen view "$screenName"',
          () => analytics.logScreenView(screenName: screenName, screenClass: screenName));
    } else {
      debugPrint('AnalyticsService [MOCK]: Screen View: "$screenName"');
    }

    _send('Facebook screen view "$screenName"',
        () => _facebookAppEvents.logEvent(
              name: 'screen_view',
              parameters: {'screen_name': screenName},
            ));
  }

  /// Ad revenue from an AdMob `onPaidEvent`. Firebase gets the standard
  /// `ad_impression` event (what its revenue reports read) and Facebook gets
  /// its standard `AdImpression` event, so both consoles detect ad revenue.
  void logAdRevenue({
    required double revenue,
    required String currencyCode,
    required String adUnitId,
    required String adFormat,
  }) {
    final analytics = _analytics;
    if (analytics != null && logAdImpressionToFirebase) {
      _send('Firebase ad_impression $adFormat $revenue $currencyCode',
          () => analytics.logAdImpression(
                adPlatform: 'admob',
                adSource: 'admob',
                adFormat: adFormat,
                adUnitName: adUnitId,
                value: revenue,
                currency: currencyCode,
              ));
    } else if (analytics == null) {
      debugPrint('AnalyticsService [MOCK]: ad_impression $adFormat $revenue $currencyCode');
    }

    _send('Facebook AdImpression $adFormat $revenue $currencyCode',
        () => _facebookAppEvents.logEvent(
              name: FacebookAppEvents.eventNameAdImpression,
              valueToSum: revenue,
              parameters: {
                FacebookAppEvents.paramNameCurrency: currencyCode,
                FacebookAppEvents.paramNameAdType: adFormat,
                'ad_unit_name': adUnitId,
              },
            ));
  }

  void logLevelStart(int levelId) {
    logEvent('level_start', parameters: {
      'level_name': 'level_$levelId',
      'level_id': levelId,
    });
  }

  void logLevelEnd(int levelId, bool won, int score, int stars) {
    logEvent('level_end', parameters: {
      'level_name': 'level_$levelId',
      'level_id': levelId,
      'success': won ? 1 : 0,
      'won': won ? 1 : 0,
      'score': score,
      'stars': stars,
    });
    if (won) {
      // Facebook's standard "Achieved Level" event (usable for ad optimization).
      _send('Facebook AchievedLevel $levelId',
          () => _facebookAppEvents.logEvent(
                name: FacebookAppEvents.eventNameAchievedLevel,
                parameters: {FacebookAppEvents.paramNameLevel: '$levelId'},
              ));
    }
  }

  /// The player tapped a real-money product and the store sheet is opening.
  void logBeginCheckout({
    required String productId,
    required double value,
    required String currency,
  }) {
    final analytics = _analytics;
    if (analytics != null) {
      _send('Firebase begin_checkout $productId',
          () => analytics.logBeginCheckout(
                value: value,
                currency: currency,
                items: [AnalyticsEventItem(itemId: productId, price: value, quantity: 1)],
              ));
    } else {
      debugPrint('AnalyticsService [MOCK]: begin_checkout $productId $value $currency');
    }
    _send('Facebook InitiatedCheckout $productId',
        () => _facebookAppEvents.logInitiatedCheckout(
              totalPrice: value,
              currency: currency,
              contentId: productId,
              numItems: 1,
            ));
  }

  /// A completed (store-confirmed) in-app purchase. Firebase gets the
  /// standard `purchase` event and Facebook its standard `Purchase` event —
  /// the ones both consoles read revenue from.
  void logPurchase({
    required String productId,
    required String productName,
    required double value,
    required String currency,
    String? transactionId,
  }) {
    final analytics = _analytics;
    if (analytics != null && logPurchaseToFirebase) {
      _send('Firebase purchase $productId $value $currency',
          () => analytics.logPurchase(
                value: value,
                currency: currency,
                transactionId: transactionId,
                items: [
                  AnalyticsEventItem(
                    itemId: productId,
                    itemName: productName,
                    price: value,
                    quantity: 1,
                  ),
                ],
              ));
    } else if (analytics == null) {
      debugPrint('AnalyticsService [MOCK]: purchase $productId $value $currency');
    }
    _send('Facebook Purchase $productId $value $currency',
        () => _facebookAppEvents.logPurchase(
              amount: value,
              currency: currency,
              parameters: {
                FacebookAppEvents.paramNameContentId: productId,
                FacebookAppEvents.paramNameContentType: 'product',
                if (transactionId != null) FacebookAppEvents.paramNameOrderId: transactionId,
              },
            ));
  }

  void logPurchaseRestored(String productId) {
    logEvent('purchase_restored', parameters: {'item_id': productId});
  }

  void logPurchaseFailed(String productId, String reason) {
    logEvent('purchase_failed', parameters: {'item_id': productId, 'reason': reason});
  }

  /// A review request: the in-app review sheet was requested (`in_app`) or the
  /// store listing was opened from Settings (`store_listing`). Neither store
  /// reports whether a rating was actually submitted, so this is the closest
  /// signal; it is also sent as Facebook's standard "Rate" event.
  void logReviewRequest(String source) {
    logEvent('review_request', parameters: {'source': source});
    _send('Facebook Rated ($source)',
        () => _facebookAppEvents.logRated(parameters: {
              FacebookAppEvents.paramNameContentType: 'app',
              'source': source,
            }));
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
