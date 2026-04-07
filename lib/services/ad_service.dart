import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants/app_config.dart';

/// Servicio centralizado para gestionar la publicidad con AdMob.
/// Respeta el flag global [AppConfig.showAds].
class AdService {
  AdService();
  
  bool _isInitialized = false;

  final Completer<void> _initCompleter = Completer<void>();
  Future<void> get initializationFuture => _initCompleter.future;

  /// Inicializa el SDK de Google Mobile Ads.
  Future<void> initialize() async {
    if (!AppConfig.showAds) {
      if (!_initCompleter.isCompleted) _initCompleter.complete();
      return;
    }
    if (_isInitialized) return;

    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      if (!_initCompleter.isCompleted) _initCompleter.complete();
      if (kDebugMode) {
        print('AdMob inicializado correctamente.');
      }
    } catch (e) {
      if (!_initCompleter.isCompleted) _initCompleter.complete();
      debugPrint('Error inicializando AdMob: $e');
    }
  }

  /// Indica si los anuncios están habilitados y el SDK inicializado.
  bool get canShowAds => AppConfig.showAds && _isInitialized;

  /// --- APP OPEN ADS ---

  AppOpenAd? _appOpenAd;
  DateTime? _appOpenLoadTime;
  DateTime? _lastAppOpenShowTime;
  bool _isAppOpenAdLoading = false;
  bool _isShowingAppOpenAd = false;
  
  // Nativos Precargados
  NativeAd? _profileNativeAd;
  bool _isProfileNativeAdLoaded = false;
  NativeAd? _settingsNativeAd;
  bool _isSettingsNativeAdLoaded = false;
  NativeAd? _alertsNativeAd;
  bool _isAlertsNativeAdLoaded = false;

  /// Carga un anuncio de apertura (App Open Ad).
  void loadAppOpenAd() {
    if (!canShowAds || _isAppOpenAdLoading) return;

    _isAppOpenAdLoading = true;
    AppOpenAd.load(
      adUnitId: kDebugMode ? 'ca-app-pub-3940256099942544/9257395921' : AppConfig.appOpenAdId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _appOpenLoadTime = DateTime.now();
          _isAppOpenAdLoading = false;
          if (kDebugMode) print('AppOpenAd cargado.');
        },
        onAdFailedToLoad: (error) {
          _isAppOpenAdLoading = false;
          debugPrint('Fallo al cargar AppOpenAd: $error');
        },
      ),
    );
  }

  final DateTime _appStartTime = DateTime.now();

  /// Muestra el anuncio de apertura si está disponible y no ha expirado (< 4 horas según política Google).
  void showAppOpenAdIfAvailable() {
    if (!canShowAds || _appOpenAd == null || _isShowingAppOpenAd) {
      if (_appOpenAd == null) loadAppOpenAd();
      return;
    }

    if (DateTime.now().difference(_appStartTime).inSeconds < 10) {
      debugPrint('AppOpenAd: Postergado por inicio muy reciente.');
      return;
    }

    if (_lastAppOpenShowTime != null) {
      final diff = DateTime.now().difference(_lastAppOpenShowTime!);
      if (diff.inMinutes < 1) {
        debugPrint('AppOpenAd: Cooldown activo. Saltando.');
        return;
      }
    }

    if (_appOpenLoadTime != null && 
        DateTime.now().difference(_appOpenLoadTime!) > const Duration(hours: 4)) {
      _appOpenAd!.dispose();
      _appOpenAd = null;
      loadAppOpenAd();
      return;
    }

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _isShowingAppOpenAd = true;
        _lastAppOpenShowTime = DateTime.now();
      },
      onAdDismissedFullScreenContent: (ad) {
        _isShowingAppOpenAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAppOpenAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isShowingAppOpenAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAppOpenAd();
      },
    );

    _appOpenAd!.show();
  }

  /// Precarga los anuncios nativos para las pantallas principales.
  void preloadNativeAds() {
    if (!canShowAds) return;
    
    _profileNativeAd = createNativeAd(
      onAdLoaded: (ad) => _isProfileNativeAdLoaded = true,
      onAdFailedToLoad: (ad, error) => _isProfileNativeAdLoaded = false,
    )..load();
    
    _settingsNativeAd = createNativeAd(
      onAdLoaded: (ad) => _isSettingsNativeAdLoaded = true,
      onAdFailedToLoad: (ad, error) => _isSettingsNativeAdLoaded = false,
    )..load();

    _alertsNativeAd = createNativeAd(
      onAdLoaded: (ad) => _isAlertsNativeAdLoaded = true,
      onAdFailedToLoad: (ad, error) => _isAlertsNativeAdLoaded = false,
    )..load();
  }
  
  NativeAd? get profileNativeAd => _isProfileNativeAdLoaded ? _profileNativeAd : null;
  NativeAd? get settingsNativeAd => _isSettingsNativeAdLoaded ? _settingsNativeAd : null;
  NativeAd? get alertsNativeAd => _isAlertsNativeAdLoaded ? _alertsNativeAd : null;

  /// --- BANNER ADS ---

  BannerAd createBannerAd({
    required void Function(Ad) onAdLoaded,
    required void Function(Ad, LoadAdError) onAdFailedToLoad,
    bool isCollapsible = false,
    String? adUnitId,
  }) {
    return BannerAd(
      adUnitId: kDebugMode 
          ? 'ca-app-pub-3940256099942544/6300978111' 
          : (adUnitId ?? AppConfig.bannerAdId),
      size: AdSize.banner,
      request: AdRequest(
        extras: isCollapsible ? {'collapsible': 'bottom'} : null,
      ),
      listener: BannerAdListener(
        onAdLoaded: onAdLoaded,
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          onAdFailedToLoad(ad, error);
        },
      ),
    );
  }

  /// --- INTERSTITIAL ADS ---

  InterstitialAd? _interstitialAd;
  DateTime? _interstitialLoadTime;
  bool _isInterstitialLoading = false;

  void loadInterstitialAd() {
    if (!canShowAds || _isInterstitialLoading) return;

    _isInterstitialLoading = true;
    InterstitialAd.load(
      adUnitId: kDebugMode ? 'ca-app-pub-3940256099942544/1033173712' : AppConfig.interstitialAdId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialLoadTime = DateTime.now();
          _isInterstitialLoading = false;
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isInterstitialLoading = false;
        },
      ),
    );
  }

  void showInterstitialAd() {
    if (_interstitialAd != null && _interstitialLoadTime != null &&
        DateTime.now().difference(_interstitialLoadTime!) > const Duration(hours: 1)) {
      _interstitialAd!.dispose();
      _interstitialAd = null;
    }

    if (_interstitialAd == null) {
      loadInterstitialAd();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
      },
    );

    _interstitialAd!.show();
  }

  /// --- NATIVE ADS ---

  NativeAd createNativeAd({
    required void Function(Ad) onAdLoaded,
    required void Function(Ad, LoadAdError) onAdFailedToLoad,
  }) {
    return NativeAd(
      adUnitId: kDebugMode ? 'ca-app-pub-3940256099942544/2247696110' : AppConfig.nativeAdId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: onAdLoaded,
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          onAdFailedToLoad(ad, error);
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: Colors.white,
        cornerRadius: 20.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: const Color(0xFF800020),
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.black,
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.grey,
          style: NativeTemplateFontStyle.normal,
          size: 14.0,
        ),
      ),
    );
  }
}
