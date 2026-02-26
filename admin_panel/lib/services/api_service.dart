import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // Singleton
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const String _baseUrl = 'http://149.74.26.171:3000/api';
  static const String _apiKey = 'alzibus-secret-key-2024';

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'X-API-Key': _apiKey,
  };

  static const Duration _timeout = Duration(seconds: 10);

  // Cache de datos
  List<Map<String, dynamic>>? _stopsCache;
  Map<String, List<Map<String, dynamic>>>? _routesCache;

  // Helper para GET
  Future<http.Response?> _get(String path) async {
    try {
      return await http
          .get(Uri.parse('$_baseUrl$path'), headers: _headers)
          .timeout(_timeout);
    } catch (e) {
      debugPrint('ApiService GET $path error: $e');
      return null;
    }
  }

  // Cargar paradas desde la API
  Future<List<Map<String, dynamic>>> getStops() async {
    final response = await _get('/stops');
    if (response != null && response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      _stopsCache = jsonList.map((e) {
        final map = Map<String, dynamic>.from(e);
        map['active'] = true;
        return map;
      }).toList();
      return _stopsCache!;
    }

    // Fallback a cache o assets
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
    if (_routesCache!.containsKey(lineId)) return _routesCache![lineId]!;
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
    final Set<String> lines = {};
    for (final stop in stops) {
      final stopLines = stop['lines'] as List;
      for (final line in stopLines) lines.add(line as String);
    }
    final lineColors = {
      'L1': 0xFF6B1B3D,
      'L2': 0xFF4A90A4,
      'L3': 0xFFE85A4F,
    };
    final routes = <Map<String, dynamic>>[];
    for (final line in lines.toList()..sort()) {
      final routeStops = await getRouteStops(line);
      final stopsInLine = stops.where((s) => (s['lines'] as List).contains(line)).length;
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

  // Dashboard Stats
  Future<Map<String, dynamic>> getDashboardStats() async {
    final response = await _get('/stats');
    if (response != null && response.statusCode == 200) {
      return json.decode(response.body);
    }
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
    final response = await _get('/stats/usage');
    if (response != null && response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [
      {'day': 'Lun', 'queries': 0}, {'day': 'Mar', 'queries': 0},
      {'day': 'Mie', 'queries': 0}, {'day': 'Jue', 'queries': 0},
      {'day': 'Vie', 'queries': 0}, {'day': 'Sab', 'queries': 0},
      {'day': 'Dom', 'queries': 0},
    ];
  }

  Future<List<Map<String, dynamic>>> getLinesDistribution() async {
    final routes = await getRoutes();
    final total = routes.fold<int>(0, (sum, r) => sum + (r['stops'] as int));
    return routes.map((route) {
      final percentage = total > 0 ? (route['stops'] as int) / total * 100 : 0.0;
      return {'line': route['code'], 'percentage': percentage, 'color': route['color']};
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getRecentActivity() async {
    final response = await _get('/stats/activity');
    if (response != null && response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [{'action': 'Sin conexión', 'user': '-', 'time': '-', 'type': 'system'}];
  }

  /// Paradas más visitadas — datos reales desde api_logs del servidor.
  Future<List<Map<String, dynamic>>> getTopStops() async {
    final response = await _get('/stats/top-stops');
    if (response != null && response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  /// Horas pico — datos reales desde api_logs del servidor.
  Future<List<Map<String, dynamic>>> getPeakHours() async {
    final response = await _get('/stats/peak-hours');
    if (response != null && response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  // CRUD
  Future<void> createStop(Map<String, dynamic> stop) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/stops'),
            headers: _headers,
            body: json.encode(stop),
          )
          .timeout(_timeout);
      if (response.statusCode == 201) {
        final newStop = json.decode(response.body);
        newStop['active'] = true;
        _stopsCache?.add(newStop);
      }
    } catch (e) {
      debugPrint('Error creando parada: $e');
    }
  }

  Future<void> updateStop(int id, Map<String, dynamic> stop) async {
    try {
      final response = await http
          .put(
            Uri.parse('$_baseUrl/stops/$id'),
            headers: _headers,
            body: json.encode(stop),
          )
          .timeout(_timeout);
      if (response.statusCode == 200 && _stopsCache != null) {
        final index = _stopsCache!.indexWhere((s) => s['id'] == id);
        if (index != -1) _stopsCache![index] = {..._stopsCache![index], ...stop};
      }
    } catch (e) {
      debugPrint('Error actualizando parada: $e');
    }
  }

  Future<void> deleteStop(int id) async {
    try {
      final response = await http
          .delete(Uri.parse('$_baseUrl/stops/$id'), headers: _headers)
          .timeout(_timeout);
      if (response.statusCode == 200) {
        _stopsCache?.removeWhere((s) => s['id'] == id);
      }
    } catch (e) {
      debugPrint('Error eliminando parada: $e');
    }
  }

  Future<void> createRoute(Map<String, dynamic> route) async {}
  Future<void> updateRoute(int id, Map<String, dynamic> route) async {}
  Future<void> deleteRoute(int id) async {}

  // ==========================================
  // GESTIÓN DE USUARIOS (ADMIN)
  // ==========================================

  Future<List<Map<String, dynamic>>> getUsers() async {
    final response = await _get('/admin/users');
    if (response != null && response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>?> toggleUserStatus(int userId) async {
    try {
      final response = await http
          .patch(
            Uri.parse('$_baseUrl/admin/users/$userId/toggle'),
            headers: _headers,
          )
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error toggling user: $e');
    }
    return null;
  }

  // ==========================================
  // AVISOS E INCIDENCIAS (ADMIN)
  // ==========================================

  Future<List<Map<String, dynamic>>> getAdminNotices() async {
    final response = await _get('/admin/notices');
    if (response != null && response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>?> createNotice({
    required String title,
    required String body,
    String? line,
    DateTime? expiresAt,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/admin/notices'),
            headers: _headers,
            body: json.encode({
              'title': title,
              'body': body,
              if (line != null) 'line': line,
              if (expiresAt != null) 'expiresAt': expiresAt.toIso8601String(),
            }),
          )
          .timeout(_timeout);
      if (response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error creando aviso: $e');
    }
    return null;
  }

  Future<void> toggleNotice(int noticeId) async {
    try {
      await http
          .patch(
            Uri.parse('$_baseUrl/admin/notices/$noticeId/toggle'),
            headers: _headers,
          )
          .timeout(_timeout);
    } catch (e) {
      debugPrint('Error toggling aviso: $e');
    }
  }

  Future<void> deleteNotice(int noticeId) async {
    try {
      await http
          .delete(
            Uri.parse('$_baseUrl/admin/notices/$noticeId'),
            headers: _headers,
          )
          .timeout(_timeout);
    } catch (e) {
      debugPrint('Error eliminando aviso: $e');
    }
  }

  void clearCache() {
    _stopsCache = null;
    _routesCache = null;
  }
}
