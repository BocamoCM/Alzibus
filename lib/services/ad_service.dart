import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants/app_config.dart';

/// Servicio centralizado para gestionar la publicidad con AdMob.
/// Respeta el flag global [AppConfig.showAds].
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  bool _isInitialized = false;

  /// Inicializa el SDK de Google Mobile Ads.
  Future<void> initialize() async {
    if (!AppConfig.showAds) return;
    if (_isInitialized) return;

    await MobileAds.instance.initialize();
    _isInitialized = true;
    if (kDebugMode) {
      print('AdMob inicializado correctamente.');
    }
  }

  /// Indica si los anuncios están habilitados y el SDK inicializado.
  bool get canShowAds => AppConfig.showAds && _isInitialized;

  /// --- BANNER ADS ---

  /// Crea un Banner Ad con los parámetros configurados.
  BannerAd createBannerAd({
    required void Function(Ad) onAdLoaded,
    required void Function(Ad, LoadAdError) onAdFailedToLoad,
  }) {
    return BannerAd(
      adUnitId: kDebugMode ? 'ca-app-pub-3940256099942544/6300978111' : AppConfig.bannerAdId,
      size: AdSize.banner,
      request: const AdRequest(),
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
  bool _isInterstitialLoading = false;

  /// Carga un anuncio intersticial para mostrarlo más tarde.
  void loadInterstitialAd() {
    if (!canShowAds || _isInterstitialLoading) return;

    _isInterstitialLoading = true;
    InterstitialAd.load(
      adUnitId: kDebugMode ? 'ca-app-pub-3940256099942544/1033173712' : AppConfig.interstitialAdId,
    request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isInterstitialLoading = false;
        },
      ),
    );
  }

  /// Muestra el anuncio intersticial si está cargado.
  void showInterstitialAd() {
    if (_interstitialAd == null) {
      loadInterstitialAd(); // Intentar cargar para la próxima vez
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd(); // Pre-cargar el siguiente
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

  /// Crea un anuncio nativo configurado para el diseño de Alzitrans.
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
      // Usamos un template para no requerir código nativo (Java/Kotlin) adicional
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: Colors.white,
        cornerRadius: 20.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: const Color(0xFF800020), // Borgoña Alzitrans
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
