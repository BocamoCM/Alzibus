import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/providers/game_currency_provider.dart';
import '../models/albus_skin.dart';

/// Widget de la mascota Albus.
///
/// Renderiza el SVG del estado actual (`assets/mascot/states/`) y, si el
/// usuario tiene un skin equipado distinto del default, superpone el SVG
/// overlay del skin (`assets/mascot/skins/<skin>/overlay.svg`).
///
/// El skin equipado se lee de `equippedAlbusSkinProvider`, así que se
/// actualiza reactivamente cuando el usuario equipa otro desde la tienda.
enum AlbusState {
  idle,
  talking,
  thinking,
  happy,
  sleeping,
  sad,
}

extension _AlbusStateAsset on AlbusState {
  String get assetPath => switch (this) {
        AlbusState.idle => 'assets/mascot/states/albus_idle.svg',
        AlbusState.talking => 'assets/mascot/states/albus_talking.svg',
        AlbusState.thinking => 'assets/mascot/states/albus_thinking.svg',
        AlbusState.happy => 'assets/mascot/states/albus_happy.svg',
        AlbusState.sleeping => 'assets/mascot/states/albus_sleeping.svg',
        AlbusState.sad => 'assets/mascot/states/albus_sad.svg',
      };
}

class AlbusMascot extends ConsumerWidget {
  /// Estado emocional de Albus (idle, talking, etc.).
  final AlbusState state;

  /// Tamaño en píxeles (SVGs son 400x400 cuadrados).
  final double size;

  /// Animación de flotar arriba/abajo. Desactivar para listas o como
  /// decoración estática.
  final bool animated;

  /// Si se pasa, ignora el skin equipado y fuerza este. Útil para la
  /// previsualización dentro de la tienda (ver cada skin sin equiparlo).
  final AlbusSkin? skinOverride;

  const AlbusMascot({
    super.key,
    this.state = AlbusState.idle,
    this.size = 200,
    this.animated = true,
    this.skinOverride,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tipo explícito para que el analyzer entienda que `skin` NO es null
    // (el `??` siempre cae al provider que devuelve AlbusSkin no-null).
    final AlbusSkin skin = skinOverride ?? ref.watch(equippedAlbusSkinProvider);

    Widget mascot = SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1) Base — siempre presente. AnimatedSwitcher para fade entre estados.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: SvgPicture.asset(
              state.assetPath,
              key: ValueKey('base-$state'),
              width: size,
              height: size,
              fit: BoxFit.contain,
              placeholderBuilder: (_) => _FallbackPlaceholder(size: size),
            ),
          ),

          // 2) Skin overlay si tiene asset. Default no tiene → no overlay.
          if (skin.overlayAsset != null)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: SvgPicture.asset(
                skin.overlayAsset!,
                key: ValueKey('skin-${skin.id}'),
                width: size,
                height: size,
                fit: BoxFit.contain,
              ),
            ),
        ],
      ),
    );

    if (animated) {
      mascot = mascot
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(begin: 0, end: -8, duration: 1800.ms, curve: Curves.easeInOut);
    }

    return mascot;
  }
}

/// Burbuja de diálogo de Albus.
class AlbusBubble extends StatelessWidget {
  final String text;
  final double maxWidth;
  const AlbusBubble({super.key, required this.text, this.maxWidth = 280});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF4A1D3D), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF2A1530),
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
      )
          .animate()
          .fadeIn(duration: 400.ms)
          .slideY(begin: 0.3, end: 0, duration: 400.ms, curve: Curves.easeOut),
    );
  }
}

class _FallbackPlaceholder extends StatelessWidget {
  final double size;
  const _FallbackPlaceholder({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7A3268), Color(0xFF4A1D3D)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Center(
        child: Text('🚌', style: TextStyle(fontSize: size * 0.4)),
      ),
    );
  }
}
