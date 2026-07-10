/*
import 'package:flutter/material.dart';
import 'package:easy_audience_network/easy_audience_network.dart';
import 'package:get/get.dart';
import 'ad_shimmer_widgets.dart';
import 'controller/ads_response_service.dart';

class FacebookNativeAdWidget extends StatefulWidget {
  final bool isLarge;
  final VoidCallback? onLoaded;
  final VoidCallback? onError;

  const FacebookNativeAdWidget({
    super.key,
    this.isLarge = false,
    this.onLoaded,
    this.onError,
  });

  @override
  State<FacebookNativeAdWidget> createState() => _FacebookNativeAdWidgetState();
}

class _FacebookNativeAdWidgetState extends State<FacebookNativeAdWidget> {
  bool _isLoaded = false;

  @override
  Widget build(BuildContext context) {
    final adData = Get.find<AdsResponseService>().getCreditEducationData();
    final isEnabled = adData?.isFaceBook ?? false;
    final fbId = widget.isLarge
        ? (adData?.fNative ?? '')
        : (adData?.fNativeBanner ?? adData?.fNative ?? '');

    if (!isEnabled || fbId.isEmpty || fbId == '0') {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // Shimmer Overlay (shown only while loading)
        if (!_isLoaded)
          widget.isLarge
              ? const LargeNativeAdShimmer()
              : const SmallAdCardShell(child: SmallNativeAdShimmer()),

        // The Ad Widget (always built but hidden behind until loaded)
        Opacity(
          opacity: _isLoaded ? 1.0 : 0.0,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: NativeAd(
              placementId: fbId,
              adType: NativeAdType.NATIVE_AD,
              width: double.infinity,
              height: widget.isLarge ? 380 : 250,
              backgroundColor: Colors.white,
              titleColor: Colors.black,
              descriptionColor: Colors.black87,
              buttonColor: Theme.of(context).primaryColor,
              buttonTitleColor: Colors.white,
              buttonBorderColor: Theme.of(context).primaryColor,
              listener: NativeAdListener(
                onLoaded: () {
                  print('✅ FB Native Ad Loaded');
                  if (mounted) {
                    setState(() {
                      _isLoaded = true;
                    });
                  }
                  widget.onLoaded?.call();
                },
                onError: (code, message) {
                  print('❌ FB Native Ad Error: $message');
                  // Only report error if we hasn't loaded anything yet
                  if (!_isLoaded) {
                    widget.onError?.call();
                  }
                },
                onClicked: () => print('FB Native Ad Clicked'),
                onLoggingImpression: () => print('FB Native Ad Impression'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
*/

import 'package:flutter/material.dart';

class FacebookNativeAdWidget extends StatelessWidget {
  final bool isLarge;
  final VoidCallback? onLoaded;
  final VoidCallback? onError;

  const FacebookNativeAdWidget({
    super.key,
    this.isLarge = false,
    this.onLoaded,
    this.onError,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

