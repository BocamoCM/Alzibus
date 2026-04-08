import 'dart:async';
import 'package:flutter/material.dart';

/// Versión Web del servicio de anuncios (Stub).
/// En la web no usamos el SDK nativo de AdMob.
class AdService {
  AdService();
  
  bool _isInitialized = false;
  final Completer<void> _initCompleter = Completer<void>();
  Future<void> get initializationFuture => _initCompleter.future;

  Future<void> initialize() async {
    _isInitialized = true;
    if (!_initCompleter.isCompleted) _initCompleter.complete();
  }

  bool get canShowAds => true; // En web permitimos "mostrar" nuestros propios anuncios

  // Stubs para App Open
  void loadAppOpenAd() {}
  void showAppOpenAdIfAvailable() {}

  // Stubs para Nativo
  void preloadNativeAds() {}
  dynamic get profileNativeAd => null;
  dynamic get settingsNativeAd => null;
  dynamic get alertsNativeAd => null;

  // Stubs para Banner (Devuelven null o disparan lógica web)
  dynamic createBannerAd({required Function onAdLoaded, required Function onAdFailedToLoad}) => null;
  Future<dynamic> createAdaptiveBannerAd({
    required BuildContext context,
    required void Function(dynamic) onAdLoaded,
    required void Function(dynamic, dynamic) onAdFailedToLoad,
    bool isCollapsible = false,
  }) async => null;

  // Stubs para Intersticial
  void loadInterstitialAd() {}
  void showInterstitialAd() {}
  void trackStopQuery() {}
  void showInterstitialOnResume(DateTime? lastPausedTime) {}

  // Stubs para Rewarded
  bool get isBannerFree => false;
  int get bannerFreeMinutesLeft => 0;
  void loadRewardedAd() {}
  bool get isRewardedAdReady => false;
  void showRewardedAd({VoidCallback? onRewarded}) {}

  // Native ad stubs
  dynamic createNativeAd({
    required void Function(dynamic) onAdLoaded,
    required void Function(dynamic, dynamic) onAdFailedToLoad,
  }) {
    return null;
  }

  // Métodos específicos para Web Ads (Opcional)
  Widget buildWebBanner() {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF800020), Color(0xFF4A1D3D)]),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Text(
          'Descarga Alzitrans para Android para la experiencia completa 🚀',
          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
