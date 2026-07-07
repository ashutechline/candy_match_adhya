import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

class UpdateService {
  static final UpdateService instance = UpdateService._();

  UpdateService._();

  /// Checks for app updates and triggers update flow if available on Android.
  Future<void> checkForUpdates() async {
    if (defaultTargetPlatform != TargetPlatform.android || kIsWeb) {
      debugPrint('UpdateService: In-app updates are only supported on Android. Bypassing check.');
      return;
    }

    try {
      debugPrint('UpdateService: Checking for updates...');
      final info = await InAppUpdate.checkForUpdate();
      
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        debugPrint('UpdateService: Update available!');
        if (info.immediateUpdateAllowed) {
          debugPrint('UpdateService: Starting immediate update...');
          await InAppUpdate.performImmediateUpdate();
        } else if (info.flexibleUpdateAllowed) {
          debugPrint('UpdateService: Starting flexible update...');
          final result = await InAppUpdate.startFlexibleUpdate();
          if (result == AppUpdateResult.success) {
            debugPrint('UpdateService: Flexible update downloaded. Completing update...');
            await InAppUpdate.completeFlexibleUpdate();
          }
        }
      } else {
        debugPrint('UpdateService: App is up to date.');
      }
    } catch (e) {
      debugPrint('UpdateService: Failed to check or perform in-app update: $e');
    }
  }
}
