import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

import '../../ads/storage_service.dart';
import '../analytics/analytics_service.dart';

/// Asks for a store rating. The in-app sheet is requested on the FIRST clear
/// of a few early levels (a happy moment); Google/Apple rate-limit the sheet
/// themselves, so a request may legitimately show nothing.
class ReviewService {
  static final ReviewService instance = ReviewService._();

  ReviewService._();

  static const Set<int> promptAfterLevels = {3, 10, 25};

  Future<void> maybePromptAfterFirstClear(int levelId) async {
    if (!promptAfterLevels.contains(levelId)) return;
    try {
      if (StorageService.isReviewSubmitted()) return;
      final review = InAppReview.instance;
      if (!await review.isAvailable()) {
        debugPrint('ReviewService: In-app review not available on this device.');
        return;
      }
      AnalyticsService.instance.logReviewRequest('in_app');
      await review.requestReview();
    } catch (e) {
      debugPrint('ReviewService: Review request failed: $e');
    }
  }

  /// "Rate us" from Settings: opens the store page. On iOS this needs the App
  /// Store id (`openStoreListing(appStoreId: ...)`) once the app is live.
  Future<void> openStoreListing() async {
    AnalyticsService.instance.logReviewRequest('store_listing');
    try {
      await StorageService.setReviewSubmitted(true);
      await InAppReview.instance.openStoreListing();
    } catch (e) {
      debugPrint('ReviewService: Could not open store listing: $e');
    }
  }
}
