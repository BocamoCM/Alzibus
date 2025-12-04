import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import '../services/api_service.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _routes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    setState(() => _isLoading = true);
    try {
      _routes = await _api.getRoutes();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gestion de Rutas',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Administra las lineas y rutas del sistema',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: () => _showRouteDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Nueva Ruta'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Card(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildDataTable(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    return DataTable2(
      columnSpacing: 16,
      horizontalMargin: 16,
      minWidth: 600,
      columns: const [
        DataColumn2(label: Text('Linea'), size: ColumnSize.S),
        DataColumn2(label: Text('Nombre'), size: ColumnSize.L),
        DataColumn2(label: Text('Paradas'), size: ColumnSize.S),
        DataColumn2(label: Text('Frecuencia'), size: ColumnSize.S),
        DataColumn2(label: Text('Estado'), size: ColumnSize.S),
        DataColumn2(label: Text('Acciones'), size: ColumnSize.S),
      ],
      rows: _routes.map((route) => _buildDataRow(route)).toList(),
    );
  }

  DataRow2 _buildDataRow(Map<String, dynamic> route) {
    final isActive = route['active'] as bool;
    final color = Color(route['color'] as int);
    
    return DataRow2(
      cells: [
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              route['code'] as String,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        DataCell(Text(route['name'] as String)),
        DataCell(Text('${route['stops']} paradas')),
        DataCell(Text('${route['frequency']} min')),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isActive ? 'Activa' : 'Inactiva',
              style: TextStyle(
                color: isActive ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => _showRouteDialog(route: route),
                tooltip: 'Editar',
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                onPressed: () => _confirmDelete(route),
                tooltip: 'Eliminar',
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showRouteDialog({Map<String, dynamic>? route}) {
    final isEdit = route != null;
    final nameController = TextEditingController(
      text: route?['name'] as String?,
    );
    final codeController = TextEditingController(
      text: route?['code'] as String?,
    );
    final frequencyController = TextEditingController(
      text: route?['frequency']?.toString(),
    );
    bool isActive = route?['active'] as bool? ?? true;
    Color selectedColor = route != null
        ? Color(route['color'] as int)
        : const Color(0xFF6B1B3D);

    final colors = [
      const Color(0xFF6B1B3D),
      const Color(0xFF8B2252),
      const Color(0xFFB22234),
      const Color(0xFFE85A4F),
      const Color(0xFF4A90A4),
      const Color(0xFF2E7D32),
      const Color(0xFFF57C00),
      const Color(0xFF5E35B1),
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Editar Ruta' : 'Nueva Ruta'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: 'Codigo (ej: L1)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: frequencyController,
                  decoration: const InputDecoration(
                    labelText: 'Frecuencia (minutos)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                const Text('Color de la linea:'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: colors.map((color) {
                    final isSelected = selectedColor.value == color.value;
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() => selectedColor = color);
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.black, width: 3)
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Ruta activa'),
                  value: isActive,
                  onChanged: (value) {
                    setDialogState(() => isActive = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final newRoute = {
                  'name': nameController.text,
                  'code': codeController.text,
                  'color': selectedColor.value,
                  'frequency': int.tryParse(frequencyController.text) ?? 15,
                  'active': isActive,
                  'stops': route?['stops'] ?? 0,
                };
                if (isEdit) {
                  await _api.updateRoute(route['id'] as int, newRoute);
                } else {
                  await _api.createRoute(newRoute);
                }
                if (mounted) {
                  Navigator.pop(context);
                  _loadRoutes();
                }
              },
              child: Text(isEdit ? 'Guardar' : 'Crear'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> route) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminacion'),
        content: Text(
          'Estas seguro de que quieres eliminar la ruta "${route['name']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _api.deleteRoute(route['id'] as int);
              if (mounted) {
                Navigator.pop(context);
                _loadRoutes();
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
