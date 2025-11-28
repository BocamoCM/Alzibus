import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bus_stop.dart';

class StopsService {
  Future<List<BusStop>> loadStops() async {
    final data = await rootBundle.loadString('assets/stops.json');
    final List<dynamic> jsonList = json.decode(data);
    
    // Guardar en caché para el servicio en segundo plano
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
