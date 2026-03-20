import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:applovin_max/applovin_max.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AdsManager {
  static final AdsManager _instance = AdsManager._internal();
  static AdsManager get instance => _instance;

  AdsManager._internal();

  // Состояние загрузки
  InterstitialAd? _adMobInterstitialAd;
  bool _isAdMobLoading = false;
  
  bool _isAppLovinReady = false;
  bool _isAppLovinLoading = false;

  bool isAdShowing = false;
  Completer<bool>? _adCompleter;

  // Ключи из .env
  String get _adMobId => Platform.isAndroid
      ? dotenv.get('ADMOB_INTERSTITIAL_ID_ANDROID', fallback: '')
      : dotenv.get('ADMOB_INTERSTITIAL_ID_IOS', fallback: '');

  String get _appLovinId => Platform.isAndroid
      ? dotenv.get('APPLOVIN_INTERSTITIAL_ID_ANDROID', fallback: '')
      : dotenv.get('APPLOVIN_INTERSTITIAL_ID_IOS', fallback: '');

  String get _appLovinSdkKey => dotenv.get('APPLOVIN_SDK_KEY', fallback: '');

  /// Инициализация всех SDK
  Future<void> initialize() async {
    if (kIsWeb) return;

    // AdMob init
    await MobileAds.instance.initialize();
    
    // AppLovin init
    final configuration = await AppLovinMAX.initialize(_appLovinSdkKey);
    if (configuration != null) {
      debugPrint('AppLovin SDK Initialized');
    }

    // Первый предзагруз
    _loadAdMobAd();
    _loadAppLovinAd();
  }

  // --- AdMob Logic ---

  void _loadAdMobAd() {
    if (_adMobInterstitialAd != null || _isAdMobLoading || _adMobId.isEmpty) return;
    _isAdMobLoading = true;

    InterstitialAd.load(
      adUnitId: _adMobId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('AdMob Interstitial Loaded');
          _adMobInterstitialAd = ad;
          _isAdMobLoading = false;
          _setupAdMobCallbacks(ad);
        },
        onAdFailedToLoad: (error) {
          debugPrint('AdMob Interstitial Failed to Load: $error');
          _adMobInterstitialAd = null;
          _isAdMobLoading = false;
        },
      ),
    );
  }

  void _setupAdMobCallbacks(InterstitialAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('AdMob Ad Dismissed');
        ad.dispose();
        _adMobInterstitialAd = null;
        isAdShowing = false;
        _adCompleter?.complete(true);
        _adCompleter = null;
        _loadAdMobAd(); // Релоад после закрытия
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AdMob Ad Failed to Show: $error');
        ad.dispose();
        _adMobInterstitialAd = null;
        isAdShowing = false;
        _adCompleter?.complete(false);
        _adCompleter = null;
        _loadAdMobAd();
      },
      onAdShowedFullScreenContent: (ad) {
        isAdShowing = true;
      },
    );
  }

  // --- AppLovin Logic ---

  void _loadAppLovinAd() {
    if (_isAppLovinReady || _isAppLovinLoading || _appLovinId.isEmpty) return;
    _isAppLovinLoading = true;

    AppLovinMAX.setInterstitialListener(InterstitialListener(
      onAdLoadedCallback: (ad) {
        debugPrint('AppLovin Ad Loaded');
        _isAppLovinReady = true;
        _isAppLovinLoading = false;
      },
      onAdLoadFailedCallback: (adUnitId, error) {
        debugPrint('AppLovin Ad Failed to Load: $error');
        _isAppLovinReady = false;
        _isAppLovinLoading = false;
      },
      onAdDisplayedCallback: (ad) {
        isAdShowing = true;
      },
      onAdDisplayFailedCallback: (ad, error) {
        debugPrint('AppLovin Ad Failed to Display: $error');
        _isAppLovinReady = false;
        isAdShowing = false;
        _adCompleter?.complete(false);
        _adCompleter = null;
        _loadAppLovinAd();
      },
      onAdClickedCallback: (ad) {},
      onAdHiddenCallback: (ad) {
        debugPrint('AppLovin Ad Hidden');
        _isAppLovinReady = false;
        isAdShowing = false;
        _adCompleter?.complete(true);
        _adCompleter = null;
        _loadAppLovinAd();
      },
    ));

    AppLovinMAX.loadInterstitial(_appLovinId);
  }

  // --- Public Interface ---

  /// Показать рекламу с логикой Fallback (AdMob -> AppLovin)
  /// Возвращает true, если реклама начала показываться и завершается после закрытия
  Future<bool> showInterstitialAd() async {
    if (kIsWeb || isAdShowing) return false;

    // 1. Пытаемся AdMob
    if (_adMobInterstitialAd != null) {
      _adCompleter = Completer<bool>();
      await _adMobInterstitialAd!.show();
      return _adCompleter!.future;
    }

    // 2. Fallback на AppLovin
    if (_isAppLovinReady) {
      _adCompleter = Completer<bool>();
      AppLovinMAX.showInterstitial(_appLovinId);
      return _adCompleter!.future;
    }

    // Если ничего не готово, пробуем загрузить на будущее
    _loadAdMobAd();
    _loadAppLovinAd();
    
    return false;
  }
}
