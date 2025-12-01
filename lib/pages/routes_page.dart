import 'package:flutter/material.dart';
import '../services/stops_service.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRoutes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: stops.length,
      itemBuilder: (context, index) {
        final stop = stops[index];
        final isFirst = index == 0;
        final isLast = index == stops.length - 1;

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
                        color: isFirst ? Colors.transparent : color,
                      ),
                    ),
                    // Círculo del punto
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: (isFirst || isLast) ? color : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 3),
                        boxShadow: [
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
                              child: Text(
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
                        color: isLast ? Colors.transparent : color,
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
                      // Crear un BusStop desde los datos del mapa
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
                      color: (isFirst || isLast) 
                          ? color.withOpacity(0.1) 
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (isFirst || isLast) 
                            ? color.withOpacity(0.3) 
                            : Colors.grey[200]!,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Row(
                        children: [
                          if (isFirst)
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
                          if (isLast)
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
                                fontWeight: (isFirst || isLast) 
                                    ? FontWeight.bold 
                                    : FontWeight.w500,
                                fontSize: (isFirst || isLast) ? 16 : 14,
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
    );
  }
}
