import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/ad_provider.dart';
import '../core/providers/game_currency_provider.dart';
import '../models/albus_skin.dart';
import '../theme/app_theme.dart';
import '../widgets/albus_mascot.dart';

/// Tienda de skins de Albus.
///
/// Lista todos los skins disponibles (default + comprables). Cada card
/// muestra una preview del skin con AlbusMascot(skinOverride:), su nombre,
/// descripción, y un botón cuyo estado depende de:
///
///   - Si es el equipado actual           → "EQUIPADO" disabled
///   - Si lo posee pero no está equipado  → "Equipar" en burgundy
///   - Si NO lo posee y tiene monedas     → "Desbloquear · 200 🪙" en coral
///   - Si NO lo posee y le faltan monedas → "Te faltan 50 🪙" disabled
class AlbusShopScreen extends ConsumerWidget {
  const AlbusShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins = ref.watch(gameCurrencyProvider);
    final owned = ref.watch(ownedSkinsProvider);
    final equipped = ref.watch(equippedSkinProvider);

    return Scaffold(
      backgroundColor: AlzitransColors.background,
      appBar: AppBar(
        title: const Text('Vestidor de Albus'),
        backgroundColor: AlzitransColors.burgundy,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 15)),
                    const SizedBox(width: 5),
                    Text(
                      '$coins',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(equipped),
            const SizedBox(height: 24),
            const Text(
              'Vestidos disponibles',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            for (final skin in AlbusSkin.all)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SkinCard(
                  skin: skin,
                  owned: owned.contains(skin.id),
                  equipped: equipped == skin.id,
                  coins: coins,
                  onBuy: () => _attemptBuy(context, ref, skin),
                  onEquip: () => _equip(context, ref, skin),
                ),
              ),
            const SizedBox(height: 16),
            _earnCoinsWithAdCard(context, ref),
            const SizedBox(height: 10),
            _dailyProgressCard(ref),
            const SizedBox(height: 10),
            _howToEarn(),
          ],
        ),
      ),
    );
  }

  /// Card prominente: "Ver un anuncio → +50 monedas".
  ///
  /// Aprovecha el eCPM altísimo del rewarded (6.41€) — el usuario que
  /// llega aquí buscando comprar skins es target perfecto para anuncios.
  /// Limit: 1 cada 60s para no spamear ni dar coins infinitas.
  Widget _earnCoinsWithAdCard(BuildContext context, WidgetRef ref) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Text('🎬', style: TextStyle(fontSize: 40)),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ver un anuncio',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'y consigue +30 🪙 al instante',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _watchAdForCoins(context, ref),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF2E7D32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              child: const Text(
                'Ganar',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _watchAdForCoins(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final adService = ref.read(adServiceProvider);

    if (!adService.isRewardedAdReady) {
      // No hay ad listo — pedirle a AdMob que cargue uno y avisar.
      adService.loadRewardedAd();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Anuncio cargando, intenta de nuevo en unos segundos…'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Usamos Completer para esperar al callback de AdMob de forma fiable.
    // BUG ANTERIOR: usábamos polling de 15s (60×250ms) que expiraba ANTES
    // de que el usuario terminara un ad de 30s → onRewarded llegaba tarde
    // y las monedas no se sumaban. Ahora damos hasta 5 minutos.
    final completer = Completer<bool>();
    adService.showRewardedAd(
      grantBannerFree: false, // no doble premio (banner-free + coins)
      onRewarded: () {
        if (!completer.isCompleted) completer.complete(true);
      },
    );

    // Esperamos al callback con un timeout generoso. Si el usuario
    // cierra el ad sin ver lo suficiente, el callback nunca dispara
    // y el timeout salta (sin monedas, comportamiento correcto).
    bool rewarded;
    try {
      rewarded = await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => false,
      );
    } catch (_) {
      rewarded = false;
    }

    if (!context.mounted) return;
    if (!rewarded) {
      // Anuncio cerrado sin completarlo o timeout — no decimos nada
      // (la mayoría de usuarios SÍ completarán y verán el snackbar).
      return;
    }

    final added = await ref.read(gameCurrencyProvider.notifier).add(
      30,
      source: CoinSource.rewardedAd,
    );
    if (added == 0) {
      // Llegó al cap diario de anuncios — la moneda no se añadió.
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Has alcanzado el límite de anuncios de hoy. ¡Vuelve mañana!',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text('+$added monedas 🪙 ¡Gracias!'),
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildHeader(String equippedId) {
    final skin = AlbusSkin.findById(equippedId);
    return Center(
      child: Column(
        children: [
          AlbusMascot(
            state: AlbusState.happy,
            size: 180,
            animated: true,
          ),
          const SizedBox(height: 6),
          Text(
            'Llevas el "${skin.name}"',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _howToEarn() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: const Row(
        children: [
          Text('💡', style: TextStyle(fontSize: 28)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cada día puedes ganar hasta 30 monedas jugando + 60 viendo '
              '2 anuncios. Los skins se ganan con constancia: vuelve cada '
              'día para subir el monedero.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B5500), height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  /// Card con barra de progreso del día: monedas ganadas en juegos hoy
  /// + contador de ads vistos. Refresca al volver de un juego o anuncio.
  Widget _dailyProgressCard(WidgetRef ref) {
    return FutureBuilder<({int gameCoins, int adsWatched})>(
      future: _readDailyProgress(ref),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox(height: 80);
        final notifier = ref.read(gameCurrencyProvider.notifier);
        final gc = snap.data!.gameCoins;
        final ads = snap.data!.adsWatched;
        final cap = notifier.dailyGameCap;
        final adCap = notifier.dailyAdCap;
        final progress = (gc / cap).clamp(0.0, 1.0);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.amber.shade200, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text('📅', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 8),
                  Text(
                    'Progreso de hoy',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('🎮', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  const Text('Juegos', style: TextStyle(fontSize: 13)),
                  const Spacer(),
                  Text(
                    '$gc / $cap 🪙',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: gc >= cap ? Colors.orange.shade700 : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(
                    gc >= cap ? Colors.orange.shade700 : Colors.amber.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('🎬', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  const Text('Anuncios extra', style: TextStyle(fontSize: 13)),
                  const Spacer(),
                  Text(
                    '$ads / $adCap',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: ads >= adCap ? Colors.orange.shade700 : Colors.black87,
                    ),
                  ),
                ],
              ),
              if (gc >= cap && ads >= adCap) ...[
                const SizedBox(height: 8),
                Text(
                  'Has llegado al máximo de hoy. ¡Vuelve mañana!',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade800,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<({int gameCoins, int adsWatched})> _readDailyProgress(WidgetRef ref) async {
    final n = ref.read(gameCurrencyProvider.notifier);
    return (
      gameCoins: await n.earnedTodayFromGames(),
      adsWatched: await n.coinAdsWatchedToday(),
    );
  }

  Future<void> _attemptBuy(BuildContext context, WidgetRef ref, AlbusSkin skin) async {
    final messenger = ScaffoldMessenger.of(context);
    // Confirmación
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Desbloquear ${skin.name}'),
        content: Text(
          '¿Confirmas que quieres gastar ${skin.cost} 🪙 para desbloquear '
          'este vestido? Una vez desbloqueado lo tienes para siempre.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AlzitransColors.burgundy,
              foregroundColor: Colors.white,
            ),
            child: const Text('Desbloquear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await ref.read(gameCurrencyProvider.notifier).spend(skin.cost);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No tienes suficientes monedas.')),
      );
      return;
    }
    await ref.read(ownedSkinsProvider.notifier).unlock(skin.id);
    // Equipar automáticamente tras comprar
    await ref.read(equippedSkinProvider.notifier).equip(skin.id);
    messenger.showSnackBar(
      SnackBar(content: Text('¡${skin.name} desbloqueado y equipado! 🎉')),
    );
  }

  Future<void> _equip(BuildContext context, WidgetRef ref, AlbusSkin skin) async {
    await ref.read(equippedSkinProvider.notifier).equip(skin.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${skin.name} equipado'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }
}

class _SkinCard extends StatelessWidget {
  final AlbusSkin skin;
  final bool owned;
  final bool equipped;
  final int coins;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  const _SkinCard({
    required this.skin,
    required this.owned,
    required this.equipped,
    required this.coins,
    required this.onBuy,
    required this.onEquip,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: equipped ? 4 : 1.5,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          border: Border.all(
            color: equipped ? skin.accentColor : Colors.grey.shade200,
            width: equipped ? 2.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Preview: mini Albus con el skin aplicado (skinOverride)
            SizedBox(
              width: 90,
              height: 90,
              child: AlbusMascot(
                state: AlbusState.idle,
                size: 90,
                animated: false,
                skinOverride: skin,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          skin.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: skin.accentColor,
                          ),
                        ),
                      ),
                      if (equipped)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: skin.accentColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'EQUIPADO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    skin.description,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildActionButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    if (equipped) {
      return SizedBox(
        height: 32,
        child: OutlinedButton.icon(
          onPressed: null, // disabled
          icon: const Icon(Icons.check_circle, size: 16),
          label: const Text('Equipado'),
          style: OutlinedButton.styleFrom(
            foregroundColor: skin.accentColor,
            side: BorderSide(color: skin.accentColor.withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }
    if (owned) {
      return SizedBox(
        height: 32,
        child: ElevatedButton.icon(
          onPressed: onEquip,
          icon: const Icon(Icons.checkroom, size: 16),
          label: const Text('Equipar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: skin.accentColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }
    // No poseído: comprar si hay monedas, mostrar faltantes si no.
    final canAfford = coins >= skin.cost;
    final missing = skin.cost - coins;
    return SizedBox(
      height: 32,
      child: ElevatedButton.icon(
        onPressed: canAfford ? onBuy : null,
        icon: const Text('🪙', style: TextStyle(fontSize: 13)),
        label: Text(canAfford
            ? 'Desbloquear · ${skin.cost}'
            : 'Faltan ${missing} 🪙'),
        style: ElevatedButton.styleFrom(
          backgroundColor: canAfford ? Colors.amber.shade700 : Colors.grey.shade300,
          foregroundColor: canAfford ? Colors.white : Colors.grey.shade600,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
