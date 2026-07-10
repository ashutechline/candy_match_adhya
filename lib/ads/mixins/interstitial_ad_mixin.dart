import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../ad_service.dart';
import '../ad_revenue_logger.dart';
import '../controller/ads_response_service.dart';

mixin InterstitialAdMixin on DisposableInterface {
  AdsResponseService get adsResponseService => Get.find<AdsResponseService>();

  InterstitialAd? _interstitialAd;
  final RxBool isInterstitialAdLoaded = false.obs;
  bool _isInterstitialAdLoading = false;
  Completer<void>? _adDismissCompleter;
  bool _isLoadingDialogVisible = false;

  void _showLoadingIndicator() {
    if (_isLoadingDialogVisible ||
        Get.context == null ||
        Get.isDialogOpen == true) {
      return;
    }
    _isLoadingDialogVisible = true;
    Get.dialog(
      Scaffold(
        backgroundColor: Colors.white,
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 64,
                width: 64,
                child: CircularProgressIndicator(),
              ),
              SizedBox(height: 16),
              Text(
                'Please wait while the ad is loading.',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  void _hideLoadingIndicator() {
    if (_isLoadingDialogVisible && Get.isDialogOpen == true) {
      Get.back();
    }
    _isLoadingDialogVisible = false;
  }

  Completer<void>? _adLoadCompleter;

  /// Load interstitial ad with fallback support
  Future<void> loadInterstitialAd({bool isFallback = false}) async {
    if (!_areAdsEnabled()) return;
    
    // If already loading, wait for the existing load to finish
    if (_isInterstitialAdLoading) {
      return _adLoadCompleter?.future;
    }

    // If ad is already loaded and we're not forcing a fallback, just return
    if (_interstitialAd != null && !isFallback) return;

    final adUnitId = isFallback ? _getFallbackAdUnitId() : _getAdUnitId();
    if (adUnitId == null || adUnitId.isEmpty || adUnitId == '0') {
      print('⚠️ AdService: No valid interstitial ad unit ID found');
      return;
    }

    _isInterstitialAdLoading = true;
    _adLoadCompleter = Completer<void>();
    print('📱 AdService: Loading interstitial ad: $adUnitId (isFallback: $isFallback)');

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          print('✅ AdService: Interstitial loaded: $adUnitId');
          AdRevenueLogger.attachRevenueTracking(
            ad: ad,
            adFormat: 'interstitial',
          );
          _interstitialAd = ad;
          isInterstitialAdLoaded.value = true;
          _isInterstitialAdLoading = false;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              print('📺 AdService: Interstitial ad showed');
              final adService = Get.find<AdService>();
              adService.setAdShowing(true);
            },
            onAdDismissedFullScreenContent: (ad) {
              print('✅ AdService: Interstitial dismissed');
              ad.dispose();
              _interstitialAd = null;
              isInterstitialAdLoaded.value = false;
              
              final adService = Get.find<AdService>();
              adService.setAdShowing(false);
              
              _adDismissCompleter?.complete();
              _adDismissCompleter = null;
              
              // Preload next ad only after showing current ad
              loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              print('❌ AdService: Failed to show: ${error.message}');
              ad.dispose();
              _interstitialAd = null;
              isInterstitialAdLoaded.value = false;

              final adService = Get.find<AdService>();
              adService.setAdShowing(false);

              _adDismissCompleter?.completeError(error);
              _adDismissCompleter = null;
            },
          );
          
          _adLoadCompleter?.complete();
          _adLoadCompleter = null;
        },
        onAdFailedToLoad: (error) {
          print('❌ AdService: Failed to load: $adUnitId → ${error.message}');
          _isInterstitialAdLoading = false;
          _interstitialAd = null;
          isInterstitialAdLoaded.value = false;

          if (!isFallback) {
            print('🔄 AdService: Trying fallback Gaz ID...');
            // Chain the fallback load but resolve the original completer when it's done
            loadInterstitialAd(isFallback: true).then((_) {
              _adLoadCompleter?.complete();
              _adLoadCompleter = null;
            });
          } else {
            print('🚫 AdService: Both primary and fallback ads failed.');
            _adLoadCompleter?.complete();
            _adLoadCompleter = null;
          }
        },
      ),
    );
    
    return _adLoadCompleter?.future;
  }

  /// Load interstitial ad bypassing frequency gating
  void loadInterstitialAdAlways() {
    loadInterstitialAd();
  }

  Future<bool> showInterstitialAd({
    VoidCallback? onAdDismissed,
    VoidCallback? onAdFailed,
    bool waitForDismiss = false,
    bool force = false,
    bool isLevelUpdate = false,
  }) async {
    if (!_areAdsEnabled()) {
      onAdDismissed?.call();
      return false;
    }

    final adService = Get.find<AdService>();
    final bool shouldShow = force || (isLevelUpdate 
        ? adService.shouldShowInterstitialAdOnLevelUpdate()
        : adService.shouldShowInterstitialAd());

    if (!shouldShow) {
      onAdDismissed?.call();
      return false;
    }

    // Check if ad is ready, if not, load it on-demand
    if (_interstitialAd == null) {
      print('⏳ AdService: Interstitial ad not ready, loading on-demand...');
      _showLoadingIndicator();
      // Wait for load with a timeout to avoid infinite hanging
      await loadInterstitialAd().timeout(const Duration(seconds: 10), onTimeout: () {
        print('⏱️ AdService: On-demand load timed out');
      });
      _hideLoadingIndicator();
      
      if (_interstitialAd == null) {
        print('⚠️ AdService: On-demand load failed, continuing navigation');
        onAdDismissed?.call();
        return false;
      }
    }

    _showLoadingIndicator();
    // Small delay to ensure dialog is rendered
    await Future.delayed(const Duration(milliseconds: 500));
    _hideLoadingIndicator();

    _adDismissCompleter = Completer<void>();
    _adDismissCompleter!.future.then((_) {
      onAdDismissed?.call();
    }).catchError((e) {
      onAdFailed?.call();
    });

    try {
      if (!adService.isForeground) {
        print('🚫 InterstitialAdMixin: App in background, skipping show');
        onAdDismissed?.call();
        return false;
      }

      print('✅ AdService: Showing interstitial ad');
      await _interstitialAd!.show();
      
      if (waitForDismiss) {
        await _adDismissCompleter!.future.timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            print('⏱️ Timeout waiting for dismiss');
          },
        );
      }
      return true;
    } catch (e) {
      print('❌ Error showing ad: $e');
      onAdFailed?.call();
      adService.setAdShowing(false);
      return false;
    }
  }

  bool _areAdsEnabled() {
    final adData = adsResponseService.getCreditEducationData();
    if (adData == null) return false;
    return adData.adStart;
  }

  String? _getAdUnitId() {
    if (!_areAdsEnabled()) return null;

    final adData = adsResponseService.getCreditEducationData();
    if (adData == null) return null;

    if (Platform.isAndroid) {
      return adData.gInter.isNotEmpty ? adData.gInter : null;
    } else {
      return adData.applInter.isNotEmpty ? adData.applInter : null;
    }
  }

  /// Fallback GazInter ID
  String? _getFallbackAdUnitId() {
    final adData = adsResponseService.getCreditEducationData();
    if (adData == null) return null;

    if (Platform.isAndroid) {
      return adData.gazInter.isNotEmpty ? adData.gazInter : null;
    } else {
      return adData.dwInter.isNotEmpty ? adData.dwInter : null;
    }
  }

  Future<void> navigateWithInterstitialAd(String route, {Map<String, dynamic>? data}) async {
    final adShown = await showInterstitialAd(
      waitForDismiss: true,
      onAdDismissed: () {
        Get.toNamed(route, arguments: data);
      },
      onAdFailed: () {
        Get.toNamed(route, arguments: data);
      },
    );

    if (!adShown) {
      Get.toNamed(route, arguments: data);
    }
  }

  void disposeInterstitialAd() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    isInterstitialAdLoaded.value = false;
    _adDismissCompleter?.complete();
    _adDismissCompleter = null;
  }

  @override
  void onClose() {
    disposeInterstitialAd();
    super.onClose();
  }
}
