import 'dart:async';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'favorite_stops_service.dart';
import 'bus_times_service.dart';

/// Servicio para integrar con Google Assistant
class AssistantService {
  static const MethodChannel _channel = MethodChannel('com.alzitrans.app/assistant');
  
  // Stream para comunicar navegación desde Assistant/Shortcuts a la UI
  static final StreamController<String> _navController = StreamController<String>.broadcast();
  static Stream<String> get navigationStream => _navController.stream;
  
  /// Inicializa el manejador del method channel para Assistant
  static void initialize() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }
  
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'getBusTimes':
        return await getBusTimesForAssistant();
      case 'getBusTimesWithQuery':
        final String? query = call.arguments['query'];
        return await getBusTimesForAssistant(query: query);
      case 'refreshWidget':
        await FavoriteStopsService.updateWidget();
        return 'Widget actualizado';
      case 'navigateTo':
        final String destination = call.arguments;
        _navController.add(destination);
        return true;
      default:
        throw PlatformException(
          code: 'NOT_IMPLEMENTED',
          message: 'Método ${call.method} no implementado',
        );
    }
  }
  
  /// Obtiene un resumen de los tiempos de bus para Google Assistant / Gemini
  /// [query] opcional para filtrar por una línea específica (ej. "L1")
  static Future<String> getBusTimesForAssistant({String? query}) async {
    try {
      final stop = await FavoriteStopsService.getWidgetFavorite();
      
      if (stop == null) {
        return 'No tienes paradas favoritas. Abre Alzitrans y añade una parada a favoritos.';
      }
      
      final busTimesService = BusTimesService();
      var arrivals = await busTimesService.getArrivalTimes(stop.stopId);
      
      String premiumMessage = "";
      
      // Lógica de filtrado por línea (Preparado para Premium en el futuro)
      if (query != null && query.isNotEmpty) {
        // Normalizar query (quitar espacios, puntos, pasar a mayúsculas)
        final cleanQuery = query.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
        
        // Intentar encontrar la línea en los resultados
        final filtered = arrivals.where((a) => 
          a.line.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase() == cleanQuery
        ).toList();
        
        if (filtered.isNotEmpty) {
          arrivals = filtered;
          // NOTA: Aquí podrías comprobar si es premium para decidir si mostrar esto o no.
          // De momento, lo permitimos para todos como pidió el usuario.
          // premiumMessage = "\n(Función disponible gracias a Alzitrans Premium)"; 
        } else {
          return 'No encontré la línea $query en tu parada actual (${stop.stopName}).';
        }
      }
      
      if (arrivals.isEmpty) {
        return 'No hay buses programados para tu parada ${stop.stopName}.';
      }
      
      final StringBuffer response = StringBuffer();
      response.write('En ${stop.stopName}: ');
      
      for (int i = 0; i < arrivals.length && i < 3; i++) {
        final arrival = arrivals[i];
        final timeText = _formatTimeForSpeech(arrival.time);
        response.write('Línea ${arrival.line} hacia ${arrival.destination} $timeText. ');
      }
      
      return response.toString() + premiumMessage;
    } catch (e) {
      return 'No pude obtener los tiempos de bus. Por favor, abre Alzitrans.';
    }
  }
  
  /// Formatea el tiempo para que suene natural al hablar
  static String _formatTimeForSpeech(String time) {
    if (time.contains('<') || time.toLowerCase().contains('llegando')) {
      return 'está llegando';
    }
    
    final match = RegExp(r'(\d+)').firstMatch(time);
    if (match != null) {
      final minutes = int.parse(match.group(1)!);
      if (minutes == 1) {
        return 'llega en 1 minuto';
      }
      return 'llega en $minutes minutos';
    }
    
    return 'llega en $time';
  }
  
  /// Actualiza los datos del widget con información completa para Assistant
  static Future<void> updateWidgetDataForAssistant() async {
    try {
      final stop = await FavoriteStopsService.getWidgetFavorite();
      if (stop == null) return;
      
      final busTimesService = BusTimesService();
      final arrivals = await busTimesService.getArrivalTimes(stop.stopId);
      
      // Guardar número de llegadas
      await HomeWidget.saveWidgetData('widget_arrival_count', arrivals.length);
      
      // Guardar cada llegada individualmente para que Android pueda leerlo
      for (int i = 0; i < arrivals.length && i < 5; i++) {
        await HomeWidget.saveWidgetData('widget_line_$i', arrivals[i].line);
        await HomeWidget.saveWidgetData('widget_dest_$i', arrivals[i].destination);
        await HomeWidget.saveWidgetData('widget_time_$i', arrivals[i].time);
      }
      
      await HomeWidget.updateWidget(
        name: 'BusWidgetProvider',
        androidName: 'BusWidgetProvider',
      );
    } catch (e) {
      print('Error actualizando datos para Assistant: $e');
    }
  }
}
