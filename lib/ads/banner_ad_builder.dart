import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'controller/ads_response_service.dart';
import 'mixins/banner_ad_mixin.dart';
import 'facebook_banner_ad_widget.dart';
import 'ad_shimmer_widgets.dart';
import 'ad_service.dart';
import 'unique_ad_widget.dart';


class BannerAdBuilder {
  static Widget buildBannerAd(GetxController controller, {bool isAlwaysShow = false}) {
    if (controller is! BannerAdMixin) {
      return const SizedBox.shrink();
    }

    return Obx(() {
      final bannerAd = controller.bannerAd.value;
      

      // Check frequency gating
      if (!isAlwaysShow) {
        if (!Get.find<AdService>().shouldShowBannerAd()) {
          return const SizedBox.shrink();
        }
      }

      if (bannerAd != null) {
        return Container(
          color: Colors.transparent,
          width: bannerAd.size.width.toDouble(),
          height: bannerAd.size.height.toDouble(),
          child: UniqueAdWidget(ad: bannerAd),
        );
      }

/*
      // Facebook Fallback check
      if (controller.isBannerAdLoaded.value && bannerAd == null) {
        return const FacebookBannerAdWidget();
      }
*/

      if (controller.isBannerAdFailed.value) {
        return const SizedBox.shrink();
      }

      return SizedBox(
        height: 60,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Center(child: BannerAdShimmer()),
          ),
        ),
      );
    });
  }
}

