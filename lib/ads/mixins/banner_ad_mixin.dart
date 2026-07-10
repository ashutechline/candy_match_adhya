import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../ad_service.dart';
import '../controller/ads_response_service.dart';

/// Mixin to provide reusable banner ad loading functionality
/// Use this mixin in any controller that needs to display banner ads
/// Each controller gets its own ad instances to avoid conflicts
mixin BannerAdMixin on GetxController {
  AdsResponseService get adsResponseService =>
      Get.find<AdsResponseService>();
  AdService get _adService => Get.find<AdService>();
  bool _hasCountedNavigation = false;
  bool _isMixinDisposed = false;

  // Reactive variables for banner ads
  final Rx<BannerAd?> bannerAd = Rx<BannerAd?>(null);
  final RxBool isBannerAdLoaded = false.obs;
  final RxBool isBannerAdFailed = false.obs;
  Timer? _bannerRetryTimer;

  /// Load banner ad
  /// Call this method in onInit() of your controller
  void loadBannerAd() {
    if (_isMixinDisposed) return;
    if (!_hasCountedNavigation) {
      _adService.incrementBannerScreenCount();
      _hasCountedNavigation = true;
    }



    if (_areAdsEnabled()) {
      if (!_adService.shouldShowBannerAd()) {
        return;
      }
      _loadBannerAd();
    } else {
      if (adsResponseService.getCreditEducationData() == null) {
        _bannerRetryTimer ??= Timer(const Duration(seconds: 2), () {
          _bannerRetryTimer = null;
          loadBannerAd();
        });
      }
    }
  }

  bool _isBannerAdLoading = false;

  /// Load banner ad for this controller instance
  Future<void> _loadBannerAd({bool force = false}) async {
    if (_isMixinDisposed) return;
    if (!_areAdsEnabled()) {
      isBannerAdFailed.value = true;
      return;
    }

    // Check if ad is already loaded or in progress
    if (!force && (bannerAd.value != null || isBannerAdLoaded.value || _isBannerAdLoading)) {
      return;
    }
    final context = Get.context;
    final size = context != null
        ? await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
            MediaQuery.of(context).size.width.truncate(),
          )
        : AdSize.banner;
    _isBannerAdLoading = true;
    _adService.loadBannerInto(
      targetAd: bannerAd,
      size: size!,
      isAdLoaded: isBannerAdLoaded,
      onAdLoaded: () => _isBannerAdLoading = false,
      onAdFailed: () {
        _isBannerAdLoading = false;
        isBannerAdFailed.value = true;
      },
      isDisposed: () => _isMixinDisposed,
    );
  }

  /// Force-load banner ad bypassing frequency gating
  void loadBannerAdAlways({bool bypassAdStart = false}) {
    if (_isMixinDisposed) return;
    // 1. Immediately nullify reactive variables to trigger UI rebuild (removing old AdWidget)
    final oldAd = bannerAd.value;
    bannerAd.value = null;
    isBannerAdLoaded.value = false;
    isBannerAdFailed.value = false;

    // 2. Increment navigation count
    _adService.incrementBannerScreenCount();
    _hasCountedNavigation = true;

    // 3. Dispose old ad with a delay to ensure Flutter state machine has fully unmounted the widget
    if (oldAd != null) {
      Future.delayed(const Duration(milliseconds: 3000), () {
        oldAd.dispose();
        print('🗑️ BannerAdMixin: Old banner ad disposed');
      });
    }

    if (!bypassAdStart && !_areAdsEnabled()) {
      if (adsResponseService.getCreditEducationData() == null) {
        _bannerRetryTimer ??= Timer(const Duration(seconds: 2), () {
          _bannerRetryTimer = null;
          loadBannerAdAlways(bypassAdStart: bypassAdStart);
        });
        return;
      }
      isBannerAdFailed.value = true;
      return;
    }



    // 4. Load NEW instance after a longer delay to avoid "already in tree" conflict during transition
    Future.delayed(const Duration(milliseconds: 500), () {
      if (isClosed || _isMixinDisposed) return; // Don't load if controller was closed during delay
      _loadBannerAd(force: true);
    });
  }

  /// Check if ads are enabled
  bool _areAdsEnabled() {
    if (!Get.isRegistered<AdsResponseService>()) {
      return false;
    }
    final adData = adsResponseService.getCreditEducationData();
    if (adData == null) {
      return false;
    }
    return adData.adStart;
  }

  @override
  void onClose() {
    _isMixinDisposed = true;
    _bannerRetryTimer?.cancel();
    
    // Immediate cleanup of reactive state to help Obx/UI unmount AdWidget
    final adToDispose = bannerAd.value;
    bannerAd.value = null;
    isBannerAdLoaded.value = false;
    
    // Dispose the ad instance with delay to let UI unmount
    if (adToDispose != null) {
      Future.delayed(const Duration(milliseconds: 3000), () {
        adToDispose.dispose();
        print('🗑️ BannerAdMixin: Banner ad disposed on controller close');
      });
    }
    
    super.onClose();
  }
}
