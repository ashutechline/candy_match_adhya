/*
import 'package:flutter/material.dart';
import 'package:easy_audience_network/easy_audience_network.dart';
import 'package:get/get.dart';
import 'ad_shimmer_widgets.dart';
import 'controller/ads_response_service.dart';

class FacebookBannerAdWidget extends StatefulWidget {
  const FacebookBannerAdWidget({super.key});

  @override
  State<FacebookBannerAdWidget> createState() => _FacebookBannerAdWidgetState();
}

class _FacebookBannerAdWidgetState extends State<FacebookBannerAdWidget> {
  bool _isLoaded = false;

  @override
  Widget build(BuildContext context) {
    final adData = Get.find<AdsResponseService>().getCreditEducationData();
    final isEnabled = adData?.isFaceBook ?? false;
    final fbId = adData?.fBanner ?? '';

    if (!isEnabled || fbId.isEmpty || fbId == '0') {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      height: 50, // Enforce standard banner height
      alignment: Alignment.center,
      child: Stack(
        children: [
          BannerAd(
            placementId: fbId,
            bannerSize: BannerSize.STANDARD,
            listener: BannerAdListener(
              onLoaded: () {
                print('✅ FB Banner Ad Loaded');
                if (mounted) {
                  setState(() {
                    _isLoaded = true;
                  });
                }
              },
              onError: (code, message) =>
                  print('❌ FB Banner Ad Error: $message'),
              onClicked: () => print('FB Banner Ad Clicked'),
              onLoggingImpression: () => print('FB Banner Ad Impression'),
            ),
          ),
          if (!_isLoaded) const Positioned.fill(child: BannerAdShimmer()),
        ],
      ),
    );
  }
}
*/

import 'package:flutter/material.dart';

class FacebookBannerAdWidget extends StatelessWidget {
  const FacebookBannerAdWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

