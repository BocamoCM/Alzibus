// Script para parsear GPX y generar polyline simplificada para rutas
// Ejecutar con: dart run tools/gpx_parser.dart

import 'dart:io';
import 'dart:math';

class GpxPoint {
  final double lat;
  final double lon;
  final double speed;
  final DateTime time;
  
  GpxPoint({
    required this.lat,
    required this.lon,
    required this.speed,
    required this.time,
  });
  
  @override
  String toString() => '{"lat": $lat, "lng": $lon}';
}

void main() async {
  final gpxFile = File('20251202-134853 - L1.gpx');
  
  if (!await gpxFile.exists()) {
    print('Error: No se encuentra el archivo GPX');
    return;
  }
  
  final content = await gpxFile.readAsString();
  final points = parseGpx(content);
  
  print('Total de puntos GPS: ${points.length}');
  
  // Filtrar puntos cuando el vehículo se está moviendo (speed > 1 m/s)
  final movingPoints = points.where((p) => p.speed > 1.0).toList();
  print('Puntos en movimiento: ${movingPoints.length}');
  
  // Simplificar la ruta usando el algoritmo Douglas-Peucker
  final simplified = douglasPeucker(movingPoints, 0.00005); // ~5 metros de tolerancia
  print('Puntos después de simplificar: ${simplified.length}');
  
  // Generar el JSON para la polyline
  final polylineJson = simplified.map((p) => '    {"lat": ${p.lat}, "lng": ${p.lon}}').join(',\n');
  
  // Guardar como nuevo archivo de ruta
  final outputFile = File('assets/routes/L1_gps.json');
  await outputFile.writeAsString('''[
$polylineJson
]
''');
  
  print('\nRuta guardada en: assets/routes/L1_gps.json');
  print('\nPrimeros 5 puntos:');
  for (var i = 0; i < min(5, simplified.length); i++) {
    print('  ${simplified[i]}');
  }
  print('\nÚltimos 5 puntos:');
  for (var i = max(0, simplified.length - 5); i < simplified.length; i++) {
    print('  ${simplified[i]}');
  }
  
  // Calcular estadísticas
  final bounds = calculateBounds(simplified);
  print('\n📍 Límites de la ruta:');
  print('  minLat: ${bounds['minLat']}, maxLat: ${bounds['maxLat']}');
  print('  minLon: ${bounds['minLon']}, maxLon: ${bounds['maxLon']}');
  
  // Calcular distancia total
  double totalDistance = 0;
  for (var i = 1; i < simplified.length; i++) {
    totalDistance += haversineDistance(
      simplified[i-1].lat, simplified[i-1].lon,
      simplified[i].lat, simplified[i].lon,
    );
  }
  print('\n📏 Distancia total: ${(totalDistance / 1000).toStringAsFixed(2)} km');
}

List<GpxPoint> parseGpx(String content) {
  final points = <GpxPoint>[];
  
  // Regex para extraer puntos del GPX
  final regex = RegExp(
    r'<trkpt lat="([^"]+)" lon="([^"]+)">[^<]*<ele>[^<]*</ele><time>([^<]+)</time><speed>([^<]+)</speed>',
    multiLine: true,
  );
  
  for (final match in regex.allMatches(content)) {
    final lat = double.parse(match.group(1)!);
    final lon = double.parse(match.group(2)!);
    final time = DateTime.parse(match.group(3)!);
    final speed = double.parse(match.group(4)!);
    
    points.add(GpxPoint(lat: lat, lon: lon, speed: speed, time: time));
  }
  
  return points;
}

// Algoritmo Douglas-Peucker para simplificar líneas
List<GpxPoint> douglasPeucker(List<GpxPoint> points, double epsilon) {
  if (points.length < 3) return points;
  
  // Encontrar el punto más lejano de la línea entre el primero y el último
  double maxDist = 0;
  int maxIndex = 0;
  
  final first = points.first;
  final last = points.last;
  
  for (var i = 1; i < points.length - 1; i++) {
    final dist = perpendicularDistance(points[i], first, last);
    if (dist > maxDist) {
      maxDist = dist;
      maxIndex = i;
    }
  }
  
  // Si la distancia máxima es mayor que epsilon, simplificar recursivamente
  if (maxDist > epsilon) {
    final left = douglasPeucker(points.sublist(0, maxIndex + 1), epsilon);
    final right = douglasPeucker(points.sublist(maxIndex), epsilon);
    
    // Combinar resultados (sin duplicar el punto del medio)
    return [...left.sublist(0, left.length - 1), ...right];
  } else {
    // Si todos los puntos están cerca de la línea, devolver solo los extremos
    return [first, last];
  }
}

double perpendicularDistance(GpxPoint point, GpxPoint lineStart, GpxPoint lineEnd) {
  final dx = lineEnd.lon - lineStart.lon;
  final dy = lineEnd.lat - lineStart.lat;
  
  // Normalizar
  final mag = sqrt(dx * dx + dy * dy);
  if (mag == 0) return sqrt(pow(point.lon - lineStart.lon, 2) + pow(point.lat - lineStart.lat, 2));
  
  final dxNorm = dx / mag;
  final dyNorm = dy / mag;
  
  // Vector desde lineStart hasta point
  final pvx = point.lon - lineStart.lon;
  final pvy = point.lat - lineStart.lat;
  
  // Producto cruzado para obtener la distancia perpendicular
  return (pvx * dyNorm - pvy * dxNorm).abs();
}

Map<String, double> calculateBounds(List<GpxPoint> points) {
  double minLat = double.infinity;
  double maxLat = double.negativeInfinity;
  double minLon = double.infinity;
  double maxLon = double.negativeInfinity;
  
  for (final p in points) {
    if (p.lat < minLat) minLat = p.lat;
    if (p.lat > maxLat) maxLat = p.lat;
    if (p.lon < minLon) minLon = p.lon;
    if (p.lon > maxLon) maxLon = p.lon;
  }
  
  return {
    'minLat': minLat,
    'maxLat': maxLat,
    'minLon': minLon,
    'maxLon': maxLon,
  };
}

// Fórmula de Haversine para calcular distancia entre dos puntos GPS
double haversineDistance(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371000; // Radio de la Tierra en metros
  
  final dLat = _toRadians(lat2 - lat1);
  final dLon = _toRadians(lon2 - lon1);
  
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
      sin(dLon / 2) * sin(dLon / 2);
  
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  
  return R * c;
}

double _toRadians(double degrees) => degrees * pi / 180;
