import 'dart:convert';
import 'package:flutter/services.dart';

class ApiService {
  // Singleton
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Cache de datos
  List<Map<String, dynamic>>? _stopsCache;
  Map<String, List<Map<String, dynamic>>>? _routesCache;

  // Cargar paradas desde assets
  Future<List<Map<String, dynamic>>> getStops() async {
    if (_stopsCache != null) return _stopsCache!;
    
    final data = await rootBundle.loadString('assets/stops.json');
    final List<dynamic> jsonList = json.decode(data);
    _stopsCache = jsonList.map((e) {
      final map = Map<String, dynamic>.from(e);
      map['active'] = true;
      return map;
    }).toList();
    return _stopsCache!;
  }

  // Cargar ruta especifica
  Future<List<Map<String, dynamic>>> getRouteStops(String lineId) async {
    _routesCache ??= {};
    
    if (_routesCache!.containsKey(lineId)) {
      return _routesCache![lineId]!;
    }
    
    try {
      final data = await rootBundle.loadString('assets/routes/$lineId.json');
      final List<dynamic> jsonList = json.decode(data);
      _routesCache![lineId] = jsonList.map((e) => Map<String, dynamic>.from(e)).toList();
      return _routesCache![lineId]!;
    } catch (e) {
      return [];
    }
  }

  // Obtener rutas (lineas)
  Future<List<Map<String, dynamic>>> getRoutes() async {
    final stops = await getStops();
    
    // Extraer lineas unicas de las paradas
    final Set<String> lines = {};
    for (final stop in stops) {
      final stopLines = stop['lines'] as List;
      for (final line in stopLines) {
        lines.add(line as String);
      }
    }
    
    // Colores para cada linea
    final lineColors = {
      'L1': 0xFF6B1B3D,
      'L2': 0xFF4A90A4,
      'L3': 0xFFE85A4F,
    };
    
    final routes = <Map<String, dynamic>>[];
    for (final line in lines.toList()..sort()) {
      final routeStops = await getRouteStops(line);
      final stopsInLine = stops.where((s) => 
        (s['lines'] as List).contains(line)
      ).length;
      
      routes.add({
        'id': lines.toList().indexOf(line) + 1,
        'name': 'Linea ${line.substring(1)}',
        'code': line,
        'color': lineColors[line] ?? 0xFF9E9E9E,
        'stops': routeStops.isNotEmpty ? routeStops.length : stopsInLine,
        'frequency': line == 'L1' ? 15 : (line == 'L2' ? 20 : 25),
        'active': true,
      });
    }
    
    return routes;
  }

  // Dashboard Stats basado en datos reales
  Future<Map<String, dynamic>> getDashboardStats() async {
    final stops = await getStops();
    final routes = await getRoutes();
    
    return {
      'totalStops': stops.length,
      'totalRoutes': routes.length,
      'activeUsers': 1250,
      'todayQueries': 3420,
      'weeklyGrowth': 12.5,
      'avgResponseTime': 0.8,
    };
  }

  Future<List<Map<String, dynamic>>> getUsageData() async {
    return [
      {'day': 'Lun', 'queries': 450},
      {'day': 'Mar', 'queries': 520},
      {'day': 'Mie', 'queries': 480},
      {'day': 'Jue', 'queries': 610},
      {'day': 'Vie', 'queries': 580},
      {'day': 'Sab', 'queries': 320},
      {'day': 'Dom', 'queries': 280},
    ];
  }

  Future<List<Map<String, dynamic>>> getLinesDistribution() async {
    final routes = await getRoutes();
    final total = routes.fold<int>(0, (sum, r) => sum + (r['stops'] as int));
    
    return routes.map((route) {
      final percentage = (route['stops'] as int) / total * 100;
      return {
        'line': route['code'],
        'percentage': percentage,
        'color': route['color'],
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getRecentActivity() async {
    return [
      {'action': 'Panel admin iniciado', 'user': 'Admin', 'time': 'Ahora', 'type': 'system'},
      {'action': 'Datos cargados', 'user': 'Sistema', 'time': 'Hace 1 min', 'type': 'update'},
      {'action': 'Cache actualizado', 'user': 'Sistema', 'time': 'Hace 5 min', 'type': 'system'},
    ];
  }

  // CRUD (los cambios no persisten sin backend)
  Future<void> createStop(Map<String, dynamic> stop) async {
    _stopsCache?.add(stop);
  }

  Future<void> updateStop(int id, Map<String, dynamic> stop) async {
    if (_stopsCache != null) {
      final index = _stopsCache!.indexWhere((s) => s['id'] == id);
      if (index != -1) {
        _stopsCache![index] = {..._stopsCache![index], ...stop};
      }
    }
  }

  Future<void> deleteStop(int id) async {
    _stopsCache?.removeWhere((s) => s['id'] == id);
  }

  Future<void> createRoute(Map<String, dynamic> route) async {}

  Future<void> updateRoute(int id, Map<String, dynamic> route) async {}

  Future<void> deleteRoute(int id) async {}

  void clearCache() {
    _stopsCache = null;
    _routesCache = null;
  }
}
