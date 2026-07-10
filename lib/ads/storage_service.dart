import 'dart:convert';
import 'package:get_storage/get_storage.dart';

class StorageService {
  static final GetStorage _storage = GetStorage();
  static const String _reportsKey = 'credit_reports';
  static const String _quickChecksKey = 'quick_checks';
  static const String _onboardingShownKey = 'onboarding_shown';
  static const String _languageKey = 'selected_language';
  static const String _languageSelectionShownKey = 'language_selection_shown';
  static const String _currencyKey = 'selected_currency';
  static const String _reviewLaterPendingKey = 'review_later_pending';
  static const String _reviewSubmittedKey = 'review_submitted';
  static const String _premiumShownKey = 'premium_shown';

  // Save Full Report
  static Future<void> saveFullReport(Map<String, dynamic> report) async {
    final reports = getFullReports();
    reports.insert(0, report); // Add to beginning
    await _storage.write(_reportsKey, jsonEncode(reports));
  }

  // Get All Full Reports
  static List<Map<String, dynamic>> getFullReports() {
    final data = _storage.read(_reportsKey);
    if (data == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(data);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // Save Quick Check
  static Future<void> saveQuickCheck(Map<String, dynamic> check) async {
    final checks = getQuickChecks();
    checks.insert(0, check); // Add to beginning
    await _storage.write(_quickChecksKey, jsonEncode(checks));
  }

  // Get All Quick Checks
  static List<Map<String, dynamic>> getQuickChecks() {
    final data = _storage.read(_quickChecksKey);
    if (data == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(data);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // Delete Full Report
  static Future<void> deleteFullReport(int index) async {
    final reports = getFullReports();
    if (index >= 0 && index < reports.length) {
      reports.removeAt(index);
      await _storage.write(_reportsKey, jsonEncode(reports));
    }
  }

  // Delete Quick Check
  static Future<void> deleteQuickCheck(int index) async {
    final checks = getQuickChecks();
    if (index >= 0 && index < checks.length) {
      checks.removeAt(index);
      await _storage.write(_quickChecksKey, jsonEncode(checks));
    }
  }

  // Get All History (combined and sorted by date)
  static List<Map<String, dynamic>> getAllHistory() {
    final reports = getFullReports();
    final checks = getQuickChecks();

    final allHistory = <Map<String, dynamic>>[];

    // Add full reports
    for (var report in reports) {
      allHistory.add({...report, 'type': 'full_report'});
    }

    // Add quick checks
    for (var check in checks) {
      allHistory.add({...check, 'type': 'quick_check'});
    }

    // Sort by date (newest first) - use 'date' field for proper sorting
    allHistory.sort((a, b) {
      final dateA = a['date'] as String? ?? '';
      final dateB = b['date'] as String? ?? '';
      return dateB.compareTo(dateA);
    });

    return allHistory;
  }

  // Check if onboarding has been shown
  static bool isOnboardingShown() {
    return _storage.read(_onboardingShownKey) ?? false;
  }

  // Mark onboarding as shown
  static Future<void> setOnboardingShown() async {
    await _storage.write(_onboardingShownKey, true);
  }

  // Avatar storage
  static const String _avatarIndexKey = 'avatar_index';
  static const String _bgColorIndexKey = 'bg_color_index';

  // Save avatar index
  static Future<void> saveAvatarIndex(int index) async {
    await _storage.write(_avatarIndexKey, index);
  }

  // Get saved avatar index
  static int? getSavedAvatarIndex() {
    return _storage.read(_avatarIndexKey);
  }

  // Save background color index
  static Future<void> saveBgColorIndex(int index) async {
    await _storage.write(_bgColorIndexKey, index);
  }

  // Get saved background color index
  static int? getSavedBgColorIndex() {
    return _storage.read(_bgColorIndexKey);
  }

  // Profile storage
  static const String _profileKey = 'user_profile';

  // Save profile data
  static Future<void> saveProfile(Map<String, dynamic> profile) async {
    await _storage.write(_profileKey, jsonEncode(profile));
  }

  // Get saved profile data
  static Map<String, dynamic>? getProfile() {
    final data = _storage.read(_profileKey);
    if (data == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(data));
    } catch (e) {
      return null;
    }
  }

  // Clear profile data
  static Future<void> clearProfile() async {
    await _storage.remove(_profileKey);
  }


  // Save selected language
  static Future<void> saveLanguage(String languageCode) async {
    await _storage.write(_languageKey, languageCode);
  }

  // Get selected language
  static String? getLanguage() {
    return _storage.read(_languageKey);
  }

  // Check if language selection has been shown
  static bool isLanguageSelectionShown() {
    return _storage.read(_languageSelectionShownKey) ?? false;
  }

  // Mark language selection as shown
  static Future<void> setLanguageSelectionShown() async {
    await _storage.write(_languageSelectionShownKey, true);
  }

  // Save selected currency
  static Future<void> saveCurrency(String currencyCode) async {
    await _storage.write(_currencyKey, currencyCode);
  }

  // Get selected currency
  static String? getCurrency() {
    return _storage.read(_currencyKey);
  }

  // Get selected currency symbol
  static String getCurrencySymbol() {
    final code = getCurrency() ?? 'USD';
    switch (code) {
      case 'INR':
        return '₹';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      case 'AUD':
        return 'A\$';
      case 'CAD':
        return 'C\$';
      case 'CHF':
        return 'CHF';
      case 'CNY':
        return '¥';
      default:
        return '\$';
    }
  }

  // Credit Education Data storage
  static const String _creditEducationKey = 'credit_education_data';

  // Save Credit Education Data
  static Future<void> saveCreditEducation(Map<String, dynamic> data) async {
    await _storage.write(_creditEducationKey, jsonEncode(data));
  }

  // Get Credit Education Data
  static Map<String, dynamic>? getCreditEducation() {
    final data = _storage.read(_creditEducationKey);
    if (data == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(data));
    } catch (e) {
      return null;
    }
  }

  // Review prompt storage
  static Future<void> setReviewLaterPending(bool value) async {
    await _storage.write(_reviewLaterPendingKey, value);
  }

  static bool isReviewLaterPending() {
    return _storage.read(_reviewLaterPendingKey) ?? false;
  }

  static Future<void> setReviewSubmitted(bool value) async {
    await _storage.write(_reviewSubmittedKey, value);
  }

  static bool isReviewSubmitted() {
    return _storage.read(_reviewSubmittedKey) ?? false;
  }

  // Check if premium screen has been shown today
  static bool hasSeenPremiumToday() {
    final dynamic lastShownDate = _storage.read(_premiumShownKey);
    if (lastShownDate == null || lastShownDate is! String) return false;
    final String today = DateTime.now().toIso8601String().split('T')[0];
    return lastShownDate == today;
  }

  // Mark premium screen as shown today
  static Future<void> setHasSeenPremiumToday() async {
    final String today = DateTime.now().toIso8601String().split('T')[0];
    await _storage.write(_premiumShownKey, today);
  }
}
