import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

/// Resultado del segmento entre paradas
class TrackSegment {
  final int fromIndex;
  final int toIndex;
  
  TrackSegment(this.fromIndex, this.toIndex);
}

/// Servicio para cargar y usar tracks GPS reales de las líneas de autobús.
/// Los tracks se obtienen de archivos GPX convertidos a JSON.
class GpsTrackService {
  // Cache de tracks GPS por línea
  static final Map<String, List<LatLng>> _trackCache = {};
  
  /// Carga el track GPS de una línea desde assets
  static Future<List<LatLng>> loadTrack(String lineId) async {
    if (_trackCache.containsKey(lineId)) {
      return _trackCache[lineId]!;
    }
    
    try {
      final jsonString = await rootBundle.loadString('assets/routes/${lineId}_gps.json');
      final List<dynamic> points = json.decode(jsonString);
      
      final track = points.map<LatLng>((point) {
        return LatLng(
          (point['lat'] as num).toDouble(),
          (point['lng'] as num).toDouble(),
        );
      }).toList();
      
      _trackCache[lineId] = track;
      print('[GpsTrackService] Track $lineId cargado: ${track.length} puntos');
      
      return track;
    } catch (e) {
      print('[GpsTrackService] Error cargando track $lineId: $e');
      return [];
    }
  }
  
  /// Encuentra el índice del punto del track más cercano a una posición
  static int findNearestPointIndex(List<LatLng> track, LatLng position) {
    if (track.isEmpty) return 0;
    
    const distance = Distance();
    int nearestIndex = 0;
    double minDist = double.infinity;
    
    for (int i = 0; i < track.length; i++) {
      final d = distance(track[i], position);
      if (d < minDist) {
        minDist = d;
        nearestIndex = i;
      }
    }
    
    return nearestIndex;
  }
  
  /// Encuentra el segmento del track entre dos paradas
  /// Devuelve un TrackSegment con los índices [inicio, fin] del track
  static TrackSegment findSegmentBetweenStops(
    List<LatLng> track,
    LatLng fromStop,
    LatLng toStop,
  ) {
    if (track.isEmpty) return TrackSegment(0, 0);
    
    final fromIndex = findNearestPointIndex(track, fromStop);
    var toIndex = findNearestPointIndex(track, toStop);
    
    // Si los índices son iguales o toIndex está antes, buscar el siguiente punto más cercano después de fromIndex
    if (toIndex <= fromIndex) {
      // Buscar el punto más cercano a toStop que esté DESPUÉS de fromIndex
      const distance = Distance();
      double minDist = double.infinity;
      int bestIndex = (fromIndex + 1) % track.length;
      
      for (int i = fromIndex + 1; i < track.length && i < fromIndex + 50; i++) {
        final d = distance(track[i], toStop);
        if (d < minDist) {
          minDist = d;
          bestIndex = i;
        }
      }
      toIndex = bestIndex;
    }
    
    return TrackSegment(fromIndex, toIndex);
  }
  
  /// Obtiene la posición interpolada a lo largo del track entre dos índices
  /// progress: 0.0 = fromIndex, 1.0 = toIndex
  static LatLng interpolateOnTrack(
    List<LatLng> track,
    int fromIndex,
    int toIndex,
    double progress,
  ) {
    if (track.isEmpty) return LatLng(0, 0);
    if (track.length == 1) return track[0];
    
    // Validar índices
    fromIndex = fromIndex.clamp(0, track.length - 1);
    toIndex = toIndex.clamp(0, track.length - 1);
    
    if (fromIndex == toIndex) return track[fromIndex];
    
    // Asegurar que siempre vamos hacia adelante
    if (toIndex < fromIndex) {
      toIndex = (fromIndex + 1).clamp(0, track.length - 1);
    }
    
    // Número de puntos en el segmento
    final numPoints = toIndex - fromIndex;
    if (numPoints <= 0) return track[fromIndex];
    
    // Clamp progress
    progress = progress.clamp(0.0, 1.0);
    
    // Calcular en qué punto del segmento estamos
    final exactPosition = progress * numPoints;
    final baseIndex = exactPosition.floor().clamp(0, numPoints - 1);
    final fraction = exactPosition - baseIndex;
    
    // Obtener los índices reales
    final currentIndex = (fromIndex + baseIndex).clamp(0, track.length - 1);
    final nextIndex = (fromIndex + baseIndex + 1).clamp(0, track.length - 1);
    
    // Interpolar entre los dos puntos
    final from = track[currentIndex];
    final to = track[nextIndex];
    
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * fraction,
      from.longitude + (to.longitude - from.longitude) * fraction,
    );
  }
  
  /// Calcula el heading (dirección) en un punto del track
  static double getHeadingOnTrack(List<LatLng> track, int fromIndex, int toIndex, double progress) {
    if (track.isEmpty || track.length < 2) return 0;
    
    // Validar índices
    fromIndex = fromIndex.clamp(0, track.length - 1);
    toIndex = toIndex.clamp(0, track.length - 1);
    
    if (toIndex <= fromIndex) {
      toIndex = (fromIndex + 1).clamp(0, track.length - 1);
    }
    
    final numPoints = toIndex - fromIndex;
    if (numPoints <= 0) return 0;
    
    progress = progress.clamp(0.0, 1.0);
    
    final exactPosition = progress * numPoints;
    final baseIndex = exactPosition.floor().clamp(0, numPoints - 1);
    
    final currentIndex = (fromIndex + baseIndex).clamp(0, track.length - 1);
    final nextIndex = (currentIndex + 1).clamp(0, track.length - 1);
    
    final from = track[currentIndex];
    final to = track[nextIndex];
    
    return _calculateHeading(from, to);
  }
  
  static double _calculateHeading(LatLng from, LatLng to) {
    final dLng = (to.longitude - from.longitude) * math.pi / 180;
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }
}
