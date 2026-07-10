import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'large_native_ad_widget.dart';
import 'small_native_ad_widget.dart';
import 'facebook_native_ad_widget.dart';
import 'mixins/native_ad_mixin.dart';
import 'controller/ads_response_service.dart';
import 'ad_shimmer_widgets.dart';

class NativeAdBuilder {
  static Widget buildSmallAd(GetxController controller, {bool? isSize}) {
    // Hide if premium or ads disabled globally

    
    final adData = Get.find<AdsResponseService>().getCreditEducationData();
    if (adData != null && !adData.adStart) {
      return const SizedBox.shrink();
    }

    if (controller is! NativeAdMixin) {
      return const SmallAdCardShell(child: SmallNativeAdShimmer());
    }

    return Obx(() {
      final nativeAd = controller.smallNativeAd.value;
      if (nativeAd != null) {
        return SmallNativeAdWidget(nativeAd: nativeAd, key: ObjectKey(nativeAd),);
      }
      
/*
      // Facebook Fallback check
      if (controller.isSmallNativeAdLoaded.value && nativeAd == null) {
        return FacebookNativeAdWidget(
          isLarge: false,
          onError: () {
            controller.isSmallNativeAdLoaded.value = false;
            controller.isSmallNativeAdFailed.value = true;
          },
        );
      }
*/

      if (controller.isSmallNativeAdLoading.value) {
        return const SmallAdCardShell(child: SmallNativeAdShimmer());
      }

      return const SizedBox.shrink();
    });
  }

  static Widget buildLargeAd(GetxController controller) {


    final adData = Get.find<AdsResponseService>().getCreditEducationData();
    if (adData != null && !adData.adStart) {
      return const SizedBox.shrink();
    }

    if (controller is! NativeAdMixin) {
      return const LargeNativeAdShimmer();
    }
    return Obx(() {
      final nativeAd = controller.largeNativeAd.value;
      if (nativeAd != null) {
        return LargeNativeAdWidget(nativeAd: nativeAd, key: ObjectKey(nativeAd),);
      }

/*
      // Facebook Fallback check
      if (controller.isLargeNativeAdLoaded.value && nativeAd == null) {
        return FacebookNativeAdWidget(
          isLarge: true,
          onError: () {
            controller.isLargeNativeAdLoaded.value = false;
            controller.isLargeNativeAdFailed.value = true;
          },
        );
      }
*/

      if (controller.isLargeNativeAdLoading.value) {
        return const LargeNativeAdShimmer();
      }
      return const SizedBox.shrink();
    });
  }

  static Widget buildSmallAdWithSpacing(
    GetxController controller, {
    double topSpacing = 12,
    double bottomSpacing = 12,
  }) {
    return Column(
      children: [
        SizedBox(height: topSpacing),
        buildSmallAd(controller),
        SizedBox(height: bottomSpacing),
      ],
    );
  }

  static Widget buildLargeAdWithSpacing(
    GetxController controller, {
    double topSpacing = 12,
    double bottomSpacing = 12,
  }) {
    return Column(
      children: [
        SizedBox(height: topSpacing),
        buildLargeAd(controller),
        SizedBox(height: bottomSpacing),
      ],
    );
  }
}


