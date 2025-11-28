import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

class FavoriteStop {
  final int stopId;
  final String stopName;
  final double lat;
  final double lng;
  final List<String> lines;

  FavoriteStop({
    required this.stopId,
    required this.stopName,
    required this.lat,
    required this.lng,
    required this.lines,
  });

  Map<String, dynamic> toJson() => {
    'stopId': stopId,
    'stopName': stopName,
    'lat': lat,
    'lng': lng,
    'lines': lines,
  };

  factory FavoriteStop.fromJson(Map<String, dynamic> json) => FavoriteStop(
    stopId: json['stopId'],
    stopName: json['stopName'],
    lat: json['lat'],
    lng: json['lng'],
    lines: List<String>.from(json['lines']),
  );
}

class FavoriteStopsService {
  static const String _prefsKey = 'favorite_stops';
  static const String _widgetStopKey = 'widget_favorite_stop';
  
  // Obtener todas las paradas favoritas
  static Future<List<FavoriteStop>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefsKey);
    if (json == null || json.isEmpty) return [];
    
    try {
      final List<dynamic> list = jsonDecode(json);
      return list.map((e) => FavoriteStop.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }
  
  // Verificar si una parada es favorita
  static Future<bool> isFavorite(int stopId) async {
    final favorites = await getFavorites();
    return favorites.any((f) => f.stopId == stopId);
  }
  
  // Añadir parada a favoritos
  static Future<void> addFavorite(FavoriteStop stop) async {
    final favorites = await getFavorites();
    
    // No añadir duplicados
    if (favorites.any((f) => f.stopId == stop.stopId)) return;
    
    favorites.add(stop);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(favorites.map((f) => f.toJson()).toList()));
    
    // Si es la primera favorita, establecerla como widget
    if (favorites.length == 1) {
      await setWidgetFavorite(stop.stopId);
    }
  }
  
  // Eliminar parada de favoritos
  static Future<void> removeFavorite(int stopId) async {
    final favorites = await getFavorites();
    favorites.removeWhere((f) => f.stopId == stopId);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(favorites.map((f) => f.toJson()).toList()));
    
    // Si era la del widget, limpiar widget
    final widgetStopId = await getWidgetFavoriteId();
    if (widgetStopId == stopId) {
      if (favorites.isNotEmpty) {
        await setWidgetFavorite(favorites.first.stopId);
      } else {
        await clearWidget();
      }
    }
  }
  
  // Establecer parada para el widget
  static Future<void> setWidgetFavorite(int stopId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_widgetStopKey, stopId);
    await updateWidget();
  }
  
  // Obtener ID de la parada del widget
  static Future<int?> getWidgetFavoriteId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_widgetStopKey);
  }
  
  // Obtener la parada favorita del widget
  static Future<FavoriteStop?> getWidgetFavorite() async {
    final stopId = await getWidgetFavoriteId();
    if (stopId == null) return null;
    
    final favorites = await getFavorites();
    try {
      return favorites.firstWhere((f) => f.stopId == stopId);
    } catch (e) {
      return favorites.isNotEmpty ? favorites.first : null;
    }
  }
  
  // Actualizar el widget con datos en tiempo real
  static Future<void> updateWidget() async {
    final stop = await getWidgetFavorite();
    
    if (stop == null) {
      await clearWidget();
      return;
    }
    
    try {
      // Obtener tiempos de llegada
      final url = 'https://servidor.autocareslozano.es/Alzira/webtiempos/PopupPoste.aspx?id=${stop.stopId}';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      
      String lineDestination = 'Sin datos';
      String arrivalTime = '--';
      
      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final rows = document.querySelectorAll('tr');
        
        if (rows.isNotEmpty) {
          for (final row in rows) {
            final cells = row.querySelectorAll('td');
            if (cells.length >= 3) {
              final line = cells[0].text.trim();
              final destination = cells[1].text.trim();
              final time = cells[2].text.trim();
              
              lineDestination = '$line → $destination';
              arrivalTime = _formatTime(time);
              break; // Tomar el primero
            }
          }
        }
      }
      
      // Actualizar SharedPreferences para el widget
      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      
      await HomeWidget.saveWidgetData('widget_stop_name', stop.stopName);
      await HomeWidget.saveWidgetData('widget_line_destination', lineDestination);
      await HomeWidget.saveWidgetData('widget_arrival_time', arrivalTime);
      await HomeWidget.saveWidgetData('widget_last_update', timeStr);
      
      // Actualizar widget de Android
      await HomeWidget.updateWidget(
        name: 'BusWidgetProvider',
        androidName: 'BusWidgetProvider',
      );
    } catch (e) {
      print('Error actualizando widget: $e');
    }
  }
  
  static String _formatTime(String time) {
    if (time.contains('<') || time.toLowerCase().contains('llegando')) {
      return '¡Llegando!';
    }
    
    final match = RegExp(r'(\d+)').firstMatch(time);
    if (match != null) {
      return '${match.group(1)} min';
    }
    
    return time;
  }
  
  // Limpiar widget
  static Future<void> clearWidget() async {
    await HomeWidget.saveWidgetData('widget_stop_name', 'Sin parada favorita');
    await HomeWidget.saveWidgetData('widget_line_destination', 'Añade una desde la app');
    await HomeWidget.saveWidgetData('widget_arrival_time', '--');
    await HomeWidget.saveWidgetData('widget_last_update', '--:--');
    
    await HomeWidget.updateWidget(
      name: 'BusWidgetProvider',
      androidName: 'BusWidgetProvider',
    );
  }
}
