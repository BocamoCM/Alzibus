import 'dart:async';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'dart:typed_data';
import 'package:vibration/vibration.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

const String portName = 'background_location_port';

@pragma('vm:entry-point')
class BackgroundService {
  static const int alarmId = 0;
  
  static Future<void> initialize() async {
    await AndroidAlarmManager.initialize();
  }

  static Future<void> startBackgroundService() async {
    await AndroidAlarmManager.periodic(
      const Duration(minutes: 1),
      alarmId,
      _checkLocationCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
  }

  static Future<void> stopBackgroundService() async {
    await AndroidAlarmManager.cancel(alarmId);
  }

  @pragma('vm:entry-point')
  static Future<void> _checkLocationCallback() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Log para depuración
      final now = DateTime.now().toIso8601String();
      await prefs.setString('last_background_check', now);
      
      // Inicializar plugin de notificaciones
      final FlutterLocalNotificationsPlugin notif = FlutterLocalNotificationsPlugin();
      const initializationSettingsAndroid = AndroidInitializationSettings('@drawable/ic_launcher_foreground');
      const initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
      await notif.initialize(initializationSettings);
      
      // === CHEQUEAR ALERTAS DE BUS (siempre, incluso con notificaciones de proximidad desactivadas) ===
      await _checkBusAlerts(prefs, notif);
      
      // Verificar si las notificaciones de proximidad están habilitadas
      final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      if (!notificationsEnabled) return;

      // Obtener configuración
      final distance = prefs.getDouble('notification_distance') ?? 100.0;
      final cooldown = prefs.getInt('notification_cooldown') ?? 300;
      
      // Obtener ubicación actual
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Cargar paradas desde SharedPreferences (guardadas al iniciar la app)
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
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          
          if (now - lastNotified >= cooldown) {
            await _showNotification(
              stopName,
              lines,
              distanceToStop,
            );
            
            // Actualizar tiempo de última notificación
            await prefs.setInt('last_notified_$stopName', now);
          }
        }
      }
      
    } catch (e) {
      print('Error en servicio de fondo: $e');
    }
  }

  // Chequear alertas de bus programadas
  static Future<void> _checkBusAlerts(SharedPreferences prefs, FlutterLocalNotificationsPlugin notif) async {
    final alertsJson = prefs.getString('bus_alerts');
    if (alertsJson == null || alertsJson.isEmpty) return;
    
    try {
      final List<dynamic> alerts = jsonDecode(alertsJson);
      if (alerts.isEmpty) return;
      
      final updatedAlerts = <Map<String, dynamic>>[];
      bool anyUpdated = false;
      
      for (final alertData in alerts) {
        final stopId = int.parse(alertData['stopId'].toString());
        final stopName = alertData['stopName'].toString();
        final line = alertData['line'].toString();
        final destination = alertData['destination'].toString();
        final createdAt = DateTime.parse(alertData['createdAt'].toString());
        final notified5min = alertData['notified5min'].toString() == 'true';
        final notified2min = alertData['notified2min'].toString() == 'true';
        final notifiedArriving = alertData['notifiedArriving'].toString() == 'true';
        
        // Eliminar alertas de más de 30 minutos
        if (DateTime.now().difference(createdAt).inMinutes > 30) {
          anyUpdated = true;
          continue;
        }
        
        // Obtener tiempos del bus
        final arrivals = await _fetchBusArrivals(stopId);
        final matchingArrival = arrivals.firstWhere(
          (a) => a['line'] == line && a['destination'] == destination,
          orElse: () => {'line': '', 'time': ''},
        );
        
        if (matchingArrival['line'] == '') {
          updatedAlerts.add(alertData);
          continue;
        }
        
        final minutes = _parseMinutes(matchingArrival['time'] ?? '');
        Map<String, dynamic> updatedAlert = Map<String, dynamic>.from(alertData);
        
        // Si minutes es -1 (>>> sin servicio) - eliminar la alerta (el bus ya pasó o no hay servicio)
        if (minutes < 0) {
          anyUpdated = true;
          continue; // No añadir = eliminar
        }
        
        // Primera notificación (≤10 min)
        if (minutes <= 10 && !notified5min && !notified2min && !notifiedArriving) {
          await _showBusAlert(notif, stopName, line, destination, minutes, 'pronto');
          updatedAlert['notified5min'] = true;
          if (minutes <= 2) updatedAlert['notified2min'] = true;
          anyUpdated = true;
        }
        // Segunda notificación (≤2 min)
        else if (minutes <= 2 && minutes > 0 && notified5min && !notified2min) {
          await _showBusAlert(notif, stopName, line, destination, minutes, 'muy_cerca');
          updatedAlert['notified2min'] = true;
          anyUpdated = true;
        }
        // Notificación final (0 min)
        else if (minutes == 0 && !notifiedArriving) {
          await _showBusAlert(notif, stopName, line, destination, 0, 'llegando', stopId: stopId, prefs: prefs);
          updatedAlert['notifiedArriving'] = true;
          anyUpdated = true;
          continue; // No añadir, eliminar la alerta
        }
        
        updatedAlerts.add(updatedAlert);
      }
      
      // Guardar alertas actualizadas
      if (anyUpdated) {
        await prefs.setString('bus_alerts', jsonEncode(updatedAlerts));
      }
    } catch (e) {
      // Error silenciado
    }
  }

  // Obtener tiempos de llegada desde la API
  static Future<List<Map<String, String>>> _fetchBusArrivals(int stopId) async {
    try {
      final url = Uri.parse('https://servidor.autocareslozano.es/Alzira/webtiempos/PopupPoste.aspx?id=$stopId');
      final response = await http.get(url);
      if (response.statusCode != 200) return [];
      
      final document = html_parser.parse(response.body);
      final rows = document.querySelectorAll('table tr');
      final arrivals = <Map<String, String>>[];
      
      for (var i = 1; i < rows.length; i++) {
        final cells = rows[i].querySelectorAll('td');
        if (cells.length >= 3) {
          arrivals.add({
            'line': cells[0].text.trim(),
            'destination': cells[1].text.trim(),
            'time': cells[2].text.trim(),
          });
        }
      }
      return arrivals;
    } catch (e) {
      return [];
    }
  }

  // Parsear minutos
  static int _parseMinutes(String time) {
    // Bus en parada
    if (time.toLowerCase().contains('parada')) return 0;
    
    // Sin datos o ya pasó (>>> significa sin tiempo disponible)
    if (time.contains('>>>') || time.contains('---') || time.trim().isEmpty) return -1;
    
    // Formato "X min"
    final minMatch = RegExp(r'(\d+)\s*min', caseSensitive: false).firstMatch(time);
    if (minMatch != null) return int.tryParse(minMatch.group(1) ?? '99') ?? 99;
    
    // Formato hora "HH:MM"
    final timeMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(time);
    if (timeMatch != null) {
      final hour = int.tryParse(timeMatch.group(1) ?? '0') ?? 0;
      final minute = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;
      final now = DateTime.now();
      final busTime = DateTime(now.year, now.month, now.day, hour, minute);
      var diff = busTime.difference(now).inMinutes;
      if (diff < 0) diff += 24 * 60;
      return diff;
    }
    return 99;
  }

  // Mostrar notificación de alerta de bus
  static Future<void> _showBusAlert(
    FlutterLocalNotificationsPlugin notif,
    String stopName,
    String line,
    String destination,
    int minutes,
    String urgency, {
    int? stopId,
    SharedPreferences? prefs,
  }) async {
    String title;
    Int64List vibrationPattern;
    
    switch (urgency) {
      case 'muy_cerca':
        title = '⚠️ ¡Bus muy cerca!';
        vibrationPattern = Int64List.fromList([0, 800, 200, 800, 200, 800]);
        break;
      case 'llegando':
        title = '🔔 ¡BUS LLEGANDO AHORA!';
        vibrationPattern = Int64List.fromList([0, 500, 200, 500, 200, 500, 200, 500]);
        break;
      default:
        title = '🚌 Bus llegando pronto';
        vibrationPattern = Int64List.fromList([0, 1000, 300, 1000]);
    }
    
    // Crear canal de alertas
    final alertsChannel = AndroidNotificationChannel(
      'alzibus-alerts',
      'Alertas de Bus',
      description: 'Te avisa cuando tu bus está llegando',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
      vibrationPattern: vibrationPattern,
    );
    await notif.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(alertsChannel);
    
    // Si es notificación final (llegando), guardar viaje pendiente para historial
    String? payload;
    if (urgency == 'llegando' && stopId != null && prefs != null) {
      // Guardar viaje pendiente
      final pendingTrip = {
        'line': line,
        'destination': destination,
        'stopName': stopName,
        'stopId': stopId,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await prefs.setString('pending_trip', jsonEncode(pendingTrip));
      payload = 'trip_confirm'; // Para identificar que debe preguntar al abrir
    }
    
    final androidDetails = AndroidNotificationDetails(
      'alzibus-alerts',
      'Alertas de Bus',
      channelDescription: 'Te avisa cuando tu bus está llegando',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    );
    
    final timeText = minutes == 0 
        ? '¡Ya está en parada!' 
        : minutes == 1 
            ? '¡Llega en 1 minuto!' 
            : 'Llega en $minutes minutos';
    
    final bodyText = urgency == 'llegando'
        ? '$stopName → $destination\n$timeText\n👆 Toca para confirmar si lo cogiste'
        : '$stopName → $destination\n$timeText';
    
    // Vibrar
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(pattern: vibrationPattern.toList());
    }
    
    await notif.show(
      '${line}_$destination'.hashCode,
      '$title - Línea $line',
      bodyText,
      NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  static Future<void> _showNotification(
    String stopName,
    List<String> lines,
    double distance,
  ) async {
    final FlutterLocalNotificationsPlugin notif = FlutterLocalNotificationsPlugin();

    const initializationSettingsAndroid = AndroidInitializationSettings('@drawable/ic_launcher_foreground');
    const initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await notif.initialize(initializationSettings);

    // Asegurar que el canal heads-up exista en el isolate de fondo
    const androidChannel = AndroidNotificationChannel(
      'alzibus-hu',
      'Alzibus (Heads-up)',
      description: 'Notificaciones heads-up de paradas cercanas',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await notif
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    final androidDetails = AndroidNotificationDetails(
      'alzibus-hu',
      'Alzibus (Heads-up)',
      channelDescription: 'Notificaciones heads-up de paradas cercanas',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
      ticker: 'Parada cercana',
      styleInformation: const BigTextStyleInformation(''),
      fullScreenIntent: true,
      category: AndroidNotificationCategory.navigation,
      visibility: NotificationVisibility.public,
    );
    
    final details = NotificationDetails(android: androidDetails);
    
    // Vibrar el dispositivo
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(pattern: [0, 500, 200, 500]);
    }
    
    await notif.show(
      0,
      '🚍 Parada cercana',
      '$stopName — ${lines.join(', ')} (${distance.toStringAsFixed(0)}m)',
      details,
    );
  }

  // Método para guardar las paradas en SharedPreferences (llamar desde la app principal)
  static Future<void> saveStopsToPreferences(List<Map<String, dynamic>> stops) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bus_stops', jsonEncode(stops));
  }
}
