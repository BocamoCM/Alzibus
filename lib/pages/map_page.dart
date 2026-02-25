import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/bus_stop.dart';
import '../constants/line_colors.dart';
import '../services/notification_service.dart';
import '../services/location_service.dart';
import '../services/stops_service.dart';
import '../services/bus_simulation_service.dart';
import '../widgets/line_filter.dart';
import '../widgets/stop_info_sheet.dart';
import '../widgets/animated_bus_marker.dart';
import '../theme/app_theme.dart';

class MapPage extends StatefulWidget {
  final FlutterLocalNotificationsPlugin notif;
  final bool notificationsEnabled;
  final double notificationDistance;
  final int notificationCooldown;
  final bool showSimulatedBuses;
  final BusStop? initialStop;

  const MapPage({
    super.key,
    required this.notif,
    required this.notificationsEnabled,
    required this.notificationDistance,
    required this.notificationCooldown,
    required this.showSimulatedBuses,
    this.initialStop,
  });

  @override
  State<MapPage> createState() => MapPageState();
}

class MapPageState extends State<MapPage> {
  List<BusStop> stops = [];
  Set<String> selectedLines = {'L1', 'L2', 'L3'};
  LatLng center = LatLng(39.1566, -0.4354);
  LatLng? myLocation;
  double? myHeading = 0.0;
  final TextEditingController _searchController = TextEditingController();
  
  final Distance distance = Distance();
  final Map<String, DateTime> _lastNotified = {};
  final MapController _mapController = MapController();
  
  late final NotificationService _notificationService;
  late final LocationService _locationService;
  late final StopsService _stopsService;
  late final BusSimulationService _busSimulationService;
  
  Map<String, SimulatedBus> _simulatedBuses = {};
  Timer? _busUpdateTimer;
  
  // Exponer el servicio de simulación para otras páginas
  BusSimulationService get busSimulationService => _busSimulationService;

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService(widget.notif);
    _stopsService = StopsService();
    _busSimulationService = BusSimulationService();
    _locationService = LocationService(
      onLocationUpdate: (position, heading) {
        setState(() {
          myLocation = position;
          myHeading = heading;
        });
        _checkProximity(position);
      },
    );
    
    _loadStops();
    _locationService.startTracking();
    _setupBusSimulation();
    
    // Si hay una parada inicial, ir a ella después de cargar
    if (widget.initialStop != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        goToStop(widget.initialStop!);
      });
    }
  }
  
  /// Método público para ir a una parada desde otras pantallas
  void goToStop(BusStop stop) {
    // Mover el mapa a la parada
    _mapController.move(LatLng(stop.lat, stop.lng), 17);
    
    // Mostrar la info de la parada
    Future.delayed(const Duration(milliseconds: 300), () {
      _showStopInfo(stop);
    });
  }

  @override
  void dispose() {
    _locationService.stopTracking();
    // NO destruir el singleton _busSimulationService.dispose();
    _busUpdateTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }
  
  void _setupBusSimulation() {
    _busSimulationService.busStream.listen((buses) {
      if (mounted) {
        setState(() {
          _simulatedBuses = buses;
        });
      }
    });
    
    // Obtener estado actual INMEDIATO
    if (mounted) {
      setState(() {
        _simulatedBuses = _busSimulationService.buses;
      });
    }
  }
  

  Future<void> _loadStops() async {
    print('Intentando cargar paradas...');
    final loadedStops = await _stopsService.loadStops();
    print('Paradas cargadas: ${loadedStops.length}');
    
    if (mounted) {
      setState(() {
        stops = loadedStops;
      });
    }
  }

  void _checkProximity(LatLng myPos) async {
    if (!widget.notificationsEnabled) return;

    final double thresholdMeters = widget.notificationDistance;
    for (final stop in stops) {
      final stopPos = LatLng(stop.lat, stop.lng);
      final d = distance(myPos, stopPos);
      final id = stop.id.toString();
      
      if (d <= thresholdMeters) {
        final last = _lastNotified[id];
        final cooldown = Duration(minutes: widget.notificationCooldown);
        if (last == null || DateTime.now().difference(last) > cooldown) {
          _lastNotified[id] = DateTime.now();
          await _notificationService.showProximityNotification(
            stop.name,
            stop.lines,
            d,
          );
        }
      }
    }
  }

  void _showStopInfo(BusStop stop) {
    showModalBottomSheet(
      context: context,
      builder: (context) => StopInfoSheet(
        stop: stop,
        userLocation: myLocation,
      ),
    );
  }

  void _showBusInfo(SimulatedBus bus) {
    final lineStops = _busSimulationService.getLineStops(bus.lineId);
    String nextStopName = 'Desconocida';
    String estimatedTime = '--';
    
    if (lineStops != null && bus.nextStopIndex < lineStops.length) {
      nextStopName = lineStops[bus.nextStopIndex]['name'] ?? 'Desconocida';
    }
    
    if (bus.lastKnownMinutes != null) {
      estimatedTime = bus.lastKnownMinutes == 0 
          ? 'Llegando' 
          : '${bus.lastKnownMinutes} min';
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getLineColor(bus.lineId),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    bus.lineId,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Autobús en servicio',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.location_on, 'Próxima parada', nextStopName),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.access_time, 'Tiempo estimado', estimatedTime),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.speed, 
              'Estado', 
              bus.isAtStop ? '🛑 En parada' : '🚌 En movimiento',
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: 20),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(color: Colors.grey[600]),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Color _getLineColor(String lineId) {
    switch (lineId) {
      case 'L1':
        return const Color(0xFF1565C0); // Azul
      case 'L2':
        return const Color(0xFF2E7D32); // Verde
      case 'L3':
        return const Color(0xFFE65100);
      default:
        return Colors.grey;
    }
  }

  void _centerOnMyLocation() {
    if (myLocation != null) {
      _mapController.move(myLocation!, 16.0);
    }
  }

  void goToStopById(int stopId) {
    try {
      final stop = stops.firstWhere((s) => s.id == stopId);
      
      // Move map logic similar to the search logic
      _mapController.move(LatLng(stop.lat, stop.lng), 17.0);
      
      // Select the lines of this stop so it appears
      setState(() {
        for (final line in stop.lines) {
          if (!selectedLines.contains(line)) {
            selectedLines.add(line);
          }
        }
      });
      
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _showStopInfo(stop);
      });
    } catch (e) {
      debugPrint('Parada ID $stopId no encontrada en la lista.');
    }
  }

  void _showSearchDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Buscar parada...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  onChanged: (value) {
                    // Actualiza el filtro
                  },
                ),
              ),
              Expanded(
                child: StatefulBuilder(
                  builder: (context, setStateLocal) {
                    final query = _searchController.text.toLowerCase();
                    final filteredStops = stops.where((stop) {
                      return stop.name.toLowerCase().contains(query);
                    }).toList();
                    
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: filteredStops.length,
                      itemBuilder: (context, index) {
                        final stop = filteredStops[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: LineColors.getStopColor(stop.lines, selectedLines),
                            child: const Icon(Icons.directions_bus, color: Colors.white, size: 20),
                          ),
                          title: Text(stop.name),
                          subtitle: Text(stop.lines.join(', ')),
                          onTap: () {
                            Navigator.pop(context);
                            _mapController.move(LatLng(stop.lat, stop.lng), 17.0);
                            Future.delayed(const Duration(milliseconds: 300), () {
                              _showStopInfo(stop);
                            });
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleLine(String line) {
    setState(() {
      if (selectedLines.contains(line)) {
        selectedLines.remove(line);
      } else {
        selectedLines.add(line);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredStops = stops.where((stop) {
      return stop.lines.any((line) => selectedLines.contains(line));
    }).toList();

    final markers = filteredStops.map((stop) {
      return Marker(
        width: 50,
        height: 50,
        point: LatLng(stop.lat, stop.lng),
        child: GestureDetector(
          onTap: () => _showStopInfo(stop),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.directions_bus_rounded,
                color: LineColors.getStopColor(stop.lines, selectedLines),
                size: 28,
              ),
            ),
          ),
        ),
      );
    }).toList();

    if (myLocation != null) {
      markers.add(
        Marker(
          width: 50,
          height: 50,
          point: myLocation!,
          child: Transform.rotate(
            angle: (myHeading ?? 0) * 3.14159 / 180,
            child: const Icon(Icons.navigation, color: AlzibusColors.burgundy, size: 40),
          ),
        ),
      );
    }
    
    // Agregar marcadores de autobuses simulados (si está habilitado)
    if (widget.showSimulatedBuses) {
      for (final bus in _simulatedBuses.values) {
        if (!selectedLines.contains(bus.lineId)) continue;
        
        markers.add(
          Marker(
            width: 60,
            height: 60,
            point: bus.currentPosition,
            child: GestureDetector(
              onTap: () => _showBusInfo(bus),
              child: AnimatedBusMarker(
                heading: bus.heading,
                lineId: bus.lineId,
                isAtStop: bus.isAtStop,
                size: 56,
              ),
            ),
          ),
        );
      }
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: myLocation ?? center,
            initialZoom: 15.0,
            maxZoom: 19.0,
            minZoom: 12.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.alzibus',
              maxZoom: 19,
            ),
            if (myLocation != null)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: myLocation!,
                    radius: widget.notificationDistance,
                    useRadiusInMeter: true,
                    color: AlzibusColors.wine.withOpacity(0.15),
                    borderColor: AlzibusColors.wine.withOpacity(0.7),
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            MarkerLayer(markers: markers),
          ],
        ),
        // Barra de búsqueda superior
        Positioned(
          top: 16,
          left: 16,
          right: 80,
          child: GestureDetector(
            onTap: _showSearchDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.grey[600]),
                  const SizedBox(width: 12),
                  Text(
                    'Buscar parada...',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: LineFilter(
            selectedLines: selectedLines,
            onLineToggle: _toggleLine,
          ),
        ),
        // Botón para centrar en mi ubicación
        Positioned(
          bottom: 24,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'location',
            onPressed: _centerOnMyLocation,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.my_location,
              color: myLocation != null ? AlzibusColors.burgundy : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
}
