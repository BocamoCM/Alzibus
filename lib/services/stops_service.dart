import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/bus_stop.dart';

class StopsService {
  // Cambia esto por la IP de tu ordenador en la red local si pruebas en un móvil físico
  // Si usas el emulador de Android, usa 'http://10.0.2.2:3000'
  static const String baseUrl = 'http://10.196.241.62:3000/api';

  Future<List<BusStop>> loadStops() async {
    try {
      // 1. Intentar cargar desde la API (Base de datos)
      final response = await http.get(Uri.parse('$baseUrl/stops'));
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        
        // Guardar en caché para el servicio en segundo plano
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('stops_cache', response.body);
        
        // Mapear los datos de la BD al modelo BusStop
        return jsonList.map((json) => BusStop(
          id: json['id'] as int,
          name: json['name'],
          lat: (json['lat'] as num).toDouble(),
          lng: (json['lng'] as num).toDouble(),
          lines: json['lines'] != null ? List<String>.from(json['lines']) : [],
        )).toList();
      }
    } catch (e) {
      print('Error cargando paradas desde la API: $e');
    }

    // 2. Fallback: Si la API falla, cargar desde el archivo local (assets/stops.json)
    print('Usando paradas locales (fallback)');
    final data = await rootBundle.loadString('assets/stops.json');
    final List<dynamic> jsonList = json.decode(data);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('stops_cache', data);
    
    return jsonList.map((json) => BusStop.fromJson(json)).toList();
  }
  
  Future<List<Map<String, dynamic>>> loadLineRoute(String lineId) async {
    try {
      final data = await rootBundle.loadString('assets/routes/$lineId.json');
      final List<dynamic> jsonList = json.decode(data);
      return jsonList.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      print('Error cargando ruta $lineId: $e');
      return [];
    }
  }
}
