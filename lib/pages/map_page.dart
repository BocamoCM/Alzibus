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
import '../widgets/line_filter.dart';
import '../widgets/stop_info_sheet.dart';

class MapPage extends StatefulWidget {
  final FlutterLocalNotificationsPlugin notif;
  final bool notificationsEnabled;
  final double notificationDistance;
  final int notificationCooldown;

  const MapPage({
    super.key,
    required this.notif,
    required this.notificationsEnabled,
    required this.notificationDistance,
    required this.notificationCooldown,
  });

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  List<BusStop> stops = [];
  Set<String> selectedLines = {'L1', 'L2', 'L3'};
  LatLng center = LatLng(39.1566, -0.4354);
  LatLng? myLocation;
  double? myHeading = 0.0;
  
  final Distance distance = Distance();
  final Map<String, DateTime> _lastNotified = {};
  
  late final NotificationService _notificationService;
  late final LocationService _locationService;
  late final StopsService _stopsService;

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService(widget.notif);
    _stopsService = StopsService();
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
  }

  @override
  void dispose() {
    _locationService.stopTracking();
    super.dispose();
  }

  Future<void> _loadStops() async {
    final loadedStops = await _stopsService.loadStops();
    setState(() => stops = loadedStops);
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
            child: const Icon(Icons.navigation, color: Colors.blue, size: 40),
          ),
        ),
      );
    }

    return Stack(
      children: [
        FlutterMap(
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
                    color: Colors.blue.withOpacity(0.15),
                    borderColor: Colors.blue.withOpacity(0.7),
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            MarkerLayer(markers: markers),
          ],
        ),
        Positioned(
          top: 16,
          right: 16,
          child: LineFilter(
            selectedLines: selectedLines,
            onLineToggle: _toggleLine,
          ),
        ),
      ],
    );
  }
}
