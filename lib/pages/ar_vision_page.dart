import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:math' as math;
import '../models/bus_stop.dart';
import '../core/utils/ar_math_utils.dart';
import '../theme/app_theme.dart';

class ArVisionPage extends StatefulWidget {
  final List<BusStop> nearbyStops;
  final String? targetStopId; // Si no es null, solo muestra la flecha a esta parada
  final LatLng? initialUserLocation; // Posición ya calculada por el mapa para evitar colapso de GPS
  
  const ArVisionPage({
    super.key, 
    required this.nearbyStops, 
    this.targetStopId,
    this.initialUserLocation,
  });

  @override
  State<ArVisionPage> createState() => _ArVisionPageState();
}

class _ArVisionPageState extends State<ArVisionPage> {
  CameraController? _cameraController;
  StreamSubscription? _compassSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<Position>? _locationSubscription;
  
  // Variables para la dirección y su suavizado EMA
  bool _headingInitialized = false;
  double _headingSin = 0;
  double _headingCos = 0;
  
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

      // Obtener posición inicial rápido para pintar las paradas sin esperar al stream
      if (widget.initialUserLocation != null) {
        _currentPosition = Position(
          longitude: widget.initialUserLocation!.longitude,
          latitude: widget.initialUserLocation!.latitude,
          timestamp: DateTime.now(),
          accuracy: 5,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      } else {
        _currentPosition = await Geolocator.getLastKnownPosition() ?? await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        );
      }

      // Usar Stream para que la precisión GPS mejore continuamente y no se quede colgada
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 1),
      ).listen((Position position) {
        if (mounted) setState(() => _currentPosition = position);
      });
      
      _compassSubscription = FlutterCompass.events?.listen((event) {
        if (mounted) {
          setState(() {
            double h = event.headingForCameraMode ?? event.heading ?? 0.0;
            // Workaround: Algunos Android devuelven exactamente 0.0 si el modo cámara no está soportado.
            if (event.headingForCameraMode == 0.0 && event.heading != null && event.heading != 0.0) {
              h = event.heading!;
            }
            
            // Suavizado EMA utilizando Seno y Coseno para evitar el temblor y el error de salto 360 -> 0
            final rad = h * math.pi / 180;
            if (!_headingInitialized) {
              _headingSin = math.sin(rad);
              _headingCos = math.cos(rad);
              _headingInitialized = true;
            } else {
              const alpha = 0.15; // Ajuste para solidez vs respuesta rápida
              _headingSin = _headingSin * (1 - alpha) + math.sin(rad) * alpha;
              _headingCos = _headingCos * (1 - alpha) + math.cos(rad) * alpha;
            }
            
            h = math.atan2(_headingSin, _headingCos) * 180 / math.pi;
            if (h < 0) h += 360;
            
            _heading = h;
          });
        }
      });
      
      _accelerometerSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
        if (mounted) {
          setState(() {
            // Calcula pitch en grados. 0 = vertical, -90 = mirando al cielo, +90 = mirando al suelo
            final rawPitch = math.atan2(event.z, event.y) * 180 / math.pi; 
            // Aplicar un filtro de paso bajo (Exponential Moving Average) para suavizar el temblor
            // 0.1 significa que toma 10% del nuevo valor y 90% del valor anterior
            final alpha = 0.10;
            _pitch = _pitch == 0 ? rawPitch : (_pitch * (1 - alpha) + rawPitch * alpha);
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
    _accelerometerSubscription?.cancel();
    _locationSubscription?.cancel();
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
    int markersRendered = 0;
    
    // UI de Debug para saber qué está fallando (lo quitaremos luego)
    final debugWidget = Positioned(
      top: 100,
      left: 10,
      child: Container(
        padding: const EdgeInsets.all(8),
        color: Colors.black87,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GPS: ${_currentPosition?.latitude ?? "N/A"}, ${_currentPosition?.longitude ?? "N/A"}', style: const TextStyle(color: Colors.greenAccent, fontSize: 10)),
            Text('Heading: ${_heading.toStringAsFixed(1)}', style: const TextStyle(color: Colors.amber, fontSize: 10)),
            Text('Pitch: ${_pitch.toStringAsFixed(1)}', style: const TextStyle(color: Colors.orange, fontSize: 10)),
          ],
        ),
      ),
    );

    if (_currentPosition == null) return [debugWidget];
    
    final userLoc = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    final screenWidth = MediaQuery.of(context).size.width;
    final List<Widget> markers = [debugWidget];

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
        // Ajustar escala según distancia
        final scale = (1.0 - (distance / 12000)).clamp(0.2, 1.0);
        
        // Compensación de pitch (inclinación de cámara)
        final screenHeight = MediaQuery.of(context).size.height;
        // Asumiendo un FOV vertical de aprox 60 grados para la cámara estándar
        // Si pitch es negativo (mirando cielo), la parada debe pintar MÁS ABAJO (+yOffset)
        final dy = -_pitch * (screenHeight / 60.0);
        
        // Base: si mantienes móvil recto, a 0 pitch, está aprox. en el tercio inferior/medio del FOV
        final horizonBase = (screenHeight / 2) - 50; 
        
        // Lejos = ligeramente más alto en perspectiva, Cerca = más bajo
        final distanceHeightOffset = (distance / 40); 

        // Offset final en pantalla
        final yOffset = horizonBase + dy + distanceHeightOffset;

        markers.add(
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
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
