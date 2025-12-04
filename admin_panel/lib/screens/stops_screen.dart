import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import '../services/api_service.dart';

class StopsScreen extends StatefulWidget {
  const StopsScreen({super.key});

  @override
  State<StopsScreen> createState() => _StopsScreenState();
}

class _StopsScreenState extends State<StopsScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _stops = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadStops();
  }

  Future<void> _loadStops() async {
    setState(() => _isLoading = true);
    try {
      _stops = await _api.getStops();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredStops {
    if (_searchQuery.isEmpty) return _stops;
    final query = _searchQuery.toLowerCase();
    return _stops.where((stop) {
      final name = (stop['name'] as String).toLowerCase();
      final id = stop['id'].toString();
      return name.contains(query) || id.contains(query);
    }).toList();
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
                    'Gestion de Paradas',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Administra las paradas del sistema',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: () => _showStopDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Nueva Parada'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar parada...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: _loadStops,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Actualizar',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
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
      minWidth: 800,
      columns: const [
        DataColumn2(label: Text('ID'), size: ColumnSize.S),
        DataColumn2(label: Text('Nombre'), size: ColumnSize.L),
        DataColumn2(label: Text('Coordenadas'), size: ColumnSize.M),
        DataColumn2(label: Text('Lineas'), size: ColumnSize.M),
        DataColumn2(label: Text('Estado'), size: ColumnSize.S),
        DataColumn2(label: Text('Acciones'), size: ColumnSize.S),
      ],
      rows: _filteredStops.map((stop) => _buildDataRow(stop)).toList(),
    );
  }

  DataRow2 _buildDataRow(Map<String, dynamic> stop) {
    final isActive = stop['active'] as bool? ?? true;
    final name = stop['name']?.toString() ?? 'Sin nombre';
    final lat = stop['lat']?.toString() ?? '0';
    final lng = stop['lng']?.toString() ?? '0';
    final lines = (stop['lines'] as List?) ?? [];
    
    return DataRow2(
      cells: [
        DataCell(
          Text(
            '#${stop['id']}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        DataCell(Text(name)),
        DataCell(Text('$lat, $lng')),
        DataCell(
          Wrap(
            spacing: 4,
            children: lines.map((line) {
              return Chip(
                label: Text(
                  line as String,
                  style: const TextStyle(fontSize: 11),
                ),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ),
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
                onPressed: () => _showStopDialog(stop: stop),
                tooltip: 'Editar',
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                onPressed: () => _confirmDelete(stop),
                tooltip: 'Eliminar',
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showStopDialog({Map<String, dynamic>? stop}) {
    final isEdit = stop != null;
    final nameController = TextEditingController(text: stop?['name'] as String?);
    final latController = TextEditingController(text: stop?['lat']?.toString());
    final lngController = TextEditingController(text: stop?['lng']?.toString());
    bool isActive = stop?['active'] as bool? ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Editar Parada #${stop['id']}' : 'Nueva Parada'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: latController,
                        decoration: const InputDecoration(
                          labelText: 'Latitud',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: lngController,
                        decoration: const InputDecoration(
                          labelText: 'Longitud',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Parada activa'),
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
                final newStop = {
                  'name': nameController.text,
                  'lat': double.tryParse(latController.text) ?? 0,
                  'lng': double.tryParse(lngController.text) ?? 0,
                  'active': isActive,
                  'lines': stop?['lines'] ?? [],
                };
                if (isEdit) {
                  await _api.updateStop(stop['id'] as int, newStop);
                } else {
                  await _api.createStop(newStop);
                }
                if (mounted) {
                  Navigator.pop(context);
                  _loadStops();
                }
              },
              child: Text(isEdit ? 'Guardar' : 'Crear'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> stop) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminacion'),
        content: Text(
          'Estas seguro de que quieres eliminar la parada "${stop['name']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _api.deleteStop(stop['id'] as int);
              if (mounted) {
                Navigator.pop(context);
                _loadStops();
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
