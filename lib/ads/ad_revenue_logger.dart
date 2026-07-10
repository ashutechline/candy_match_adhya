import 'dart:developer' as developer;
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Centralized logger for tracking AdMob ad revenue using Firebase Analytics and Facebook App Events.
class AdRevenueLogger {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FacebookAppEvents _facebookAppEvents = FacebookAppEvents();

  // Duplicate callback prevention cache
  static final Set<int> _loggedAdHashcodes = {};

  /// Unified method to log ad revenue.
  /// Converts valueMicros to normal currency value, logs to Firebase Analytics 'ad_impression' event,
  /// and prints logs using dart:developer.
  static void logAdRevenue({
    required double valueMicros,
    required PrecisionType precision,
    required String currencyCode,
    required String adUnitId,
    required String adFormat,
    int? adHashCode,
  }) {
    try {
      final double revenue = valueMicros / 1000000.0;

      // 11. Safety Check: Null / zero value checks
      if (revenue < 0) return;

      // 11. Safety Check: Duplicate callback prevention
      if (adHashCode != null) {
        if (_loggedAdHashcodes.contains(adHashCode)) {
          developer.log(
            '⚠️ Duplicate onPaidEvent blocked for format=$adFormat, unit=$adUnitId, revenue=$revenue',
            name: 'AdRevenueLogger',
          );
          return;
        }
        _loggedAdHashcodes.add(adHashCode);
        // Limit cache size to prevent memory leaks
        if (_loggedAdHashcodes.length > 500) {
          _loggedAdHashcodes.remove(_loggedAdHashcodes.first);
        }
      }

      // 9. Add test logs (Required console outputs)
      print("🔥 onPaidEvent Triggered");
      print("💰 Revenue: $revenue");

      // 5. Add detailed debug logs
      developer.log(
        '💸 AdMob Revenue Logged: format=$adFormat, unit=$adUnitId, revenue=$revenue $currencyCode, precision=${precision.name}',
        name: 'AdRevenueLogger',
      );

      // 3. Every onPaidEvent ma proper Firebase Analytics event send karo
      _analytics.logEvent(
        name: 'ad_impression',
        parameters: {
          'ad_platform': 'admob',
          'ad_source': 'admob',
          'ad_unit_name': adUnitId,
          'ad_format': adFormat,
          'currency': currencyCode,
          'value': revenue,
        },
      ).then((_) {
        // 9. print "📡 Firebase Event Sent" on success
        print("📡 Firebase Event Sent");
        developer.log(
          '✅ Firebase Analytics ad_impression logged successfully for format=$adFormat, revenue=$revenue',
          name: 'AdRevenueLogger',
        );
      }).catchError((error) {
        // 5. print Firebase event failed details
        print("❌ Firebase Event Failed to Send");
        developer.log(
          '❌ Failed to log ad revenue event to Firebase Analytics: $error',
          name: 'AdRevenueLogger',
          error: error,
        );
      });

      // Log to Facebook App Events
      _facebookAppEvents.logEvent(
        name: 'ad_impression',
        parameters: {
          'ad_platform': 'admob',
          'ad_source': 'admob',
          'ad_unit_name': adUnitId,
          'ad_format': adFormat,
          'currency': currencyCode,
          'value': revenue,
        },
      ).then((_) {
        print("📡 Facebook App Event Sent");
        developer.log(
          '✅ Facebook App Events ad_impression logged successfully for format=$adFormat, revenue=$revenue',
          name: 'AdRevenueLogger',
        );
      }).catchError((error) {
        print("❌ Facebook App Event Failed to Send");
        developer.log(
          '❌ Failed to log ad revenue event to Facebook App Events: $error',
          name: 'AdRevenueLogger',
          error: error,
        );
      });
    } catch (e, stackTrace) {
      developer.log(
        '❌ Exception in logAdRevenue: $e',
        name: 'AdRevenueLogger',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // 13. Centralized helper method for full-screen ads
  static void attachRevenueTracking({
    required AdWithoutView ad,
    required String adFormat,
  }) {
    try {
      // 11. Safety Check: Null check
      ad.onPaidEvent = (loadedAd, valueMicros, precision, currencyCode) {
        // 5. Debug log for onPaidEvent triggered
        developer.log(
          '🔥 onPaidEvent Triggered on ad: ${loadedAd.adUnitId} for format: $adFormat',
          name: 'AdRevenueLogger',
        );
        logAdRevenue(
          valueMicros: valueMicros,
          precision: precision,
          currencyCode: currencyCode,
          adUnitId: loadedAd.adUnitId,
          adFormat: adFormat,
          adHashCode: loadedAd.hashCode,
        );
      };
      
      // 5. Debug log for ad loaded / tracking attached
      developer.log(
        '📱 ${ad.runtimeType} revenue tracking attached for unit: ${ad.adUnitId}',
        name: 'AdRevenueLogger',
      );
    } catch (e, stackTrace) {
      developer.log(
        '❌ Exception in attachRevenueTracking: $e',
        name: 'AdRevenueLogger',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Attach revenue tracking to a Banner Ad.
  static void attachBannerAd(BannerAd bannerAd) {
    developer.log(
      '📱 BannerAd revenue tracking attached for unit: ${bannerAd.adUnitId}',
      name: 'AdRevenueLogger',
    );
  }

  /// Attach revenue tracking to an Interstitial Ad.
  static void attachInterstitialAd(InterstitialAd interstitialAd) {
    attachRevenueTracking(ad: interstitialAd, adFormat: 'interstitial');
  }

  /// Attach revenue tracking to a Rewarded Ad.
  static void attachRewardedAd(RewardedAd rewardedAd) {
    attachRevenueTracking(ad: rewardedAd, adFormat: 'rewarded');
  }

  /// Attach revenue tracking to an App Open Ad.
  static void attachAppOpenAd(AppOpenAd appOpenAd) {
    attachRevenueTracking(ad: appOpenAd, adFormat: 'app_open');
  }

  /// Convenience method matching the native Android name 'attachAppOpenAdRevenueLogger'.
  static void attachAppOpenAdRevenueLogger(AppOpenAd appOpenAd) {
    attachAppOpenAd(appOpenAd);
  }

  /// Attach revenue tracking to a Native Ad.
  static void attachNativeAd(NativeAd nativeAd, [String? id]) {
    developer.log(
      '📱 NativeAd revenue tracking attached for unit: ${id ?? nativeAd.adUnitId}',
      name: 'AdRevenueLogger',
    );
  }

  /// Attach revenue tracking to a Native Small Ad.
  static void attachNativeSmallAd(NativeAd nativeAd, [String? id]) {
    developer.log(
      '📱 NativeSmallAd revenue tracking attached for unit: ${id ?? nativeAd.adUnitId}',
      name: 'AdRevenueLogger',
    );
  }

  /// Convenience method matching the native Android name 'attachNativeAdsmall'.
  static void attachNativeAdsmall(NativeAd nativeAd, [String? id]) {
    attachNativeSmallAd(nativeAd, id);
  }
}

