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
