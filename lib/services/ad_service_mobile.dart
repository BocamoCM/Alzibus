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

  /// Indica si hay un App Open Ad cargado y listo para mostrar.
  bool get hasAppOpenAdReady => _appOpenAd != null && !_isShowingAppOpenAd;

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

  static DateTime? lastAdDismissedTime; // Global para prevenir bucles de resume

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
    
    // Si cerramos CUALQUIER anuncio hace menos de 15 segundos, no disparamos App Open (evita bucles por resume)
    if (lastAdDismissedTime != null) {
      final diff = DateTime.now().difference(lastAdDismissedTime!);
      if (diff.inSeconds < 15) {
        debugPrint('AppOpenAd: Global dismiss cooldown activo. Evitando bucle.');
        return;
      }
    }

    // Cooldown de 60 segundos para evitar bucles si mostrar el ad dispara pause/resume
    if (_lastAppOpenShowTime != null) {
      final diff = DateTime.now().difference(_lastAppOpenShowTime!);
      if (diff.inSeconds < 60) {
        debugPrint('AppOpenAd: Cooldown activo (loop prevention). Saltando.');
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
        lastAdDismissedTime = DateTime.now();
        ad.dispose();
        _appOpenAd = null;
        loadAppOpenAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isShowingAppOpenAd = false;
        lastAdDismissedTime = DateTime.now();
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

  /// --- BANNER ADS (ADAPTIVE) ---

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

  /// Crea un banner adaptativo que se ajusta al ancho de la pantalla.
  /// Genera ~30-50% más eCPM que un banner fijo 320x50.
  Future<BannerAd?> createAdaptiveBannerAd({
    required BuildContext context,
    required void Function(Ad) onAdLoaded,
    required void Function(Ad, LoadAdError) onAdFailedToLoad,
    bool isCollapsible = false,
    String? adUnitId,
  }) async {
    final width = MediaQuery.of(context).size.width.truncate();
    final adSize = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    if (adSize == null) return null;

    return BannerAd(
      adUnitId: kDebugMode 
          ? 'ca-app-pub-3940256099942544/6300978111' 
          : (adUnitId ?? AppConfig.bannerAdId),
      size: adSize,
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
  
  // Contador global para intersticiales inteligentes
  int _stopQueryCount = 0;
  DateTime? _lastInterstitialShowTime;
  static const int _interstitialCooldownMinutes = 3;
  static const int _stopQueriesBeforeAd = 3;

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

  /// Muestra intersticial si está disponible y respeta el cooldown.
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

    // Respetar cooldown global
    if (_lastInterstitialShowTime != null &&
        DateTime.now().difference(_lastInterstitialShowTime!).inMinutes < _interstitialCooldownMinutes) {
      debugPrint('[AdService] Interstitial cooldown activo. Saltando.');
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _lastInterstitialShowTime = DateTime.now();
        AdService.lastAdDismissedTime = DateTime.now();
        loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        AdService.lastAdDismissedTime = DateTime.now();
        loadInterstitialAd();
      },
    );

    _lastInterstitialShowTime = DateTime.now();
    _interstitialAd!.show();
  }

  /// Registrar consulta de parada y mostrar intersticial cada N consultas.
  void trackStopQuery() {
    _stopQueryCount++;
    if (_stopQueryCount >= _stopQueriesBeforeAd) {
      _stopQueryCount = 0;
      showInterstitialAd();
    }
  }

  /// Mostrar intersticial al volver del background después de X minutos.
  void showInterstitialOnResume(DateTime? lastPausedTime) {
    if (lastPausedTime == null) return;
    final diff = DateTime.now().difference(lastPausedTime);
    if (diff.inMinutes >= 5) {
      showInterstitialAd();
    }
  }

  /// --- REWARDED ADS (Banner-free 30 min) ---

  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoading = false;
  DateTime? _bannerFreeUntil;

  /// Indica si el usuario está en modo "sin banners" (vio un rewarded).
  bool get isBannerFree {
    if (_bannerFreeUntil == null) return false;
    return DateTime.now().isBefore(_bannerFreeUntil!);
  }

  /// Minutos restantes sin banners.
  int get bannerFreeMinutesLeft {
    if (_bannerFreeUntil == null) return 0;
    final diff = _bannerFreeUntil!.difference(DateTime.now()).inMinutes;
    return diff > 0 ? diff : 0;
  }

  void loadRewardedAd() {
    if (!canShowAds || _isRewardedAdLoading) return;

    _isRewardedAdLoading = true;
    RewardedAd.load(
      adUnitId: kDebugMode ? 'ca-app-pub-3940256099942544/5224354917' : AppConfig.rewardedAdId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdLoading = false;
          if (kDebugMode) print('RewardedAd cargado.');
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isRewardedAdLoading = false;
          debugPrint('Fallo al cargar RewardedAd: $error');
        },
      ),
    );
  }

  /// ¿Hay un rewarded listo para mostrar?
  bool get isRewardedAdReady => _rewardedAd != null;

  /// Muestra el rewarded ad. Al completar, activa 30 min sin banners.
  void showRewardedAd({VoidCallback? onRewarded}) {
    if (_rewardedAd == null) {
      loadRewardedAd();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        AdService.lastAdDismissedTime = DateTime.now();
        loadRewardedAd(); // Precargar siguiente
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        AdService.lastAdDismissedTime = DateTime.now();
        loadRewardedAd();
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        // Activar 30 minutos sin banners
        _bannerFreeUntil = DateTime.now().add(const Duration(minutes: 30));
        if (kDebugMode) print('🎁 Banner-free hasta: $_bannerFreeUntil');
        onRewarded?.call();
      },
    );
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
