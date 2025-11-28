import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/foreground_service.dart';

class SettingsPage extends StatefulWidget {
  final bool notificationsEnabled;
  final double notificationDistance;
  final int notificationCooldown;
  final Function(bool) onNotificationsChanged;
  final Function(double) onDistanceChanged;
  final Function(int) onCooldownChanged;

  const SettingsPage({
    super.key,
    required this.notificationsEnabled,
    required this.notificationDistance,
    required this.notificationCooldown,
    required this.onNotificationsChanged,
    required this.onDistanceChanged,
    required this.onCooldownChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _lastBackgroundCheck = 'Nunca';
  String _lastBusCheck = 'Sin datos';
  int _alertsCount = 0;
  bool _serviceRunning = false;

  @override
  void initState() {
    super.initState();
    _loadDebugInfo();
  }

  Future<void> _loadDebugInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getString('last_foreground_check') ?? prefs.getString('last_background_check');
    final lastBus = prefs.getString('last_bus_check') ?? 'Sin datos';
    final alertsJson = prefs.getString('bus_alerts');
    final isRunning = await ForegroundService.isRunning();
    
    setState(() {
      _serviceRunning = isRunning;
      _lastBusCheck = lastBus;
      if (lastCheck != null) {
        final dt = DateTime.tryParse(lastCheck);
        if (dt != null) {
          final diff = DateTime.now().difference(dt);
          if (diff.inMinutes < 1) {
            _lastBackgroundCheck = 'Hace ${diff.inSeconds}s';
          } else if (diff.inMinutes < 60) {
            _lastBackgroundCheck = 'Hace ${diff.inMinutes} min';
          } else {
            _lastBackgroundCheck = 'Hace ${diff.inHours}h ${diff.inMinutes % 60}min';
          }
        }
      }
      if (alertsJson != null && alertsJson.isNotEmpty) {
        try {
          final list = alertsJson.split('},{').length;
          _alertsCount = alertsJson == '[]' ? 0 : list;
        } catch (_) {}
      }
    });
  }

  Future<void> _testNotification() async {
    final notif = FlutterLocalNotificationsPlugin();
    
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_launcher_foreground'),
    );
    await notif.initialize(initSettings);
    
    // Crear canal
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
    
    // Mostrar notificación de prueba
    const androidDetails = AndroidNotificationDetails(
      'alzibus_alerts',
      'Alertas de Bus',
      channelDescription: 'Te avisa cuando tu bus está llegando',
      importance: Importance.max,
      priority: Priority.max,
      ticker: 'Prueba',
      icon: '@drawable/ic_launcher_foreground',
      playSound: true,
      enableVibration: true,
    );
    
    await notif.show(
      999999,
      '🧪 Notificación de prueba',
      '¡Las notificaciones funcionan correctamente!',
      const NotificationDetails(android: androidDetails),
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Notificación de prueba enviada'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text(
          'Notificaciones',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Activar notificaciones'),
          subtitle: const Text('Recibir avisos al acercarse a paradas'),
          value: widget.notificationsEnabled,
          onChanged: widget.onNotificationsChanged,
        ),
        const Divider(),
        ListTile(
          title: const Text('Distancia de aviso'),
          subtitle: Text('${widget.notificationDistance.toInt()} metros'),
        ),
        Slider(
          value: widget.notificationDistance,
          min: 20,
          max: 200,
          divisions: 18,
          label: '${widget.notificationDistance.toInt()}m',
          onChanged: widget.notificationsEnabled ? widget.onDistanceChanged : null,
        ),
        const Divider(),
        ListTile(
          title: const Text('Tiempo entre notificaciones'),
          subtitle: Text('${widget.notificationCooldown} minutos'),
        ),
        Slider(
          value: widget.notificationCooldown.toDouble(),
          min: 1,
          max: 30,
          divisions: 29,
          label: '${widget.notificationCooldown} min',
          onChanged: widget.notificationsEnabled
              ? (value) => widget.onCooldownChanged(value.toInt())
              : null,
        ),
        const SizedBox(height: 24),
        
        // Sección de depuración
        const Text(
          'Estado del servicio',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          color: _serviceRunning ? Colors.green[50] : Colors.red[50],
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _serviceRunning ? Icons.check_circle : Icons.error,
                      color: _serviceRunning ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _serviceRunning ? 'Servicio activo' : 'Servicio detenido',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _serviceRunning ? Colors.green[800] : Colors.red[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Último chequeo:'),
                    Text(_lastBackgroundCheck, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Alertas activas:'),
                    Text('$_alertsCount', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Último bus:'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _lastBusCheck, 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _loadDebugInfo();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Actualizado'), duration: Duration(seconds: 1)),
                          );
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Actualizar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await _testNotification();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        icon: const Icon(Icons.notifications),
                        label: const Text('Probar'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      final alertsJson = prefs.getString('bus_alerts');
                      if (alertsJson != null && alertsJson.isNotEmpty) {
                        final List<dynamic> alerts = jsonDecode(alertsJson);
                        for (var alert in alerts) {
                          alert['notified5min'] = false;
                          alert['notified2min'] = false;
                          alert['notifiedArriving'] = false;
                        }
                        await prefs.setString('bus_alerts', jsonEncode(alerts));
                        _loadDebugInfo();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Alertas reiniciadas - volverás a recibir notificaciones'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No hay alertas activas')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reiniciar alertas (volver a notificar)'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Verificando alertas...')),
                      );
                      await ForegroundService.checkAlertsNow();
                      await _loadDebugInfo();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Verificación completada - revisa los logs'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.search),
                    label: const Text('Verificar buses AHORA'),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        const Text(
          'Información',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alzibus',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('Versión: 1.2.0'),
                SizedBox(height: 8),
                Text(
                  'Aplicación para ver paradas de bus en Alzira, Valencia.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        // Información sobre foreground service
        Card(
          color: Colors.blue[50],
          child: const Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Servicio en primer plano', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Alzibus usa un servicio en primer plano para garantizar que las notificaciones funcionen correctamente incluso en Samsung y Xiaomi. '
                  'Verás una notificación permanente mientras esté activo.',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Instrucciones para Samsung/MIUI
        Card(
          color: Colors.orange[50],
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Samsung / Xiaomi', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Si las notificaciones no funcionan bien:',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
                const Text('• Samsung: Ajustes → Aplicaciones → Alzibus → Batería → Sin restricciones', style: TextStyle(fontSize: 12)),
                const Text('• Xiaomi: Ajustes → Apps → Alzibus → Autostart → Activar', style: TextStyle(fontSize: 12)),
                const Text('• Xiaomi: Seguridad → Batería → Sin restricciones para Alzibus', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
