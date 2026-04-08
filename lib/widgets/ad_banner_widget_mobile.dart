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
    if (!adService.canShowAds) return;

    // Si el usuario vio un rewarded y está en modo "sin banners", no cargar
    if (adService.isBannerFree) return;

    // Pequeño delay de cortesía para evitar colisiones con App Open Ads en el arranque
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

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

    // Si está en modo banner-free, mostrar indicador
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
    
    // Si no ha cargado, devolver un hueco o título genérico
    return const Text(
      'Alzitrans -- Alzira',
      style: TextStyle(fontWeight: FontWeight.bold),
    );
  }
}
