import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import 'package:vibration/vibration.dart';
import '../core/network/api_client.dart';
import '../core/repositories/scraping_repository.dart';
import 'package:home_widget/home_widget.dart';

// Callbacks top-level para el background service
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  
  final FlutterLocalNotificationsPlugin notif = FlutterLocalNotificationsPlugin();
  
  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@drawable/ic_launcher_foreground'),
  );
  await notif.initialize(initSettings);
  
  // Crear canal de alertas con alta prioridad
  final androidPlugin = notif.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  const alertsChannel = AndroidNotificationChannel(
    'alzibus_alerts',
    'Alertas de Bus',
    description: 'Te avisa cuando tu bus está llegando',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );
  await androidPlugin?.createNotificationChannel(alertsChannel);
  
  // Escuchar comandos desde la app
  service.on('stop').listen((event) {
    service.stopSelf();
  });
  
  // Timer principal - cada 30 segundos
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    await _checkLocationStatic(service, notif);
  });
  
  // Primera verificación inmediata
  await _checkLocationStatic(service, notif);
}

Future<void> _checkLocationStatic(
  ServiceInstance service,
  FlutterLocalNotificationsPlugin notif,
) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // IMPORTANTE: Recargar SharedPreferences para sincronizar con el isolate principal
    await prefs.reload();
    
    // Log para depuración
    final now = DateTime.now();
    await prefs.setString('last_foreground_check', now.toIso8601String());
    
    // SIEMPRE verificar alertas de bus
    await _checkBusAlertsStatic(prefs, notif);
    
    // Actualizar widget de Android con parada favorita
    await _updateWidgetStatic(prefs);
    
    // Verificar si las notificaciones de PROXIMIDAD están habilitadas
    final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    
    // NO actualizar la notificación del foreground service para evitar molestar
    // El servicio funciona silenciosamente en segundo plano
    
    if (!notificationsEnabled) return;
    
    // Obtener configuración para notificaciones de proximidad
    final distance = prefs.getDouble('notification_distance') ?? 100.0;
    final cooldown = prefs.getInt('notification_cooldown') ?? 5;
    
    // Obtener ubicación actual (con timeout más largo y fallback)
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );
    } catch (e) {
      // Intentar obtener última ubicación conocida
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {}
      
      if (position == null) {
        print('No se pudo obtener ubicación: $e');
        return; // No podemos verificar proximidad sin ubicación
      }
    }
    
    // Cargar paradas
    final stopsJson = prefs.getString('bus_stops');
    if (stopsJson == null) return;
    
    final List<dynamic> stopsData = jsonDecode(stopsJson);
    final Distance distanceCalculator = Distance();
    
    // Verificar proximidad a cada parada
    for (var stopData in stopsData) {
      final stopLat = stopData['lat'];
      final stopLng = stopData['lng'];
      final stopName = stopData['name'];
      final List<String> lines = List<String>.from(stopData['lines']);
      
      final stopLocation = LatLng(stopLat, stopLng);
      final userLocation = LatLng(position.latitude, position.longitude);
      
      final distanceToStop = distanceCalculator.as(
        LengthUnit.Meter,
        userLocation,
        stopLocation,
      );
      
      if (distanceToStop <= distance) {
        // Verificar cooldown
        final lastNotified = prefs.getInt('last_notified_$stopName') ?? 0;
        final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final cooldownSeconds = cooldown * 60;
        
        if (nowSeconds - lastNotified >= cooldownSeconds) {
          await _showProximityNotificationStatic(notif, stopName, lines, distanceToStop);
          await prefs.setInt('last_notified_$stopName', nowSeconds);
        }
      }
    }
  } catch (e) {
    print('Error en foreground service: $e');
  }
}

Future<void> _showProximityNotificationStatic(
  FlutterLocalNotificationsPlugin notif,
  String stopName,
  List<String> lines,
  double distance,
) async {
  // Vibrar
  if (await Vibration.hasVibrator()) {
    Vibration.vibrate(pattern: [0, 200, 100, 200]);
  }
  
  final androidDetails = AndroidNotificationDetails(
    'alzibus_alerts',
    'Alertas de paradas',
    channelDescription: 'Notificaciones cuando estás cerca de una parada',
    importance: Importance.high,
    priority: Priority.high,
    ticker: 'Parada cercana',
    icon: '@drawable/ic_launcher_foreground',
    color: const Color(0xFF4A1D3D),
    styleInformation: BigTextStyleInformation(
      '📍 $stopName\n🚌 Líneas: ${lines.join(", ")}\n📏 A ${distance.round()}m',
      contentTitle: '🚏 Parada cercana',
    ),
  );
  
  await notif.show(
    stopName.hashCode,
    '🚏 Parada cercana',
    '$stopName - ${lines.join(", ")}',
    NotificationDetails(android: androidDetails),
  );
}

Future<void> _checkBusAlertsStatic(
  SharedPreferences prefs,
  FlutterLocalNotificationsPlugin notif,
) async {
  try {
    // IMPORTANTE: Recargar SharedPreferences para obtener datos actualizados
    // desde el isolate principal
    await prefs.reload();
    
    final alertsJson = prefs.getString('bus_alerts');
    print('[ForegroundService] Checking bus alerts. Data: ${alertsJson?.substring(0, alertsJson.length > 100 ? 100 : alertsJson.length) ?? "null"}');
    
    if (alertsJson == null || alertsJson.isEmpty) {
      print('[ForegroundService] No alerts found');
      return;
    }
    
    final List<dynamic> alerts = jsonDecode(alertsJson);
    if (alerts.isEmpty) {
      print('[ForegroundService] Alerts list is empty');
      return;
    }
    
    print('[ForegroundService] Found ${alerts.length} alerts');
    bool alertsModified = false;
    
    for (int i = 0; i < alerts.length; i++) {
      final alert = alerts[i];
      final stopId = alert['stopId'];
      final line = alert['line'];
      final stopName = alert['stopName'];
      final destination = alert['destination'] ?? '';
      final notified5min = alert['notified5min'] == true || alert['notified5min'] == 'true';
      final notified2min = alert['notified2min'] == true || alert['notified2min'] == 'true';
      final notifiedArriving = alert['notifiedArriving'] == true || alert['notifiedArriving'] == 'true';
      
      print('[ForegroundService] Processing alert: line=$line, stop=$stopName, notified5=$notified5min, notified2=$notified2min, notifiedArriving=$notifiedArriving');
      
      // Consultar tiempo real
      final arrivals = await ScrapingRepository.getStopArrivals(stopId.toString());
      print('[ForegroundService] Got ${arrivals.length} arrivals from API for stop $stopId');
        
      for (final arrival in arrivals) {
        final busLine = arrival['line']!;
        final timeText = arrival['timeText']!;
            
            // Comparación flexible (ignorar espacios y mayúsculas)
            final lineNormalized = line.toString().trim().toUpperCase();
            final busLineNormalized = busLine.trim().toUpperCase();
            
            print('[ForegroundService] Comparing: "$busLineNormalized" vs "$lineNormalized"');
            
            if (busLineNormalized == lineNormalized || busLineNormalized.contains(lineNormalized)) {
              final minutes = _parseMinutesStatic(timeText);
              
              print('[ForegroundService] MATCH! Line: $busLine, Time: $timeText, Minutes: $minutes');
              
              // Log para debug
              await prefs.setString('last_bus_check', 'Line: $busLine, Time: $timeText, Minutes: $minutes, At: ${DateTime.now()}');
              
              // Notificar según el tiempo restante
              // 5 minutos: una sola vez
              if (minutes >= 3 && minutes <= 5 && !notified5min) {
                print('[ForegroundService] Sending 5min notification');
                await _showBusArrivingNotificationStatic(notif, line, stopName, minutes);
                alerts[i]['notified5min'] = true;
                alertsModified = true;
              } 
              // 2 minutos: una sola vez
              else if (minutes == 2 && !notified2min) {
                print('[ForegroundService] Sending 2min notification');
                await _showBusArrivingNotificationStatic(notif, line, stopName, minutes);
                alerts[i]['notified2min'] = true;
                alertsModified = true;
              } 
              // 1 minuto o llegando (0): notificar si no se ha notificado "arriving"
              else if (minutes >= 0 && minutes <= 1 && !notifiedArriving) {
                print('[ForegroundService] Sending ARRIVING notification (minutes=$minutes)');
                await _showBusArrivingNotificationStatic(notif, line, stopName, minutes, isArriving: true);
                alerts[i]['notifiedArriving'] = true;
                alertsModified = true;
                
                // Guardar viaje pendiente para historial
                final pendingTrip = {
                  'line': line.toString(),
                  'destination': destination,
                  'stopName': stopName,
                  'stopId': stopId,
                  'timestamp': DateTime.now().toIso8601String(),
                };
                await prefs.setString('pending_trip', jsonEncode(pendingTrip));
                print('[ForegroundService] Saved pending trip for history');
              } else {
                print('[ForegroundService] No notification needed. minutes=$minutes, notified5=$notified5min, notified2=$notified2min, notifiedArriving=$notifiedArriving');
              }
              break;
        }
      }
    }
    
    // Guardar alertas actualizadas
    if (alertsModified) {
      await prefs.setString('bus_alerts', jsonEncode(alerts));
      print('[ForegroundService] Alerts updated and saved');
    }
    
    // Limpiar alertas completadas (todas las notificaciones enviadas) o muy antiguas
    final List<dynamic> alertsToKeep = [];
    for (final alert in alerts) {
      final notified5 = alert['notified5min'] == true || alert['notified5min'] == 'true';
      final notified2 = alert['notified2min'] == true || alert['notified2min'] == 'true';
      final notifiedArr = alert['notifiedArriving'] == true || alert['notifiedArriving'] == 'true';
      final createdAt = DateTime.tryParse(alert['createdAt']?.toString() ?? '');
      
      // Eliminar si: todas las notificaciones enviadas O más de 2 horas de antigüedad
      final isCompleted = notified5 && notified2 && notifiedArr;
      final isTooOld = createdAt != null && DateTime.now().difference(createdAt).inHours >= 2;
      
      if (!isCompleted && !isTooOld) {
        alertsToKeep.add(alert);
      } else {
        print('[ForegroundService] Removing alert: ${alert['stopName']} (completed=$isCompleted, tooOld=$isTooOld)');
      }
    }
    
    // Guardar lista limpia si cambió
    if (alertsToKeep.length != alerts.length) {
      await prefs.setString('bus_alerts', jsonEncode(alertsToKeep));
      print('[ForegroundService] Cleaned ${alerts.length - alertsToKeep.length} completed/old alerts');
    }
  } catch (e) {
    print('[ForegroundService] Error checking bus alerts: $e');
    print('Error checking bus alerts: $e');
  }
}

int _parseMinutesStatic(String timeStr) {
  if (timeStr.contains('<') || timeStr.contains('>')) return 0;
  if (timeStr.toLowerCase().contains('llegando')) return 0;
  
  final match = RegExp(r'(\d+)').firstMatch(timeStr);
  if (match != null) {
    return int.tryParse(match.group(1)!) ?? -1;
  }
  return -1;
}

Future<void> _showBusArrivingNotificationStatic(
  FlutterLocalNotificationsPlugin notif,
  String line,
  String stopName,
  int minutes, {
  bool isArriving = false,
}) async {
  // Vibrar fuerte
  try {
    if (await Vibration.hasVibrator() == true) {
      Vibration.vibrate(pattern: [0, 500, 200, 500, 200, 500]);
    }
  } catch (_) {}
  
  final timeText = minutes == 0 ? '¡LLEGANDO!' : 'en $minutes min';
  
  // Crear canal si no existe
  final androidPlugin = notif.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  const alertsChannel = AndroidNotificationChannel(
    'alzibus_alerts',
    'Alertas de Bus',
    description: 'Te avisa cuando tu bus está llegando',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );
  await androidPlugin?.createNotificationChannel(alertsChannel);
  
  final androidDetails = AndroidNotificationDetails(
    'alzibus_alerts',
    'Alertas de Bus',
    channelDescription: 'Te avisa cuando tu bus está llegando',
    importance: Importance.max,
    priority: Priority.max,
    ticker: 'Bus llegando',
    icon: '@drawable/ic_launcher_foreground',
    color: const Color(0xFF1565C0),
    fullScreenIntent: true,
    playSound: true,
    enableVibration: true,
    styleInformation: BigTextStyleInformation(
      '🚌 Línea $line $timeText\n📍 $stopName\n\n¡Prepárate para coger el bus!',
      contentTitle: '🚨 ¡Tu bus está llegando!',
    ),
  );
  
  await notif.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000, // ID único
    '🚨 ¡Tu bus está llegando!',
    'Línea $line $timeText - $stopName',
    NotificationDetails(android: androidDetails),
    payload: isArriving ? 'trip_confirm' : null,
  );
}

// Actualizar el widget de Android con la parada favorita
Future<void> _updateWidgetStatic(SharedPreferences prefs) async {
  try {
    // Obtener todas las paradas favoritas
    final favoritesJson = prefs.getString('favorite_stops');
    List<Map<String, dynamic>> favorites = [];
    
    if (favoritesJson != null) {
      try {
        final List<dynamic> parsed = jsonDecode(favoritesJson);
        favorites = parsed.cast<Map<String, dynamic>>();
      } catch (e) {
        print('[ForegroundService] Error parsing favorites: $e');
      }
    }
    
    if (favorites.isEmpty) {
      // No hay favoritos
      await HomeWidget.saveWidgetData<int>('widget_arrival_count', 0);
      await HomeWidget.saveWidgetData<String>('widget_empty_text', 'Añade favoritos desde la app');
      await HomeWidget.saveWidgetData<String>('widget_last_update', '--:--');
      await HomeWidget.updateWidget(
        name: 'BusWidgetProvider',
        androidName: 'BusWidgetProvider',
      );
      return;
    }
    
    // Recoger llegadas de todas las paradas favoritas
    List<Map<String, String>> allArrivals = [];
    
    for (final favorite in favorites) {
      final stopId = favorite['stopId']?.toString();
      if (stopId == null) continue;
      
      try {
        final arrivals = await ScrapingRepository.getStopArrivals(stopId);
        
        for (final arrival in arrivals) {
          final lineText = arrival['line']!;
          final destText = arrival['destination']!;
          final timeText = arrival['timeText']!;
              
              if (lineText.isNotEmpty && timeText.isNotEmpty) {
                // Formatear tiempo
                String formattedTime;
                int minutesValue = 999;
                
                if (timeText.toLowerCase().contains('llegando') || 
                    timeText.toLowerCase().contains('inminente') ||
                    timeText.contains('<')) {
                  formattedTime = '¡Ya!';
                  minutesValue = 0;
                } else {
                  final match = RegExp(r'(\d+)').firstMatch(timeText);
                  if (match != null) {
                    minutesValue = int.tryParse(match.group(1)!) ?? 999;
                    formattedTime = '${match.group(1)} min';
                  } else {
                    formattedTime = timeText;
                  }
                }
                
                allArrivals.add({
                  'line': lineText,
                  'destination': destText,
                  'time': formattedTime,
                  'minutes': minutesValue.toString(),
                });
              }
        }
      } catch (e) {
        print('[ForegroundService] Error fetching stop $stopId: $e');
      }
    }
    
    // Ordenar por tiempo (los más próximos primero)
    allArrivals.sort((a, b) {
      final aMin = int.tryParse(a['minutes'] ?? '999') ?? 999;
      final bMin = int.tryParse(b['minutes'] ?? '999') ?? 999;
      return aMin.compareTo(bMin);
    });
    
    // Obtener hora actual
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    // Guardar los primeros 3 buses
    final count = allArrivals.length.clamp(0, 3);
    await HomeWidget.saveWidgetData<int>('widget_arrival_count', count);
    await HomeWidget.saveWidgetData<String>('widget_last_update', timeStr);
    
    if (count == 0) {
      await HomeWidget.saveWidgetData<String>('widget_empty_text', 'Sin buses próximos');
    }
    
    for (int i = 0; i < 3; i++) {
      if (i < allArrivals.length) {
        final arrival = allArrivals[i];
        await HomeWidget.saveWidgetData<String>('widget_line_${i + 1}', arrival['line'] ?? '');
        await HomeWidget.saveWidgetData<String>('widget_dest_${i + 1}', arrival['destination'] ?? '');
        await HomeWidget.saveWidgetData<String>('widget_time_${i + 1}', arrival['time'] ?? '--');
      } else {
        await HomeWidget.saveWidgetData<String>('widget_line_${i + 1}', '');
        await HomeWidget.saveWidgetData<String>('widget_dest_${i + 1}', '');
        await HomeWidget.saveWidgetData<String>('widget_time_${i + 1}', '--');
      }
    }
    
    await HomeWidget.updateWidget(
      name: 'BusWidgetProvider',
      androidName: 'BusWidgetProvider',
    );
    print('[ForegroundService] Widget actualizado: $count buses de ${favorites.length} favoritos');
  } catch (e) {
    print('[ForegroundService] Error actualizando widget: $e');
  }
}

// Clase principal del servicio
class ForegroundService {
  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static const String _channelId = 'alzibus_foreground';
  static const String _channelName = 'Alzibus Service';
  
  static Future<void> initialize() async {
    // No inicializar en web
    if (kIsWeb) {
      print('[ForegroundService] Web platform detected, skipping initialization');
      return;
    }
    
    // Crear canal de notificaciones ANTES de configurar el servicio
    final FlutterLocalNotificationsPlugin notif = FlutterLocalNotificationsPlugin();
    
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Servicio de notificaciones de Alzibus',
      importance: Importance.min, // Mínima importancia para que no moleste
      playSound: false,
      enableVibration: false,
      showBadge: false,
    );
    
    await notif.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(androidChannel);
    
    // También crear canal para alertas
    const alertChannel = AndroidNotificationChannel(
      'alzibus_alerts',
      'Alertas de paradas',
      description: 'Notificaciones cuando estás cerca de una parada',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    
    await notif.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(alertChannel);
    
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _channelId,
        initialNotificationTitle: 'Alzibus',
        initialNotificationContent: 'Activo en segundo plano',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }
  
  static Future<void> start() async {
    if (kIsWeb) return;
    
    try {
      // Si ya está corriendo, no intentar arrancarlo de nuevo para evitar errores de sistema
      if (await _service.isRunning()) {
        print('[ForegroundService] Service is already running, skipping start');
        return;
      }
      
      // Pequeño delay para asegurar que la app está en primer plano (especialmente en cold starts)
      await Future.delayed(const Duration(seconds: 1));
      
      await _service.startService();
      print('[ForegroundService] Service started successfully');
    } catch (e) {
      print('[ForegroundService] Error starting service (likely background restriction): $e');
      // No relanzamos el error para evitar que la app crashee completamente
    }
  }
  
  static Future<void> stop() async {
    if (kIsWeb) return;
    final isRunning = await _service.isRunning();
    if (isRunning) {
      _service.invoke('stop');
      print('[ForegroundService] Service stopped');
    }
  }
  
  static Future<bool> isRunning() async {
    if (kIsWeb) return false;
    return await _service.isRunning();
  }
  
  /// Envía una notificación de prueba para verificar que funciona
  static Future<void> sendTestNotification() async {
    if (kIsWeb) return;
    final FlutterLocalNotificationsPlugin notif = FlutterLocalNotificationsPlugin();
    
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_launcher_foreground'),
    );
    await notif.initialize(initSettings);
    
    const androidDetails = AndroidNotificationDetails(
      'alzibus_alerts',
      'Alertas de Bus',
      channelDescription: 'Te avisa cuando tu bus está llegando',
      importance: Importance.max,
      priority: Priority.max,
      ticker: 'Test',
      icon: '@drawable/ic_launcher_foreground',
      color: Color(0xFF1565C0),
      fullScreenIntent: true,
    );
    
    await notif.show(
      9999,
      '🧪 Prueba de notificación',
      'Si ves esto, las notificaciones funcionan correctamente',
      const NotificationDetails(android: androidDetails),
    );
    print('[ForegroundService] Test notification sent');
  }
  
  /// Fuerza una verificación inmediata de alertas
  static Future<void> checkAlertsNow() async {
    final prefs = await SharedPreferences.getInstance();
    final FlutterLocalNotificationsPlugin notif = FlutterLocalNotificationsPlugin();
    
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_launcher_foreground'),
    );
    await notif.initialize(initSettings);
    
    print('[ForegroundService] Manual check triggered');
    await _checkBusAlertsStatic(prefs, notif);
  }
}
