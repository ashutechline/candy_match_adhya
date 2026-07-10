import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../ad_service.dart';
import '../ad_revenue_logger.dart';
import '../controller/ads_response_service.dart';

/// Mixin to provide reusable native ad loading functionality
/// Use this mixin in any controller that needs to display native ads
/// Each controller gets its own ad instances to avoid conflicts
mixin NativeAdMixin on GetxController {
  final AdsResponseService adsResponseService = Get.find<AdsResponseService>();
  final _adService = Get.find<AdService>();
  bool _hasCountedNavigation = false;
  bool _isMixinDisposed = false; // RULE 3: Lifecycle flag

  // Reactive variables for native ads - each controller has its own instances
  final Rx<NativeAd?> smallNativeAd = Rx<NativeAd?>(null);
  final Rx<NativeAd?> largeNativeAd = Rx<NativeAd?>(null);
  final RxBool isSmallNativeAdLoaded = false.obs;
  final RxBool isLargeNativeAdLoaded = false.obs;
  final RxBool isSmallNativeAdFailed = false.obs;
  final RxBool isLargeNativeAdFailed = false.obs;
  final RxBool isSmallNativeAdSkipped = false.obs;
  final RxBool isLargeNativeAdSkipped = false.obs;
  final RxBool isSmallNativeAdLoading = false.obs;
  final RxBool isLargeNativeAdLoading = false.obs;

  Timer? _smallAdTimeoutFlag;
  Timer? _largeAdTimeoutFlag;

  void _startSmallTimeout() {
    _smallAdTimeoutFlag?.cancel();
    _smallAdTimeoutFlag = Timer(const Duration(seconds: 10), () {
      if (!isSmallNativeAdLoaded.value && !isSmallNativeAdFailed.value) {
        print('⏰ Small native ad load timed out');
        isSmallNativeAdFailed.value = true;
        isSmallNativeAdLoading.value = false;
      }
    });
  }

  void _startLargeTimeout() {
    _largeAdTimeoutFlag?.cancel();
    _largeAdTimeoutFlag = Timer(const Duration(seconds: 12), () {
      if (!isLargeNativeAdLoaded.value && !isLargeNativeAdFailed.value) {
        print('⏰ Large native ad load timed out');
        isLargeNativeAdFailed.value = true;
        isLargeNativeAdLoading.value = false;
      }
    });
  }

  void _cancelSmallTimeout() {
    _smallAdTimeoutFlag?.cancel();
    _smallAdTimeoutFlag = null;
  }

  void _cancelLargeTimeout() {
    _largeAdTimeoutFlag?.cancel();
    _largeAdTimeoutFlag = null;
  }

  /// Load native ads (both small and large)
  /// Call this method in onInit() of your controller
  /// Each controller creates its own ad instances to avoid conflicts
  void loadNativeAds() {
    // RULE 3: Lifecycle Guard
    if (_isMixinDisposed) return;

    // Increment navigation count if not already counted for this instance
    if (!_hasCountedNavigation) {
      _adService.incrementNativeScreenCount();
      _hasCountedNavigation = true;
    }

    // FIX: Trigger check for future pre-loads even if current screen skips
    if (!_adService.shouldShowNativeAd()) {
      return;
    }

    _loadSmallNativeAd();
    // _loadLargeNativeAd(); // Removed to avoid duplicate requests when only small ad is needed
  }

  /// Force-load large native ad bypassing frequency gating
  void loadLargeNativeAdAlways({bool isFallback = false}) {
    // RULE 3: Lifecycle Guard
    if (_isMixinDisposed) return;

    // Increment navigation count
    if (!_hasCountedNavigation) {
      _adService.incrementNativeScreenCount();
      _hasCountedNavigation = true;
    }

    if (!isFallback) {
      isLargeNativeAdFailed.value = false;
    }

    if (!_areAdsEnabled()) {
      isLargeNativeAdLoading.value = false;
      return;
    }

    // FIX: Try to use pre-loaded ad first for forced large loads
    if (largeNativeAd.value == null) {
      final cached = _adService.claimCachedLargeAd();
      if (cached != null) {
        print('📦 NativeAdMixin: Claimed a PRE-LOADED large ad (force)');
        largeNativeAd.value = cached;
        isLargeNativeAdLoaded.value = true;
        isLargeNativeAdLoading.value = false;

        // Trigger next pool refill after claim
        _adService.preloadNativeAds(isLarge: true);
        return;
      }
    }

    if (!isFallback) {
      isLargeNativeAdLoading.value = true;
    }

    final adUnitId = isFallback
        ? _getFallbackNativeAdUnitId()
        : _getAdUnitId('native');

    if (adUnitId == null || adUnitId.isEmpty || adUnitId == '0') {
      if (!isFallback) {
        print(
          '⚠️ Primary large native ad unit ID not available, trying fallback...',
        );
        loadLargeNativeAdAlways(isFallback: true);
        return;
      }
      print('⚠️ No valid large native ad unit ID found');
      isLargeNativeAdLoading.value = false;
      return;
    }

    print('📱 Force-loading large native ad: $adUnitId');

    final ad = NativeAd(
      adUnitId: adUnitId,
      factoryId: 'mediumAdFactory',
      request: const AdRequest(),
      nativeAdOptions: NativeAdOptions(
        adChoicesPlacement: AdChoicesPlacement.topRightCorner,
        videoOptions: VideoOptions(startMuted: true),
      ),
      customOptions: {
        'buttonBackgroundColor': '#FF5CA8',
        'buttonTextColor': '#FFFFFF',
        'headlineTextColor': '#FF5CA8',
        'bodyTextColor': '#F3ECFF',
      },
      listener: NativeAdListener(
        onPaidEvent: (ad, valueMicros, precision, currencyCode) {
          AdRevenueLogger.logAdRevenue(
            valueMicros: valueMicros,
            precision: precision,
            currencyCode: currencyCode,
            adUnitId: ad.adUnitId,
            adFormat: 'native',
            adHashCode: ad.hashCode,
          );
        },
        onAdLoaded: (ad) {
          print('✅ Large native ad loaded (force): $adUnitId');
          largeNativeAd.value = ad as NativeAd;
          isLargeNativeAdLoaded.value = true;
          // Trigger next pool refill after fresh load
          _adService.preloadNativeAds(isLarge: true);
        },
        onAdFailedToLoad: (ad, error) {
          print(
            '❌ Failed to load large ad (force): $adUnitId → ${error.message}',
          );
          ad.dispose();

          if (!isFallback) {
            print('🔁 Trying fallback large native ad...');
            loadLargeNativeAdAlways(isFallback: true);
          } else {
            print('🚫 Both primary and fallback AdMob ads failed.');
            isLargeNativeAdLoaded.value = false;
            largeNativeAd.value = null;
            isLargeNativeAdFailed.value = true;
          }
        },
      ),
    );
    try {
      ad.load().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          // Silently fail — don't crash the app
          debugPrint('Ad load timed out');
          return; // or show a fallback
        },
      );
    } on TimeoutException catch (e) {
      debugPrint('Ad timeout: $e');
      // Handle gracefully — don't rethrow
    } catch (e) {
      debugPrint('Ad load error: $e');
      // Handle other errors gracefully
    }
  }

  /// Load only large native ad
  void loadLargeNativeAd() {
    // RULE 3: Lifecycle Guard
    if (_isMixinDisposed) return;

    // Increment navigation count if not already counted for this instance
    if (!_hasCountedNavigation) {
      _adService.incrementNativeScreenCount();
      _hasCountedNavigation = true;
    }
    _loadLargeNativeAd();
  }

  /// Load only small native ad (useful for page-specific ads)
  /// Call this when you need to load a new small ad instance
  /// This will dispose the existing ad and load a fresh one
  void loadSmallNativeAdOnly() {
    // RULE 3: Lifecycle Guard
    if (_isMixinDisposed) return;

    // Keep current ad visible until new one loads to avoid shimmer
    isSmallNativeAdFailed.value = false;
    isSmallNativeAdSkipped.value = false;

    // Always increment navigation count when loading a new small ad explicitly
    _adService.incrementNativeScreenCount();
    _hasCountedNavigation = true;

    _loadSmallNativeAd(forceReload: true);
  }

  /// Force-load small native ad bypassing frequency gating
  /// Use this for flows where an ad must be shown on every page
  void loadSmallNativeAdAlways({bool isFallback = false}) {
    // RULE 3: Lifecycle Guard
    if (_isMixinDisposed) return;

    // FIX 2: Try to use a pre-loaded ad first
    if (smallNativeAd.value == null) {
      final cached = _adService.claimCachedSmallAd();
      if (cached != null) {
        print(
          '📦 NativeAdMixin: Claimed a PRE-LOADED small ad for this screen',
        );
        smallNativeAd.value = cached;
        isSmallNativeAdLoaded.value = true;
        isSmallNativeAdLoading.value = false;

        // Trigger next pool refill immediately after claim
        _adService.preloadNativeAds(isLarge: false);
        return;
      }
    }

    if (!isFallback) {
      isSmallNativeAdLoading.value = true;
    }

    isSmallNativeAdFailed.value = false;
    isSmallNativeAdSkipped.value = false;

    // Count navigation to keep cycle consistent
    if (!_hasCountedNavigation) {
      _adService.incrementNativeScreenCount();
      _hasCountedNavigation = true;
    }

    if (!_areAdsEnabled()) {
      isSmallNativeAdLoading.value = false;
      return;
    }

    final adUnitId = isFallback
        ? _getFallbackNativeAdUnitId()
        : _getAdUnitId('native');

    if (adUnitId == null || adUnitId.isEmpty || adUnitId == '0') {
      if (!isFallback) {
        print(
          '⚠️ Primary small native ad unit ID not available, trying fallback...',
        );
        loadSmallNativeAdAlways(isFallback: true);
        return;
      }
      print('⚠️  NativeAdMixin: Small native ad unit ID not available');
      isSmallNativeAdLoading.value = false;
      return;
    }


    _startSmallTimeout();
    _performSmallNativeAdLoad(adUnitId, isFallback);
  }

  void _performSmallNativeAdLoad(String adUnitId, bool isFallback) {
    if (_isMixinDisposed) return;

    if (adUnitId == '0' || adUnitId.isEmpty) {
      if (!isFallback) {
        final fallbackId = _getFallbackNativeAdUnitId();
        if (fallbackId != null && fallbackId != '0' && fallbackId.isNotEmpty) {
          _performSmallNativeAdLoad(fallbackId, true);
          return;
        }
      }
      isSmallNativeAdLoading.value = false;
      return;
    }


    print('📱 Loading fresh small native ad: $adUnitId');

    final ad = NativeAd(
      adUnitId: adUnitId,
      factoryId: 'jobStyleAdFactory',
      request: const AdRequest(),
      nativeAdOptions: NativeAdOptions(
        adChoicesPlacement: AdChoicesPlacement.topRightCorner,
        videoOptions: VideoOptions(startMuted: true),
      ),
      customOptions: {
        'buttonBackgroundColor': '#FF5CA8',
        'buttonTextColor': '#FFFFFF',
        'headlineTextColor': '#FF5CA8',
        'bodyTextColor': '#F3ECFF',
      },
      listener: NativeAdListener(
        onPaidEvent: (ad, valueMicros, precision, currencyCode) {
          AdRevenueLogger.logAdRevenue(
            valueMicros: valueMicros,
            precision: precision,
            currencyCode: currencyCode,
            adUnitId: ad.adUnitId,
            adFormat: 'native',
            adHashCode: ad.hashCode,
          );
        },
        onAdLoaded: (ad) {
          if (_isMixinDisposed) {
            print('🗑️ Ad loaded after mixin disposed, disposing ad...');
            ad.dispose();
            return;
          }
          print('✅ Small native ad loaded: $adUnitId');
          _cancelSmallTimeout();
          final oldAd = smallNativeAd.value;
          smallNativeAd.value = ad as NativeAd;
          isSmallNativeAdLoaded.value = true;
          isSmallNativeAdLoading.value = false;

          // Trigger next pool refill after fresh load
          _adService.preloadNativeAds(isLarge: false);

          // Dispose old ad after swap
          if (oldAd != null && oldAd != ad) {
            Future.delayed(const Duration(milliseconds: 2000), () {
              oldAd.dispose();
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          print('❌ Failed to load: $adUnitId → ${error.message}');
          ad.dispose();

          if (!isFallback) {
            final fallbackId = _getFallbackNativeAdUnitId();
            if (fallbackId != null &&
                fallbackId != '0' &&
                fallbackId.isNotEmpty) {
              _performSmallNativeAdLoad(fallbackId, true);
              return; // We're still trying
            }
          }

          // If we reach here, either the fallback load failed OR there was no fallback to try
          if (smallNativeAd.value == null) {
            print('🚫 Both AdMob primary and fallback failed.');
            isSmallNativeAdLoaded.value = false;
            isSmallNativeAdFailed.value = true;
            isSmallNativeAdLoading.value = false;
            _cancelSmallTimeout();
          }
        },
      ),
    );
    try {
      ad.load().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          // Silently fail — don't crash the app
          debugPrint('Ad load timed out');
          return; // or show a fallback
        },
      );
    } on TimeoutException catch (e) {
      debugPrint('Ad timeout: $e');
      // Handle gracefully — don't rethrow
    } catch (e) {
      debugPrint('Ad load error: $e');
      // Handle other errors gracefully
    }
  }

  /// Load small native ad for this controller instance
  /// [forceReload] if true, will dispose existing ad and load a new one
  void _loadSmallNativeAd({bool forceReload = false, bool isFallback = false}) {
    // RULE 3: Lifecycle Guard
    if (_isMixinDisposed) return;

    if (!forceReload && !isFallback) {
      isSmallNativeAdFailed.value = false;
      isSmallNativeAdSkipped.value = false;
      isSmallNativeAdLoading.value = true;
    }

    if (!_areAdsEnabled()) {
      isSmallNativeAdLoading.value = false;
      return;
    }

    if (!_adService.shouldShowNativeAd()) {
      print('⏭️ Skipping small native ad load');
      isSmallNativeAdSkipped.value = true;
      isSmallNativeAdLoading.value = false;
      return;
    }

    if (!forceReload &&
        isSmallNativeAdLoaded.value &&
        smallNativeAd.value != null) {
      isSmallNativeAdLoading.value = false;
      return;
    }

    // FIX 2 & 5: Try to claim from the pre-loading pool for an instant entrance
    if (smallNativeAd.value == null) {
      final cached = _adService.claimCachedSmallAd();
      if (cached != null) {
        print('📦 NativeAdMixin: Claimed a PRE-LOADED small ad from pool');
        smallNativeAd.value = cached;
        isSmallNativeAdLoaded.value = true;
        isSmallNativeAdLoading.value = false;

        // Trigger next pool refill immediately after claim
        _adService.preloadNativeAds(isLarge: false);
        return;
      }
    }

    final adUnitId = isFallback
        ? _getFallbackNativeAdUnitId()
        : _getAdUnitId('native');

    if (adUnitId == null || adUnitId.isEmpty || adUnitId == '0') {
      if (!isFallback) {
        print(
          '⚠️ Primary small native ad unit ID not available, trying fallback...',
        );
        _loadSmallNativeAd(isFallback: true, forceReload: forceReload);
        return;
      }
      print('⚠️ No valid small native ad unit ID found');
      isSmallNativeAdLoading.value = false;
      return;
    }

    _performSmallNativeAdLoad(adUnitId, isFallback);
  }

  /// Load large native ad for this controller instance
  void _loadLargeNativeAd({bool isFallback = false}) {
    // RULE 3: Lifecycle Guard
    if (_isMixinDisposed) return;

    if (!isFallback) {
      isLargeNativeAdFailed.value = false;
      isLargeNativeAdSkipped.value = false;
      isLargeNativeAdLoading.value = true;
    }

    if (!_areAdsEnabled()) {
      isLargeNativeAdLoading.value = false;
      return;
    }

    if (!_adService.shouldShowNativeAd()) {
      print(
        '⏭️ Skipping large native ad load (Navigation count criteria not met)',
      );
      isLargeNativeAdSkipped.value = true;
      isLargeNativeAdLoading.value = false;
      return;
    }

    if (isLargeNativeAdLoaded.value &&
        largeNativeAd.value != null &&
        !isFallback) {
      isLargeNativeAdLoading.value = false;
      return;
    }

    // FIX 2 & 5: Try to claim from the pre-loading pool for an instant entrance
    if (largeNativeAd.value == null) {
      final cached = _adService.claimCachedLargeAd();
      if (cached != null) {
        print(
          '📦 NativeAdMixin: Claimed a PRE-LOADED large ad for this screen',
        );
        largeNativeAd.value = cached;
        isLargeNativeAdLoaded.value = true;
        isLargeNativeAdLoading.value = false;

        // Trigger next pool refill immediately after claim
        _adService.preloadNativeAds(isLarge: true);
        return;
      }
    }

    final adUnitId = isFallback
        ? _getFallbackNativeAdUnitId()
        : _getAdUnitId('native');

    if (adUnitId == null || adUnitId.isEmpty || adUnitId == '0') {
      if (!isFallback) {
        print(
          '⚠️ Primary large native ad unit ID not available, trying fallback...',
        );
        _loadLargeNativeAd(isFallback: true);
        return;
      }
      print('⚠️ No valid large native ad unit ID found');
      isLargeNativeAdLoading.value = false;
      return;
    }

    _performLargeNativeAdLoad(adUnitId, isFallback);
  }

  void _performLargeNativeAdLoad(String adUnitId, bool isFallback) {
    if (_isMixinDisposed) return;

    if (adUnitId == '0' || adUnitId.isEmpty) {
      if (!isFallback) {
        final fallbackId = _getFallbackNativeAdUnitId();
        if (fallbackId != null && fallbackId != '0' && fallbackId.isNotEmpty) {
          _performLargeNativeAdLoad(fallbackId, true);
          return;
        }
      }
      isLargeNativeAdLoading.value = false;
      return;
    }


    print('📱 Loading fresh large native ad: $adUnitId');

    final ad = NativeAd(
      adUnitId: adUnitId,
      factoryId: 'mediumAdFactory',
      request: const AdRequest(),
      nativeAdOptions: NativeAdOptions(
        adChoicesPlacement: AdChoicesPlacement.topRightCorner,
        videoOptions: VideoOptions(startMuted: true),
      ),
      customOptions: {
        'buttonBackgroundColor': '#FF5CA8',
        'buttonTextColor': '#FFFFFF',
        'headlineTextColor': '#FF5CA8',
        'bodyTextColor': '#F3ECFF',
      },
      listener: NativeAdListener(
        onPaidEvent: (ad, valueMicros, precision, currencyCode) {
          AdRevenueLogger.logAdRevenue(
            valueMicros: valueMicros,
            precision: precision,
            currencyCode: currencyCode,
            adUnitId: ad.adUnitId,
            adFormat: 'native',
            adHashCode: ad.hashCode,
          );
        },
        onAdLoaded: (ad) {
          if (_isMixinDisposed) {
            print('🗑️ Ad loaded after mixin disposed, disposing ad...');
            ad.dispose();
            return;
          }
          print('✅ Large native ad loaded: $adUnitId');
          _cancelLargeTimeout();
          final oldAd = largeNativeAd.value;
          largeNativeAd.value = ad as NativeAd;
          isLargeNativeAdLoaded.value = true;
          isLargeNativeAdLoading.value = false;

          // Trigger next pool refill after fresh load
          _adService.preloadNativeAds(isLarge: true);

          // Dispose old ad after swap
          if (oldAd != null && oldAd != ad) {
            Future.delayed(const Duration(milliseconds: 800), () {
              oldAd.dispose();
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          print('❌ Failed to load large ad: $adUnitId → ${error.message}');
          ad.dispose();

          if (!isFallback) {
            final fallbackId = _getFallbackNativeAdUnitId();
            if (fallbackId != null &&
                fallbackId != '0' &&
                fallbackId.isNotEmpty) {
              _performLargeNativeAdLoad(fallbackId, true);
              return; // We're still trying
            }
          }

          // If we reach here, either the fallback load failed OR there was no fallback to try
          if (largeNativeAd.value == null) {
            print('🚫 Both AdMob primary and fallback failed.');
            isLargeNativeAdLoaded.value = false;
            isLargeNativeAdFailed.value = true;
            isLargeNativeAdLoading.value = false;
            _cancelLargeTimeout();
          }
        },
      ),
    );
    try {
      ad.load().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          // Silently fail — don't crash the app
          debugPrint('Ad load timed out');
          return; // or show a fallback
        },
      );
    } on TimeoutException catch (e) {
      debugPrint('Ad timeout: $e');
      // Handle gracefully — don't rethrow
    } catch (e) {
      debugPrint('Ad load error: $e');
      // Handle other errors gracefully
    }
  }

  String? _getFallbackNativeAdUnitId() {
    final adData = adsResponseService.getCreditEducationData();
    if (adData == null) return null;

    if (Platform.isAndroid) {
      return adData.gazNative.isNotEmpty ? adData.gazNative : null;
    } else {
      return adData.dwNative.isNotEmpty ? adData.dwNative : null;
    }
  }

  /// Check if ads are enabled
  bool _areAdsEnabled() {
    final adData = adsResponseService.getCreditEducationData();
    if (adData == null) {
      return false;
    }
    return adData.adStart;
  }

  /// Get the appropriate ad unit ID based on platform and ad type
  String? _getAdUnitId(String adType) {
    if (!_areAdsEnabled()) {
      return null;
    }

    final adData = adsResponseService.getCreditEducationData();
    if (adData == null) {
      return null;
    }

    switch (adType) {
      case 'native':
        if (Platform.isAndroid) {
          print("----------gNative---${adData.gNative}");
          return adData.gNative.isNotEmpty ? adData.gNative : null;
        } else {
          return adData.applNative.isNotEmpty ? adData.applNative : null;
        }
      default:
        return null;
    }
  }

  /// Reload native ads if needed
  /// Call this when you want to refresh ads
  void reloadNativeAds() {
    // Keep existing ads visible until new ones load to avoid shimmer
    isSmallNativeAdFailed.value = false;
    isLargeNativeAdFailed.value = false;
    isSmallNativeAdSkipped.value = false;
    isLargeNativeAdSkipped.value = false;

    loadNativeAds();
  }

  @override
  void onClose() {
    _isMixinDisposed = true;
    _smallAdTimeoutFlag?.cancel();
    _largeAdTimeoutFlag?.cancel();

    // Dispose ads when controller is closed
    final oldSmallAd = smallNativeAd.value;
    final oldLargeAd = largeNativeAd.value;

    smallNativeAd.value = null;
    largeNativeAd.value = null;

    // Cleanup with delay to let UI unmount
    if (oldSmallAd != null || oldLargeAd != null) {
      Future.delayed(const Duration(milliseconds: 3000), () {
        oldSmallAd?.dispose();
        oldLargeAd?.dispose();
      });
    }

    super.onClose();
  }
}
