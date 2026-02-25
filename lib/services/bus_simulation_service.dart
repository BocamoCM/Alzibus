import 'dart:async';
import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'bus_times_service.dart';
import 'gps_track_service.dart';

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
  List<LatLng>? gpsTrack; // Track GPS completo de la línea
  int trackFromIndex; // Índice del punto de inicio en el track
  int trackToIndex; // Índice del punto de destino en el track
  DateTime? lastApiUpdate; // Cuando se actualizo por ultima vez desde la API
  double targetProgress; // Progreso objetivo basado en tiempo real
  
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
    this.gpsTrack,
    this.trackFromIndex = 0,
    this.trackToIndex = 0,
    this.lastApiUpdate,
    this.targetProgress = 0,
  });
}

class BusSimulationService {
  // --- Singleton Setup ---
  static final BusSimulationService _instance = BusSimulationService._internal();

  factory BusSimulationService() {
    return _instance;
  }

  BusSimulationService._internal();
  // -----------------------

  final BusTimesService _busTimesService = BusTimesService();
  final Map<String, SimulatedBus> _buses = {};
  final Map<String, List<Map<String, dynamic>>> _lineStops = {};
  
  Timer? _updateTimer;
  Timer? _trackingTimer;
  // Behavior-like logic so new listeners get the current buses immediately
  StreamController<Map<String, SimulatedBus>>? _busStreamController;
  bool _isDisposed = false;
  
  Stream<Map<String, SimulatedBus>> get busStream {
    _busStreamController ??= StreamController<Map<String, SimulatedBus>>.broadcast(
      onListen: () {
        // Al conectar un nuevo listener (pantalla), mandarle el estado actual enseguida
        if (_buses.isNotEmpty && !_isDisposed) {
          _busStreamController?.add(_buses);
        }
      }
    );
    return _busStreamController!.stream;
  }
  
  Map<String, SimulatedBus> get buses => Map.unmodifiable(_buses);
  
  void _emitBuses() {
    if (!_isDisposed && _busStreamController != null && !_busStreamController!.isClosed) {
      _busStreamController!.add(_buses);
    }
  }
  
  void setLineStops(String lineId, List<Map<String, dynamic>> stops) {
    _lineStops[lineId] = stops;
  }
  
  List<Map<String, dynamic>>? getLineStops(String lineId) => _lineStops[lineId];
  
  void startSimulation() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _updateBusPositions();
    });
    
    // Actualizar posiciones de buses cada 15 segundos consultando siguiente parada
    _trackingTimer?.cancel();
    _trackingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
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
      final stopId = stop['id'] as int? ?? 0;
      if (stopId == 0) continue;
      
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
      
      // Calcular progreso inicial basado en minutos
      double initialProgress = 0.0;
      if (minutes <= 1) {
        initialProgress = 0.9; // Casi llegando
      } else if (minutes == 2) {
        initialProgress = 0.5; // A medio camino
      } else if (minutes <= 4) {
        initialProgress = 0.2; // Saliendo de parada
      }
      
      final pos = _getStopPosition(lineStops[estimatedStopIndex]);
      
      print('');
      print('==> Creando bus $lineId:');
      print('    Llegara a parada ${data['stopName']} en $minutes min');
      print('    Posicion estimada: parada $estimatedStopIndex de ${lineStops.length}');
      print('    Progreso inicial: ${(initialProgress * 100).toInt()}%');
      
      final bus = SimulatedBus(
        lineId: lineId,
        busId: lineId,
        currentPosition: pos,
        currentStopIndex: estimatedStopIndex,
        nextStopIndex: (estimatedStopIndex + 1) % lineStops.length,
        progress: initialProgress,
        targetProgress: initialProgress,
        lastKnownMinutes: minutes,
        trackingStopId: data['stopId'] as int,
        lastApiUpdate: DateTime.now(),
        speed: 1.0,
      );
      
      // Cargar el track GPS para esta línea
      final gpsTrack = await GpsTrackService.loadTrack(lineId);
      if (gpsTrack.isNotEmpty) {
        bus.gpsTrack = gpsTrack;
      }
      
      _buses[lineId] = bus;
      
      // Actualizar los índices del segmento inicial
      _updateBusTrackSegment(bus);
    }
    
    print('');
    print('=== ESCANEO COMPLETO: ${_buses.length} buses encontrados ===');
    _emitBuses();
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
          
          // Solo loguear si hay cambio significativo
          if (bus.lastKnownMinutes == null || (bus.lastKnownMinutes! - minutes).abs() > 1) {
            print('${bus.lineId}: Próxima parada ${nextStopData['name']} en $minutes min');
          }
          
          bus.lastApiUpdate = DateTime.now();
          bus.lastKnownMinutes = minutes;
          bus.trackingStopId = nextStopId;
          
          // Ajustar velocidad según tiempo real - SIN teletransportar
          if (minutes <= 0) {
            // Bus llegando - acelerar para llegar
            bus.targetProgress = 1.0;
            bus.speed = 2.0;
          } else if (minutes == 1) {
            bus.targetProgress = 0.8;
            bus.speed = 1.5;
          } else if (minutes <= 3) {
            // Tiempo normal entre paradas
            bus.targetProgress = max(0.3, 1.0 - (minutes * 0.25));
            bus.speed = 1.2;
          } else {
            // Más de 3 min - ir más lento, el bus está lejos
            bus.speed = 0.6;
            // NO reposicionar - dejar que llegue naturalmente
          }
          
          // Reanudar movimiento
          bus.isAtStop = false;
          bus.departureTime = null;
        }
      } catch (e) {
        // Mantener velocidad actual si falla la consulta
      }
    }
    
    _emitBuses();
  }
  
  int _estimateCurrentStop(int targetStopIndex, int minutesToArrival, int totalStops) {
    // Si llega en 0-1 min, esta muy cerca de esa parada
    if (minutesToArrival <= 1) {
      // El bus esta en la parada anterior o llegando a esta
      int prev = targetStopIndex - 1;
      if (prev < 0) prev = totalStops - 1;
      return prev;
    }
    
    // Estimar ~2.5 minutos por parada (mas realista)
    final stopsAway = (minutesToArrival / 2.5).ceil();
    int estimated = targetStopIndex - stopsAway;
    
    // Asegurar que este dentro del rango valido
    while (estimated < 0) {
      estimated += totalStops;
    }
    if (estimated >= totalStops) estimated = estimated % totalStops;
    
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
          bus.departureTime = DateTime.now().add(const Duration(seconds: 5));
        } else if (DateTime.now().isAfter(bus.departureTime!)) {
          bus.isAtStop = false;
          bus.departureTime = null;
          bus.targetProgress = 0;
          // Actualizar segmento del track para el siguiente tramo
          _updateBusTrackSegment(bus);
        }
        continue;
      }
      
      final stops = _lineStops[bus.lineId];
      if (stops == null || stops.length < 2) continue;
      
      // Movimiento suave hacia el progreso objetivo
      // Si tenemos datos recientes de la API, ajustar el progreso hacia el objetivo
      if (bus.lastApiUpdate != null) {
        final secondsSinceUpdate = DateTime.now().difference(bus.lastApiUpdate!).inSeconds;
        
        // Si los datos tienen mas de 30 segundos, avanzar normalmente
        if (secondsSinceUpdate < 30) {
          // Suavizar el movimiento hacia el objetivo
          final diff = bus.targetProgress - bus.progress;
          if (diff.abs() > 0.01) {
            // Mover hacia el objetivo suavemente
            bus.progress += diff * 0.05 * bus.speed;
          } else {
            // Continuar avanzando normalmente
            bus.progress += 0.006 * bus.speed;
          }
        } else {
          // Datos viejos, avanzar normalmente
          bus.progress += 0.006 * bus.speed;
        }
      } else {
        bus.progress += 0.006 * bus.speed;
      }
      
      changed = true;
      
      if (bus.progress >= 1.0) {
        bus.progress = 0;
        bus.targetProgress = 0;
        bus.currentStopIndex = bus.nextStopIndex;
        bus.nextStopIndex = (bus.nextStopIndex + 1) % stops.length;
        bus.isAtStop = true;
        bus.lastApiUpdate = null; // Forzar nueva consulta
        // Actualizar segmento del track para el próximo tramo
        _updateBusTrackSegment(bus);
      }
      
      // Usar el track GPS si está disponible y los índices son válidos
      if (bus.gpsTrack != null && 
          bus.gpsTrack!.isNotEmpty && 
          bus.trackFromIndex < bus.gpsTrack!.length &&
          bus.trackToIndex < bus.gpsTrack!.length &&
          bus.trackToIndex > bus.trackFromIndex) {
        bus.currentPosition = GpsTrackService.interpolateOnTrack(
          bus.gpsTrack!,
          bus.trackFromIndex,
          bus.trackToIndex,
          bus.progress,
        );
        bus.heading = GpsTrackService.getHeadingOnTrack(
          bus.gpsTrack!,
          bus.trackFromIndex,
          bus.trackToIndex,
          bus.progress,
        );
      } else {
        // Fallback a línea recta si no hay track GPS
        final from = _getStopPosition(stops[bus.currentStopIndex]);
        final to = _getStopPosition(stops[bus.nextStopIndex]);
        
        bus.currentPosition = _interpolate(from, to, bus.progress);
        bus.heading = _calculateHeading(from, to);
      }
    }
    
    if (changed) {
      _emitBuses();
    }
  }
  
  /// Actualiza los índices del segmento del track para un bus
  void _updateBusTrackSegment(SimulatedBus bus) {
    final stops = _lineStops[bus.lineId];
    if (stops == null || stops.length < 2) return;
    if (bus.gpsTrack == null || bus.gpsTrack!.isEmpty) return;
    
    final from = _getStopPosition(stops[bus.currentStopIndex]);
    final to = _getStopPosition(stops[bus.nextStopIndex]);
    
    final segment = GpsTrackService.findSegmentBetweenStops(bus.gpsTrack!, from, to);
    bus.trackFromIndex = segment.fromIndex;
    bus.trackToIndex = segment.toIndex;
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
    _isDisposed = true;
    stopSimulation();
    _busStreamController?.close();
  }
}
