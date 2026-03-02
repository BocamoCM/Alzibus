import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import '../models/bus_stop.dart';
import '../constants/line_colors.dart';
import '../services/bus_times_service.dart';
import '../services/bus_alert_service.dart';
import '../services/foreground_service.dart';
import '../services/favorite_stops_service.dart';
import '../services/renfe_service.dart';
import 'package:alzitrans/l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/tts_service.dart';
import 'simple_map_widget.dart';

class StopInfoSheet extends StatefulWidget {
  final BusStop stop;
  final LatLng? userLocation;

  const StopInfoSheet({
    super.key,
    required this.stop,
    this.userLocation,
  });

  @override
  State<StopInfoSheet> createState() => _StopInfoSheetState();
}

class _StopInfoSheetState extends State<StopInfoSheet> {
  final BusTimesService _busTimesService = BusTimesService();
  final BusAlertService _alertService = BusAlertService();
  List<BusArrival>? _arrivals;
  bool _loading = true;
  bool _showStreetView = false;
  Timer? _autoRefreshTimer;
  final Set<String> _activeAlerts = {};
  bool _isFavorite = false;
  
  // Estado para trenes de Renfe (solo para estación Renfe)
  List<TrainArrival>? _trainArrivals;
  bool _loadingTrains = false;
  
  /// Verifica si esta parada es la estación de Renfe
  bool get _isRenfeStation {
    final name = widget.stop.name.toUpperCase();
    return name.contains('RENFE') || name.contains('ESTACIÓ') || name.contains('ESTACION');
  }

  @override
  void initState() {
    super.initState();
    _loadArrivalTimes(shouldSpeak: true);
    _startAutoRefresh();
    _checkFavorite();
    if (_isRenfeStation) {
      _loadTrainTimes();
    }
  }
  
  Future<void> _loadTrainTimes() async {
    if (!mounted) return;
    setState(() => _loadingTrains = true);
    try {
      final trains = await RenfeService.getNextTrains(limit: 6);
      if (mounted) {
        setState(() {
          _trainArrivals = trains;
          _loadingTrains = false;
        });
      }
    } catch (e) {
      print('[StopInfoSheet] Error loading trains: $e');
      if (mounted) {
        setState(() => _loadingTrains = false);
      }
    }
  }

  Future<void> _checkFavorite() async {
    final isFav = await FavoriteStopsService.isFavorite(widget.stop.id);
    if (mounted) {
      setState(() => _isFavorite = isFav);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isFavorite) {
      await FavoriteStopsService.removeFavorite(widget.stop.id);
      if (mounted) {
        setState(() => _isFavorite = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parada eliminada de favoritos'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      final favorite = FavoriteStop(
        stopId: widget.stop.id,
        stopName: widget.stop.name,
        lat: widget.stop.lat,
        lng: widget.stop.lng,
        lines: widget.stop.lines,
      );
      await FavoriteStopsService.addFavorite(favorite);
      if (mounted) {
        setState(() => _isFavorite = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⭐ Parada añadida a favoritos'),
            backgroundColor: Colors.amber,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadArrivalTimes(shouldSpeak: false);
      }
    });
  }

  // Convertir coordenadas a tiles de Google Maps
  int _lng2tile(double lng, int zoom) {
    return ((lng + 180) / 360 * (1 << zoom)).floor();
  }

  int _lat2tile(double lat, int zoom) {
    final latRad = lat * math.pi / 180;
    return ((1 - math.log(math.tan(latRad) + (1 / math.cos(latRad))) / math.pi) / 2 * (1 << zoom)).floor();
  }

  Future<void> _loadArrivalTimes({bool shouldSpeak = false}) async {
    if (!mounted) return;
    setState(() => _loading = true);
    
    final arrivals = await _busTimesService.getArrivalTimes(widget.stop.id);
    
    if (!mounted) return;
    
    // Actualizar estado de alertas activas (solo las que realmente existen)
    final currentActiveAlerts = <String>{};
    for (final arrival in arrivals) {
      final key = '${widget.stop.id}_${arrival.line}_${arrival.destination}';
      if (_alertService.hasAlert(widget.stop.id, arrival.line, arrival.destination)) {
        currentActiveAlerts.add(key);
      }
    }
    
    setState(() {
      _activeAlerts.clear();
      _activeAlerts.addAll(currentActiveAlerts);
      _arrivals = arrivals;
      _loading = false;
    });
    
    // Anunciar por voz la parada y buses si hay datos (solo la primera vez)
    if (mounted && shouldSpeak) {
      final l = AppLocalizations.of(context)!;
      final tts = TtsService();
      
      // Anunciar nombre de la parada (primera locución)
      tts.speak(l.stopAnnounce(widget.stop.name));
      
      if (arrivals.isEmpty) {
        // Sin buses: esperar a que termine el nombre de la parada y luego anunciar
        tts.speakQueued('No hay buses disponibles en este momento en esta parada.');
      } else {
        // Anunciar primer bus después del nombre de la parada (queued)
        final first = arrivals.first;
        if (first.time.contains('<<<') || first.time.toLowerCase().contains('llegando')) {
          tts.speakQueued(l.busArrivingAnnounce(first.line, first.destination, widget.stop.name));
        } else {
          final minMatch = RegExp(r'(\d+)').firstMatch(first.time);
          if (minMatch != null) {
            final mins = int.tryParse(minMatch.group(1)!) ?? 0;
            tts.speakQueued(l.busArrivalAnnounce(first.line, first.destination, widget.stop.name, mins));
          }
        }
      }
    }
  }

  Future<void> _setAlert(BusArrival arrival) async {
    final alert = BusAlert(
      stopId: widget.stop.id,
      stopName: widget.stop.name,
      line: arrival.line,
      destination: arrival.destination,
      createdAt: DateTime.now(),
    );
    
    await _alertService.addAlert(alert);
    
    if (!mounted) return;
    
    setState(() {
      _activeAlerts.add(alert.key);
    });
    
    // Asegurar que el ForegroundService está corriendo
    final isRunning = await ForegroundService.isRunning();
    if (!isRunning) {
      await ForegroundService.start();
    }
    
    // Chequear inmediatamente
    await ForegroundService.checkAlertsNow();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Te avisaremos cuando llegue la línea ${arrival.line}'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _cancelAlert(String alertKey) async {
    await _alertService.removeAlert(alertKey);
    
    if (!mounted) return;
    
    setState(() {
      _activeAlerts.remove(alertKey);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Alerta cancelada'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openInGoogleMaps() async {
    try {
      const platform = MethodChannel('com.alzitrans.app/maps');
      await platform.invokeMethod('openMaps', {
        'latitude': widget.stop.lat,
        'longitude': widget.stop.lng,
      });
    } catch (e) {
      print('Error abriendo Google Maps: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    const distance = Distance();
    
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Mapa visual / Street View de la parada
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                  ),
                  child: _showStreetView
                    ? Stack(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 200,
                            child: Image.network(
                              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/18/${_lat2tile(widget.stop.lat, 18)}/${_lng2tile(widget.stop.lng, 18)}',
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: Colors.grey[100],
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                              : null,
                                        ),
                                        const SizedBox(height: 8),
                                        const Text('Cargando vista satelital...', style: TextStyle(color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.satellite_alt, size: 48, color: Colors.grey),
                                        SizedBox(height: 8),
                                        Text('Vista satelital no disponible', style: TextStyle(color: Colors.grey)),
                                        SizedBox(height: 4),
                                        Text('(Requiere conexión a internet)', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          // Marcador en el centro
                          const Center(
                            child: Icon(
                              Icons.location_on,
                              size: 40,
                              color: Colors.red,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : SimpleMapWidget(
                        latitude: widget.stop.lat,
                        longitude: widget.stop.lng,
                        width: double.infinity,
                        height: 200,
                      ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  elevation: 4,
                  child: InkWell(
                    onTap: () {
                      setState(() => _showStreetView = !_showStreetView);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showStreetView ? Icons.map : Icons.streetview,
                            size: 20,
                            color: AlzitransColors.burgundy,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _showStreetView ? 'Mapa' : 'Satélite',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AlzitransColors.burgundy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.directions_bus,
                color: LineColors.getStopColor(widget.stop.lines, widget.stop.lines.toSet()),
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.stop.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: Icon(
                  _isFavorite ? Icons.star : Icons.star_border,
                  color: _isFavorite ? Colors.amber : Colors.grey,
                  size: 28,
                ),
                onPressed: _toggleFavorite,
                tooltip: _isFavorite ? 'Quitar de favoritos' : 'Añadir a favoritos',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Tiempos de llegada en tiempo real
          Row(
            children: [
              const Text('⏱️ Próximos buses:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _loadArrivalTimes,
                tooltip: 'Actualizar',
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_arrivals == null || _arrivals!.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No hay buses próximos',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._arrivals!.map((arrival) {
              final alertKey = '${widget.stop.id}_${arrival.line}_${arrival.destination}';
              final hasAlert = _activeAlerts.contains(alertKey);
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                color: hasAlert ? Colors.orange[50] : AlzitransColors.burgundy.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: hasAlert ? Colors.orange[300]! : AlzitransColors.burgundy.withOpacity(0.3), 
                    width: 1
                ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: LineColors.getColor(arrival.line),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            arrival.line,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            arrival.destination,
                            style: const TextStyle(fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 80),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              arrival.time,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AlzitransColors.burgundy,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!hasAlert) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _setAlert(arrival),
                          icon: const Icon(Icons.notifications_active, size: 18),
                          label: const Text(
                            'Avisar cuando llegue',
                            style: TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            foregroundColor: Colors.orange[700],
                            side: BorderSide(color: Colors.orange[300]!),
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.notifications_active, size: 16, color: Colors.orange),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Te avisaremos cuando llegue',
                              style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w500),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _cancelAlert(alertKey),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: const Size(0, 28),
                            ),
                            child: const Text('Cancelar', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),
          
          // Sección de trenes (solo para estación Renfe)
          if (_isRenfeStation) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF79529), // Color naranja de la línea C2
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.train, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '🚆 Trenes Cercanías C2:', 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _loadTrainTimes,
                  tooltip: 'Actualizar trenes',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loadingTrains)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(color: Color(0xFFF79529)),
                ),
              )
            else if (_trainArrivals == null || _trainArrivals!.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No hay trenes próximos',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._trainArrivals!.map((train) {
                final minutesUntil = RenfeService.minutesUntilArrival(train.scheduledTime, train.delayMinutes);
                final bool isDelayed = train.delayMinutes > 0;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDelayed ? Colors.red[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDelayed ? Colors.red[300]! : Colors.orange[200]!, 
                      width: 1
                    ),
                  ),
                  child: Row(
                    children: [
                      // Badge C2
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF79529),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'C2',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Destino
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              train.destination,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  train.scheduledTime,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDelayed ? Colors.grey : Colors.grey[700],
                                    decoration: isDelayed ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                if (isDelayed) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    train.actualTime,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Tiempo restante
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 80),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                minutesUntil <= 0 ? 'Llegando' : '$minutesUntil min',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: minutesUntil <= 5 ? Colors.red : const Color(0xFFF79529),
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (isDelayed)
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '+${train.delayMinutes} min',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.red,
                                  ),
                                ),
                              )
                            else
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  train.statusText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
          
          const SizedBox(height: 16),
          const Text('Líneas:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: widget.stop.lines.map((line) {
              return Chip(
                label: Text(line, style: const TextStyle(color: Colors.white)),
                backgroundColor: LineColors.getColor(line),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text('Coordenadas: ${widget.stop.lat.toStringAsFixed(5)}, ${widget.stop.lng.toStringAsFixed(5)}'),
          if (widget.userLocation != null) ...[
            const SizedBox(height: 8),
            Text(
              'Distancia: ${distance(widget.userLocation!, LatLng(widget.stop.lat, widget.stop.lng)).toStringAsFixed(0)}m',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AlzitransColors.burgundy),
            ),
          ],
          const SizedBox(height: 12),
          // Botón para ver en Google Maps
          OutlinedButton.icon(
            onPressed: _openInGoogleMaps,
            icon: const Icon(Icons.map),
            label: const Text('Ver en Google Maps'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
