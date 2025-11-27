import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  int _alertsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDebugInfo();
  }

  Future<void> _loadDebugInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getString('last_background_check');
    final alertsJson = prefs.getString('bus_alerts');
    
    setState(() {
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
          color: Colors.grey[100],
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Último chequeo en segundo plano:'),
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
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
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
                Text('Versión: 0.1.0'),
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
        // Instrucciones para MIUI
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
                    Text('Xiaomi/MIUI', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Para que las notificaciones funcionen en segundo plano:',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
                const Text('1. Ajustes → Apps → Alzibus → Batería → Sin restricciones', style: TextStyle(fontSize: 12)),
                const Text('2. Ajustes → Apps → Alzibus → Autostart → Activar', style: TextStyle(fontSize: 12)),
                const Text('3. Seguridad → Batería → Ahorro ultra → Desactivar para Alzibus', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
