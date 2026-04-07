import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/bus_stop.dart';
import '../core/utils/ar_math_utils.dart';
import '../theme/app_theme.dart';

class ArVisionPage extends StatefulWidget {
  final List<BusStop> nearbyStops;
  final String? targetStopId; // Nueva propiedad
  
  const ArVisionPage({
    super.key, 
    required this.nearbyStops, 
    this.targetStopId,
  });

  @override
  State<ArVisionPage> createState() => _ArVisionPageState();
}

class _ArVisionPageState extends State<ArVisionPage> {
  CameraController? _cameraController;
  StreamSubscription? _compassSubscription;
  double _heading = 0;
  double _pitch = 0; // Para la inclinación arriba/abajo
  Position? _currentPosition;
  bool _initialized = false;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _initAr();
  }

  Future<void> _initAr() async {
    final cameraStatus = await Permission.camera.request();
    final locationStatus = await Permission.location.request();

    if (cameraStatus.isGranted && locationStatus.isGranted) {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      _currentPosition = await Geolocator.getCurrentPosition();
      
      _compassSubscription = FlutterCompass.events?.listen((event) {
        if (mounted) {
          setState(() {
            _heading = event.heading ?? 0;
            // Estimar inclinación (Pitch) desde los datos del sensor si están disponibles
            // Algunos dispositivos devuelven esto en el compass event o usaremos un valor base
            _pitch = (event.accuracy ?? 0) > 0 ? 0 : 0; 
          });
        }
      });

      if (mounted) {
        setState(() {
          _hasPermission = true;
          _initialized = true;
        });
      }
    } else {
      if (mounted) setState(() => _hasPermission = false);
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _compassSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPermission) {
      return Scaffold(
        appBar: AppBar(title: const Text('Visión Alzitrans')),
        body: const Center(child: Text('Se necesitan permisos de cámara y ubicación para el AR.')),
      );
    }

    if (!_initialized || _cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          // Feed de Cámara
          Positioned.fill(
            child: AspectRatio(
              aspectRatio: _cameraController!.value.aspectRatio,
              child: CameraPreview(_cameraController!),
            ),
          ),
          
          // Overlay de Paradas
          ..._buildArMarkers(),

          // UI de Control
          Positioned(
            top: 40,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Gira el móvil para localizar las paradas',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildArMarkers() {
    if (_currentPosition == null) return [];
    
    final userLoc = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    final screenWidth = MediaQuery.of(context).size.width;
    final List<Widget> markers = [];

    // Filtrar paradas: Si hay una seleccionada, solo esa. Si no, las cercanas.
    final List<BusStop> stopsToRender = widget.targetStopId != null
        ? widget.nearbyStops.where((s) => s.id.toString() == widget.targetStopId).toList()
        : widget.nearbyStops;

    for (var stop in stopsToRender) {
      final stopLoc = LatLng(stop.lat, stop.lng);
      final azimuth = ArMathUtils.calculateBearing(userLoc, stopLoc);
      final distance = ArMathUtils.calculateDistance(userLoc, stopLoc);
      
      // Si no es el objetivo, limitar a 2km para evitar caos
      if (widget.targetStopId == null && distance > 2000) continue;
      // Si es el objetivo, mostrar hasta 15km
      if (widget.targetStopId != null && distance > 15000) continue;

      final xOffset = ArMathUtils.getXOffset(azimuth, _heading, screenWidth);
      
      if (xOffset != null) {
        // Ajustar escala y posición vertical según distancia (límite 10km)
        final scale = (1.0 - (distance / 12000)).clamp(0.2, 1.0);
        final yOffset = 100.0 + (distance / 50); // Menos sensible a la altura para largas distancias

        markers.add(
          Positioned(
            left: xOffset - 60,
            top: yOffset,
            child: Transform.scale(
              scale: scale,
              child: _ArMarkerWidget(stop: stop, distance: distance),
            ),
          ),
        );
      }
    }
    return markers;
  }
}

class _ArMarkerWidget extends StatelessWidget {
  final BusStop stop;
  final double distance;
  const _ArMarkerWidget({required this.stop, required this.distance});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AlzitransColors.burgundy.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
          ),
          child: Column(
            children: [
              Text(
                stop.name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              Text(
                '${distance.toStringAsFixed(0)}m',
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ),
        const Icon(Icons.arrow_drop_down, color: Colors.white, size: 30),
      ],
    );
  }
}
