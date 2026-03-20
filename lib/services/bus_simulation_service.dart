import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
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
  int? trackingStopIndex;
  List<LatLng>? gpsTrack;
  int trackFromIndex;
  int trackToIndex;
  DateTime? lastApiUpdate;
  double targetProgress;

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
    this.trackingStopIndex,
    this.gpsTrack,
    this.trackFromIndex = 0,
    this.trackToIndex = 0,
    this.lastApiUpdate,
    this.targetProgress = 0,
  });
}

class BusSimulationService {
  BusSimulationService();

  final BusTimesService _busTimesService = BusTimesService();
  final Map<String, SimulatedBus> _buses = {};
  final Map<String, List<Map<String, dynamic>>> _lineStops = {};

  Timer? _updateTimer;
  Timer? _trackingTimer;
  StreamController<Map<String, SimulatedBus>>? _busStreamController;
  bool _isDisposed = false;

  // Interval of the position update timer (500ms)
  static const double _tickSeconds = 0.5;

  Stream<Map<String, SimulatedBus>> get busStream {
    _busStreamController ??= StreamController<Map<String, SimulatedBus>>.broadcast(
      onListen: () {
        if (_buses.isNotEmpty && !_isDisposed) {
          _busStreamController?.add(_buses);
        }
      },
    );
    return _busStreamController!.stream;
  }

  Map<String, SimulatedBus> get buses => Map.unmodifiable(_buses);

  void _emitBuses() {
    if (!_isDisposed &&
        _busStreamController != null &&
        !_busStreamController!.isClosed) {
      _busStreamController!.add(_buses);
    }
  }

  void setLineStops(String lineId, List<Map<String, dynamic>> stops) {
    _lineStops[lineId] = stops;
  }

  List<Map<String, dynamic>>? getLineStops(String lineId) => _lineStops[lineId];

  void startSimulation() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(
      Duration(milliseconds: (_tickSeconds * 1000).toInt()),
      (_) => _updateBusPositions(),
    );

    _trackingTimer?.cancel();
    _trackingTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _trackBuses(),
    );
  }

  void stopSimulation() {
    _updateTimer?.cancel();
    _trackingTimer?.cancel();
    _updateTimer = null;
    _trackingTimer = null;
  }

  /// Escaneo inicial: consulta todas las paradas para encontrar buses.
  Future<void> initialScan(List<Map<String, dynamic>> allStops) async {
    debugPrint('=== ESCANEO INICIAL DE TODAS LAS PARADAS ===');

    // guardamos el bus más cercano encontrado por cada línea
    final Map<String, Map<String, dynamic>> closestBusByLine = {};

    for (final stop in allStops) {
      final stopId = stop['id'] as int? ?? 0;
      if (stopId == 0) continue;

      final lines = List<String>.from(stop['lines'] as List);

      try {
        final arrivals = await _busTimesService.getArrivalTimes(stopId);

        for (final arrival in arrivals) {
          if (!lines.contains(arrival.line)) continue;
          if (!_lineStops.containsKey(arrival.line)) continue;

          final lineStops = _lineStops[arrival.line]!;
          final stopIndex = lineStops.indexWhere((s) => s['id'] == stopId);
          if (stopIndex < 0) continue;

          final minutes = _parseMinutes(arrival.time);
          final lineId = arrival.line;

          if (!closestBusByLine.containsKey(lineId) ||
              minutes < (closestBusByLine[lineId]!['minutes'] as int)) {
            closestBusByLine[lineId] = {
              'minutes': minutes,
              'stopIndex': stopIndex,
              'stopId': stopId,
              'stopName': stop['name'],
              'destination': arrival.destination,
            };
            debugPrint('$lineId: Bus en ${stop['name']} -> ${arrival.destination} ($minutes min)');
          }
        }
      } catch (e) {
        debugPrint('Error en parada $stopId: $e');
      }

      await Future.delayed(const Duration(milliseconds: 50));
    }

    for (final entry in closestBusByLine.entries) {
      final lineId = entry.key;
      final data = entry.value;
      final lineStops = _lineStops[lineId]!;

      final stopIndex = data['stopIndex'] as int;
      final minutes = data['minutes'] as int;

      // Mejora 1: Calcular progreso inicial calibrado según minutos reales
      final estimatedStopIndex = _estimateCurrentStop(stopIndex, minutes, lineStops.length);
      final double initialProgress = _progressFromMinutes(minutes);

      final pos = _getStopPosition(lineStops[estimatedStopIndex]);

      debugPrint('');
      debugPrint('==> Creando bus $lineId:');
      debugPrint('    Llegara a parada ${data['stopName']} en $minutes min');
      debugPrint('    Posicion estimada: parada $estimatedStopIndex de ${lineStops.length}');
      debugPrint('    Progreso inicial: ${(initialProgress * 100).toInt()}%');

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
        trackingStopIndex: data['stopIndex'] as int,
        lastApiUpdate: DateTime.now(),
        speed: 1.0,
      );

      final gpsTrack = await GpsTrackService.loadTrack(lineId);
      if (gpsTrack.isNotEmpty) {
        bus.gpsTrack = gpsTrack;
      }

      _buses[lineId] = bus;
      _updateBusTrackSegment(bus);
    }

    debugPrint('');
    debugPrint('=== ESCANEO COMPLETO: ${_buses.length} buses encontrados ===');
    _emitBuses();
  }

  /// Convierte minutos de llegada a un progreso inicial [0..1].
  /// 0 min → 0.95 (casi llegando), 5+ min → ~0.05 (acaba de salir).
  double _progressFromMinutes(int minutes) {
    if (minutes <= 0) return 0.95;
    if (minutes == 1) return 0.75;
    if (minutes == 2) return 0.50;
    if (minutes <= 4) return 0.20;
    return 0.05;
  }

  /// Seguimiento continuo: consulta la API para calibrar cada bus.
  /// Mejora 2: si la parada siguiente no tiene datos, prueba adyacentes.
  Future<void> _trackBuses() async {
    for (final bus in _buses.values.toList()) {
      final lineStops = _lineStops[bus.lineId];
      if (lineStops == null || lineStops.isEmpty) continue;

      // Candidatos: próxima parada y sus vecinas (fallback)
      final candidateIndices = [
        bus.nextStopIndex,
        (bus.nextStopIndex + 1) % lineStops.length,
        (bus.nextStopIndex - 1 + lineStops.length) % lineStops.length,
      ];

      bool matched = false;
      for (final idx in candidateIndices) {
        final stopData = lineStops[idx];
        final stopId = stopData['id'] as int;

        try {
          final arrivals = await _busTimesService.getArrivalTimes(stopId);
          final lineArrivals = arrivals.where((a) => a.line == bus.lineId).toList();

          if (lineArrivals.isEmpty) continue;

          final arrival = lineArrivals.first;
          final minutes = _parseMinutes(arrival.time);

          if (bus.lastKnownMinutes == null ||
              (bus.lastKnownMinutes! - minutes).abs() > 1) {
            debugPrint('${bus.lineId}: Próxima parada ${stopData['name']} en $minutes min');
          }

          bus.lastApiUpdate = DateTime.now();
          bus.lastKnownMinutes = minutes;
          bus.trackingStopId = stopId;
          bus.trackingStopIndex = idx;

          // Mejora 4: targetProgress solo avanza, nunca retrocede
          final newTarget = _computeTargetProgress(bus.progress, minutes);
          if (newTarget > bus.targetProgress) {
            bus.targetProgress = newTarget;
          }

          // Ajustar velocidad relativa
          bus.speed = _speedFromMinutes(minutes);
          bus.isAtStop = false;
          bus.departureTime = null;

          matched = true;
          break;
        } catch (_) {
          continue;
        }
      }

      if (!matched) {
        // Sin datos de API: avanzar a velocidad media conservadora
        bus.speed = 0.8;
      }
    }

    _emitBuses();
  }

  /// Calcula el targetProgress asegurando que el bus llegue al destino
  /// exactamente cuando la API dice (sin saltos ni retrocesos).
  double _computeTargetProgress(double currentProgress, int minutes) {
    if (minutes <= 0) return 1.0;
    // Objetivo: llegar al 100% en exactly `minutes` minutos
    // Cada tick = 0.5s → totalTicks = minutes * 120 ticks
    // incrementoPorTick = (1.0 - currentProgress) / totalTicks
    // Ajustamos el objetivo al trayecto completo restante
    final remaining = 1.0 - currentProgress;
    final estimatedTarget = currentProgress + (remaining * (1.0 / (minutes * 2.0)));
    return estimatedTarget.clamp(currentProgress, 1.0);
  }

  double _speedFromMinutes(int minutes) {
    if (minutes <= 0) return 2.5;
    if (minutes == 1) return 1.8;
    if (minutes <= 2) return 1.3;
    if (minutes <= 4) return 1.0;
    return 0.7;
  }

  int _estimateCurrentStop(int targetStopIndex, int minutesToArrival, int totalStops) {
    if (minutesToArrival <= 1) {
      int prev = targetStopIndex - 1;
      if (prev < 0) prev = totalStops - 1;
      return prev;
    }
    // ~2.5 min/parada en promedio
    final stopsAway = (minutesToArrival / 2.5).ceil();
    int estimated = targetStopIndex - stopsAway;
    while (estimated < 0) {
      estimated += totalStops;
    }
    return estimated % totalStops;
  }

  int _parseMinutes(String timeStr) {
    if (timeStr.contains('<') || timeStr.contains('>')) return 0;
    if (timeStr.toLowerCase().contains('llegando')) return 0;
    final match = RegExp(r'(\d+)').firstMatch(timeStr);
    if (match != null) return int.tryParse(match.group(1)!) ?? 0;
    return 0;
  }

  void _updateBusPositions() {
    bool changed = false;

    for (final bus in _buses.values) {
      if (bus.isAtStop) {
        if (bus.departureTime == null) {
          // Mejora 5: tiempo en parada escalado por minutos (3..15 seg)
          final stopSeconds = (bus.lastKnownMinutes != null)
              ? (bus.lastKnownMinutes! * 2).clamp(3, 15)
              : 5;
          bus.departureTime =
              DateTime.now().add(Duration(seconds: stopSeconds));
        } else if (DateTime.now().isAfter(bus.departureTime!)) {
          bus.isAtStop = false;
          bus.departureTime = null;
          bus.targetProgress = 0;
          _updateBusTrackSegment(bus);
        }
        continue;
      }

      final stops = _lineStops[bus.lineId];
      if (stops == null || stops.length < 2) continue;

      // Mejora 1: avance calibrado por tiempo real
      // Si tenemos minutos reales, calcular delta exacto para llegar a tiempo
      final minutes = bus.lastKnownMinutes;
      double delta;

      if (minutes != null && minutes > 0 && bus.lastApiUpdate != null) {
        // Segundos restantes de los datos de la API ajustados al tiempo transcurrido
        final elapsed = DateTime.now().difference(bus.lastApiUpdate!).inSeconds;
        final remainingSeconds = (minutes * 60 - elapsed).clamp(1, 3600).toDouble();
        final remainingProgress = 1.0 - bus.progress;
        // Delta para completar el progreso restante en el tiempo restante
        delta = (remainingProgress / remainingSeconds) * _tickSeconds;
        delta = delta.clamp(0.001, 0.05); // límites de seguridad
      } else {
        delta = 0.006 * (bus.speed);
      }

      // Mejora 4: no retroceder — siempre avanzar
      bus.progress = (bus.progress + delta).clamp(bus.progress, 1.0);

      // Suavizar hacia targetProgress si este está por delante
      if (bus.targetProgress > bus.progress + 0.02) {
        final diff = bus.targetProgress - bus.progress;
        bus.progress += diff * 0.04;
      }

      changed = true;

      if (bus.progress >= 1.0) {
        bus.progress = 0;
        bus.targetProgress = 0;
        bus.currentStopIndex = bus.nextStopIndex;
        bus.nextStopIndex = (bus.nextStopIndex + 1) % stops.length;
        bus.isAtStop = true;
        // Mejora 3: NO resetear lastApiUpdate al llegar a parada
        _updateBusTrackSegment(bus);
      }

      // Actualizar posición física
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
        // Fallback a línea recta
        final from = _getStopPosition(stops[bus.currentStopIndex]);
        final to = _getStopPosition(stops[bus.nextStopIndex]);
        bus.currentPosition = _interpolate(from, to, bus.progress);
        bus.heading = _calculateHeading(from, to);
      }
    }

    if (changed) _emitBuses();
  }

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
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
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
