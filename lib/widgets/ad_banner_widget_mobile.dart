import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';
import '../core/providers/ad_provider.dart';

class AdBannerWidget extends ConsumerStatefulWidget {
  final bool isCollapsible;
  final String? adUnitId;
  const AdBannerWidget({
    super.key, 
    this.isCollapsible = false,
    this.adUnitId,
  });

  @override
  ConsumerState<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends ConsumerState<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() async {
    final adService = ref.read(adServiceProvider);

    // Esperar a que AdMob esté inicializado.
    // Desde que diferimos la inicialización de AdMob ~3s tras runApp (fix
    // del bug "app en negro al minimizar"), si el banner se monta antes
    // de ese tiempo, canShowAds es false porque _isInitialized aún es
    // false. Antes había un delay fijo de 1s que NO era suficiente y
    // por eso el banner del AppBar no aparecía. Reemplazamos por una
    // espera real al Completer de inicialización (con timeout 20s por
    // seguridad — si tarda más, mejor no bloquear el widget).
    if (!adService.canShowAds) {
      try {
        await adService.initializationFuture.timeout(const Duration(seconds: 20));
      } catch (_) {
        return; // timeout o error de init: salimos sin banner
      }
    }
    if (!mounted) return;
    if (!adService.canShowAds) return;

    // Si el usuario vio un rewarded y está en modo "sin banners", no cargar
    if (adService.isBannerFree) return;

    // Intentar banner adaptativo primero (mayor eCPM)
    BannerAd? adaptiveBanner = await adService.createAdaptiveBannerAd(
      context: context,
      isCollapsible: widget.isCollapsible,
      adUnitId: widget.adUnitId,
      onAdLoaded: (ad) {
        if (mounted) {
          setState(() {
            _isLoaded = true;
          });
        }
      },
      onAdFailedToLoad: (ad, err) {
        debugPrint('Error al cargar banner adaptativo: ${err.message}');
        ad.dispose();
        // Fallback a banner estándar
        _loadStandardBanner();
      },
    );

    if (adaptiveBanner != null) {
      _bannerAd = adaptiveBanner..load();
    } else {
      // Fallback a banner estándar si no se pudo crear adaptativo
      _loadStandardBanner();
    }
  }

  void _loadStandardBanner() {
    if (!mounted) return;
    final adService = ref.read(adServiceProvider);

    _bannerAd = adService.createBannerAd(
      isCollapsible: widget.isCollapsible,
      adUnitId: widget.adUnitId,
      onAdLoaded: (ad) {
        if (mounted) {
          setState(() {
            _isLoaded = true;
          });
        }
      },
      onAdFailedToLoad: (ad, err) {
        debugPrint('Error al cargar banner estándar: ${err.message}');
        ad.dispose();
        
        // Reintento único tras 5 segundos si falla la primera vez
        if (mounted && !_isLoaded) {
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted && !_isLoaded) _loadStandardBanner();
          });
        }
      },
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adService = ref.watch(adServiceProvider);

    // Si está en modo banner-free, no ocupa espacio.
    if (adService.isBannerFree) {
      return const SizedBox.shrink();
    }

    if (_isLoaded && _bannerAd != null) {
      return Container(
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(
          key: UniqueKey(), // Forzar reconstrucción limpia
          ad: _bannerAd!,
        ),
      );
    }

    // Placeholder mientras carga: reservamos altura ESTÁNDAR de banner
    // (50dp) para que el layout no salte cuando aparezca el anuncio.
    // Mostramos un texto sutil para que el usuario vea que es una zona
    // de la app y no un hueco vacío.
    return SizedBox(
      height: 50,
      child: Center(
        child: Text(
          'Alzitrans · Alzira',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }
}
