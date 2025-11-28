import 'dart:async';
import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'bus_times_service.dart';

class SimulatedBus {
  final String lineId;
  final String busId;
  LatLng currentPosition;
  double heading;
  double speed;
  int currentStopIndex;
  int nextStopIndex;
  double progress;
  bool isAtStop;
  DateTime? departureTime;
  int? lastKnownMinutes;
  int? trackingStopId;
  
  SimulatedBus({
    required this.lineId,
    required this.busId,
    required this.currentPosition,
    this.heading = 0,
    this.speed = 1.0,
    this.currentStopIndex = 0,
    this.nextStopIndex = 1,
    this.progress = 0,
    this.isAtStop = false,
    this.departureTime,
    this.lastKnownMinutes,
    this.trackingStopId,
  });
}

class BusSimulationService {
  final BusTimesService _busTimesService = BusTimesService();
  final Map<String, SimulatedBus> _buses = {};
  final Map<String, List<Map<String, dynamic>>> _lineStops = {};
  
  Timer? _updateTimer;
  Timer? _trackingTimer;
  final _busStreamController = StreamController<Map<String, SimulatedBus>>.broadcast();
  
  Stream<Map<String, SimulatedBus>> get busStream => _busStreamController.stream;
  Map<String, SimulatedBus> get buses => Map.unmodifiable(_buses);
  
  void setLineStops(String lineId, List<Map<String, dynamic>> stops) {
    _lineStops[lineId] = stops;
  }
  
  List<Map<String, dynamic>>? getLineStops(String lineId) => _lineStops[lineId];
  
  void startSimulation() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _updateBusPositions();
    });
    
    // Actualizar posiciones de buses cada 20 segundos consultando siguiente parada
    _trackingTimer?.cancel();
    _trackingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _trackBuses();
    });
  }
  
  void stopSimulation() {
    _updateTimer?.cancel();
    _trackingTimer?.cancel();
    _updateTimer = null;
    _trackingTimer = null;
  }
  
  /// Escaneo inicial: consulta todas las paradas para encontrar buses
  Future<void> initialScan(List<Map<String, dynamic>> allStops) async {
    print('=== ESCANEO INICIAL DE TODAS LAS PARADAS ===');
    
    // Guardamos el bus mas cercano encontrado por cada linea
    // Key: lineId, Value: {minutes, stopIndex, stopId}
    final Map<String, Map<String, dynamic>> closestBusByLine = {};
    
    for (final stop in allStops) {
      final stopId = stop['id'] as int;
      final lines = List<String>.from(stop['lines'] as List);
      
      try {
        final arrivals = await _busTimesService.getArrivalTimes(stopId);
        
        for (final arrival in arrivals) {
          // Verificar que la linea esta en esta parada
          if (!lines.contains(arrival.line)) continue;
          if (!_lineStops.containsKey(arrival.line)) continue;
          
          final lineStops = _lineStops[arrival.line]!;
          final stopIndex = lineStops.indexWhere((s) => s['id'] == stopId);
          if (stopIndex < 0) continue;
          
          final minutes = _parseMinutes(arrival.time);
          final lineId = arrival.line;
          
          // Solo guardar si es el bus mas cercano de esta linea
          if (!closestBusByLine.containsKey(lineId) || 
              minutes < (closestBusByLine[lineId]!['minutes'] as int)) {
            closestBusByLine[lineId] = {
              'minutes': minutes,
              'stopIndex': stopIndex,
              'stopId': stopId,
              'stopName': stop['name'],
              'destination': arrival.destination,
            };
            print('$lineId: Bus en ${stop['name']} -> ${arrival.destination} ($minutes min)');
          }
        }
      } catch (e) {
        print('Error en parada $stopId: $e');
      }
      
      // Pequena pausa para no saturar el servidor
      await Future.delayed(const Duration(milliseconds: 50));
    }
    
    // Ahora crear un bus por cada linea encontrada
    for (final entry in closestBusByLine.entries) {
      final lineId = entry.key;
      final data = entry.value;
      final lineStops = _lineStops[lineId]!;
      
      final stopIndex = data['stopIndex'] as int;
      final minutes = data['minutes'] as int;
      
      final estimatedStopIndex = _estimateCurrentStop(stopIndex, minutes, lineStops.length);
      final pos = _getStopPosition(lineStops[estimatedStopIndex]);
      
      print('');
      print('==> Creando bus $lineId:');
      print('    Llegara a parada ${data['stopName']} en $minutes min');
      print('    Posicion estimada: parada $estimatedStopIndex de ${lineStops.length}');
      
      _buses[lineId] = SimulatedBus(
        lineId: lineId,
        busId: lineId,
        currentPosition: pos,
        currentStopIndex: estimatedStopIndex,
        nextStopIndex: (estimatedStopIndex + 1) % lineStops.length,
        lastKnownMinutes: minutes,
        trackingStopId: data['stopId'] as int,
        speed: 1.0,
      );
    }
    
    print('');
    print('=== ESCANEO COMPLETO: ${_buses.length} buses encontrados ===');
    _busStreamController.add(_buses);
  }
  
  /// Seguimiento continuo: consulta la siguiente parada de cada bus
  Future<void> _trackBuses() async {
    for (final bus in _buses.values.toList()) {
      final lineStops = _lineStops[bus.lineId];
      if (lineStops == null || lineStops.isEmpty) continue;
      
      // Consultar la siguiente parada del bus
      final nextStopData = lineStops[bus.nextStopIndex];
      final nextStopId = nextStopData['id'] as int;
      
      try {
        final arrivals = await _busTimesService.getArrivalTimes(nextStopId);
        final lineArrivals = arrivals.where((a) => a.line == bus.lineId).toList();
        
        if (lineArrivals.isNotEmpty) {
          final arrival = lineArrivals.first;
          final minutes = _parseMinutes(arrival.time);
          
          print('${bus.lineId}: Siguiente parada ${nextStopData['name']} en $minutes min (${arrival.time})');
          
          // Ajustar velocidad segun tiempo real
          if (minutes == 0) {
            // Bus llegando, acelerar
            bus.speed = 2.0;
          } else if (minutes <= 2) {
            bus.speed = 1.5;
          } else if (minutes <= 5) {
            bus.speed = 1.0;
          } else {
            bus.speed = 0.6;
          }
          
          // Siempre reanudar el movimiento cuando tenemos datos frescos
          bus.isAtStop = false;
          bus.departureTime = null;
          
          bus.lastKnownMinutes = minutes;
          bus.trackingStopId = nextStopId;
        }
      } catch (e) {
        // Mantener velocidad actual si falla la consulta
      }
    }
    
    _busStreamController.add(_buses);
  }
  
  int _estimateCurrentStop(int targetStopIndex, int minutesToArrival, int totalStops) {
    // Si llega en 0 min, esta en esa parada o muy cerca
    if (minutesToArrival <= 0) {
      // El bus esta en la parada anterior o llegando a esta
      int prev = targetStopIndex - 1;
      if (prev < 0) prev = totalStops - 1;
      return prev;
    }
    
    // Estimar ~2 minutos por parada
    final stopsAway = (minutesToArrival / 2.0).ceil();
    int estimated = targetStopIndex - stopsAway;
    
    // Asegurar que este dentro del rango valido
    if (estimated < 0) {
      // El bus viene desde el final de la ruta (circular)
      estimated = totalStops + estimated;
    }
    if (estimated < 0) estimated = 0;
    if (estimated >= totalStops) estimated = totalStops - 1;
    
    print('    Calculo: parada destino=$targetStopIndex, minutos=$minutesToArrival, stopsAway=$stopsAway -> estimado=$estimated');
    return estimated;
  }
  
  int _parseMinutes(String timeStr) {
    // Si contiene <<< o >> o similar significa que esta llegando o acaba de pasar
    if (timeStr.contains('<') || timeStr.contains('>')) return 0;
    if (timeStr.toLowerCase().contains('llegando')) return 0;
    
    final match = RegExp(r'(\d+)').firstMatch(timeStr);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }
  
  void _updateBusPositions() {
    bool changed = false;
    
    for (final bus in _buses.values) {
      if (bus.isAtStop) {
        if (bus.departureTime == null) {
          bus.departureTime = DateTime.now().add(const Duration(seconds: 8));
        } else if (DateTime.now().isAfter(bus.departureTime!)) {
          bus.isAtStop = false;
          bus.departureTime = null;
        }
        continue;
      }
      
      final stops = _lineStops[bus.lineId];
      if (stops == null || stops.length < 2) continue;
      
      bus.progress += 0.008 * bus.speed;
      changed = true;
      
      if (bus.progress >= 1.0) {
        bus.progress = 0;
        bus.currentStopIndex = bus.nextStopIndex;
        bus.nextStopIndex = (bus.nextStopIndex + 1) % stops.length;
        bus.isAtStop = true;
      }
      
      final from = _getStopPosition(stops[bus.currentStopIndex]);
      final to = _getStopPosition(stops[bus.nextStopIndex]);
      
      bus.currentPosition = _interpolate(from, to, bus.progress);
      bus.heading = _calculateHeading(from, to);
    }
    
    if (changed) {
      _busStreamController.add(_buses);
    }
  }
  
  LatLng _getStopPosition(Map<String, dynamic> stop) {
    return LatLng(
      (stop['lat'] as num).toDouble(),
      (stop['lng'] as num).toDouble(),
    );
  }
  
  LatLng _interpolate(LatLng from, LatLng to, double t) {
    final lat = from.latitude + (to.latitude - from.latitude) * t;
    final lng = from.longitude + (to.longitude - from.longitude) * t;
    return LatLng(lat, lng);
  }
  
  double _calculateHeading(LatLng from, LatLng to) {
    final dLng = (to.longitude - from.longitude) * pi / 180;
    final lat1 = from.latitude * pi / 180;
    final lat2 = to.latitude * pi / 180;
    
    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);
    
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }
  
  void dispose() {
    stopSimulation();
    _busStreamController.close();
  }
}
