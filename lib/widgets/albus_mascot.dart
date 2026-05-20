import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Widget de la mascota Albus.
///
/// Renderiza el SVG correspondiente al estado en `assets/mascot/states/`.
/// Cuando esté el diseño final en `.riv` (Rive con state machine), bastará
/// con sustituir [_SvgMascot] por un `RiveAnimation` — el resto de la API
/// pública del widget se queda igual y los callers no se enteran.
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

class AlbusMascot extends StatelessWidget {
  /// Estado emocional de Albus. Determina qué SVG se renderiza.
  final AlbusState state;

  /// Tamaño en píxeles (alto y ancho, ya que los SVG son cuadrados 400×400).
  /// Usar 80-120 para badges, 180-220 para diálogos en card, 280+ para
  /// pantalla completa (onboarding).
  final double size;

  /// Si true, Albus flota suavemente arriba y abajo (idle animation a nivel
  /// widget — adicional a las animaciones internas del SVG como la luz
  /// parpadeante, los Zzz, etc.).
  final bool animated;

  const AlbusMascot({
    super.key,
    this.state = AlbusState.idle,
    this.size = 200,
    this.animated = true,
  });

  @override
  Widget build(BuildContext context) {
    // AnimatedSwitcher hace fade entre estados cuando cambia el SVG. Sin
    // esto, el cambio de estado se ve como un "salto" brusco.
    Widget mascot = SizedBox(
      width: size,
      height: size,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: SvgPicture.asset(
          state.assetPath,
          key: ValueKey(state),
          width: size,
          height: size,
          fit: BoxFit.contain,
          // Si el SVG falla por algún motivo (asset no incluido en pubspec,
          // formato inválido…), un placeholder discreto. Mejor que un crash.
          placeholderBuilder: (_) => _FallbackPlaceholder(size: size),
        ),
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

/// Burbuja de diálogo de Albus. Úsala junto al [AlbusMascot] para hacer que
/// "hable". Animación de aparición incluida.
///
/// Ejemplo:
/// ```dart
/// Column(
///   children: [
///     AlbusBubble(text: '¡Hola! ¿A dónde vamos hoy?'),
///     AlbusMascot(state: AlbusState.talking, size: 180),
///   ],
/// )
/// ```
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

/// Fallback si flutter_svg no puede renderizar el asset (raro, pero pasa con
/// SVGs muy complejos o sin SMIL en algunas plataformas). Mantiene el layout
/// estable.
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
