import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de routing usando OSRM (OpenStreetMap Routing Machine)
/// Obtiene rutas reales por calles entre dos puntos
class RoutingService {
  // OSRM público (demo) - para producción usar servidor propio
  static const String _osrmBaseUrl = 'https://router.project-osrm.org';
  
  // Cache de rutas para no consultar repetidamente
  static final Map<String, List<LatLng>> _routeCache = {};
  
  /// Obtiene la ruta entre dos puntos siguiendo las calles
  /// Devuelve una lista de puntos que forman la polilínea de la ruta
  static Future<List<LatLng>> getRoute(LatLng from, LatLng to) async {
    final cacheKey = '${from.latitude},${from.longitude}-${to.latitude},${to.longitude}';
    
    // Verificar cache en memoria
    if (_routeCache.containsKey(cacheKey)) {
      return _routeCache[cacheKey]!;
    }
    
    // Verificar cache persistente
    final cachedRoute = await _loadFromCache(cacheKey);
    if (cachedRoute != null) {
      _routeCache[cacheKey] = cachedRoute;
      return cachedRoute;
    }
    
    try {
      // Consultar OSRM
      final url = '$_osrmBaseUrl/route/v1/driving/'
          '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
          '?overview=full&geometries=geojson';
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['code'] == 'Ok' && data['routes'] != null && data['routes'].isNotEmpty) {
          final geometry = data['routes'][0]['geometry'];
          final coordinates = geometry['coordinates'] as List;
          
          final route = coordinates.map<LatLng>((coord) {
            return LatLng(coord[1].toDouble(), coord[0].toDouble());
          }).toList();
          
          // Guardar en cache
          _routeCache[cacheKey] = route;
          await _saveToCache(cacheKey, route);
          
          return route;
        }
      }
    } catch (e) {
      print('[RoutingService] Error obteniendo ruta: $e');
    }
    
    // Si falla, devolver línea recta como fallback
    return [from, to];
  }
  
  /// Pre-carga todas las rutas entre paradas consecutivas de una línea
  static Future<void> preloadLineRoutes(String lineId, List<Map<String, dynamic>> stops) async {
    print('[RoutingService] Precargando rutas para línea $lineId (${stops.length} paradas)');
    
    for (int i = 0; i < stops.length; i++) {
      final from = LatLng(
        (stops[i]['lat'] as num).toDouble(),
        (stops[i]['lng'] as num).toDouble(),
      );
      
      final toIndex = (i + 1) % stops.length;
      final to = LatLng(
        (stops[toIndex]['lat'] as num).toDouble(),
        (stops[toIndex]['lng'] as num).toDouble(),
      );
      
      // Obtener ruta (se cachea automáticamente)
      await getRoute(from, to);
      
      // Pequeña pausa para no saturar el servidor
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    print('[RoutingService] Rutas precargadas para línea $lineId');
  }
  
  /// Interpola una posición a lo largo de una ruta
  /// progress: 0.0 = inicio, 1.0 = final
  static LatLng interpolateAlongRoute(List<LatLng> route, double progress) {
    if (route.isEmpty) return LatLng(0, 0);
    if (route.length == 1) return route[0];
    if (progress <= 0) return route.first;
    if (progress >= 1) return route.last;
    
    // Calcular la longitud total de la ruta
    double totalDistance = 0;
    final distances = <double>[];
    
    for (int i = 0; i < route.length - 1; i++) {
      final d = _haversineDistance(route[i], route[i + 1]);
      distances.add(d);
      totalDistance += d;
    }
    
    if (totalDistance == 0) return route.first;
    
    // Encontrar el punto en la ruta según el progreso
    final targetDistance = totalDistance * progress;
    double accumulated = 0;
    
    for (int i = 0; i < distances.length; i++) {
      if (accumulated + distances[i] >= targetDistance) {
        // El punto está en este segmento
        final segmentProgress = (targetDistance - accumulated) / distances[i];
        return _interpolatePoints(route[i], route[i + 1], segmentProgress);
      }
      accumulated += distances[i];
    }
    
    return route.last;
  }
  
  /// Calcula el heading (dirección) en un punto de la ruta
  static double getHeadingAtProgress(List<LatLng> route, double progress) {
    if (route.length < 2) return 0;
    
    // Encontrar los dos puntos más cercanos al progreso actual
    final totalLength = route.length - 1;
    final exactIndex = progress * totalLength;
    final fromIndex = exactIndex.floor().clamp(0, route.length - 2);
    final toIndex = (fromIndex + 1).clamp(0, route.length - 1);
    
    return _calculateHeading(route[fromIndex], route[toIndex]);
  }
  
  static LatLng _interpolatePoints(LatLng from, LatLng to, double t) {
    final lat = from.latitude + (to.latitude - from.latitude) * t;
    final lng = from.longitude + (to.longitude - from.longitude) * t;
    return LatLng(lat, lng);
  }
  
  static double _haversineDistance(LatLng from, LatLng to) {
    const R = 6371000; // Radio de la Tierra en metros
    final lat1 = from.latitude * 3.141592653589793 / 180;
    final lat2 = to.latitude * 3.141592653589793 / 180;
    final dLat = (to.latitude - from.latitude) * 3.141592653589793 / 180;
    final dLng = (to.longitude - from.longitude) * 3.141592653589793 / 180;
    
    final a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(lat1) * _cos(lat2) * _sin(dLng / 2) * _sin(dLng / 2);
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    
    return R * c;
  }
  
  static double _calculateHeading(LatLng from, LatLng to) {
    final dLng = (to.longitude - from.longitude) * 3.141592653589793 / 180;
    final lat1 = from.latitude * 3.141592653589793 / 180;
    final lat2 = to.latitude * 3.141592653589793 / 180;
    
    final y = _sin(dLng) * _cos(lat2);
    final x = _cos(lat1) * _sin(lat2) - _sin(lat1) * _cos(lat2) * _cos(dLng);
    
    return (_atan2(y, x) * 180 / 3.141592653589793 + 360) % 360;
  }
  
  // Funciones matemáticas básicas
  static double _sin(double x) => _taylorSin(x);
  static double _cos(double x) => _taylorCos(x);
  static double _sqrt(double x) => _babylonianSqrt(x);
  static double _atan2(double y, double x) => _approxAtan2(y, x);
  
  static double _taylorSin(double x) {
    // Normalizar x al rango [-π, π]
    while (x > 3.141592653589793) x -= 2 * 3.141592653589793;
    while (x < -3.141592653589793) x += 2 * 3.141592653589793;
    
    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }
  
  static double _taylorCos(double x) {
    while (x > 3.141592653589793) x -= 2 * 3.141592653589793;
    while (x < -3.141592653589793) x += 2 * 3.141592653589793;
    
    double result = 1;
    double term = 1;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }
  
  static double _babylonianSqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }
  
  static double _approxAtan2(double y, double x) {
    if (x == 0) {
      if (y > 0) return 3.141592653589793 / 2;
      if (y < 0) return -3.141592653589793 / 2;
      return 0;
    }
    
    double atan = _approxAtan(y / x);
    
    if (x < 0) {
      if (y >= 0) return atan + 3.141592653589793;
      return atan - 3.141592653589793;
    }
    return atan;
  }
  
  static double _approxAtan(double x) {
    // Aproximación de arcotangente usando serie de Taylor
    if (x.abs() > 1) {
      if (x > 0) return 3.141592653589793 / 2 - _approxAtan(1 / x);
      return -3.141592653589793 / 2 - _approxAtan(1 / x);
    }
    
    double result = x;
    double term = x;
    for (int i = 1; i <= 15; i++) {
      term *= -x * x;
      result += term / (2 * i + 1);
    }
    return result;
  }
  
  // Cache persistente
  static Future<List<LatLng>?> _loadFromCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('route_$key');
      if (cached != null) {
        final List<dynamic> points = json.decode(cached);
        return points.map<LatLng>((p) => LatLng(p[0], p[1])).toList();
      }
    } catch (e) {
      // Ignorar errores de cache
    }
    return null;
  }
  
  static Future<void> _saveToCache(String key, List<LatLng> route) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = route.map((p) => [p.latitude, p.longitude]).toList();
      await prefs.setString('route_$key', json.encode(data));
    } catch (e) {
      // Ignorar errores de cache
    }
  }
  
  /// Limpia el cache de rutas
  static void clearCache() {
    _routeCache.clear();
  }
}
