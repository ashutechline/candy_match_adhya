import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// A registry to track which [AdWithView] instances are currently being displayed
/// in the widget tree. This prevents the "This AdWidget is already in the Widget tree" crash.
class ActiveAdRegistry {
  static final Set<int> _activeAdHashCodes = {};
  static final List<VoidCallback> _listeners = [];

  static void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  static void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  static bool isAdActive(AdWithView ad) {
    return _activeAdHashCodes.contains(ad.hashCode);
  }

  static void markActive(AdWithView ad) {
    if (_activeAdHashCodes.add(ad.hashCode)) {
      _notify();
    }
  }

  static void markInactive(AdWithView ad) {
    if (_activeAdHashCodes.remove(ad.hashCode)) {
      _notify();
    }
  }

  static void _notify() {
    for (final listener in List<VoidCallback>.from(_listeners)) {
      listener();
    }
  }
}

/// A wrapper around [AdWidget] that ensures that no two widgets in the tree
/// try to display the same [AdWithView] instance simultaneously.
class UniqueAdWidget extends StatefulWidget {
  final AdWithView ad;

  const UniqueAdWidget({super.key, required this.ad});

  @override
  State<UniqueAdWidget> createState() => _UniqueAdWidgetState();
}

class _UniqueAdWidgetState extends State<UniqueAdWidget> {
  bool _ownsAd = false;
  late AdWithView _currentAd;

  @override
  void initState() {
    super.initState();
    _currentAd = widget.ad;
    ActiveAdRegistry.addListener(_onRegistryChanged);
    _tryClaimAd();
  }

  void _onRegistryChanged() {
    if (!mounted) return;
    if (!_ownsAd && !ActiveAdRegistry.isAdActive(_currentAd)) {
      setState(() {
        _tryClaimAd();
      });
    }
  }

  void _tryClaimAd() {
    if (!ActiveAdRegistry.isAdActive(_currentAd)) {
      ActiveAdRegistry.markActive(_currentAd);
      _ownsAd = true;
    } else {
      _ownsAd = false;
      debugPrint('⚠️ UniqueAdWidget: Ad instance ${_currentAd.hashCode} is already active in the widget tree. Skipping.');
    }
  }

  @override
  void didUpdateWidget(UniqueAdWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ad != widget.ad) {
      _releaseAd();
      _currentAd = widget.ad;
      _tryClaimAd();
    }
  }

  void _releaseAd() {
    if (_ownsAd) {
      ActiveAdRegistry.markInactive(_currentAd);
      _ownsAd = false;
    }
  }

  @override
  void dispose() {
    ActiveAdRegistry.removeListener(_onRegistryChanged);
    _releaseAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ownsAd) {
      return AdWidget(ad: _currentAd, key: ObjectKey(_currentAd));
    }
    return const SizedBox.shrink();
  }
}
