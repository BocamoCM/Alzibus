import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _usageData = [];
  List<Map<String, dynamic>> _linesData = [];
  List<Map<String, dynamic>> _recentActivity = [];
  bool _isLoading = true;
  bool _showSensitiveData = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _api.getDashboardStats(),
        _api.getUsageData(),
        _api.getLinesDistribution(),
        _api.getRecentActivity(),
      ]);
      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _usageData = results[1] as List<Map<String, dynamic>>;
        _linesData = results[2] as List<Map<String, dynamic>>;
        _recentActivity = results[3] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
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
                    Text('Dashboard', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Resumen general del sistema', style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600])),
                  ],
                ),
                IconButton(
                  icon: Icon(_showSensitiveData ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _showSensitiveData = !_showSensitiveData),
                  tooltip: _showSensitiveData ? 'Ocultar datos sensibles' : 'Mostrar datos sensibles',
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildStatsCards(theme),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildUsageChart(theme)),
                const SizedBox(width: 24),
                Expanded(child: _buildLinesDistribution(theme)),
              ],
            ),
            const SizedBox(height: 24),
            _buildRecentActivity(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards(ThemeData theme) {
    final stats = [
      {'title': 'Paradas Totales', 'value': '${_stats['totalStops'] ?? 0}', 'icon': Icons.location_on, 'color': const Color(0xFF6B1B3D)},
      {'title': 'Rutas Activas', 'value': '${_stats['totalRoutes'] ?? 0}', 'icon': Icons.route, 'color': const Color(0xFF8B2252)},
      {'title': 'Usuarios Activos', 'value': '${_stats['activeUsers'] ?? 0}', 'icon': Icons.people, 'color': const Color(0xFFB22234)},
      {'title': 'Consultas Hoy', 'value': '${_stats['todayQueries'] ?? 0}', 'icon': Icons.query_stats, 'color': const Color(0xFFE85A4F)},
      {
        'title': 'Usuarios Premium',
        'value': _showSensitiveData ? '${_stats['premiumUsers'] ?? 0}' : '***',
        'icon': Icons.diamond,
        'color': const Color(0xFFD4AF37)
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 800 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.5,
          ),
          itemCount: stats.length,
          itemBuilder: (context, index) {
            final stat = stats[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (stat['color'] as Color).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(stat['icon'] as IconData, color: stat['color'] as Color, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(stat['title'] as String, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                          const SizedBox(height: 4),
                          Text(stat['value'] as String, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUsageChart(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Consultas Semanales', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 700,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${_usageData[groupIndex]['day']}\n${rod.toY.toInt()} consultas',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < _usageData.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(_usageData[value.toInt()]['day'] as String, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()}', style: TextStyle(color: Colors.grey[600], fontSize: 12));
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 200,
                    getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[300]!, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: _usageData.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: (entry.value['queries'] as int).toDouble(),
                          color: const Color(0xFF6B1B3D),
                          width: 20,
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinesDistribution(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Distribución por Líneas', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: _linesData.map((line) {
                    return PieChartSectionData(
                      color: Color(line['color'] as int),
                      value: line['percentage'] as double,
                      title: '${(line['percentage'] as double).toInt()}%',
                      titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      radius: 50,
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: _linesData.map((line) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: Color(line['color'] as int), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(line['line'] as String, style: theme.textTheme.bodySmall),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Actividad Reciente', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                TextButton(onPressed: () {}, child: const Text('Ver todo')),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentActivity.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final activity = _recentActivity[index];
                IconData icon;
                Color color;
                switch (activity['type']) {
                  case 'add': icon = Icons.add_circle; color = Colors.green; break;
                  case 'edit': icon = Icons.edit; color = Colors.orange; break;
                  case 'update': icon = Icons.update; color = Colors.blue; break;
                  case 'user': icon = Icons.person_add; color = Colors.purple; break;
                  default: icon = Icons.settings; color = Colors.grey;
                }
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  title: Text(activity['action'] as String),
                  subtitle: Text(activity['user'] as String),
                  trailing: Text(activity['time'] as String, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
