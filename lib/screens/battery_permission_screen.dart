import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BatteryPermissionScreen extends StatefulWidget {
  final String destinationRoute;
  
  const BatteryPermissionScreen({
    super.key, 
    this.destinationRoute = '/home',
  });

  @override
  State<BatteryPermissionScreen> createState() => _BatteryPermissionScreenState();
}

class _BatteryPermissionScreenState extends State<BatteryPermissionScreen> {
  String _manufacturer = '';
  bool _isXiaomi = false;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _detectDevice();
  }

  Future<void> _detectDevice() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      setState(() {
        _manufacturer = androidInfo.manufacturer.toLowerCase();
        _isXiaomi = _manufacturer.contains('xiaomi') || 
                    _manufacturer.contains('redmi') || 
                    _manufacturer.contains('poco');
      });
    }
  }

  Future<void> _openBatterySettings() async {
    // Abrir ajustes de la app
    try {
      await openAppSettings();
    } catch (e) {
      // Si falla, mostrar mensaje
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Abre Ajustes → Apps → Alzibus manualmente'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _markAsComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('battery_permission_shown', true);
    
    if (!mounted) return;
    
    // Navegar directamente a la ruta destino
    Navigator.of(context).pushReplacementNamed(widget.destinationRoute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              
              // Icono y título
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.battery_alert,
                        size: 60,
                        color: Colors.orange[800],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _isXiaomi 
                          ? '⚠️ Configuración necesaria para Xiaomi'
                          : '⚠️ Configuración de batería',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              Text(
                _isXiaomi
                    ? 'Tu dispositivo ${_manufacturer.toUpperCase()} puede cerrar la app en segundo plano. Para recibir notificaciones:'
                    : 'Para recibir notificaciones cuando la app está cerrada:',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // Pasos
              Expanded(
                child: ListView(
                  children: [
                    _buildStep(
                      0,
                      '🔋 Batería sin restricciones',
                      'Ajustes → Apps → Alzibus → Batería → Sin restricciones',
                      'Permite que la app funcione en segundo plano',
                    ),
                    _buildStep(
                      1,
                      '🚀 Autostart activado',
                      'Ajustes → Apps → Alzibus → Autostart → Activar',
                      'Permite que la app se inicie automáticamente',
                    ),
                    if (_isXiaomi) ...[
                      _buildStep(
                        2,
                        '🔒 Bloquear app en recientes',
                        'Abre apps recientes → Mantén pulsado Alzibus → Candado',
                        'Evita que MIUI cierre la app',
                      ),
                      _buildStep(
                        3,
                        '⚡ Ahorro de batería',
                        'Seguridad → Batería → Alzibus → Sin restricciones',
                        'Desactiva el ahorro agresivo de batería',
                      ),
                    ],
                  ],
                ),
              ),
              
              // Botones
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openBatterySettings,
                      icon: const Icon(Icons.settings),
                      label: const Text('Abrir Ajustes de la App'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _markAsComplete,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Ya lo configuré, continuar'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _markAsComplete,
                    child: Text(
                      'Omitir por ahora',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(int index, String title, String instruction, String description) {
    final isActive = _currentStep >= index;
    
    return GestureDetector(
      onTap: () => setState(() => _currentStep = index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue[50] : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? Colors.blue : Colors.grey[300]!,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.blue : Colors.grey[400],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isActive ? Colors.blue[800] : Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.navigate_next, size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      instruction,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[800],
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Función para verificar si debe mostrarse la pantalla
Future<bool> shouldShowBatteryPermission() async {
  // No mostrar en web
  if (kIsWeb) return false;
  
  final prefs = await SharedPreferences.getInstance();
  final alreadyShown = prefs.getBool('battery_permission_shown') ?? false;
  
  if (alreadyShown) return false;
  
  // Solo mostrar en Android
  if (defaultTargetPlatform != TargetPlatform.android) return false;
  
  // Detectar si es Xiaomi/MIUI u otro fabricante problemático
  final deviceInfo = DeviceInfoPlugin();
  final androidInfo = await deviceInfo.androidInfo;
  final manufacturer = androidInfo.manufacturer.toLowerCase();
  
  // Fabricantes conocidos por matar apps en segundo plano
  final problematicManufacturers = [
    'xiaomi', 'redmi', 'poco', 'miui',
    'huawei', 'honor',
    'oppo', 'realme', 'oneplus',
    'vivo',
    'samsung',
    'meizu',
    'asus',
  ];
  
  return problematicManufacturers.any((m) => manufacturer.contains(m));
}
