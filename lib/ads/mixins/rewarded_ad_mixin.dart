import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../ad_service.dart';
import '../ad_revenue_logger.dart';
import '../controller/ads_response_service.dart';

mixin RewardedAdMixin on DisposableInterface {
  AdsResponseService get adsResponseService => Get.find<AdsResponseService>();

  RewardedAd? _rewardedAd;
  final RxBool isRewardedAdLoaded = false.obs;
  bool _isRewardedAdLoading = false;
  Completer<void>? _adDismissCompleter;
  bool _isLoadingDialogVisible = false;
  bool _isRewarded = false;

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

  /// Load rewarded ad with fallback support
  Future<void> loadRewardedAd({bool isFallback = false}) async {
    if (!_areAdsEnabled()) return;
    
    if (_isRewardedAdLoading) {
      return _adLoadCompleter?.future;
    }

    if (_rewardedAd != null && !isFallback) return;

    final adUnitId = isFallback ? _getFallbackAdUnitId() : _getAdUnitId();
    if (adUnitId == null || adUnitId.isEmpty || adUnitId == '0') {
      print('⚠️ AdService: No valid rewarded ad unit ID found');
      return;
    }

    _isRewardedAdLoading = true;
    _adLoadCompleter = Completer<void>();
    print('📱 AdService: Loading rewarded ad: $adUnitId (isFallback: $isFallback)');

    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          print('✅ AdService: Rewarded ad loaded: $adUnitId');
          AdRevenueLogger.attachRewardedAd(ad);
          _rewardedAd = ad;
          isRewardedAdLoaded.value = true;
          _isRewardedAdLoading = false;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              print('📺 AdService: Rewarded ad showed');
              final adService = Get.find<AdService>();
              adService.setAdShowing(true);
            },
            onAdDismissedFullScreenContent: (ad) {
              print('✅ AdService: Rewarded ad dismissed');
              ad.dispose();
              _rewardedAd = null;
              isRewardedAdLoaded.value = false;
              
              final adService = Get.find<AdService>();
              adService.setAdShowing(false);
              
              _adDismissCompleter?.complete();
              _adDismissCompleter = null;
              
              loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              print('❌ AdService: Failed to show rewarded ad: ${error.message}');
              ad.dispose();
              _rewardedAd = null;
              isRewardedAdLoaded.value = false;

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
          print('❌ AdService: Failed to load rewarded: $adUnitId → ${error.message}');
          _isRewardedAdLoading = false;
          _rewardedAd = null;
          isRewardedAdLoaded.value = false;

          if (!isFallback) {
            print('🔄 AdService: Trying fallback Gaz ID...');
            loadRewardedAd(isFallback: true).then((_) {
              _adLoadCompleter?.complete();
              _adLoadCompleter = null;
            });
          } else {
            print('🚫 AdService: Both primary and fallback rewarded ads failed.');
            _adLoadCompleter?.complete();
            _adLoadCompleter = null;
          }
        },
      ),
    );
    
    return _adLoadCompleter?.future;
  }

  void loadRewardedAdAlways() {
    loadRewardedAd();
  }

  Future<bool> showRewardedAd({
    required VoidCallback onUserEarnedReward,
    VoidCallback? onAdDismissed,
    VoidCallback? onAdFailed,
    bool waitForDismiss = false,
  }) async {
    _isRewarded = false;
    
    if (!_areAdsEnabled()) {
      onUserEarnedReward();
      onAdDismissed?.call();
      return false;
    }

    if (_rewardedAd == null) {
      print('⏳ AdService: Rewarded ad not ready, loading on-demand...');
      _showLoadingIndicator();
      await loadRewardedAd().timeout(const Duration(seconds: 10), onTimeout: () {
        print('⏱️ AdService: On-demand rewarded load timed out');
      });
      _hideLoadingIndicator();
      
      if (_rewardedAd == null) {
        print('⚠️ AdService: On-demand rewarded ad load failed');
        onAdFailed?.call();
        return false;
      }
    }

    _showLoadingIndicator();
    await Future.delayed(const Duration(milliseconds: 500));
    _hideLoadingIndicator();

    _adDismissCompleter = Completer<void>();
    _adDismissCompleter!.future.then((_) {
      if (_isRewarded) {
        onUserEarnedReward();
      } else {
        onAdFailed?.call();
      }
      onAdDismissed?.call();
    }).catchError((e) {
      onAdFailed?.call();
    });

    final adService = Get.find<AdService>();

    try {
      if (!adService.isForeground) {
        print('🚫 RewardedAdMixin: App in background, skipping show');
        onAdFailed?.call();
        return false;
      }

      print('✅ AdService: Showing rewarded ad');
      await _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
        print('🎁 AdService: User earned reward: ${reward.amount} ${reward.type}');
        _isRewarded = true;
      });
      
      if (waitForDismiss) {
        await _adDismissCompleter!.future.timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            print('⏱️ Timeout waiting for rewarded ad dismiss');
          },
        );
      }
      return true;
    } catch (e) {
      print('❌ Error showing rewarded ad: $e');
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
      return adData.gRewarded.isNotEmpty ? adData.gRewarded : null;
    } else {
      return adData.applRewarded.isNotEmpty ? adData.applRewarded : null;
    }
  }

  String? _getFallbackAdUnitId() {
    final adData = adsResponseService.getCreditEducationData();
    if (adData == null) return null;

    if (Platform.isAndroid) {
      return adData.gazRewarded.isNotEmpty ? adData.gazRewarded : null;
    } else {
      return adData.dwRewarded.isNotEmpty ? adData.dwRewarded : null;
    }
  }

  void disposeRewardedAd() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    isRewardedAdLoaded.value = false;
    _adDismissCompleter?.complete();
    _adDismissCompleter = null;
  }

  @override
  void onClose() {
    disposeRewardedAd();
    super.onClose();
  }
}
