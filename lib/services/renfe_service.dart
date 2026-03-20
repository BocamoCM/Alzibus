import 'dart:convert';
import '../core/network/api_client.dart';

/// Horario programado de un tren
class TrainSchedule {
  final String tripId;
  final String time; // HH:MM
  final String destination;
  final String direction; // 'valencia' o 'moixent'
  
  const TrainSchedule({
    required this.tripId,
    required this.time,
    required this.destination,
    required this.direction,
  });
}

/// Información de llegada de un tren
class TrainArrival {
  final String scheduledTime;
  final String destination;
  final String direction;
  final int delayMinutes;
  final String line;
  
  TrainArrival({
    required this.scheduledTime,
    required this.destination,
    required this.direction,
    required this.delayMinutes,
    required this.line,
  });
  
  /// Hora real de llegada considerando el retraso
  String get actualTime {
    final parts = scheduledTime.split(':');
    final scheduled = DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
    final actual = scheduled.add(Duration(minutes: delayMinutes));
    return '${actual.hour.toString().padLeft(2, '0')}:${actual.minute.toString().padLeft(2, '0')}';
  }
  
  /// Texto del estado del tren
  String get statusText {
    if (delayMinutes == 0) {
      return 'Puntual';
    } else if (delayMinutes > 0) {
      return '+$delayMinutes min';
    } else {
      return '$delayMinutes min';
    }
  }
}

/// Servicio para obtener horarios de trenes de Cercanías Valencia (C2)
/// Estaciones relevantes:
/// - 64104: Alzira
/// - 65000: València-Estació del Nord
/// - 64100: Xàtiva
/// - 64003: Moixent
class RenfeService {
  static const String _gtfsRtUrl = 'https://gtfsrt.renfe.com/trip_updates.json';
  
  // IDs de estaciones
  static const String alziraStopId = '64104';
  static const String valenciaNordStopId = '65000';
  static const String xativaStopId = '64100';
  static const String moixentStopId = '64003';
  
  // Horarios programados de la línea C2 que pasan por Alzira
  // Formato: {tripId: {hora: HH:MM, destino: string, direccion: 'valencia'|'moixent'}}
  // Estos horarios se extraen del GTFS estático y son para días laborables
  static final List<TrainSchedule> _scheduledTrains = [
    // Dirección Valencia (mañana)
    TrainSchedule(tripId: '4062V24000C2', time: '05:55', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24002C2', time: '06:20', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24004C2', time: '06:50', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24006C2', time: '07:18', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24008C2', time: '07:07', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24012C2', time: '07:47', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24016C2', time: '08:18', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24020C2', time: '08:32', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24024C2', time: '09:20', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24028C2', time: '09:50', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24032C2', time: '10:20', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24036C2', time: '10:50', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24040C2', time: '11:20', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24044C2', time: '12:08', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24048C2', time: '12:50', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24052C2', time: '13:20', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24056C2', time: '13:50', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24060C2', time: '14:20', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24064C2', time: '14:47', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24068C2', time: '15:20', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24072C2', time: '15:50', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24076C2', time: '16:20', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24080C2', time: '16:50', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24084C2', time: '17:20', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24088C2', time: '17:50', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24092C2', time: '18:18', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24096C2', time: '18:50', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24100C2', time: '19:20', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24104C2', time: '19:50', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24108C2', time: '20:20', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24112C2', time: '20:50', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24116C2', time: '21:18', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24120C2', time: '21:50', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24124C2', time: '22:20', destination: 'València Nord', direction: 'valencia'),
    TrainSchedule(tripId: '4062V24128C2', time: '22:57', destination: 'València Nord', direction: 'valencia'),
    
    // Dirección Moixent/Xàtiva (todo el día)
    TrainSchedule(tripId: '4062V24001C2', time: '06:12', destination: 'Moixent', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24003C2', time: '06:48', destination: 'Xàtiva', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24005C2', time: '07:06', destination: 'Moixent', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24007C2', time: '07:26', destination: 'Moixent', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24009C2', time: '07:51', destination: 'Xàtiva', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24011C2', time: '08:08', destination: 'Moixent', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24013C2', time: '08:21', destination: 'Xàtiva', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24015C2', time: '08:38', destination: 'Moixent', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24017C2', time: '08:51', destination: 'Xàtiva', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24019C2', time: '09:08', destination: 'Moixent', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24023C2', time: '09:38', destination: 'Moixent', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24027C2', time: '10:08', destination: 'Moixent', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24031C2', time: '10:38', destination: 'Moixent', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24035C2', time: '11:08', destination: 'Moixent', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24039C2', time: '11:38', destination: 'Moixent', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24043C2', time: '12:08', destination: 'Moixent', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24047C2', time: '12:38', destination: 'Moixent', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24051C2', time: '13:08', destination: 'Moixent', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24055C2', time: '13:38', destination: 'Moixent', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24059C2', time: '14:08', destination: 'Moixent', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24063C2', time: '14:38', destination: 'Moixent', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24067C2', time: '15:08', destination: 'Moixent', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24071C2', time: '15:38', destination: 'Moixent', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24075C2', time: '16:08', destination: 'Moixent', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24079C2', time: '16:38', destination: 'Moixent', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24083C2', time: '17:08', destination: 'Moixent', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24087C2', time: '17:38', destination: 'Moixent', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24091C2', time: '18:08', destination: 'Moixent', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24095C2', time: '18:38', destination: 'Moixent', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24099C2', time: '19:08', destination: 'Moixent', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24103C2', time: '19:38', destination: 'Moixent', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24107C2', time: '20:08', destination: 'Moixent', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24111C2', time: '20:38', destination: 'Moixent', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24115C2', time: '21:08', destination: 'Moixent', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24119C2', time: '21:38', destination: 'Moixent', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24123C2', time: '22:08', destination: 'Moixent', direction: 'moixent'),
    TrainSchedule(tripId: '4062V24127C2', time: '22:38', destination: 'Xàtiva', direction: 'moixent'),
  ];
  
  /// Obtiene los próximos trenes desde Alzira
  static Future<List<TrainArrival>> getNextTrains({int limit = 5}) async {
    final now = DateTime.now();
    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    // Filtrar trenes que aún no han pasado
    final upcomingTrains = _scheduledTrains.where((train) {
      return train.time.compareTo(currentTime) > 0;
    }).toList();
    
    // Ordenar por hora
    upcomingTrains.sort((a, b) => a.time.compareTo(b.time));
    
    // Obtener retrasos en tiempo real
    final delays = await _fetchDelays();
    
    // Combinar horarios con retrasos
    final arrivals = upcomingTrains.take(limit).map((train) {
      final delaySeconds = delays[train.tripId] ?? 0;
      final delayMinutes = (delaySeconds / 60).round();
      
      return TrainArrival(
        scheduledTime: train.time,
        destination: train.destination,
        direction: train.direction,
        delayMinutes: delayMinutes,
        line: 'C2',
      );
    }).toList();
    
    return arrivals;
  }
  
  /// Obtiene retrasos en tiempo real desde la API de Renfe
  static Future<Map<String, int>> _fetchDelays() async {
    try {
      final response = await ApiClient().get(_gtfsRtUrl);
      
      if (response.statusCode != 200) {
        return {};
      }
      
      final rawData = response.data;
      final data = rawData is String ? json.decode(rawData) : rawData;
      final Map<String, int> delays = {};
      
      final entities = data['entity'] as List<dynamic>? ?? [];
      for (final entity in entities) {
        final tripUpdate = entity['tripUpdate'];
        if (tripUpdate == null) continue;
        
        final trip = tripUpdate['trip'];
        if (trip == null) continue;
        
        final tripId = trip['tripId'] as String?;
        final delay = tripUpdate['delay'] as int? ?? 0;
        
        if (tripId != null && tripId.contains('C2')) {
          delays[tripId] = delay;
        }
      }
      
      return delays;
    } catch (e) {
      print('[RenfeService] Error fetching delays: $e');
      return {};
    }
  }
  
  /// Calcula los minutos hasta la llegada del tren
  static int minutesUntilArrival(String scheduledTime, int delayMinutes) {
    final now = DateTime.now();
    final parts = scheduledTime.split(':');
    final scheduledDateTime = DateTime(
      now.year, now.month, now.day,
      int.parse(parts[0]), int.parse(parts[1]),
    );
    
    final actualArrival = scheduledDateTime.add(Duration(minutes: delayMinutes));
    final diff = actualArrival.difference(now);
    
    return diff.inMinutes;
  }
}
