import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDarkMode;

  const SettingsScreen({
    super.key,
    required this.onThemeToggle,
    required this.isDarkMode,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _autoRefresh = true;
  int _refreshInterval = 30;
  String _language = 'es';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications') ?? true;
      _autoRefresh = prefs.getBool('autoRefresh') ?? true;
      _refreshInterval = prefs.getInt('refreshInterval') ?? 30;
      _language = prefs.getString('language') ?? 'es';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications', _notificationsEnabled);
    await prefs.setBool('autoRefresh', _autoRefresh);
    await prefs.setInt('refreshInterval', _refreshInterval);
    await prefs.setString('language', _language);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuracion guardada'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configuracion',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajustes del panel de administracion',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          _buildSection(
            theme,
            'Apariencia',
            Icons.palette,
            [
              _buildSwitchTile(
                'Modo oscuro',
                'Cambiar entre tema claro y oscuro',
                widget.isDarkMode,
                (value) => widget.onThemeToggle(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            theme,
            'Notificaciones',
            Icons.notifications,
            [
              _buildSwitchTile(
                'Notificaciones',
                'Recibir alertas del sistema',
                _notificationsEnabled,
                (value) {
                  setState(() => _notificationsEnabled = value);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            theme,
            'Datos',
            Icons.sync,
            [
              _buildSwitchTile(
                'Actualizacion automatica',
                'Refrescar datos automaticamente',
                _autoRefresh,
                (value) {
                  setState(() => _autoRefresh = value);
                },
              ),
              if (_autoRefresh)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'Intervalo: $_refreshInterval segundos',
                        style: theme.textTheme.bodyMedium,
                      ),
                      Slider(
                        value: _refreshInterval.toDouble(),
                        min: 10,
                        max: 120,
                        divisions: 11,
                        label: '$_refreshInterval s',
                        onChanged: (value) {
                          setState(() => _refreshInterval = value.toInt());
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            theme,
            'Idioma',
            Icons.language,
            [
              Padding(
                padding: const EdgeInsets.all(16),
                child: DropdownButtonFormField<String>(
                  value: _language,
                  decoration: const InputDecoration(
                    labelText: 'Idioma del panel',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'es', child: Text('Espanol')),
                    DropdownMenuItem(value: 'ca', child: Text('Valenciano')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _language = value);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            theme,
            'Sistema',
            Icons.info,
            [
              ListTile(
                leading: const Icon(Icons.build),
                title: const Text('Version'),
                subtitle: const Text('Panel Admin v1.0.0'),
              ),
              ListTile(
                leading: const Icon(Icons.storage),
                title: const Text('Base de datos'),
                subtitle: const Text('Conectado - localhost:3000'),
                trailing: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.memory),
                title: const Text('Estado del servidor'),
                subtitle: const Text('Operativo'),
                trailing: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Center(
            child: FilledButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save),
              label: const Text('Guardar configuracion'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSection(
    ThemeData theme,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF6B1B3D)),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}
