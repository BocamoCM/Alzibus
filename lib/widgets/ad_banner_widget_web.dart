import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/ad_provider.dart';

class AdBannerWidget extends ConsumerWidget {
  final bool isCollapsible;
  final String? adUnitId;
  
  const AdBannerWidget({
    super.key,
    this.isCollapsible = false,
    this.adUnitId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adService = ref.watch(adServiceProvider);
    
    // Si el usuario "compró" bono sin anuncios (aunque en web no aplica mucho)
    if (adService.isBannerFree) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF800020).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF800020).withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Color(0xFF800020)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Versión Web (Beta)',
                  style: TextStyle(
                    fontSize: 12, 
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF800020),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF800020),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('AD', style: TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Para disfrutar de la experiencia completa con Realidad Aumentada, NFC y Notificaciones, ¡descarga Alzitrans para Android!',
            style: TextStyle(fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
