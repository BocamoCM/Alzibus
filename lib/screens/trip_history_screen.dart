import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/trip_history_service.dart';
import '../models/trip_record.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> with SingleTickerProviderStateMixin {
  TripHistoryService? _historyService;
  late TabController _tabController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadService();
  }

  Future<void> _loadService() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _historyService = TripHistoryService(prefs);
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Historial de Viajes'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart), text: 'Estadísticas'),
            Tab(icon: Icon(Icons.history), text: 'Historial'),
          ],
        ),
        actions: [
          if (!_isLoading && _historyService != null)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'clear') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('¿Borrar historial?'),
                      content: const Text('Se eliminarán todos los viajes guardados.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Borrar'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await _historyService!.clearHistory();
                    setState(() {});
                  }
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_forever, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Borrar historial'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildStatsTab(),
                _buildHistoryTab(),
              ],
            ),
    );
  }

  Widget _buildStatsTab() {
    final stats = _historyService!.getStats();
    
    if (stats.totalTrips == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_bus, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Sin viajes registrados',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Activa alertas de bus para empezar\na registrar tus viajes',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    final stats7days = _historyService!.getStats(lastDays: 7);
    final stats30days = _historyService!.getStats(lastDays: 30);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resumen general
          _buildSummaryCard(stats),
          
          const SizedBox(height: 16),
          
          // Top líneas
          _buildTopLinesCard(stats),
          
          const SizedBox(height: 16),
          
          // Top paradas
          _buildTopStopsCard(stats),
          
          const SizedBox(height: 16),
          
          // Actividad reciente
          _buildActivityCard(stats7days, stats30days),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(TripStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📈 Resumen',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('🚌', '${stats.totalTrips}', 'Viajes totales'),
                _buildStatItem('🚏', stats.mostUsedStop ?? '-', 'Parada favorita'),
                _buildStatItem('⏰', stats.mostFrequentTimeRange, 'Horario habitual'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTopLinesCard(TripStats stats) {
    final topLines = stats.topLines;
    if (topLines.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🚌 Líneas más usadas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ...topLines.asMap().entries.map((entry) {
              final index = entry.key;
              final line = entry.value;
              final medals = ['🥇', '🥈', '🥉'];
              final maxCount = topLines.first.value;
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Text(medals[index], style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Text(
                      'Línea ${line.key}',
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                    ),
                    const Spacer(),
                    Text(
                      '${line.value} viajes',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      child: LinearProgressIndicator(
                        value: line.value / maxCount,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation(
                          index == 0 ? Colors.amber : 
                          index == 1 ? Colors.grey : Colors.brown[300],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTopStopsCard(TripStats stats) {
    final topStops = stats.topStops;
    if (topStops.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🚏 Paradas más frecuentes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ...topStops.map((stop) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      stop.key,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${stop.value}',
                      style: TextStyle(
                        color: Colors.blue[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(TripStats stats7days, TripStats stats30days) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📅 Actividad reciente',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '${stats7days.totalTrips}',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    Text('Últimos 7 días', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
                Container(width: 1, height: 50, color: Colors.grey[300]),
                Column(
                  children: [
                    Text(
                      '${stats30days.totalTrips}',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    Text('Últimos 30 días', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    final records = _historyService!.allRecords;
    
    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Sin viajes en el historial',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Agrupar por fecha
    final grouped = <String, List<TripRecord>>{};
    for (final record in records) {
      final dateKey = _formatDate(record.timestamp);
      grouped.putIfAbsent(dateKey, () => []).add(record);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final dateKey = grouped.keys.elementAt(index);
        final trips = grouped[dateKey]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Text(
                dateKey,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
              ),
            ),
            ...trips.map((trip) => _buildTripTile(trip)),
          ],
        );
      },
    );
  }

  Widget _buildTripTile(TripRecord trip) {
    return Dismissible(
      key: Key(trip.timestamp.toIso8601String()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) async {
        await _historyService!.deleteTrip(trip.timestamp);
        setState(() {});
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blue,
            child: Text(
              trip.line,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          title: Text(trip.stopName),
          subtitle: Text(
            '→ ${trip.destination}',
            style: TextStyle(color: Colors.grey[600]),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTime(trip.timestamp),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    trip.confirmed ? Icons.check_circle : Icons.help_outline,
                    size: 14,
                    color: trip.confirmed ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    trip.confirmed ? 'Confirmado' : 'Asumido',
                    style: TextStyle(
                      fontSize: 11,
                      color: trip.confirmed ? Colors.green : Colors.orange,
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return 'Hoy';
    if (dateOnly == yesterday) return 'Ayer';
    
    final weekdays = ['', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final months = ['', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    
    return '${weekdays[date.weekday]} ${date.day} ${months[date.month]}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
