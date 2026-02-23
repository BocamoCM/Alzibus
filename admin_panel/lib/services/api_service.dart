import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // Singleton
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Cambia esto por la IP de tu ordenador en la red local
  static const String baseUrl = 'http://10.196.241.62:3000/api';

  // Cache de datos
  List<Map<String, dynamic>>? _stopsCache;
  Map<String, List<Map<String, dynamic>>>? _routesCache;

  // Cargar paradas desde la API
  Future<List<Map<String, dynamic>>> getStops() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/stops'));
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        _stopsCache = jsonList.map((e) {
          final map = Map<String, dynamic>.from(e);
          map['active'] = true;
          return map;
        }).toList();
        return _stopsCache!;
      }
    } catch (e) {
      print('Error cargando paradas desde la API: $e');
    }
    
    // Fallback a assets si falla la API
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
    try {
      final response = await http.get(Uri.parse('$baseUrl/stats'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Error cargando stats: $e');
    }
    
    // Fallback
    final stops = await getStops();
    final routes = await getRoutes();
    return {
      'totalStops': stops.length,
      'totalRoutes': routes.length,
      'activeUsers': 0,
      'todayQueries': 0,
      'weeklyGrowth': 0.0,
      'avgResponseTime': 0.0,
    };
  }

  Future<List<Map<String, dynamic>>> getUsageData() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/stats/usage'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      print('Error cargando usage data: $e');
    }
    
    return [
      {'day': 'Lun', 'queries': 0},
      {'day': 'Mar', 'queries': 0},
      {'day': 'Mie', 'queries': 0},
      {'day': 'Jue', 'queries': 0},
      {'day': 'Vie', 'queries': 0},
      {'day': 'Sab', 'queries': 0},
      {'day': 'Dom', 'queries': 0},
    ];
  }

  Future<List<Map<String, dynamic>>> getLinesDistribution() async {
    final routes = await getRoutes();
    final total = routes.fold<int>(0, (sum, r) => sum + (r['stops'] as int));
    
    return routes.map((route) {
      final percentage = total > 0 ? (route['stops'] as int) / total * 100 : 0.0;
      return {
        'line': route['code'],
        'percentage': percentage,
        'color': route['color'],
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getRecentActivity() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/stats/activity'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      print('Error cargando actividad reciente: $e');
    }
    
    return [
      {'action': 'Sin conexión', 'user': '-', 'time': '-', 'type': 'system'},
    ];
  }

  // CRUD (ahora con backend)
  Future<void> createStop(Map<String, dynamic> stop) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/stops'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(stop),
      );
      if (response.statusCode == 201) {
        final newStop = json.decode(response.body);
        newStop['active'] = true;
        _stopsCache?.add(newStop);
      }
    } catch (e) {
      print('Error creando parada: $e');
    }
  }

  Future<void> updateStop(int id, Map<String, dynamic> stop) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/stops/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(stop),
      );
      if (response.statusCode == 200) {
        if (_stopsCache != null) {
          final index = _stopsCache!.indexWhere((s) => s['id'] == id);
          if (index != -1) {
            _stopsCache![index] = {..._stopsCache![index], ...stop};
          }
        }
      }
    } catch (e) {
      print('Error actualizando parada: $e');
    }
  }

  Future<void> deleteStop(int id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/stops/$id'));
      if (response.statusCode == 200) {
        _stopsCache?.removeWhere((s) => s['id'] == id);
      }
    } catch (e) {
      print('Error eliminando parada: $e');
    }
  }

  Future<void> createRoute(Map<String, dynamic> route) async {}

  Future<void> updateRoute(int id, Map<String, dynamic> route) async {}

  Future<void> deleteRoute(int id) async {}

  void clearCache() {
    _stopsCache = null;
    _routesCache = null;
  }
}
