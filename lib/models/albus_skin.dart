import 'package:flutter/material.dart';

/// Catálogo de skins disponibles para Albus.
///
/// Cada skin se compone de:
///   - Un ID corto (clave de persistencia en SharedPreferences)
///   - Nombre y descripción visible en la tienda
///   - Coste en monedas (0 = gratis / default)
///   - Asset path al SVG overlay (opcional; null si es default sin overlay)
///   - Color de acento para la card de la tienda
///   - Emoji "preview" rápido para el botón sin tener que cargar el SVG
class AlbusSkin {
  final String id;
  final String name;
  final String description;
  final int cost;
  /// Path al overlay SVG. Para "default" es null (sin overlay, base pura).
  final String? overlayAsset;
  final Color accentColor;
  /// Emoji o icono rápido para previsualizaciones donde no carga el SVG.
  final String previewEmoji;

  const AlbusSkin({
    required this.id,
    required this.name,
    required this.description,
    required this.cost,
    required this.overlayAsset,
    required this.accentColor,
    required this.previewEmoji,
  });

  bool get isFree => cost == 0;

  /// Lista cerrada de skins. Cuando añadas más, mete una entrada nueva.
  static const List<AlbusSkin> all = [
    AlbusSkin(
      id: 'default',
      name: 'Albus clásico',
      description: 'El Albus original. El que conoces de toda la vida.',
      cost: 0,
      overlayAsset: null,
      accentColor: Color(0xFF4A1D3D),
      previewEmoji: '🚌',
    ),
    AlbusSkin(
      id: 'fallero',
      name: 'Albus Faller',
      description:
          'Vestit per a les Falles: mocador roig amb llunars, faja '
          'i un clavell. Visca Sant Josep!',
      cost: 200,
      overlayAsset: 'assets/mascot/skins/fallero/overlay.svg',
      accentColor: Color(0xFFD62828),
      previewEmoji: '🪩',
    ),
    AlbusSkin(
      id: 'capurullo',
      name: 'Albus Capurullo',
      description:
          'Nazareno tradicional de la Setmana Santa d\'Alzira, '
          'amb capirot morat i cíngul daurat.',
      cost: 250,
      overlayAsset: 'assets/mascot/skins/capurullo/overlay.svg',
      accentColor: Color(0xFF5D1A6B),
      previewEmoji: '✝️',
    ),
    AlbusSkin(
      id: 'lluvia',
      name: 'Albus en la pluja',
      description:
          'Por si pilla un chaparrón de la Ribera: paraguas amarillo '
          'y chubasquero a juego. ¡Que no te pille mojado!',
      cost: 100,
      overlayAsset: 'assets/mascot/skins/lluvia/overlay.svg',
      accentColor: Color(0xFFFFC857),
      previewEmoji: '☔',
    ),
    AlbusSkin(
      id: 'graduado',
      name: 'Albus graduat',
      description:
          'Birrete con borla dorada + diploma con sello. Homenaje '
          'al TFC que dio origen a Alzitrans.',
      cost: 150,
      overlayAsset: 'assets/mascot/skins/graduado/overlay.svg',
      accentColor: Color(0xFF1A1A1A),
      previewEmoji: '🎓',
    ),
    AlbusSkin(
      id: 'navidad',
      name: 'Albus de Nadal',
      description:
          'Gorro de Santa con pompón blanco, bufanda navideña a rayas '
          'y copos de nieve. Bon Nadal!',
      cost: 150,
      overlayAsset: 'assets/mascot/skins/navidad/overlay.svg',
      accentColor: Color(0xFFE63946),
      previewEmoji: '🎅',
    ),
    AlbusSkin(
      id: 'alzira_fc',
      name: 'Albus UD Alzira',
      description:
          'Bufanda azulgrana del UD Alzira con flecos, escudo del '
          'club y banderín. ¡Visca el club!',
      cost: 200,
      overlayAsset: 'assets/mascot/skins/alzira_fc/overlay.svg',
      accentColor: Color(0xFF0D47A1),
      previewEmoji: '⚽',
    ),
  ];

  /// Busca skin por ID. Si no existe, devuelve el default.
  static AlbusSkin findById(String? id) {
    if (id == null) return all.first;
    for (final s in all) {
      if (s.id == id) return s;
    }
    return all.first;
  }
}
