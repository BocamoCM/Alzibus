import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _usageData = [];
  bool _isLoading = true;
  String _selectedPeriod = 'week';

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
      ]);
      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _usageData = results[1] as List<Map<String, dynamic>>;
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estadisticas',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Analisis detallado del uso del sistema',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          _buildPeriodSelector(theme),
          const SizedBox(height: 24),
          _buildSummaryCards(theme),
          const SizedBox(height: 24),
          _buildUsageChart(theme),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildTopStops(theme)),
              const SizedBox(width: 24),
              Expanded(child: _buildPeakHours(theme)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Text('Periodo: '),
            const SizedBox(width: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'day', label: Text('Hoy')),
                ButtonSegment(value: 'week', label: Text('Semana')),
                ButtonSegment(value: 'month', label: Text('Mes')),
                ButtonSegment(value: 'year', label: Text('Ano')),
              ],
              selected: {_selectedPeriod},
              onSelectionChanged: (selection) {
                setState(() => _selectedPeriod = selection.first);
              },
            ),
            const Spacer(),
            IconButton(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(ThemeData theme) {
    final summaryData = [
      {
        'title': 'Consultas Totales',
        'value': '${_stats['todayQueries'] ?? 0}',
        'change': '+${_stats['weeklyGrowth'] ?? 0}%',
        'isPositive': true,
        'icon': Icons.query_stats,
      },
      {
        'title': 'Usuarios Activos',
        'value': '${_stats['activeUsers'] ?? 0}',
        'change': '+8.2%',
        'isPositive': true,
        'icon': Icons.people,
      },
      {
        'title': 'Tiempo Respuesta',
        'value': '${_stats['avgResponseTime'] ?? 0}s',
        'change': '-0.1s',
        'isPositive': true,
        'icon': Icons.speed,
      },
      {
        'title': 'Errores',
        'value': '12',
        'change': '+3',
        'isPositive': false,
        'icon': Icons.error_outline,
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1000 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2,
          ),
          itemCount: summaryData.length,
          itemBuilder: (context, index) {
            final data = summaryData[index];
            final isPositive = data['isPositive'] as bool;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Icon(
                          data['icon'] as IconData,
                          color: const Color(0xFF6B1B3D),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          data['title'] as String,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          data['value'] as String,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isPositive
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            data['change'] as String,
                            style: TextStyle(
                              color: isPositive ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
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
            Text(
              'Tendencia de Uso',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 200,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey[300]!,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < _usageData.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _usageData[value.toInt()]['day'] as String,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
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
                          return Text(
                            '${value.toInt()}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _usageData.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          (entry.value['queries'] as int).toDouble(),
                        );
                      }).toList(),
                      isCurved: true,
                      color: const Color(0xFF6B1B3D),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF6B1B3D).withOpacity(0.1),
                      ),
                    ),
                  ],
                  minY: 0,
                  maxY: 700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopStops(ThemeData theme) {
    final topStops = [
      {'name': 'Plaza Mayor', 'queries': 856},
      {'name': 'Centro Comercial', 'queries': 742},
      {'name': 'Hospital', 'queries': 651},
      {'name': 'Universidad', 'queries': 589},
      {'name': 'Estacion de Tren', 'queries': 534},
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paradas Mas Consultadas',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...topStops.asMap().entries.map((entry) {
              final index = entry.key;
              final stop = entry.value;
              final percentage = (stop['queries'] as int) / 856;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: const Color(0xFF6B1B3D),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(stop['name'] as String),
                          ],
                        ),
                        Text(
                          '${stop['queries']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color.lerp(
                          const Color(0xFFE85A4F),
                          const Color(0xFF6B1B3D),
                          percentage,
                        )!,
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

  Widget _buildPeakHours(ThemeData theme) {
    final peakHours = [
      {'hour': '07:00-09:00', 'level': 0.9, 'label': 'Muy alto'},
      {'hour': '12:00-14:00', 'level': 0.7, 'label': 'Alto'},
      {'hour': '17:00-19:00', 'level': 0.95, 'label': 'Pico'},
      {'hour': '20:00-22:00', 'level': 0.5, 'label': 'Medio'},
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Horas Pico',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...peakHours.map((peak) {
              final level = peak['level'] as double;
              Color color;
              if (level >= 0.9) {
                color = Colors.red;
              } else if (level >= 0.7) {
                color = Colors.orange;
              } else {
                color = Colors.green;
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        peak['hour'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: level,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 12,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        peak['label'] as String,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
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
}
