class AdsApiResponse {
  final int iStatusCode;
  final bool isStatus;
  final int iCount;
  final String vMessage;
  final List<AdsApiResponseData> data;

  AdsApiResponse({
    required this.iStatusCode,
    required this.isStatus,
    required this.iCount,
    required this.vMessage,
    required this.data,
  });

  factory AdsApiResponse.fromJson(Map<String, dynamic> json) {
    return AdsApiResponse(
      iStatusCode: json['iStatusCode'] ?? 0,
      isStatus: json['isStatus'] ?? false,
      iCount: json['iCount'] ?? 0,
      vMessage: json['vMessage'] ?? '',
      data: (json['data'] as List<dynamic>?)
              ?.map((item) => AdsApiResponseData.fromJson(item))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'iStatusCode': iStatusCode,
      'isStatus': isStatus,
      'iCount': iCount,
      'vMessage': vMessage,
      'data': data.map((item) => item.toJson()).toList(),
    };
  }
}

class AdsApiResponseData {
  final String id;
  final bool adStart;
  final String adPlatform;
  final bool underWork;
  final String gAppOpen;
  final String gBanner;
  final String gAdaptiveBanner;
  final String gInter;
  final String gNative;
  final String gNativeVideo;
  final String gRewarded;
  final String gRewardedInterstitial;
  final String gRectangle;
  final int interCount;
  final int levelSkipCount;

  final String applAppOpen;
  final String applBanner;
  final String applInter;
  final String applNative;
  final String applRewarded;
  final String applRectangle;
  final String fBanner;
  final String fInter;
  final String fNative;
  final String fNativeBanner;
  final String fRectangle;
  final String gazAppOpen;
  final bool isFaceBook;
  final String gazBanner;
  final String gazInter;
  final String gazNative;
  final String gazRectangle;
  final String gazRewarded;
  final String dwAppOpen;
  final String dwBanner;
  final String dwInter;
  final String dwNative;
  final String dwRewarded;
  final String dwRectangle;
  final String facebookAppId;
  final String facebookClientToken;
  final int iLimit;
  final int iNativePosition;
  final int iBannerPosition;
  final bool isPreload;
  final bool splashAppOpan;
  final bool openAdBackgStart;
  final bool openAdFirstStart;
  final String faceBookInit;

  AdsApiResponseData({
    required this.id,
    required this.adStart,
    required this.isFaceBook,
    required this.adPlatform,
    required this.underWork,
    required this.gAppOpen,
    required this.gBanner,
    required this.gAdaptiveBanner,
    required this.gInter,
    required this.gNative,
    required this.gNativeVideo,
    required this.gRewarded,
    required this.gRewardedInterstitial,
    required this.gRectangle,
    required this.interCount,
    required this.levelSkipCount,
    required this.applAppOpen,
    required this.applBanner,
    required this.applInter,
    required this.applNative,
    required this.applRewarded,
    required this.applRectangle,
    required this.fBanner,
    required this.fInter,
    required this.fNative,
    required this.fNativeBanner,

    required this.fRectangle,
    required this.gazAppOpen,
    required this.gazBanner,
    required this.gazInter,
    required this.gazNative,
    required this.gazRectangle,
    required this.gazRewarded,
    required this.dwAppOpen,
    required this.dwBanner,
    required this.dwInter,
    required this.dwNative,
    required this.dwRewarded,
    required this.dwRectangle,
    required this.facebookAppId,
    required this.facebookClientToken,
    required this.iLimit,
    required this.iNativePosition,
    required this.iBannerPosition,
    required this.isPreload,
    required this.splashAppOpan,
    required this.openAdBackgStart,
    required this.openAdFirstStart,
    required this.faceBookInit,
  });

  factory AdsApiResponseData.fromJson(Map<String, dynamic> json) {
    return AdsApiResponseData(
      id: json['_id'] ?? '',
      adStart: json['Adstart'] ?? false,
      adPlatform: json['AdPlatform'] ?? '',
      underWork:  json['UnderWork'] ?? false,
      isFaceBook:  json['isFaceBook'] ?? false,

      gAppOpen: json['GAppOpen'] ?? '',
      gBanner: json['GBanner'] ?? '',
      gAdaptiveBanner: json['GAdaptiveBanner'] ?? '',
      gInter: json['GInter'] ?? '',
      gNative: json['GNative'] ?? '',
      gNativeVideo: json['GNativeVideo'] ?? '',
      gRewarded: json['GRewarded'] ?? '',
      gRewardedInterstitial: json['GRewardedInterstitial'] ?? '',
      gRectangle: json['GRectangle'] ?? '',
      interCount: json['InterCount'] ?? 0,
      levelSkipCount: json['levelSkipCount'] ?? json['LevelSkipCount'] ?? 0,
      applAppOpen: json['ApplAppOpen'] ?? '',
      applBanner: json['ApplBanner'] ?? '',
      applInter: json['ApplInter'] ?? '',
      applNative: json['ApplNative'] ?? '',
      applRewarded: json['ApplRewarded'] ?? '',
      applRectangle: json['ApplRectangle'] ?? '',
      fBanner: json['FBanner'] ?? '',
      fInter: json['FInter'] ?? '',
      fNative: json['FNative'] ?? '',
      fNativeBanner: json['FNativeBanner'] ?? '',
      fRectangle: json['FRectangle'] ?? '',
      gazAppOpen: json['GazAppOpen'] ?? '',
      gazBanner: json['GazBanner'] ?? '',
      gazInter: json['GazInter'] ?? '',
      gazNative: json['GazNative'] ?? '',
      gazRectangle: json['GazRectangle'] ?? '',
      gazRewarded: json['GazRewarded'] ?? '',
      dwAppOpen: json['DwAppOpen'] ?? '',
      dwBanner: json['DwBanner'] ?? '',
      dwInter: json['DwInter'] ?? '',
      dwNative: json['DwNative'] ?? '',
      dwRewarded: json['DwRewarded'] ?? '',
      dwRectangle: json['DwRectangle'] ?? '',
      facebookAppId: json['facebook_app_id'] ?? '',
      facebookClientToken: json['facebook_client_token'] ?? '',
      iLimit: json['iLimit'] ?? 0,
      iNativePosition: json['iNativePosition'] ?? 0,
      iBannerPosition: json['iBannerPosition'] ?? 0,
      isPreload: json['isPreload'] ?? false,
      splashAppOpan: json['splashAppOpan'] ?? false,
      openAdBackgStart: json['openAdBackgStart'] ?? false,
      openAdFirstStart: json['openAdFirstStart'] ?? false,
      faceBookInit: json['FaceBookInit'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'Adstart': adStart,
      'AdPlatform': adPlatform,
      'UnderWork': underWork,

      'isFaceBook': isFaceBook,
      'GAppOpen': gAppOpen,
      'GBanner': gBanner,
      'GAdaptiveBanner': gAdaptiveBanner,
      'GInter': gInter,
      'GNative': gNative,
      'GNativeVideo': gNativeVideo,
      'GRewarded': gRewarded,
      'GRewardedInterstitial': gRewardedInterstitial,
      'GRectangle': gRectangle,
      'InterCount': interCount,
      'levelSkipCount': levelSkipCount,
      'ApplAppOpen': applAppOpen,
      'ApplBanner': applBanner,
      'ApplInter': applInter,
      'ApplNative': applNative,
      'ApplRewarded': applRewarded,
      'ApplRectangle': applRectangle,
      'FBanner': fBanner,
      'FInter': fInter,
      'FNative': fNative,
      'FNativeBanner': fNativeBanner,
      'FRectangle': fRectangle,
      'GazAppOpen': gazAppOpen,
      'GazBanner': gazBanner,
      'GazInter': gazInter,
      'GazNative': gazNative,
      'GazRectangle': gazRectangle,
      'GazRewarded': gazRewarded,
      'DwAppOpen': dwAppOpen,
      'DwBanner': dwBanner,
      'DwInter': dwInter,
      'DwNative': dwNative,
      'DwRewarded': dwRewarded,
      'DwRectangle': dwRectangle,
      'facebook_app_id': facebookAppId,
      'facebook_client_token': facebookClientToken,
      'iLimit': iLimit,
      'iNativePosition': iNativePosition,
      'iBannerPosition': iBannerPosition,
      'isPreload': isPreload,
      'splashAppOpan': splashAppOpan,
      'openAdBackgStart': openAdBackgStart,
      'openAdFirstStart': openAdFirstStart,
      'FaceBookInit': faceBookInit,
    };
  }
}

