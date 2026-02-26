import 'package:flutter/material.dart';
import 'dart:async';
import '../services/stops_service.dart';
import '../services/bus_simulation_service.dart';
import '../models/bus_stop.dart';
import '../theme/app_theme.dart';

class RoutesPage extends StatefulWidget {
  final Function(BusStop stop)? onStopTapped;
  
  const RoutesPage({super.key, this.onStopTapped});

  @override
  State<RoutesPage> createState() => _RoutesPageState();
}

class _RoutesPageState extends State<RoutesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final StopsService _stopsService = StopsService();
  
  Map<String, List<Map<String, dynamic>>> _routes = {};
  bool _isLoading = true;
  
  // Info de buses en tiempo real
  Map<String, SimulatedBus> _buses = {};
  StreamSubscription? _busSubscription;
  Timer? _uiRefreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRoutes();
    _subscribeToBuses();
    
    // Timer para forzar refresco de UI y animar progreso de buses
    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _busSubscription?.cancel();
    _uiRefreshTimer?.cancel();
    super.dispose();
  }
  
  void _subscribeToBuses() {
    final busService = BusSimulationService(); // Usa el Singleton
    _buses = busService.buses;
    _busSubscription = busService.busStream.listen((buses) {
      if (mounted) {
        setState(() => _buses = buses);
      }
    });
  }

  Future<void> _loadRoutes() async {
    for (final line in ['L1', 'L2', 'L3']) {
      final stops = await _stopsService.loadLineRoute(line);
      _routes[line] = stops;
    }
    setState(() => _isLoading = false);
  }

  Color _getLineColor(String lineId) {
    switch (lineId) {
      case 'L1':
        return AlzibusColors.lineL1;
      case 'L2':
        return AlzibusColors.lineL2;
      case 'L3':
        return AlzibusColors.lineL3;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutas'),
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _getLineColor('L1'),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('L1'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _getLineColor('L2'),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('L2'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _getLineColor('L3'),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('L3'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRouteList('L1'),
                _buildRouteList('L2'),
                _buildRouteList('L3'),
              ],
            ),
    );
  }

  Widget _buildRouteList(String lineId) {
    final stops = _routes[lineId] ?? [];
    final color = _getLineColor(lineId);
    
    // Buscar el bus de esta línea
    final bus = _buses.values.where((b) => b.lineId == lineId).firstOrNull;
    final int? busAtStopIndex = bus?.currentStopIndex;
    final int? busNextStopIndex = bus?.nextStopIndex;

    if (stops.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No hay paradas para $lineId',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Banner del bus si existe
        if (bus != null)
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.directions_bus, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bus.isAtStop 
                          ? '🚏 En parada' 
                          : '🚌 En camino',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        bus.isAtStop
                          ? stops[busAtStopIndex ?? 0]['name'] ?? 'Parada'
                          : 'Hacia ${() {
                              if (bus.trackingStopIndex != null && bus.trackingStopIndex! < stops.length) {
                                return stops[bus.trackingStopIndex!]['name'] ?? 'siguiente';
                              } else if (bus.trackingStopId != null) {
                                try {
                                  return stops.firstWhere((s) => s['id'] == bus.trackingStopId)['name'] ?? 'siguiente';
                                } catch (_) {}
                              }
                              return stops[busNextStopIndex ?? 0]['name'] ?? 'siguiente';
                            }()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${((busNextStopIndex ?? 0) / stops.length * 100).round()}%',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        // Lista de paradas
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: stops.length,
            itemBuilder: (context, index) {
              final stop = stops[index];
              final isFirst = index == 0;
              final isLast = index == stops.length - 1;
              
              // Determinar si el bus está en esta parada o entre paradas
              final bool isBusHere = bus != null && busAtStopIndex == index && bus.isAtStop;
              final bool isBusApproaching = bus != null && busNextStopIndex == index && !bus.isAtStop;
              final bool busPassedHere = bus != null && (busNextStopIndex ?? 0) > index;

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Línea vertical con puntos
                    SizedBox(
                      width: 60,
                      child: Column(
                        children: [
                          // Línea superior
                          Expanded(
                            child: Container(
                              width: 4,
                              color: isFirst ? Colors.transparent : (busPassedHere ? color : color.withOpacity(0.3)),
                            ),
                          ),
                          // Icono del bus o círculo del punto
                          if (isBusHere)
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withOpacity(0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.directions_bus,
                                color: Colors.white,
                                size: 18,
                              ),
                            )
                          else
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: (isFirst || isLast) ? color : (busPassedHere ? color : Colors.white),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: color, 
                                  width: busPassedHere ? 3 : 2,
                                ),
                                boxShadow: isBusApproaching ? [
                                  BoxShadow(
                                    color: color.withOpacity(0.5),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ] : [
                                  BoxShadow(
                                    color: color.withOpacity(0.3),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: (isFirst || isLast)
                                  ? Icon(
                                      isFirst ? Icons.play_arrow : Icons.flag,
                                      color: Colors.white,
                                      size: 14,
                                    )
                                  : Center(
                                      child: busPassedHere
                                        ? const Icon(Icons.check, color: Colors.white, size: 14)
                                        : Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: color,
                                            ),
                                          ),
                                    ),
                            ),
                          // Línea inferior
                          Expanded(
                            child: Container(
                              width: 4,
                              color: isLast ? Colors.transparent : (busPassedHere && !isBusHere ? color : color.withOpacity(0.3)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Información de la parada
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (widget.onStopTapped != null) {
                            final busStop = BusStop(
                              id: stop['id'] ?? 0,
                              name: stop['name'] ?? 'Sin nombre',
                              lat: stop['lat'] ?? 0.0,
                              lng: stop['lng'] ?? 0.0,
                              lines: [lineId],
                            );
                            widget.onStopTapped!(busStop);
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isBusHere 
                                ? color.withOpacity(0.15)
                                : isBusApproaching
                                    ? color.withOpacity(0.08)
                                    : (isFirst || isLast) 
                                        ? color.withOpacity(0.1) 
                                        : Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isBusHere 
                                  ? color
                                  : isBusApproaching
                                      ? color.withOpacity(0.5)
                                      : (isFirst || isLast) 
                                          ? color.withOpacity(0.3) 
                                          : Colors.grey[200]!,
                              width: isBusHere ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (isBusHere)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.directions_bus, color: Colors.white, size: 12),
                                          SizedBox(width: 4),
                                          Text(
                                            'BUS AQUÍ',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (isBusApproaching)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.orange,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.arrow_forward, color: Colors.white, size: 12),
                                          SizedBox(width: 4),
                                          Text(
                                            'PRÓXIMA',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (isFirst && !isBusHere && !isBusApproaching)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'INICIO',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  if (isLast && !isBusHere && !isBusApproaching)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'FIN',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(
                                      stop['name'] ?? 'Sin nombre',
                                      style: TextStyle(
                                        fontWeight: (isFirst || isLast || isBusHere || isBusApproaching) 
                                            ? FontWeight.bold 
                                            : FontWeight.w500,
                                        fontSize: (isFirst || isLast || isBusHere) ? 16 : 14,
                                        color: isBusHere ? color : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'Parada #${stop['id']}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (busPassedHere && !isBusHere) ...[
                                    const SizedBox(width: 8),
                                    Icon(Icons.check_circle, color: color, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Pasado',
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                  const Spacer(),
                                  Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey[400],
                                    size: 20,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
