import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import '../model/api_ads_respose.dart';
import '../remote_config.dart';
import '../storage_service.dart';

class AdsResponseService extends GetxService {
  AdsApiResponse? _cachedData;
  bool _isLoading = false;

  @override
  void onInit() {
    super.onInit();
    _loadFromStorage();
  }

  void _loadFromStorage() {
    final storedData = StorageService.getCreditEducation();
    if (storedData != null) {
      try {
        _cachedData = AdsApiResponse.fromJson(storedData);
        print('💾 AdsResponseService: Loaded data from storage');
      } catch (e) {
        print('❌ AdsResponseService: Error loading from storage - $e');
      }
    }
  }

  Future<AdsApiResponse?> getCreditEducationDetails() async {
    if (_isLoading) {
      print('⏸️  API call already in progress, returning cached data');
      return _cachedData;
    }

    try {
      _isLoading = true;

      Map<String, dynamic>? response;

      // Always initialize remote config to get premium features config
      final remoteConfigResponse = await SetupRemoteConfig();

      if (kDebugMode) {
        print('🛠️ AdsResponseService: Running in DEBUG mode - loading mock ads from assets...');
        final String mockData = await rootBundle.loadString('assets/mock/ad.json');
        response = json.decode(mockData);
        print('✅ AdsResponseService: Loaded mock ads from assets/mock/ad.json');
      } else {
        print('🔄 AdsResponseService: Running in RELEASE mode - fetching from Remote Config...');
        response = remoteConfigResponse;
      }

      if (response == null) {
        print('⚠️  AdsResponseService: Ad source returned null');
        return _cachedData;
      }

      print('✅ AdsResponseService: Received Remote Config response');
      print('📋 Response Keys: ${response.keys.join(", ")}');

      // Use compute for heavy JSON parsing if response is large
      final adsApiResponse = await compute(
        (Map<String, dynamic> json) => AdsApiResponse.fromJson(json),
        response,
      );
      print('✅ AdsResponseService: Parsed response to AdsApiResponse using compute()');
      
      if (adsApiResponse.isStatus && adsApiResponse.data.isNotEmpty) {
        print('💾 AdsResponseService: Caching response data');
        _cachedData = adsApiResponse;
        
        // Save to storage
        await StorageService.saveCreditEducation(adsApiResponse.toJson());
        
        return adsApiResponse;
      }
      
      print('⚠️  AdsResponseService: Response status is false or data is empty');
      return null;
    } catch (e) {
      print('❌ AdsResponseService: Unexpected error - $e');
      return _cachedData; // Return cached data if available
    } finally {
      _isLoading = false;
      print('🏁 AdsResponseService: Remote Config fetch completed');
    }
  }

  AdsApiResponseData? getCreditEducationData() {
    if (_cachedData == null) {
       _loadFromStorage();
    }
    return _cachedData?.data.isNotEmpty == true ? _cachedData!.data.first : null;
  }
}
