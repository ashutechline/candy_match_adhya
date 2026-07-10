import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'unique_ad_widget.dart';

class SmallNativeAdWidget extends StatelessWidget {
  final NativeAd nativeAd;

  const SmallNativeAdWidget({super.key, required this.nativeAd});

  @override
  Widget build(BuildContext context) {
    // If we're on Android, we check responseInfo as a final safety check
    // to prevent "id could not be found: 0" which happens if the native side
    // hasn't fully registered the ad handle yet.
    if (nativeAd.responseInfo == null) {
      return const SizedBox(height: 220); // Placeholder height
    }

    return SizedBox(
      width: double.infinity,
      height: 220,
      child: UniqueAdWidget(ad: nativeAd),
    );
  }
}