import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/game_currency_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/albus_mascot.dart';
import 'games/catch_the_bus_screen.dart';
import 'games/memory_stops_screen.dart';
import 'games/trivia_alzira_screen.dart';

/// Hub de mini-juegos. Albus presenta el catálogo y abres uno tocando.
///
/// De momento solo "Caza el Bus". Las cards futuras aparecen como "Próximamente"
/// para mostrar la dirección y enganchar.
class GamesHubScreen extends ConsumerWidget {
  const GamesHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins = ref.watch(gameCurrencyProvider);
    final highScore = ref.watch(catchTheBusHighScoreProvider);
    final triviaScore = ref.watch(triviaHighScoreProvider);
    final memoryRound = ref.watch(memoryStopsHighScoreProvider);

    return Scaffold(
      backgroundColor: AlzitransColors.background,
      appBar: AppBar(
        title: const Text('Juegos · Mata el tiempo'),
        backgroundColor: AlzitransColors.burgundy,
        foregroundColor: Colors.white,
        actions: [
          // Indicador de monedas en la barra superior.
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      '$coins',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
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
            _buildAlbusHeader(),
            const SizedBox(height: 24),
            const Text(
              'Disponibles',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _GameCard(
              title: 'Caza el Bus',
              description:
                  'Toca buses verdes 🚌 antes de que se escapen. Esquiva '
                  'los rojos 🚒. ¿Cuánto aguantas?',
              icon: Icons.directions_bus,
              colors: const [Color(0xFF1565C0), Color(0xFF0D47A1)],
              footer: highScore > 0
                  ? '🏆 Récord actual: $highScore'
                  : '¡Sé el primero en marcar récord!',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CatchTheBusScreen(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _GameCard(
              title: 'Trivia de Alzira',
              description:
                  'Preguntas sobre el bus, la ciudad y la comarca. '
                  '10 preguntas, 15s cada una.',
              icon: Icons.psychology,
              colors: const [Color(0xFF7B1FA2), Color(0xFF4A148C)],
              footer: triviaScore > 0
                  ? '🏆 Récord actual: $triviaScore pts'
                  : '¿Cuánto sabes de Alzira?',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TriviaAlziraScreen(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _GameCard(
              title: 'Memoria de paradas',
              description:
                  'Albus muestra paradas en orden. Tú las repites. '
                  'Cada ronda añade una más.',
              icon: Icons.grid_view,
              colors: const [Color(0xFFE65100), Color(0xFFBF360C)],
              footer: memoryRound > 0
                  ? '🏆 Mejor: ronda $memoryRound'
                  : 'Simon Says estilo Alzira',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MemoryStopsScreen(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Footer con avisos legales suaves.
            const Text(
              'Los juegos pueden mostrar anuncios opcionales (revivir, '
              'bonus). Las monedas son decorativas — futuras versiones '
              'permitirán canjearlas por contenido.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbusHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AlbusMascot(state: AlbusState.happy, size: 100),
        const SizedBox(width: 12),
        const Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 14),
            child: AlbusBubble(
              text: '¿Esperando el bus? ¡Echemos una partida! Gana monedas '
                  'mientras llega.',
            ),
          ),
        ),
      ],
    );
  }
}

class _GameCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final List<Color> colors;
  final String footer;
  final VoidCallback onTap;

  const _GameCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.colors,
    required this.footer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white24,
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      footer,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

// Mantenida para futuras tarjetas "PRONTO" cuando añadamos más mini-juegos.
// ignore: unused_element
class _ComingSoonCard extends StatelessWidget {
  final String title;
  final String description;
  final String emoji;
  const _ComingSoonCard({
    required this.title,
    required this.description,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'PRONTO',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
