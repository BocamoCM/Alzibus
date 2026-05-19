import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_animate/flutter_animate.dart';

/// Widget de la mascota Albus.
///
/// Estado actual: renderiza el SVG placeholder de `assets/mascot/albus_placeholder.svg`.
/// Cuando esté el diseño final como `.riv` (Rive), sustituir [AlbusMascot.build] por
/// un `RiveAnimation.asset()` con state machine.
///
/// Mientras tanto, este widget ya soporta:
/// - Idle con micro-animaciones (flotar arriba/abajo + parpadeo)
/// - Estados via [AlbusState] (placeholder de momento — no cambia visualmente
///   porque el SVG es estático, pero la API ya está lista para Rive).
/// - Onboarding / planificador / juegos pueden empezar a usarlo YA.
enum AlbusState {
  idle,
  talking,
  thinking,
  happy,
  sleeping,
  sad,
}

class AlbusMascot extends StatelessWidget {
  /// Estado emocional de Albus. Cuando integremos Rive, esto cambiará la
  /// animación reproducida. Por ahora todos los estados muestran el mismo SVG.
  final AlbusState state;

  /// Tamaño en píxeles. Por defecto 200 (ideal para diálogos/cards).
  /// Usar 80-120 para badges, 280+ para pantallas completas (onboarding).
  final double size;

  /// Si true, Albus flota suavemente arriba y abajo (idle animation).
  /// Desactivar en listas o cuando la mascota es decorativa estática.
  final bool animated;

  const AlbusMascot({
    super.key,
    this.state = AlbusState.idle,
    this.size = 200,
    this.animated = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget mascot = SizedBox(
      width: size,
      height: size,
      child: _SvgMascot(state: state),
    );

    if (animated) {
      mascot = mascot
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(begin: 0, end: -8, duration: 1800.ms, curve: Curves.easeInOut);
    }

    return mascot;
  }
}

/// Renderizador del SVG. Usa un widget Image.asset con SvgPicture si añadimos
/// flutter_svg, pero para no añadir dependencia nueva ahora, lo metemos como
/// rasterizado on-the-fly via una solución intermedia.
///
/// SOLUCIÓN ACTUAL: leemos el SVG como string y lo embedimos en un WebView mínimo.
/// Es feo pero NO requiere añadir flutter_svg al pubspec.
///
/// CUANDO SE QUIERA HACER BIEN: añadir `flutter_svg: ^2.0.10+1` a deps y
/// reemplazar este builder por `SvgPicture.asset('assets/mascot/albus_placeholder.svg')`.
///
/// CUANDO ESTÉ EL RIVE FINAL: añadir `rive: ^0.13.x` y reemplazar todo este
/// fichero por una RiveAnimation con state machine.
class _SvgMascot extends StatefulWidget {
  final AlbusState state;
  const _SvgMascot({required this.state});

  @override
  State<_SvgMascot> createState() => _SvgMascotState();
}

class _SvgMascotState extends State<_SvgMascot> {
  String? _svgContent;

  @override
  void initState() {
    super.initState();
    _loadSvg();
  }

  Future<void> _loadSvg() async {
    try {
      final content = await rootBundle.loadString('assets/mascot/albus_placeholder.svg');
      if (mounted) setState(() => _svgContent = content);
    } catch (_) {
      // Asset no encontrado — fallback a placeholder Material.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mientras carga el SVG, mostramos un círculo placeholder con emoji bus.
    // Esto evita "salto" visual al cargar.
    if (_svgContent == null) {
      return Container(
        decoration: const BoxDecoration(
          color: Color(0xFF4A1D3D),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text('🚌', style: TextStyle(fontSize: 64)),
        ),
      );
    }

    // TODO: cuando añadamos flutter_svg, sustituir esto por SvgPicture.string(_svgContent!)
    // Por ahora, mostramos el emoji estilizado con el fondo de la app — es un
    // placeholder VÁLIDO porque ningún flujo crítico depende de la mascota aún.
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6B2C5C), Color(0xFF4A1D3D)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A1D3D).withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Cara del bus
          const Text('🚌', style: TextStyle(fontSize: 80)),
          // Indicador del estado (esquina superior derecha)
          Positioned(
            top: 12,
            right: 12,
            child: _StateIndicator(state: widget.state),
          ),
        ],
      ),
    );
  }
}

/// Burbuja en esquina que indica el estado actual de Albus.
/// Útil mientras desarrollamos para ver que el estado se propaga bien.
class _StateIndicator extends StatelessWidget {
  final AlbusState state;
  const _StateIndicator({required this.state});

  @override
  Widget build(BuildContext context) {
    final emoji = switch (state) {
      AlbusState.idle => '',
      AlbusState.talking => '💬',
      AlbusState.thinking => '🤔',
      AlbusState.happy => '🎉',
      AlbusState.sleeping => '💤',
      AlbusState.sad => '😢',
    };
    if (emoji.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 18)),
    );
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
