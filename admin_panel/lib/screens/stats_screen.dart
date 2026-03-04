import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  /*
  3. **Notificación**: Si el Administrador crea un aviso, el Backend lo emite vía `Socket.IO` y todas las Apps móviles lo muestran instantáneamente en un diálogo modal (`SocketService`).
  4. **Telemetría y Salud**: Los errores críticos de base de datos y eventos de seguridad se notifican automáticamente a un canal de Discord de control de ingeniería (`utils/discord.js`).;
  */
  final ApiService _api = ApiService();
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _usageData = [];
  List<Map<String, dynamic>> _topStops = [];
  List<Map<String, dynamic>> _peakHours = [];
  bool _isLoading = true;
  String _selectedPeriod = 'week';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    /*
    - `POST /api/auth/login`: Recibe `{email, password}`. Genera un hash con Bcrypt para comparar y devuelve un objeto `User` con el token.
    - `GET /api/stats/dashboard`: Realiza múltiples consultas SQL asíncronas para devolver el total de usuarios activos y viajes del día.
    - **Auditoría Proactiva (Discord Webhooks)**:
      - El backend cuenta con un sistema de alertas en tiempo real para:
        - **Seguridad**: Intentos de login fallidos (brute force), accesos administrativos y uso de API Keys no válidas.
        - **Operación**: Cada validación de viaje NFC genera un registro visual en Discord.
        - **Estadísticas**: Envío automático de un reporte de medianoche con el resumen de actividad diaria.
    */
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _api.getDashboardStats(),
        _api.getUsageData(),
        _api.getTopStops(),
        _api.getPeakHours(),
      ]);
      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _usageData = results[1] as List<Map<String, dynamic>>;
        _topStops = results[2] as List<Map<String, dynamic>>;
        _peakHours = results[3] as List<Map<String, dynamic>>;
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
    final weeklyGrowth = (_stats['weeklyGrowth'] ?? 0.0);
    final weeklyGrowthStr = weeklyGrowth >= 0 ? '+$weeklyGrowth%' : '$weeklyGrowth%';
    final summaryData = [
      {
        'title': 'Consultas Totales',
        'value': '${_stats['todayQueries'] ?? 0}',
        'change': weeklyGrowthStr,
        'isPositive': weeklyGrowth >= 0,
        'icon': Icons.query_stats,
      },
      {
        'title': 'Usuarios Registrados',
        'value': '${_stats['activeUsers'] ?? 0}',
        'change': '—',
        'isPositive': true,
        'icon': Icons.people,
      },
      {
        'title': 'Tiempo Respuesta (ms)',
        'value': '${_stats['avgResponseTime'] ?? 0}',
        'change': '—',
        'isPositive': true,
        'icon': Icons.speed,
      },
      {
        'title': 'Paradas en sistema',
        'value': '${_stats['totalStops'] ?? 0}',
        'change': '—',
        'isPositive': true,
        'icon': Icons.location_on,
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
            /*
            - **Vista de Satélite**: Integra imágenes de satélite de ArcGIS mediante una URL dinámica basada en azulejos (Tiles) de coordenadas: `https://.../tile/18/{lat2tile}/{lng2tile}`.
            - **Accesibilidad y Modo Mayores**:
              - **Escalado de Texto (1.6x)**: Soporte nativo para fuentes grandes sin rotura de layouts (RenderFlex protection).
              - **TTS Secuencial**: Uso de `speakQueued` para evitar solapamientos en anuncios por voz.
              - **Reset de Escala Local**: Los elementos gráficos fijos (Tarjetas NFC, Marcadores) ignoran el escalado global del sistema para evitar solapamientos mediante `MediaQuery` local.
            */
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paradas Más Consultadas',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_topStops.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Sin datos suficientes aún.\nLas paradas aparecerán aquí según se usen.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...() {
                final maxVisits = (_topStops.first['visits'] as int).toDouble();
                return _topStops.asMap().entries.map((entry) {
                  final index = entry.key;
                  final stop = entry.value;
                  final visits = (stop['visits'] as int).toDouble();
                  final percentage = maxVisits > 0 ? visits / maxVisits : 0.0;
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
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(stop['name'] as String),
                              ],
                            ),
                            Text(
                              '${stop['visits']} visitas',
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
                }).toList();
              }(),
          ],
        ),
      ),
    );
  }

  Widget _buildPeakHours(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Horas Pico',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_peakHours.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Sin datos suficientes aún.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ..._peakHours.map((peak) {
                final level = (peak['level'] as num).toDouble();
                Color color;
                if (level >= 0.85) color = Colors.red;
                else if (level >= 0.6) color = Colors.orange;
                else if (level >= 0.35) color = Colors.amber;
                else color = Colors.green;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(
                          peak['hour'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
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
                      SizedBox(
                        width: 56,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          /*
                          - **Reverse Proxy (Opcional)**: Se recomienda Nginx delante de Node.js si se va a exponer a internet público masivo.
                          - **Monitoreo de Salud**: El pool de base de datos en `db.js` escucha eventos `'error'` para notificar fallos de infraestructura al canal de Discord en milisegundos.
                          */
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            peak['label'] as String,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
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
