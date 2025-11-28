import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import 'models/bus_stop.dart';
import 'services/foreground_service.dart';
import 'services/stops_service.dart';
import 'services/bus_alert_service.dart';
import 'services/trip_history_service.dart';
import 'pages/splash_page.dart';
import 'pages/map_page.dart';
import 'pages/nfc_page.dart';
import 'pages/settings_page.dart';
import 'pages/routes_page.dart';
import 'screens/trip_history_screen.dart';
import 'screens/active_alerts_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar foreground service
  await ForegroundService.initialize();
  
  // Inicializar servicio de alertas de bus
  await BusAlertService().initialize();
  
  // Auto-confirmar viajes pendientes expirados
  final prefs = await SharedPreferences.getInstance();
  final historyService = TripHistoryService(prefs);
  await historyService.autoConfirmIfExpired();
  
  // Cargar y guardar paradas para el servicio de fondo
  final stopsService = StopsService();
  final stops = await stopsService.loadStops();
  final stopsData = stops.map((stop) => {
    'name': stop.name,
    'lat': stop.lat,
    'lng': stop.lng,
    'lines': stop.lines,
  }).toList();
  
  // Guardar paradas en preferences para el foreground service (en JSON)
  await prefs.setString('bus_stops', jsonEncode(stopsData));
  
  // Solicitar permisos necesarios
  await _requestPermissions();
  
  // Iniciar foreground service si las notificaciones están habilitadas
  final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
  if (notificationsEnabled) {
    await ForegroundService.start();
  }
  
  runApp(const AlzibusApp());
}

/// Solicita todos los permisos necesarios para el foreground service
Future<void> _requestPermissions() async {
  // 1. Permiso de notificaciones (Android 13+)
  await Permission.notification.request();
  
  // 2. Permiso de ubicación (primero foreground)
  final locationStatus = await Permission.location.request();
  
  if (locationStatus.isGranted) {
    // 3. Permiso de ubicación en segundo plano (CRÍTICO para foreground service)
    // Android requiere que primero tengas el permiso de ubicación normal
    final bgStatus = await Permission.locationAlways.request();
    
    if (!bgStatus.isGranted) {
      print('⚠️ Permiso de ubicación en segundo plano denegado');
    }
  }
}

// Handler para notificaciones en segundo plano (debe ser top-level)
@pragma('vm:entry-point')
void _onBackgroundNotificationResponse(NotificationResponse response) async {
  final action = response.actionId;
  if (action == null) return;
  
  final prefs = await SharedPreferences.getInstance();
  final historyService = TripHistoryService(prefs);
  
  if (action == 'confirm_trip') {
    await historyService.confirmTrip();
  } else if (action == 'reject_trip') {
    await historyService.rejectTrip();
  }
}

class AlzibusApp extends StatelessWidget {
  const AlzibusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alzibus',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SplashPage(),
      routes: {
        '/home': (context) => const HomePage(),
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _index = 0;
  final FlutterLocalNotificationsPlugin _notif = FlutterLocalNotificationsPlugin();
  bool _notificationsEnabled = true;
  double _notificationDistance = 80.0;
  int _notificationCooldown = 5;
  
  // Para navegar a una parada desde Rutas
  final GlobalKey<MapPageState> _mapPageKey = GlobalKey<MapPageState>();

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _notificationDistance = prefs.getDouble('notification_distance') ?? 80.0;
      _notificationCooldown = prefs.getInt('notification_cooldown') ?? 5;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setDouble('notification_distance', _notificationDistance);
    await prefs.setInt('notification_cooldown', _notificationCooldown);
  }

  Future<void> _initNotifications() async {
    const android = AndroidInitializationSettings('@drawable/ic_launcher_foreground');
    const initSettings = InitializationSettings(android: android);
    await _notif.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationResponse,
    );
    
    // Verificar si hay viaje pendiente al iniciar
    _checkPendingTrip();
  }
  
  Future<void> _checkPendingTrip() async {
    final prefs = await SharedPreferences.getInstance();
    final historyService = TripHistoryService(prefs);
    final pending = historyService.getPendingTrip();
    
    if (pending != null) {
      // Hay un viaje pendiente, mostrar diálogo después de que se construya el widget
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showTripConfirmDialog(pending);
      });
    }
  }
  
  void _showTripConfirmDialog(Map<String, dynamic> trip) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('🚌 ¿Cogiste el bus?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Línea ${trip['line']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 4),
            Text('${trip['stopName']} → ${trip['destination']}'),
            const SizedBox(height: 12),
            Text(
              'Esto nos ayuda a llevar un historial de tus viajes.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = await SharedPreferences.getInstance();
              final historyService = TripHistoryService(prefs);
              await historyService.rejectTrip();
            },
            child: const Text('❌ No lo cogí'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = await SharedPreferences.getInstance();
              final historyService = TripHistoryService(prefs);
              await historyService.confirmTrip();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Viaje registrado en el historial'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('✅ Sí, lo cogí'),
          ),
        ],
      ),
    );
  }
  
  void _onNotificationResponse(NotificationResponse response) async {
    final payload = response.payload;
    
    // Si tocó la notificación de "bus llegando", mostrar diálogo
    if (payload == 'trip_confirm') {
      final prefs = await SharedPreferences.getInstance();
      final historyService = TripHistoryService(prefs);
      final pending = historyService.getPendingTrip();
      
      if (pending != null) {
        // Esperar a que el contexto esté disponible
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showTripConfirmDialog(pending);
        });
      }
      return;
    }
    
    // Para acciones de botones (si las hubiera)
    final action = response.actionId;
    if (action == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final historyService = TripHistoryService(prefs);
    
    if (action == 'confirm_trip') {
      await historyService.confirmTrip();
    } else if (action == 'reject_trip') {
      await historyService.rejectTrip();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      MapPage(
        key: _mapPageKey,
        notif: _notif,
        notificationsEnabled: _notificationsEnabled,
        notificationDistance: _notificationDistance,
        notificationCooldown: _notificationCooldown,
      ),
      RoutesPage(
        onStopTapped: (stop) {
          // Cambiar a la pestaña del mapa
          setState(() => _index = 0);
          // Ir a la parada
          Future.delayed(const Duration(milliseconds: 100), () {
            _mapPageKey.currentState?.goToStop(stop);
          });
        },
      ),
      const NfcPage(),
      SettingsPage(
        notificationsEnabled: _notificationsEnabled,
        notificationDistance: _notificationDistance,
        notificationCooldown: _notificationCooldown,
        onNotificationsChanged: (value) async {
          setState(() => _notificationsEnabled = value);
          await _savePreferences();
          
          // Iniciar o detener foreground service
          if (value) {
            await ForegroundService.start();
          } else {
            await ForegroundService.stop();
          }
        },
        onDistanceChanged: (value) {
          setState(() => _notificationDistance = value);
          _savePreferences();
        },
        onCooldownChanged: (value) {
          setState(() => _notificationCooldown = value);
          _savePreferences();
        },
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alzibus — Alzira'),
        actions: [
          // Alertas activas
          IconButton(
            icon: const Icon(Icons.notifications_active),
            tooltip: 'Alertas activas',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ActiveAlertsScreen(
                    onViewStop: (stopId, stopName) {
                      // Cambiar al mapa
                      setState(() => _index = 0);
                      // TODO: centrar en la parada
                    },
                  ),
                ),
              );
            },
          ),
          // Historial de viajes
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Historial de viajes',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TripHistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: pages[_index],
      bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'),
            BottomNavigationBarItem(icon: Icon(Icons.route), label: 'Rutas'),
            BottomNavigationBarItem(icon: Icon(Icons.nfc), label: 'NFC'),
            BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Ajustes'),
          ],
          onTap: (i) => setState(() => _index = i)),
    );
  }
}
