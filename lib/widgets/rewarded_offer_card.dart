import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alzitrans/l10n/app_localizations.dart';
import '../core/providers/ad_provider.dart';
import '../constants/app_config.dart';
import '../theme/app_theme.dart';

/// Tarjeta CTA compacta que ofrece al usuario ver un vídeo recompensado
/// a cambio de 30 minutos sin banners. El rewarded de Alzitrans tiene el
/// eCPM más alto (~$8.75), por eso conviene exponerlo en varios sitios.
class RewardedOfferCard extends ConsumerStatefulWidget {
  const RewardedOfferCard({super.key});

  @override
  ConsumerState<RewardedOfferCard> createState() => _RewardedOfferCardState();
}

class _RewardedOfferCardState extends ConsumerState<RewardedOfferCard> {
  @override
  Widget build(BuildContext context) {
    if (!AppConfig.showAds || kIsWeb) return const SizedBox.shrink();

    final adService = ref.watch(adServiceProvider);

    if (adService.isBannerFree) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Sin anuncios durante ${adService.bannerFreeMinutesLeft} min',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (!adService.isRewardedAdReady) {
      adService.loadRewardedAd();
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AlzitransColors.burgundy, Color(0xFF4A1D3D)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _watchRewarded(context, adService),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.play_circle_fill, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.removeAdsTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppLocalizations.of(context)!.watchAdSubtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _watchRewarded(BuildContext context, dynamic adService) {
    final l = AppLocalizations.of(context)!;
    if (!adService.isRewardedAdReady) {
      adService.loadRewardedAd();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.adNotReadyYet),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    adService.showRewardedAd(
      onRewarded: () {
        if (!mounted) return;
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.adsHiddenShort),
            backgroundColor: Colors.green,
          ),
        );
      },
    );
  }
}
