import 'dart:async';
  import 'dart:io';
  import 'package:flutter/material.dart';
  import 'package:flutter/foundation.dart';
  import 'package:get/get.dart';
  import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
  // import 'package:easy_audience_network/easy_audience_network.dart' as facebook;
  import '../Utility/color_constants.dart';
  import 'ad_revenue_logger.dart';
  import 'controller/ads_response_service.dart';
  import 'mixins/interstitial_ad_mixin.dart';
import 'mixins/rewarded_ad_mixin.dart';

  /// Reusable Ad Service for managing all ad formats
  class AdService extends GetxService with WidgetsBindingObserver, InterstitialAdMixin, RewardedAdMixin {
    final AdsResponseService adsResponseService = Get.find<AdsResponseService>();

    AppOpenAd? _appOpenAd;
    bool _isAppOpenAdReady = false;
    int _bannerScreenCount = 0;

    /// Store the current AppLifecycleState
    AppLifecycleState _lastLifecycleState = AppLifecycleState.resumed;

    /// Public getter to check if app is in foreground
    bool get isForeground => _lastLifecycleState == AppLifecycleState.resumed;

    /// Global flag to prevent multiple ads from showing concurrently
    bool _isAdShowing = false;
    bool get isAdShowing => _isAdShowing;

    /// Public setter for _isAdShowing to control ad state externally (e.g. from Mixins)
    void setAdShowing(bool isShowing) {
      if (_isAdShowing == isShowing) return;
      _isAdShowing = isShowing;
      print('📱 AdService: isAdShowing set to $isShowing');
    }

    Completer<void>? _adLoadCompleter;
    Completer<void>? _adDismissCompleter;
    bool _isAppInBackground = false;
    bool _hasNavigatedFromSplash = false;
    bool _hasTriedFallback = false;

    @override
    void onInit() {
      super.onInit();
      WidgetsBinding.instance.addObserver(this);
      // Initialize with current state
      _lastLifecycleState = WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
      print('📱 AdService: Initialized with lifecycle state: $_lastLifecycleState');
    }

    @override
    void onClose() {
      WidgetsBinding.instance.removeObserver(this);
      disposeAppOpenAd();
      disposeNativeAds();
      disposeBannerAd();
      super.onClose();
    }

    @override
    void didChangeAppLifecycleState(AppLifecycleState state) {
      super.didChangeAppLifecycleState(state);
      _lastLifecycleState = state;

      if (state == AppLifecycleState.paused) {
        _isAppInBackground = true;
      } else if (state == AppLifecycleState.resumed) {
        if (_isAppInBackground && _hasNavigatedFromSplash) {
          _isAppInBackground = false;
          print('📱 AdService: App resumed from background - attempting to show App Open Ad');
          _handleAppResume();
        }
      }
    }

    void disposeBannerAd() {
      // Shared banner ad logic removed to favor unique instances via mixin/loadBannerInto
    }

    /// Increment banner screen count (matches native gating behavior)
    void incrementBannerScreenCount() {
      if (!_areAdsEnabled()) return;
      final adData = adsResponseService.getCreditEducationData();
      if (adData == null) return;
      if (adData.iBannerPosition > 0) {
        _bannerScreenCount++;
        print(
          '🧭 AdService: Banner screen count incremented to: $_bannerScreenCount | iBannerPosition: ${adData.iBannerPosition}',
        );
      }
    }

    /// Should show banner ad based on iBannerPosition (same cycle as native)
    bool shouldShowBannerAd() {
      if (!_areAdsEnabled()) return false;
      final adData = adsResponseService.getCreditEducationData();
      if (adData == null) return false;
      final position = adData.iBannerPosition;
      if (position <= 0 || position == 1) {
        return true;
      }

      return _bannerScreenCount > 0 && _bannerScreenCount % position == 0;
    }

    void loadBannerInto({
      required Rx<BannerAd?> targetAd,
      required RxBool isAdLoaded,
      AdSize size = AdSize.banner,
      VoidCallback? onAdLoaded,
      VoidCallback? onAdFailed,
      bool Function()? isDisposed,
    }) {
      // If ad is already loaded or being loaded, do nothing
      if (targetAd.value != null || isAdLoaded.value) {
        return;
      }

      if (!_areAdsEnabled()) {
        return;
      }



      // Try primary ad unit ID
      final primaryId = _getAdUnitId('banner');
      if (primaryId == null || primaryId.isEmpty || primaryId == '0') {
        // Attempt fallback immediately if primary ID unavailable
        final fallbackId = _getAdUnitId('banner', useFallback: true);
        if (fallbackId == null || fallbackId.isEmpty || fallbackId == '0') {
          print('⚠️  AdService: Banner ad unit IDs not available (primary and fallback)');
          return;
        }
        final bannerTimeout = Timer(const Duration(seconds: 15), () {
          print('⏰ AdService: Fallback banner load timed out');
          if (isDisposed != null && isDisposed()) return;
          isAdLoaded.value = false;
          targetAd.value = null;
          onAdFailed?.call();
        });

        final fbAd = BannerAd(
          adUnitId: fallbackId,
          size: size,
          request: const AdRequest(),
          listener: BannerAdListener(
            onPaidEvent: (ad, valueMicros, precision, currencyCode) {
              AdRevenueLogger.logAdRevenue(
                valueMicros: valueMicros,
                precision: precision,
                currencyCode: currencyCode,
                adUnitId: ad.adUnitId,
                adFormat: 'banner',
                adHashCode: ad.hashCode,
              );
            },
            onAdLoaded: (loadedAd) {
              bannerTimeout.cancel();
              if (isDisposed != null && isDisposed()) {
                print('🗑️ AdService: Fallback banner loaded after source disposed, disposing...');
                loadedAd.dispose();
                return;
              }
              print('✅ AdService: Fallback banner ad loaded into target');
              targetAd.value = loadedAd as BannerAd;
              isAdLoaded.value = true;
              onAdLoaded?.call();
            },
            onAdFailedToLoad: (failedAd, error) {
              bannerTimeout.cancel();
              if (isDisposed != null && isDisposed()) {
                print('🗑️ AdService: Fallback banner failed after source disposed, disposing...');
                failedAd.dispose();
                return;
              }
              print('❌ AdService: Fallback banner ad failed to load into target | Error: ${error.message}');
              isAdLoaded.value = false;
              targetAd.value = null;
              failedAd.dispose();
              onAdFailed?.call();
            },
          ),
        );
        try {
          fbAd.load();
        } catch (e) {
          bannerTimeout.cancel();
          debugPrint('Ad load error: $e');
          if (isDisposed != null && isDisposed()) return;
          isAdLoaded.value = false;
          targetAd.value = null;
          onAdFailed?.call();
        }
        return;
      }

      final primaryBannerTimeout = Timer(const Duration(seconds: 15), () {
        print('⏰ AdService: Primary banner load timed out');
        if (isDisposed != null && isDisposed()) return;
        // Set to failed on timeout to clear shimmer
        isAdLoaded.value = false;
        targetAd.value = null;
        onAdFailed?.call();
      });

      final ad = BannerAd(
        adUnitId: primaryId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onPaidEvent: (ad, valueMicros, precision, currencyCode) {
            AdRevenueLogger.logAdRevenue(
              valueMicros: valueMicros,
              precision: precision,
              currencyCode: currencyCode,
              adUnitId: ad.adUnitId,
              adFormat: 'banner',
              adHashCode: ad.hashCode,
            );
          },
          onAdLoaded: (loadedAd) {
            primaryBannerTimeout.cancel();
            if (isDisposed != null && isDisposed()) {
              print('🗑️ AdService: Banner loaded after source disposed, disposing...');
              loadedAd.dispose();
              return;
            }
            print('✅ AdService: Banner ad loaded into target');
            targetAd.value = loadedAd as BannerAd;
            isAdLoaded.value = true;
            onAdLoaded?.call();
          },
          onAdFailedToLoad: (failedAd, error) {
            primaryBannerTimeout.cancel();
            if (isDisposed != null && isDisposed()) {
              print('🗑️ AdService: Banner failed after source disposed, disposing...');
              failedAd.dispose();
              return;
            }
            print('❌ AdService: Failed to load banner ad into target | Error: ${error.message}');
            failedAd.dispose();

            // Try AdMob Fallback ID first (existing logic)
            final fallbackId = _getAdUnitId('banner', useFallback: true);
            if (fallbackId != null && fallbackId.isNotEmpty && fallbackId != '0') {
              print('🔄 AdService: Attempting AdMob fallback banner ad...');

              final fallbackBannerTimeout = Timer(const Duration(seconds: 15), () {
                print('⏰ AdService: Fallback AdMob banner load timed out');
                if (isDisposed != null && isDisposed()) return;
                isAdLoaded.value = false;
                targetAd.value = null;
                onAdFailed?.call();
              });

              final fbAd = BannerAd(
                adUnitId: fallbackId,
                size: size,
                request: const AdRequest(),
                listener: BannerAdListener(
                  onPaidEvent: (ad, valueMicros, precision, currencyCode) {
                    AdRevenueLogger.logAdRevenue(
                      valueMicros: valueMicros,
                      precision: precision,
                      currencyCode: currencyCode,
                      adUnitId: ad.adUnitId,
                      adFormat: 'banner',
                      adHashCode: ad.hashCode,
                    );
                  },
                  onAdLoaded: (loaded) {
                    fallbackBannerTimeout.cancel();
                    if (isDisposed != null && isDisposed()) {
                      print('🗑️ AdService: Fallback AdMob banner loaded after source disposed, disposing...');
                      loaded.dispose();
                      return;
                    }
                    print('✅ AdService: AdMob fallback banner ad loaded');
                    targetAd.value = loaded as BannerAd;
                    isAdLoaded.value = true;
                    onAdLoaded?.call();
                  },
                  onAdFailedToLoad: (failed, err) {
                    fallbackBannerTimeout.cancel();
                    failed.dispose();
                    if (isDisposed != null && isDisposed()) {
                      print('🗑️ AdService: Fallback AdMob banner failed after source disposed, disposing...');
                      return;
                    }
                    isAdLoaded.value = false;
                    targetAd.value = null;
                    onAdFailed?.call();
                  },
                ),
              );
              try {
                fbAd.load();
              } catch (e) {
                fallbackBannerTimeout.cancel();
                debugPrint('Ad load error: $e');
              }
            } else {
              isAdLoaded.value = false;
              targetAd.value = null;
              onAdFailed?.call();
            }
          },
        ),
      );
      try {
        ad.load();
      } catch (e) {
        primaryBannerTimeout.cancel();
        debugPrint('Ad load error: $e');
        if (isDisposed != null && isDisposed()) return;
        isAdLoaded.value = false;
        targetAd.value = null;
        onAdFailed?.call();
      }
    }

    /*
    void _tryFacebookBanner(
      Rx<BannerAd?> targetAd,
      RxBool isAdLoaded,
      VoidCallback? onAdLoaded,
      VoidCallback? onAdFailed,
    ) {
      if (!_isFacebookEnabled()) {
        isAdLoaded.value = false;
        targetAd.value = null;
        onAdFailed?.call();
        return;
      }

      final fbId = _getAdUnitId('facebook_banner');
      if (fbId == null || fbId.isEmpty || fbId == '0') {
        isAdLoaded.value = false;
        targetAd.value = null;
        onAdFailed?.call();
        return;
      }

      print('🔄 AdService: Attempting Facebook fallback banner ad...');
      // Note: Since targetAd expects BannerAd (AdMob), we can't store AudienceNetwork banner there.
      // We'll handle different UI types in the widget builder.
      // BUT we need to flag that it's a FB ad.
      // For now, let's keep it simple: If FB succeeds, isAdLoaded remains true, but targetAd is null.
      // We'll update small_native_ad_widget.dart to check for this.
      isAdLoaded.value = true;
      onAdLoaded?.call();
    }
    */

    /// Dispose banner from provided reactive targets
    void disposeBannerFrom({required Rx<BannerAd?> targetAd, required RxBool isAdLoaded}) {
      targetAd.value?.dispose();
      targetAd.value = null;
      isAdLoaded.value = false;
    }

    bool _shouldSuppressResumeAd = false;

    void pauseAppResumeAd() {
      print('⏸️ AdService: App Open Ad display PAUSED');
      _shouldSuppressResumeAd = true;
    }

    /// Resume App Open Ad behavior
    void resumeAppResumeAd() {
      print('▶️ AdService: App Open Ad display RESUMED');
      _shouldSuppressResumeAd = false;
    }

    /// Handle app resume from background
    Future<void> _handleAppResume() async {
      // Check if ads are enabled
      if (!_areAdsEnabled()) {
        print('🚫 AdService: Ads are disabled (AdStart = false)');
        return;
      }

      // Check if an ad is already showing (e.g. interstitial)
      if (_isAdShowing) {
        print('📱 AdService: Ad is already showing - skipping App Open Ad on resume');
        return;
      }

      if (_shouldSuppressResumeAd) {
        print('🚫 AdService: App Open Ad suppressed (e.g. external link) - skipping');
        // Reset flag so next resume works normally (unless paused again)
        _shouldSuppressResumeAd = false;
        return;
      }

      final adData = adsResponseService.getCreditEducationData();
      if (adData == null || !adData.openAdBackgStart) {
        return;
      }

      // Reset fallback flag for new load attempt
      _hasTriedFallback = false;

      try {
        // Only proceed if still in foreground
        if (!isForeground) {
          print('🚫 AdService: App no longer in foreground, skipping resume ad');
          return;
        }

        // Try to load ad (will attempt fallback if primary fails)
        // Pass isAppResume: true to use platform-specific fallback (GazAppOpen for Android, DwAppOpen for iOS)
        await loadAppOpenAd(showOnLoad: true, waitForDismiss: false, isAppResume: true).timeout(
          const Duration(seconds: 6),
          onTimeout: () {
            // Continue without ad if timeout
          },
        );

        // Wait a bit for ad to load (max 6 seconds total)
        int attempts = 0;
        while (!_isAppOpenAdReady && attempts < 30) {
          // Break if app goes to background during wait
          if (!isForeground) break;
          await Future.delayed(const Duration(milliseconds: 200));
          attempts++;
        }

        // Show ad if ready and still in foreground
        if (_isAppOpenAdReady && _appOpenAd != null && !_isAdShowing && isForeground) {
          print('📺 AdService: Showing App Open Ad on app resume');
          await showAppOpenAd(waitForDismiss: false);
        }
      } catch (e) {
        // Continue without ad on error
      }
    }

    /// Mark that app has navigated away from splash screen
    void markSplashNavigationComplete() {
      _hasNavigatedFromSplash = true;
    }

    /// Check if ads are enabled based on AdStart flag
    bool _areAdsEnabled() {

      final adData = adsResponseService.getCreditEducationData();
      if (adData == null) {
        return false;
      }
      return adData.adStart;
    }

    /// Check if Facebook ads are enabled based on isFaceBook flag
    bool _isFacebookEnabled() {
      return false;
    }

    /// Initialize Google Mobile Ads SDK and Facebook Audience Network
    Future<void> initializeAds() async {
      try {
        // Ensure Firebase initialize properly before ad loading
        await Firebase.initializeApp();
        await MobileAds.instance.initialize();

        // Fetch ads configurations/gating flags from mock or Remote Config
        await adsResponseService.getCreditEducationDetails();

        /*
        // Initialize Facebook Audience Network
        final adData = adsResponseService.getCreditEducationData();
        if (adData != null && adData.isFaceBook) {
          await facebook.EasyAudienceNetwork.init(
            testingId: adData.faceBookInit.isNotEmpty
                ? adData.faceBookInit
                : (kDebugMode ? "daa94eed-142f-4ca6-806c-c5520a420fc3" : null),
            testMode: kDebugMode,
          );
          print('✅ AdService: Initialized Google Mobile Ads & Facebook Audience Network');
        } else {
          print('✅ AdService: Initialized Google Mobile Ads (Facebook disabled via isFaceBook)');
        }
        */
        print('✅ AdService: Initialized Google Mobile Ads (Facebook Ad Code Commented Out)');

        // Start pre-loading native ads in background
        preloadNativeAds();

        // Preload interstitial ads
        loadInterstitialAd();

        // Preload rewarded ads
        loadRewardedAd();
      } catch (e) {
        print('❌ AdService: Failed to initialize ads: $e');
      }
    }

    /// Get the appropriate ad unit ID based on platform and ad type
    String? _getAdUnitId(String adType, {bool useFallback = false, bool isAppResume = false}) {
      if (!_areAdsEnabled()) {
        return null;
      }

      final adData = adsResponseService.getCreditEducationData();
      if (adData == null) {
        return null;
      }

      switch (adType) {
        case 'appOpen':
          if (useFallback) {
            if (Platform.isAndroid) {
              return adData.gazAppOpen.isNotEmpty ? adData.gazAppOpen : null;
            } else if (Platform.isIOS) {
              return adData.dwAppOpen.isNotEmpty ? adData.dwAppOpen : null;
            }
            return null;
          }

          if (Platform.isAndroid) {
            return adData.gAppOpen.isNotEmpty ? adData.gAppOpen : null;
          } else if (Platform.isIOS) {
            return adData.applAppOpen.isNotEmpty ? adData.applAppOpen : null;
          }
          return adData.gAppOpen.isNotEmpty ? adData.gAppOpen : null;
        case 'banner':
          if (useFallback) {
            if (Platform.isAndroid) {
              return adData.gazBanner.isNotEmpty ? adData.gazBanner : null;
            } else if (Platform.isIOS) {
              return adData.dwBanner.isNotEmpty ? adData.dwBanner : null;
            }
            return null;
          }
          if (Platform.isAndroid) {
            return adData.gBanner.isNotEmpty ? adData.gBanner : null;
          } else {
            return adData.applBanner.isNotEmpty ? adData.applBanner : null;
          }
        case 'interstitial':
          if (useFallback) {
            if (Platform.isAndroid) {
              return adData.gazInter.isNotEmpty ? adData.gazInter : null;
            } else {
              return adData.dwInter.isNotEmpty ? adData.dwInter : null;
            }
          }
          if (Platform.isAndroid) {
            return adData.gInter.isNotEmpty ? adData.gInter : null;
          } else {
            return adData.applInter.isNotEmpty ? adData.applInter : null;
          }

        case 'native':
          if (useFallback) {
            if (Platform.isAndroid) {
              return adData.gazNative.isNotEmpty ? adData.gazNative : null;
            } else {
              return adData.dwNative.isNotEmpty ? adData.dwNative : null;
            }
          }
          if (Platform.isAndroid) {
            return adData.gNative.isNotEmpty ? adData.gNative : null;
          } else {
            return adData.applNative.isNotEmpty ? adData.applNative : null;
          }

        /*
        case 'facebook_banner':
          return (adData.isFaceBook && adData.fBanner.isNotEmpty) ? adData.fBanner : null;
        case 'facebook_interstitial':
          return (adData.isFaceBook && adData.fInter.isNotEmpty) ? adData.fInter : null;
        case 'facebook_native':
          return (adData.isFaceBook && adData.fNative.isNotEmpty) ? adData.fNative : null;
        case 'facebook_native_banner':
          return (adData.isFaceBook && adData.fNativeBanner.isNotEmpty) ? adData.fNativeBanner : null;
        */

        case 'rewarded':
          if (useFallback) {
            if (Platform.isAndroid) {
              return adData.gazRewarded.isNotEmpty ? adData.gazRewarded : null;
            } else {
              return adData.dwRewarded.isNotEmpty ? adData.dwRewarded : null;
            }
          }
          if (Platform.isAndroid) {
            return adData.gRewarded.isNotEmpty ? adData.gRewarded : null;
          } else {
            return adData.applRewarded.isNotEmpty ? adData.applRewarded : null;
          }

        default:
          return null;
      }
    }

    Future<void> loadAppOpenAd({
      bool showOnLoad = false,
      bool waitForDismiss = false,
      bool useFallback = false,
      bool isAppResume = false,
    }) async {
      // Check if ads are enabled
      if (!_areAdsEnabled()) {
        print('🚫 AdService: Ads are disabled (AdStart = false) - skipping ad load');
        return;
      }

      try {
        if (_isAppOpenAdReady && _appOpenAd != null && !useFallback) {
          if (showOnLoad) {
            await showAppOpenAd(waitForDismiss: waitForDismiss);
          }
          return;
        }

        if (_adLoadCompleter != null && !useFallback) {
          if (showOnLoad) {
            try {
              await _adLoadCompleter!.future.timeout(
                const Duration(seconds: 6),
                onTimeout: () {
                  // Continue without ad if timeout
                },
              );
              if (_isAppOpenAdReady) {
                await showAppOpenAd(waitForDismiss: waitForDismiss);
              }
            } catch (e) {
              // Continue without ad on timeout or error
            }
          }
          return;
        }

        final adUnitId = _getAdUnitId('appOpen', useFallback: useFallback, isAppResume: isAppResume);
        if (adUnitId == null || adUnitId.isEmpty || adUnitId == '0') {
          // Log which ad key was attempted
          final adData = adsResponseService.getCreditEducationData();
          if (adData != null) {
            String attemptedKey = '';
            if (useFallback) {
              // DwAppOpen is ONLY used for app resume
              attemptedKey = isAppResume ? 'DwAppOpen' : 'N/A (no fallback)';
            } else {
              attemptedKey = Platform.isAndroid ? 'GAppOpen' : (Platform.isIOS ? 'ApplAppOpen' : 'GAppOpen');
            }
            print('⚠️  AdService: Ad Unit ID not available for key: $attemptedKey');
          }

          // If primary ad ID not available and haven't tried fallback, try fallback
          if (!useFallback && !_hasTriedFallback) {
            _hasTriedFallback = true;
            await loadAppOpenAd(
              showOnLoad: showOnLoad,
              waitForDismiss: waitForDismiss,
              useFallback: true,
              isAppResume: isAppResume,
            );
          }
          return;
        }

        // Log which ad key is being used
        String adKeyName = '';
        if (useFallback) {
          // DwAppOpen is ONLY used for app resume scenarios
          if (isAppResume) {
            adKeyName = 'DwAppOpen';
            print('🔄 AdService: Loading fallback ad using API key: $adKeyName (app resume) | Ad Unit ID: $adUnitId');
          } else {
            // This shouldn't happen, but log it if it does
            print('⚠️  AdService: Fallback requested but not for app resume - skipping');
            return;
          }
        } else {
          adKeyName = Platform.isAndroid ? 'GAppOpen' : (Platform.isIOS ? 'ApplAppOpen' : 'GAppOpen');
          print('📱 AdService: Loading primary ad using API key: $adKeyName | Ad Unit ID: $adUnitId');
        }

        _adLoadCompleter = Completer<void>();
        _adLoadCompleter!.future.catchError((_) {});

        // Create dismiss completer if we need to wait for dismissal
        if (showOnLoad && waitForDismiss) {
          _adDismissCompleter = Completer<void>();
          _adDismissCompleter!.future.catchError((_) {});
        }

        // For background loading (showOnLoad = false), don't await - let it load asynchronously
        if (!showOnLoad) {
          // Fire and forget - load in background without blocking
          AppOpenAd.load(
            adUnitId: adUnitId,
            request: const AdRequest(),
            adLoadCallback: AppOpenAdLoadCallback(
              onAdLoaded: (ad) {
                String adKeyName = '';
                if (useFallback) {
                  // DwAppOpen is ONLY used for app resume scenarios
                  if (isAppResume) {
                    adKeyName = 'DwAppOpen';
                    print(
                      '✅ AdService: Fallback App Open Ad loaded successfully (background) (app resume) | API Key: $adKeyName | Ad Unit ID: $adUnitId',
                    );
                  } else {
                    adKeyName = 'N/A';
                    print(
                      '✅ AdService: Fallback App Open Ad loaded successfully (background) | API Key: $adKeyName | Ad Unit ID: $adUnitId',
                    );
                  }
                } else {
                  adKeyName = Platform.isAndroid ? 'GAppOpen' : (Platform.isIOS ? 'ApplAppOpen' : 'GAppOpen');
                  print(
                    '✅ AdService: App Open Ad loaded successfully (background) | API Key: $adKeyName | Ad Unit ID: $adUnitId',
                  );
                }
                _appOpenAd = ad;
                _isAppOpenAdReady = true;
                _hasTriedFallback = false; // Reset flag on successful load
                AdRevenueLogger.attachRevenueTracking(
                  ad: ad,
                  adFormat: 'app_open',
                );
                _adLoadCompleter?.complete();
                _adLoadCompleter = null;

                ad.fullScreenContentCallback = FullScreenContentCallback(
                  onAdShowedFullScreenContent: (ad) {
                    _isAdShowing = true;
                  },
                  onAdDismissedFullScreenContent: (ad) {
                    _isAdShowing = false;
                    _appOpenAd = null;
                    _isAppOpenAdReady = false;
                    ad.dispose();
                    _adDismissCompleter?.complete();
                    _adDismissCompleter = null;
                  },
                  onAdFailedToShowFullScreenContent: (ad, error) {
                    _isAdShowing = false;
                    _appOpenAd = null;
                    _isAppOpenAdReady = false;
                    ad.dispose();
                    _adDismissCompleter?.completeError(error);
                    _adDismissCompleter = null;
                  },
                );
              },
              onAdFailedToLoad: (error) {
                String adKeyName = useFallback
                    ? (isAppResume ? 'DwAppOpen' : 'N/A') // DwAppOpen ONLY for app resume
                    : (Platform.isAndroid ? 'GAppOpen' : (Platform.isIOS ? 'ApplAppOpen' : 'GAppOpen'));
                String context = useFallback && isAppResume ? ' (app resume)' : '';
                print(
                  '❌ AdService: Failed to load App Open Ad (background)$context | API Key: $adKeyName | Ad Unit ID: $adUnitId | Error: ${error.message}',
                );
                _isAppOpenAdReady = false;
                _appOpenAd = null;
                _adLoadCompleter?.completeError(error);
                _adLoadCompleter = null;

                // Try fallback if primary ad failed and haven't tried fallback yet
                if (!useFallback && !_hasTriedFallback) {
                  _hasTriedFallback = true;
                  print('🔄 AdService: Attempting to load fallback ad | API Key: ${Platform.isAndroid ? "GazAppOpen" : "DwAppOpen"}');
                  loadAppOpenAd(
                    showOnLoad: showOnLoad,
                    waitForDismiss: waitForDismiss,
                    useFallback: true,
                    isAppResume: isAppResume,
                  );
                }
              },
            ),
          );
          return;
        }

        // Load ad with 6-second timeout
        AppOpenAd.load(
          adUnitId: adUnitId,
          request: const AdRequest(),
          adLoadCallback: AppOpenAdLoadCallback(
            onAdLoaded: (ad) {
              String adKeyName = '';
              if (useFallback) {
                // DwAppOpen is ONLY used for app resume scenarios
                if (isAppResume) {
                  adKeyName = 'DwAppOpen';
                  print(
                    '✅ AdService: Fallback App Open Ad loaded successfully (app resume) | API Key: $adKeyName | Ad Unit ID: $adUnitId',
                  );
                } else {
                  adKeyName = 'N/A';
                  print(
                    '✅ AdService: Fallback App Open Ad loaded successfully | API Key: $adKeyName | Ad Unit ID: $adUnitId',
                  );
                }
              } else {
                adKeyName = Platform.isAndroid ? 'GAppOpen' : (Platform.isIOS ? 'ApplAppOpen' : 'GAppOpen');
                print('✅ AdService: App Open Ad loaded successfully | API Key: $adKeyName | Ad Unit ID: $adUnitId');
              }
              _appOpenAd = ad;
              _isAppOpenAdReady = true;
              _hasTriedFallback = false; // Reset flag on successful load
              AdRevenueLogger.attachRevenueTracking(
                ad: ad,
                adFormat: 'app_open',
              );
              _adLoadCompleter?.complete();
              _adLoadCompleter = null;

              ad.fullScreenContentCallback = FullScreenContentCallback(
                onAdShowedFullScreenContent: (ad) {
                  _isAdShowing = true;
                },
                onAdDismissedFullScreenContent: (ad) {
                  _isAdShowing = false;
                  _appOpenAd = null;
                  _isAppOpenAdReady = false;
                  ad.dispose();
                  _adDismissCompleter?.complete();
                  _adDismissCompleter = null;
                },
                onAdFailedToShowFullScreenContent: (ad, error) {
                  _isAdShowing = false;
                  _appOpenAd = null;
                  _isAppOpenAdReady = false;
                  ad.dispose();
                  _adDismissCompleter?.completeError(error);
                  _adDismissCompleter = null;
                },
              );

              if (showOnLoad) {
                showAppOpenAd(waitForDismiss: waitForDismiss);
              }
            },
            onAdFailedToLoad: (error) {
              String adKeyName = useFallback
                  ? (isAppResume ? 'DwAppOpen' : 'N/A') // DwAppOpen ONLY for app resume
                  : (Platform.isAndroid ? 'GAppOpen' : (Platform.isIOS ? 'ApplAppOpen' : 'GAppOpen'));
              String context = useFallback && isAppResume ? ' (app resume)' : '';
              print(
                '❌ AdService: Failed to load App Open Ad$context | API Key: $adKeyName | Ad Unit ID: $adUnitId | Error: ${error.message}',
              );
              _isAppOpenAdReady = false;
              _appOpenAd = null;
              _adLoadCompleter?.completeError(error);
              _adLoadCompleter = null;
              if (_adDismissCompleter != null) {
                _adDismissCompleter?.completeError(error);
                _adDismissCompleter = null;
              }

              // Try fallback if primary ad failed and haven't tried fallback yet
              if (!useFallback && !_hasTriedFallback) {
                _hasTriedFallback = true;
                print('🔄 AdService: Attempting to load fallback ad | API Key: ${Platform.isAndroid ? "GazAppOpen" : "DwAppOpen"}');
                loadAppOpenAd(
                  showOnLoad: showOnLoad,
                  waitForDismiss: waitForDismiss,
                  useFallback: true,
                  isAppResume: isAppResume,
                );
              }
            },
          ),
        );

        // Wait for ad to load with 6-second timeout
        try {
          await _adLoadCompleter!.future.timeout(
            const Duration(seconds: 6),
            onTimeout: () {
              String adKeyName = useFallback
                  ? (isAppResume ? 'DwAppOpen' : 'N/A') // DwAppOpen ONLY for app resume
                  : (Platform.isAndroid ? 'GAppOpen' : (Platform.isIOS ? 'ApplAppOpen' : 'GAppOpen'));
              String context = useFallback && isAppResume ? ' (app resume)' : '';
              print(
                '⏱️  AdService: App Open Ad load timeout (6 seconds)$context | API Key: $adKeyName | Ad Unit ID: $adUnitId',
              );
              _adLoadCompleter = null;
              if (_adDismissCompleter != null) {
                _adDismissCompleter?.completeError(TimeoutException('Ad load timeout'));
                _adDismissCompleter = null;
              }
            },
          );
        } on TimeoutException {
          // Ad load timed out - try fallback if not already tried
          if (!useFallback && !_hasTriedFallback) {
            _hasTriedFallback = true;
            print('🔄 AdService: Attempting to load fallback ad after timeout | API Key: ${Platform.isAndroid ? "GazAppOpen" : "DwAppOpen"}');
            await loadAppOpenAd(
              showOnLoad: showOnLoad,
              waitForDismiss: waitForDismiss,
              useFallback: true,
              isAppResume: isAppResume,
            );
            return;
          }
          return;
        } catch (e) {
          // Try fallback on error if not already tried
          if (!useFallback && !_hasTriedFallback) {
            _hasTriedFallback = true;
            print(
              '🔄 AdService: Attempting to load fallback ad after error | API Key: ${Platform.isAndroid ? "GazAppOpen" : "DwAppOpen"} | Error: $e',
            );
            await loadAppOpenAd(
              showOnLoad: showOnLoad,
              waitForDismiss: waitForDismiss,
              useFallback: true,
              isAppResume: isAppResume,
            );
            return;
          }
          return;
        }

        if (showOnLoad && waitForDismiss && _adDismissCompleter != null) {
          try {
            int showAttempts = 0;
            while (!_isAdShowing && showAttempts < 25) {
              await Future.delayed(const Duration(milliseconds: 100));
              showAttempts++;
            }

            await _adDismissCompleter!.future.timeout(const Duration(seconds: 60), onTimeout: () {});
          } catch (e) {
            // Continue on error
          }
        }
      } catch (e) {
        _adLoadCompleter?.completeError(e);
        _adLoadCompleter = null;
      }
    }

    /// Show App Open Ad
    /// Returns true if ad was shown, false otherwise
    /// If [waitForDismiss] is true, waits for ad to be dismissed before returning
    Future<bool> showAppOpenAd({bool waitForDismiss = false}) async {
      // Check if ads are enabled
      if (!_areAdsEnabled()) {
        print('🚫 AdService: Ads are disabled (AdStart = false) - skipping ad show');
        return false;
      }

      try {
        // CRITICAL: Prevent overlapping ads
        if (_isAdShowing) {
          print('🚫 AdService: Another ad is already visible - skipping show');
          if (waitForDismiss && _adDismissCompleter != null) {
            try {
              await _adDismissCompleter!.future.timeout(const Duration(seconds: 15), onTimeout: () {});
              return true;
            } catch (e) {
              return false;
            }
          }
          return false;
        }

        if (!_isAppOpenAdReady || _appOpenAd == null) {
          try {
            await loadAppOpenAd(showOnLoad: true, waitForDismiss: waitForDismiss).timeout(
              const Duration(seconds: 6),
              onTimeout: () {
                // Continue without ad if timeout
              },
            );
          } catch (e) {
            // Continue without ad on error
          }
          if (!_isAppOpenAdReady || _appOpenAd == null) {
            return false;
          }
        }

        // Double check foreground state before final show call
        if (!isForeground) {
          print('🚫 AdService: App moved to background during load, skipping show');
          return false;
        }

        if (waitForDismiss && _adDismissCompleter == null) {
          _adDismissCompleter = Completer<void>();
          _adDismissCompleter!.future.catchError((_) {});
        }

        try {
          _appOpenAd!.show();
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          print('❌ AdService: Exception in AppOpenAd.show(): $e');
          _isAppOpenAdReady = false;
          _appOpenAd = null;
          return false;
        }

        if (waitForDismiss) {
          try {
            int showAttempts = 0;
            while (!_isAdShowing && showAttempts < 20) {
              await Future.delayed(const Duration(milliseconds: 100));
              showAttempts++;
            }

            await _adDismissCompleter!.future.timeout(const Duration(seconds: 60), onTimeout: () {});
          } catch (e) {
            // Continue on error
          } finally {
            _adDismissCompleter = null;
          }
        }

        return true;
      } catch (e) {
        _adDismissCompleter?.completeError(e);
        _adDismissCompleter = null;
        return false;
      }
    }

    /// Show background-loaded App Open Ad
    /// This is called after navigation when splashAppOpan was false
    Future<void> showBackgroundLoadedAd() async {
      // Check if ads are enabled
      if (!_areAdsEnabled()) return;

      if (_isAdShowing) {
        print('🚫 AdService: Cannot show background ad - another ad is visible');
        return;
      }

      if (_isAppOpenAdReady && _appOpenAd != null) {
        await showAppOpenAd(waitForDismiss: false);
      } else if (!_isAppOpenAdReady) {
        int attempts = 0;
        while (!_isAppOpenAdReady && attempts < 20) {
          if (!isForeground || _isAdShowing) break;
          await Future.delayed(const Duration(milliseconds: 200));
          attempts++;
        }
        if (_isAppOpenAdReady && _appOpenAd != null && !_isAdShowing && isForeground) {
          await showAppOpenAd(waitForDismiss: false);
        }
      }
    }

    /// Dispose of App Open Ad
    void disposeAppOpenAd() {
      _appOpenAd?.dispose();
      _appOpenAd = null;
      _isAppOpenAdReady = false;
      _isAdShowing = false;
      _hasTriedFallback = false; // Reset fallback flag
    }

    // Native Ad Management
    NativeAd? _smallNativeAd;
    NativeAd? _largeNativeAd;
    bool _isSmallNativeAdReady = false;
    bool _isLargeNativeAdReady = false;

    // Native Ad Pre-loading Pool
    // We maintain a pool of PRE-LOADED ads that have never been shown.
    // When a screen starts, it claims a ready-to-use ad from this pool.
    final List<NativeAd> _preloadedSmallAds = [];
    final List<NativeAd> _preloadedLargeAds = [];
    static const int _targetPoolSize = 1; // RULE: Pool max = 1
    bool _isSmallInFlight = false;
    bool _isLargeInFlight = false;
    Timer? _smallInFlightTimer;
    Timer? _largeInFlightTimer;

    /// Public getters to check pool status
    /// Includes in-flight loading status to prevent redundant requests (FIX 4)
    int get smallPoolCount => _preloadedSmallAds.length;
    int get largePoolCount => _preloadedLargeAds.length;
    bool get isSmallPoolFull => _preloadedSmallAds.length >= _targetPoolSize || _isSmallInFlight;
    bool get isLargePoolFull => _preloadedLargeAds.length >= _targetPoolSize || _isLargeInFlight;

    /// Start pre-loading native ads to fill the pools
    /// Triggered on app init or after an ad is claimed/loaded
    /// [isLarge] if provided, only refills the specified pool. If null, refills both.
    void preloadNativeAds({bool? isLarge}) {
      if (!_areAdsEnabled()) return;
      if (isLarge == null || isLarge == false) _refillSmallPool();
      if (isLarge == null || isLarge == true) _refillLargePool();
    }

    void _refillSmallPool() {
      // FIX 1 & 4: Pool full check and loading lock BEFORE making any request
      if (!_areAdsEnabled()) return;
      if (_isSmallInFlight) {
        print('⏳ AdService: Small native ad load already in-flight, skipping');
        return;
      }
      if (isSmallPoolFull) {
        print('📦 AdService: Small pool is full (${_preloadedSmallAds.length}), skipping refill');
        return;
      }

      // FIX 3: Consistent skip logic for pre-loading
      if (!shouldPreloadNativeAd()) {
        print('📦 AdService: Next screen (Count: ${_nativeScreenCount + 1}) does not require native ad, skipping pre-load');
        return;
      }

      _isSmallInFlight = true;
      _smallInFlightTimer?.cancel();
      _smallInFlightTimer = Timer(const Duration(seconds: 15), () {
        if (_isSmallInFlight) {
          print('⏰ AdService: Small native pool refill timed out');
          _isSmallInFlight = false;
        }
      });
      _loadNativeAdToPool(isLarge: false);
    }

    void _refillLargePool() {
      // FIX 1 & 4: Pool full check and loading lock BEFORE making any request
      if (!_areAdsEnabled()) return;
      if (_isLargeInFlight) {
        print('⏳ AdService: Large native ad load already in-flight, skipping');
        return;
      }
      if (isLargePoolFull) {
        print('📦 AdService: Large pool is full (${_preloadedLargeAds.length}), skipping refill');
        return;
      }

      // FIX 3: Consistent skip logic for pre-loading
      if (!shouldPreloadNativeAd()) {
        print('📦 AdService: Next screen (Count: ${_nativeScreenCount + 1}) does not require native ad, skipping pre-load');
        return;
      }

      _isLargeInFlight = true;
      _largeInFlightTimer?.cancel();
      _largeInFlightTimer = Timer(const Duration(seconds: 20), () {
        if (_isLargeInFlight) {
          print('⏰ AdService: Large native pool refill timed out');
          _isLargeInFlight = false;
        }
      });
      _loadNativeAdToPool(isLarge: true);
    }

    void _loadNativeAdToPool({required bool isLarge, bool isFallback = false}) {
      // Double check before starting (Safety first)
      if (isLarge) {
        if (isLargePoolFull && !isFallback) {
          _isLargeInFlight = false;
          return;
        }
      } else {
        if (isSmallPoolFull && !isFallback) {
          _isSmallInFlight = false;
          return;
        }
      }

      final adUnitId = _getAdUnitId('native', useFallback: isFallback);
      if (adUnitId == null || adUnitId.isEmpty || adUnitId == '0') {
        if (!isFallback) {
          print('⚠️ AdService: Primary native ID not available, trying fallback...');
          _loadNativeAdToPool(isLarge: isLarge, isFallback: true);
          return;
        }
        if (isLarge)
          _isLargeInFlight = false;
        else
          _isSmallInFlight = false;
        return;
      }

      print('📱 AdService: Pre-loading ${isLarge ? "large" : "small"} native ad into pool (isFallback: $isFallback) | Ad Unit ID: $adUnitId');

      late NativeAd ad;
      ad = NativeAd(
        adUnitId: adUnitId,
        factoryId: isLarge ? 'mediumAdFactory' : 'jobStyleAdFactory',
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
          onAdLoaded: (_) {
            print('✅ AdService: ${isLarge ? "Large" : "Small"} native ad pre-loaded successfully (isFallback: $isFallback)');
            if (isLarge) {
              _preloadedLargeAds.add(ad);
              _isLargeInFlight = false;
              _largeInFlightTimer?.cancel();
            } else {
              _preloadedSmallAds.add(ad);
              _isSmallInFlight = false;
              _smallInFlightTimer?.cancel();
            }
          },
          onAdFailedToLoad: (failedAd, error) {
            print('❌ AdService: Failed to pre-load ${isLarge ? "large" : "small"} native ad (isFallback: $isFallback) | Error: ${error.message}');
            failedAd.dispose();

            if (!isFallback) {
              print('🔄 AdService: Attempting backup Gaz ID for pre-load native ad...');
              _loadNativeAdToPool(isLarge: isLarge, isFallback: true);
            } else {
              if (isLarge) {
                _isLargeInFlight = false;
                _largeInFlightTimer?.cancel();
              } else {
                _isSmallInFlight = false;
                _smallInFlightTimer?.cancel();
              }
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

    /// Claim a pre-loaded small native ad
    /// FIX 2 & 5: Decoupled pre-load trigger from claim
    NativeAd? claimCachedSmallAd() {
      if (_preloadedSmallAds.isNotEmpty) {
        final ad = _preloadedSmallAds.removeAt(0);
        print('📦 AdService: Claimed pre-loaded small ad (Remaining: ${_preloadedSmallAds.length})');
        return ad;
      }
      return null;
    }

    /// Claim a pre-loaded large native ad
    /// FIX 2 & 5: Decoupled pre-load trigger from claim
    NativeAd? claimCachedLargeAd() {
      if (_preloadedLargeAds.isNotEmpty) {
        final ad = _preloadedLargeAds.removeAt(0);
        print('📦 AdService: Claimed pre-loaded large ad (Remaining: ${_preloadedLargeAds.length})');
        return ad;
      }
      return null;
    }

    /// No longer releasing back to pool to avoid reuse issues & blank spots.
    /// Each screen should dispose its ad on close.
    void releaseCachedAd(NativeAd? ad, {bool isLarge = false}) {
      if (ad == null) return;
      print('📦 AdService: Ad disposal managed by controller (Pool is fresh-only)');
      // If we want to truly never dispose, we could put it back, but SDK reuse is buggy.
      // For now, let's let the mixin dispose it.
    }

    /// Load inline native ads for a paginated list
    /// [itemCount] total items in the list (used to determine number of ads)
    /// [interval] show one ad after every [interval] items
    /// [inlineAds] target reactive list of native ads to populate
    /// [isAdLoaded] target reactive list of load flags aligned with [inlineAds]
    /// [factoryId] the native ad factory to use (e.g., 'jobStyleAdFactory')
    void loadInlineNativeAdsForList({
      required int itemCount,
      int interval = 4,
      required RxList<NativeAd?> inlineAds,
      required RxList<bool> isAdLoaded,
      String factoryId = 'jobStyleAdFactory',
    }) {
      // Always dispose existing ad instances first
      for (var ad in inlineAds) {
        ad?.dispose();
      }

      // If ads are disabled, clear lists and return
      if (!_areAdsEnabled()) {
        inlineAds.clear();
        isAdLoaded.clear();
        print('🚫 AdService: Ads are disabled (AdStart = false) - skipping inline native ads');
        return;
      }

      // Calculate how many ads we need (one after every [interval] items)
      final numberOfAds = (itemCount / interval).ceil();

      // Initialize lists
      inlineAds.clear();
      isAdLoaded.clear();
      for (int i = 0; i < numberOfAds; i++) {
        inlineAds.add(null);
        isAdLoaded.add(false);
        _loadInlineNativeAd(index: i, inlineAds: inlineAds, isAdLoaded: isAdLoaded, factoryId: factoryId);
      }
    }

    /// Load a single inline native ad into target lists
    void _loadInlineNativeAd({
      required int index,
      required RxList<NativeAd?> inlineAds,
      required RxList<bool> isAdLoaded,
      String factoryId = 'jobStyleAdFactory',
      bool isFallback = false,
    }) {
      if (!_areAdsEnabled()) {
        return;
      }

      final adUnitId = _getAdUnitId('native', useFallback: isFallback);
      if (adUnitId == null || adUnitId.isEmpty || adUnitId == '0') {
        if (!isFallback) {
          print('⚠️ AdService: Primary inline native ID not available, trying fallback...');
          _loadInlineNativeAd(
            index: index,
            inlineAds: inlineAds,
            isAdLoaded: isAdLoaded,
            factoryId: factoryId,
            isFallback: true,
          );
          return;
        }
        print('⚠️  AdService: Inline native ad unit ID not available (isFallback: $isFallback)');
        return;
      }

      print('📱 AdService: Loading inline native ad #$index (isFallback: $isFallback) | Ad Unit ID: $adUnitId');

      final ad = NativeAd(
        adUnitId: adUnitId,
        factoryId: factoryId,
        request: const AdRequest(),
        nativeAdOptions: NativeAdOptions(adChoicesPlacement: AdChoicesPlacement.topRightCorner),
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
          onAdLoaded: (loadedAd) {
            print('✅ AdService: Inline native ad #$index loaded successfully (isFallback: $isFallback)');
            if (index < inlineAds.length) {
              inlineAds[index] = loadedAd as NativeAd;
              isAdLoaded[index] = true;
            }
          },
          onAdFailedToLoad: (failedAd, error) {
            print('❌ AdService: Failed to load inline native ad #$index (isFallback: $isFallback) | Error: ${error.message}');
            failedAd.dispose();

            if (!isFallback) {
              print('🔄 AdService: Attempting backup Gaz ID for inline native ad #$index...');
              _loadInlineNativeAd(
                index: index,
                inlineAds: inlineAds,
                isAdLoaded: isAdLoaded,
                factoryId: factoryId,
                isFallback: true,
              );
            } else {
              if (index < inlineAds.length) {
                isAdLoaded[index] = false;
                inlineAds[index] = null;
              }
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

    /// Dispose and clear inline native ads lists
    void disposeInlineNativeAds(RxList<NativeAd?> inlineAds, RxList<bool> isAdLoaded) {
      for (var ad in inlineAds) {
        ad?.dispose();
      }
      inlineAds.clear();
      isAdLoaded.clear();
    }

    /// Load small native ad
    Future<void> loadSmallNativeAd({bool isFallback = false}) async {
      if (!_areAdsEnabled()) {
        print('🚫 AdService: Ads are disabled (AdStart = false) - skipping small native ad load');
        return;
      }

      // Check if we should show based on navigation count
      if (!shouldShowNativeAd()) {
        return;
      }

      if (_isSmallNativeAdReady && _smallNativeAd != null && !isFallback) {
        return;
      }

      final adUnitId = _getAdUnitId('native', useFallback: isFallback);
      if (adUnitId == null || adUnitId.isEmpty || adUnitId == '0') {
        print('⚠️  AdService: Native ad unit ID not available (isFallback: $isFallback)');
        return;
      }

      print('📱 AdService: Loading small native ad (isFallback: $isFallback) | Ad Unit ID: $adUnitId');

      _smallNativeAd = NativeAd(
        adUnitId: adUnitId,
        factoryId: 'jobStyleAdFactory',
        request: const AdRequest(),
        nativeAdOptions: NativeAdOptions(adChoicesPlacement: AdChoicesPlacement.topRightCorner),
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
            print('✅ AdService: Small native ad loaded successfully (isFallback: $isFallback) | Ad Unit ID: $adUnitId');
            _isSmallNativeAdReady = true;
          },
          onAdFailedToLoad: (ad, error) {
            print('❌ AdService: Failed to load small native ad (isFallback: $isFallback) | Ad Unit ID: $adUnitId | Error: ${error.message}');
            _isSmallNativeAdReady = false;
            _smallNativeAd = null;
            ad.dispose();

            if (!isFallback) {
              print('🔄 AdService: Attempting backup Gaz ID for small native ad...');
              loadSmallNativeAd(isFallback: true);
            }
          },
        ),
      );
      try {
        _smallNativeAd?.load().timeout(
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

    /// Load large native ad
    Future<void> loadLargeNativeAd({bool isFallback = false}) async {
      if (!_areAdsEnabled()) {
        print('🚫 AdService: Ads are disabled (AdStart = false) - skipping large native ad load');
        return;
      }

      // Check if we should show based on navigation count (using same logic as small native ad)
      if (!shouldShowNativeAd()) {
        return;
      }

      if (_isLargeNativeAdReady && _largeNativeAd != null && !isFallback) {
        return;
      }

      final adUnitId = _getAdUnitId('native', useFallback: isFallback);
      if (adUnitId == null || adUnitId.isEmpty || adUnitId == '0') {
        print('⚠️  AdService: Native ad unit ID not available (isFallback: $isFallback)');
        return;
      }

      print('📱 AdService: Loading large native ad (isFallback: $isFallback) | Ad Unit ID: $adUnitId');

      _largeNativeAd = NativeAd(
        adUnitId: adUnitId,
        factoryId: "mediumAdFactory",
        request: const AdRequest(),
        nativeAdOptions: NativeAdOptions(adChoicesPlacement: AdChoicesPlacement.topRightCorner),
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
            print('✅ AdService: Large native ad loaded successfully (isFallback: $isFallback) | Ad Unit ID: $adUnitId');
            _isLargeNativeAdReady = true;
          },
          onAdFailedToLoad: (ad, error) {
            print('❌ AdService: Failed to load large native ad (isFallback: $isFallback) | Ad Unit ID: $adUnitId | Error: ${error.message}');
            _isLargeNativeAdReady = false;
            _largeNativeAd = null;
            ad.dispose();

            if (!isFallback) {
              print('🔄 AdService: Attempting backup Gaz ID for large native ad...');
              loadLargeNativeAd(isFallback: true);
            }
          },
        ),
      );
      try {
        _largeNativeAd?.load().timeout(
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

    /// Get small native ad
    NativeAd? getSmallNativeAd() {
      if (_isSmallNativeAdReady && _smallNativeAd != null) {
        return _smallNativeAd;
      }
      return null;
    }

    /// Get large native ad
    NativeAd? getLargeNativeAd() {
      if (_isLargeNativeAdReady && _largeNativeAd != null) {
        return _largeNativeAd;
      }
      return null;
    }

    /// Dispose of native ads
    void disposeNativeAds() {
      _smallNativeAd?.dispose();
      _smallNativeAd = null;
      _isSmallNativeAdReady = false;

      _largeNativeAd?.dispose();
      _largeNativeAd = null;
      _isLargeNativeAdReady = false;

      // Dispose cached ads in the pool
      for (var ad in _preloadedSmallAds) {
        ad.dispose();
      }
      _preloadedSmallAds.clear();

      for (var ad in _preloadedLargeAds) {
        ad.dispose();
      }
      _preloadedLargeAds.clear();
    }

    // Native Ad Navigation Logic
    int _nativeScreenCount = 0;

    /// Increment native screen count
    /// Call this when a screen that uses native ads is initialized
    /// Increment native screen count
    /// Call this when a screen that uses native ads is initialized
    void incrementNativeScreenCount() {
      if (!_areAdsEnabled()) return;

      final adData = adsResponseService.getCreditEducationData();
      if (adData == null) return;

      // Only increment if iNativePosition > 0
      if (adData.iNativePosition > 0) {
        _nativeScreenCount++;
        print(
          '🧭 AdService: Native screen count incremented to: $_nativeScreenCount | iNativePosition: ${adData.iNativePosition}',
        );
      }
    }

    /// Consistent check to see if an ad should be shown for the current screen count
    bool shouldShowNativeAd() {
      return _shouldDisplayNativeAd(count: _nativeScreenCount);
    }

    /// Consistent check to see if we should start pre-loading for the NEXT screen
    /// Fix for the 4x request issue: Pre-loading only triggers if the next screen actually needs it.
    bool shouldPreloadNativeAd() {
      // If pool is already full, no need to even check the next screen count
      if (isSmallPoolFull || isLargePoolFull) return false;

      // Check if the NEXT screen in the cycle will require an ad
      return _shouldDisplayNativeAd(count: _nativeScreenCount + 1);
    }

    /// Core logic for native ad frequency gating
    /// [count] corresponds to the 1-indexed navigation screen count
    bool _shouldDisplayNativeAd({required int count}) {
      if (!_areAdsEnabled()) return false;

      final adData = adsResponseService.getCreditEducationData();
      if (adData == null) return false;

      final position = adData.iNativePosition;

      // position 0 means ads are disabled for native, 1 means show every time
      if (position <= 0) return false;
      if (position == 1) return true;

      // Cycle logic: Show ad if current count is a multiple of position
      return count > 0 && count % position == 0;
    }

    // Banner Ad Navigation Logic

    // Interstitial Ad Click Logic
    int _interstitialClickCount = 0;

    /// Check if interstitial ad should be shown based on InterCount
    /// [increment] if true, increments the click count before checking. Default is true.
    /// If [increment] is false, strictly simulates the next click without changing state.
    bool shouldShowInterstitialAd({bool increment = true}) {
      if (!_areAdsEnabled()) {
        return false;
      }

      final adData = adsResponseService.getCreditEducationData();
      if (adData == null) {
        return false;
      }

      if (increment) {
        _interstitialClickCount++;
        print('🖱️ AdService: Click count: $_interstitialClickCount | InterCount: ${adData.interCount}');
      }

      final interCount = adData.interCount;

      // If interCount is 0 or less, show ad every time
      if (interCount <= 0) {
        if (increment) _interstitialClickCount = 0;
        return true;
      }

      // New Logic: Show ad only when click count reaches InterCount
      if (_interstitialClickCount >= interCount) {
        if (increment) {
          print('✅ AdService: Click count ($_interstitialClickCount) reached InterCount ($interCount). Showing ad.');
          _interstitialClickCount = 0; // Reset as requested
        }
        return true;
      }

      if (increment) {
        print('⏭️ AdService: Skipping interstitial ad (Click count $_interstitialClickCount < InterCount $interCount)');
      }
      return false;
    }

    int _levelUpdateCount = 0;

    /// Check if interstitial ad should be shown based on levelSkipCount
    /// [increment] if true, increments the level update count before checking. Default is true.
    bool shouldShowInterstitialAdOnLevelUpdate({bool increment = true}) {
      if (!_areAdsEnabled()) {
        return false;
      }

      final adData = adsResponseService.getCreditEducationData();
      if (adData == null) {
        return false;
      }

      final levelSkipCount = adData.levelSkipCount;

      if (increment) {
        _levelUpdateCount++;
        print('🏆 AdService: Level update count: $_levelUpdateCount | levelSkipCount: $levelSkipCount');
      }

      // If levelSkipCount is 0 or less, show ad every time
      if (levelSkipCount <= 0) {
        if (increment) _levelUpdateCount = 0;
        return true;
      }

      // Show ad only when level update count reaches levelSkipCount
      if (_levelUpdateCount >= levelSkipCount) {
        if (increment) {
          print('✅ AdService: Level update count ($_levelUpdateCount) reached levelSkipCount ($levelSkipCount). Showing ad.');
          _levelUpdateCount = 0; // Reset
        }
        return true;
      }

      if (increment) {
        print('⏭️ AdService: Skipping level update interstitial ad (Level update count $_levelUpdateCount < levelSkipCount $levelSkipCount)');
      }
      return false;
    }

    /*
    void tryFacebookNative(RxBool isAdLoaded, RxBool isAdFailed, VoidCallback? onAdLoaded, VoidCallback? onAdFailed) {
      if (!_isFacebookEnabled()) {
        isAdLoaded.value = false;
        isAdFailed.value = true;
        onAdFailed?.call();
        return;
      }

      final fbId = _getAdUnitId('facebook_native');
      if (fbId == null || fbId.isEmpty || fbId == '0') {
        isAdLoaded.value = false;
        isAdFailed.value = true;
        onAdFailed?.call();
        return;
      }

      print('🔄 AdService: Attempting Facebook fallback native ad...');
      // For Facebook native, we don't have a 'NativeAd' object we can pass around like AdMob.
      // Instead, we'll just flag it as loaded and have the widget handle the rendering.
      isAdLoaded.value = true;
      onAdLoaded?.call();
    }

    void tryFacebookInterstitial({required VoidCallback onAdDismissed, required VoidCallback onAdFailed}) {
      if (!_isFacebookEnabled()) {
        onAdFailed();
        return;
      }

      final fbId = _getAdUnitId('facebook_interstitial');
      if (fbId == null || fbId.isEmpty || fbId == '0') {
        onAdFailed();
        return;
      }

      print('🔄 AdService: Attempting Facebook fallback interstitial ad...');

      final interstitialAd = facebook.InterstitialAd(fbId);
      interstitialAd.listener = facebook.InterstitialAdListener(
        onLoaded: () {
          print('✅ FB Interstitial Loaded');
          interstitialAd.show();
        },
        onError: (code, message) {
          print('❌ FB Interstitial Error: $message');
          onAdFailed();
        },
        onDismissed: () {
          print('✅ FB Interstitial Dismissed');
          interstitialAd.destroy();
          onAdDismissed();
        },
      );
      try {
        interstitialAd.load().timeout(
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
    */
  }