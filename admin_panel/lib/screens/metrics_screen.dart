import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';

/// Panel de Métricas v2 — consume los endpoints /api/stats/* nuevos.
/// Robusto frente a datos vacíos (los endpoints devuelven {} si fallan).
class MetricsScreen extends StatefulWidget {
  const MetricsScreen({super.key});

  @override
  State<MetricsScreen> createState() => _MetricsScreenState();
}

class _MetricsScreenState extends State<MetricsScreen> {
  final _api = ApiService();
  String _period = 'month';
  bool _loading = true;

  Map<String, dynamic> _retention = {};
  Map<String, dynamic> _heatmap = {};
  Map<String, dynamic> _payments = {};
  Map<String, dynamic> _routes = {};
  Map<String, dynamic> _premium = {};
  Map<String, dynamic> _game = {};
  Map<String, dynamic> _liveShare = {};
  Map<String, dynamic> _support = {};
  Map<String, dynamic> _webApp = {};
  Map<String, dynamic> _revenue = {};

  static const _burgundy = Color(0xFF6B1B3D);
  static const _coral = Color(0xFFE85A4F);
  static const _teal = Color(0xFF2E7D32);
  static const _blue = Color(0xFF1565C0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getRetention(),
        _api.getHeatmap(_period),
        _api.getPayments(_period),
        _api.getRouteStats(_period),
        _api.getPremiumStats(),
        _api.getGameStats(),
        _api.getLiveShareStats(_period),
        _api.getSupportStats(_period),
        _api.getWebAppStats(_period),
        _api.getRevenue(),
      ]);
      if (!mounted) return;
      setState(() {
        _retention = results[0];
        _heatmap = results[1];
        _payments = results[2];
        _routes = results[3];
        _premium = results[4];
        _game = results[5];
        _liveShare = results[6];
        _support = results[7];
        _webApp = results[8];
        _revenue = results[9];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Helpers ──
  List<Map<String, dynamic>> _rows(dynamic v) {
    if (v is List) return v.map((e) => Map<String, dynamic>.from(e)).toList();
    return [];
  }

  num _n(dynamic v) => v is num ? v : (num.tryParse('${v ?? 0}') ?? 0);

  String _shortDay(dynamic d) {
    final s = '${d ?? ''}';
    final base = s.contains('T') ? s.split('T').first : s;
    final parts = base.split('-');
    return parts.length == 3 ? '${parts[2]}/${parts[1]}' : base;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _header(),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _revenueSection(),
              const SizedBox(height: 28),
              _retentionSection(),
              const SizedBox(height: 28),
              _webAppSection(),
              const SizedBox(height: 28),
              _heatmapSection(),
              const SizedBox(height: 28),
              _routesSection(),
              const SizedBox(height: 28),
              _paymentsPremiumRow(),
              const SizedBox(height: 28),
              _liveShareSection(),
              const SizedBox(height: 28),
              _gameSection(),
              const SizedBox(height: 28),
              _supportSection(),
              const SizedBox(height: 40),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        const Icon(Icons.insights, color: _burgundy, size: 28),
        const SizedBox(width: 10),
        const Text('Métricas',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const Spacer(),
        DropdownButton<String>(
          value: _period,
          items: const [
            DropdownMenuItem(value: 'week', child: Text('7 días')),
            DropdownMenuItem(value: 'month', child: Text('30 días')),
            DropdownMenuItem(value: 'year', child: Text('1 año')),
          ],
          onChanged: (v) {
            if (v != null) {
              setState(() => _period = v);
              _load();
            }
          },
        ),
        const SizedBox(width: 12),
        IconButton(
          tooltip: 'Actualizar',
          icon: const Icon(Icons.refresh),
          onPressed: _load,
        ),
      ],
    );
  }

  // ── Secciones ──
  Widget _revenueSection() {
    final configured = _revenue['configured'] == true;
    if (!configured) {
      final reason = '${_revenue['reason'] ?? 'Pendiente de configurar la API de Google (AdMob/AdSense).'}';
      return _card(
        'Ingresos (AdMob + AdSense)',
        Row(
          children: [
            const Icon(Icons.payments_outlined, color: Colors.grey, size: 36),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ingresos no configurados',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(reason, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Añade las credenciales OAuth de Google en backend/.env (ver tools/google-oauth.js).',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final admob = _revenue['admob'];
    final adsense = _revenue['adsense'];
    final errors = Map<String, dynamic>.from(_revenue['errors'] ?? {});
    return _card(
      'Ingresos (estimados, EUR)',
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _revenueBlock('AdMob (app)', admob, errors['admob'], _coral)),
          const SizedBox(width: 20),
          Expanded(child: _revenueBlock('AdSense (web)', adsense, errors['adsense'], _blue)),
        ],
      ),
    );
  }

  Widget _revenueBlock(String title, dynamic data, dynamic error, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 10),
        if (data == null)
          _empty(error != null ? 'Error: $error' : 'Sin datos todavía.')
        else
          _kpiWrap([
            _kpi('Hoy', '${_n(data['today']).toStringAsFixed(2)} €', '', color),
            _kpi('Ayer', '${_n(data['yesterday']).toStringAsFixed(2)} €', '', Colors.grey),
            _kpi('7 días', '${_n(data['last7']).toStringAsFixed(2)} €', '', _teal),
            _kpi('30 días', '${_n(data['last30']).toStringAsFixed(2)} €', '', _burgundy),
            _kpi('Impresiones', _n(data['impressions30']).toString(), '30 días', Colors.indigo),
            _kpi('Clics', _n(data['clicks30']).toString(), '30 días', Colors.teal),
          ]),
      ],
    );
  }

  Widget _retentionSection() {
    final series = _rows(_retention['dailyActive']);
    return _card(
      'Retención — usuarios activos',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kpiWrap([
            _kpi('DAU', _n(_retention['dau']).toString(), 'activos hoy', _burgundy),
            _kpi('WAU', _n(_retention['wau']).toString(), '7 días', _teal),
            _kpi('MAU', _n(_retention['mau']).toString(), '30 días', _blue),
            _kpi('Stickiness', '${_n(_retention['stickiness'])}%', 'DAU/MAU', _coral),
            _kpi('Nuevos hoy', _n(_retention['newToday']).toString(), '', Colors.indigo),
            _kpi('Recurrentes hoy', _n(_retention['returningToday']).toString(), '', Colors.teal),
          ]),
          const SizedBox(height: 16),
          if (series.length >= 2)
            _lineChart(
              series.map((e) => _n(e['active']).toDouble()).toList(),
              series.map((e) => _shortDay(e['day'])).toList(),
              _burgundy,
            )
          else
            _empty('Sin datos de actividad en el periodo.'),
        ],
      ),
    );
  }

  Widget _webAppSection() {
    final opens = _rows(_webApp['opensByDay']);
    final byPlatform = _rows(_webApp['byPlatform']);
    final byBrowser = _rows(_webApp['byBrowser']);
    return _card(
      'App web (alzitrans.es/app)',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kpiWrap([
            _kpi('Visitantes únicos', _n(_webApp['uniqueVisitors']).toString(), 'web app', _blue),
            _kpi('Eventos', _n(_webApp['totalEvents']).toString(), 'aperturas/visitas', _teal),
          ]),
          const SizedBox(height: 16),
          if (opens.length >= 2)
            _lineChart(
              opens.map((e) => _n(e['opens']).toDouble()).toList(),
              opens.map((e) => _shortDay(e['day'])).toList(),
              _blue,
            )
          else
            _empty('Aún no hay aperturas registradas de la app web.'),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _barList('Por plataforma', byPlatform, 'platform', 'cnt', _teal)),
              const SizedBox(width: 20),
              Expanded(child: _barList('Por navegador', byBrowser, 'browser', 'cnt', _coral)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heatmapSection() {
    final cells = _rows(_heatmap['cells']);
    // matriz [dow][hour]
    final grid = List.generate(7, (_) => List<int>.filled(24, 0));
    int maxV = 0;
    for (final c in cells) {
      final d = _n(c['dow']).toInt();
      final h = _n(c['hour']).toInt();
      final v = _n(c['cnt']).toInt();
      if (d >= 0 && d < 7 && h >= 0 && h < 24) {
        grid[d][h] = v;
        if (v > maxV) maxV = v;
      }
    }
    const days = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
    return _card(
      'Mapa de calor de viajes (día × hora)',
      cells.isEmpty
          ? _empty('Sin viajes registrados en el periodo.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int d = 0; d < 7; d++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(width: 34, child: Text(days[d], style: const TextStyle(fontSize: 11))),
                        for (int h = 0; h < 24; h++)
                          Expanded(
                            child: Container(
                              height: 16,
                              margin: const EdgeInsets.all(1),
                              decoration: BoxDecoration(
                                color: maxV == 0
                                    ? Colors.grey[200]
                                    : Color.lerp(const Color(0xFFF0E6EC), _burgundy,
                                        grid[d][h] / maxV),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const SizedBox(width: 34),
                    Text('0h', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                    const Spacer(),
                    Text('12h', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                    const Spacer(),
                    Text('23h', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _routesSection() {
    final dests = _rows(_routes['topDestinations']);
    final routes = _rows(_routes['topRoutes']);
    return _card(
      'Rutas y destinos más usados',
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _barList('Destinos top', dests, 'destination', 'cnt', _burgundy)),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Trayectos top (origen → destino)',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                if (routes.isEmpty) _empty('Sin trayectos.'),
                for (final r in routes.take(8))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        _lineBadge('${r['line'] ?? ''}'),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${r['origin'] ?? ''} → ${r['destination'] ?? ''}',
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text('${_n(r['cnt'])}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentsPremiumRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _card(
            'Método de pago',
            _barList('', _rows(_payments['methods']), 'method', 'cnt', _teal),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _card(
            'Premium',
            Column(
              children: [
                _kpiWrap([
                  _kpi('Premium', _n(_premium['premiumUsers']).toString(), 'usuarios', _coral),
                  _kpi('Tasa', '${_n(_premium['premiumRate'])}%', 'de verificados', _burgundy),
                  _kpi('Verificados', _n(_premium['verifiedUsers']).toString(), '', _blue),
                  _kpi('Total', _n(_premium['totalUsers']).toString(), 'registros', Colors.grey),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _liveShareSection() {
    final err = _liveShare['etaAvgErrorMin'];
    return _card(
      'Compartir viaje en vivo + precisión del ETA',
      _kpiWrap([
        _kpi('Viajes compartidos', _n(_liveShare['total']).toString(), 'en periodo', _burgundy),
        _kpi('Activos ahora', _n(_liveShare['active']).toString(), '', _teal),
        _kpi('Usuarios distintos', _n(_liveShare['uniqueSharers']).toString(), 'lo usaron', _blue),
        _kpi('Duración media', '${_n(_liveShare['avgDurationMin'])} min', '', Colors.indigo),
        _kpi('Error ETA medio', err == null ? '—' : '${_n(err)} min', 'planificador', _coral),
        _kpi('Muestras ETA', _n(_liveShare['etaSamples']).toString(), '', Colors.grey),
      ]),
    );
  }

  Widget _gameSection() {
    final buckets = _rows(_game['coinBuckets']);
    final skins = _rows(_game['topSkins']);
    return _card(
      'Gamificación (Albus)',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kpiWrap([
            _kpi('Jugadores', _n(_game['usersWithCoins']).toString(), 'con monedas', _coral),
            _kpi('Media monedas', _n(_game['avgCoinsAmongPlayers']).toString(), 'por jugador', _burgundy),
          ]),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _barList('Monedas por usuario', buckets, 'bucket', 'cnt', _teal)),
              const SizedBox(width: 20),
              Expanded(child: _barList('Skins más poseídos', skins, 'skin', 'cnt', _coral)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _supportSection() {
    final tags = _rows(_support['byTag']);
    final avg = _support['avgFirstResponseHours'];
    return _card(
      'Soporte (feedback)',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kpiWrap([
            _kpi('Tickets', _n(_support['total']).toString(), 'en periodo', _burgundy),
            _kpi('Abiertos', _n(_support['open']).toString(), '', _coral),
            _kpi('Cerrados', _n(_support['closed']).toString(), '', _teal),
            _kpi('1ª respuesta', avg == null ? '—' : '${_n(avg)} h', 'media', _blue),
          ]),
          const SizedBox(height: 16),
          _barList('Por categoría (tag)', tags, 'tag', 'cnt', _burgundy),
        ],
      ),
    );
  }

  // ── Widgets reutilizables ──
  Widget _card(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _kpiWrap(List<Widget> items) =>
      Wrap(spacing: 14, runSpacing: 14, children: items);

  Widget _kpi(String label, String value, String sub, Color color) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          if (sub.isNotEmpty)
            Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }

  /// Lista de barras horizontales proporcionales (sin fl_chart, robusto).
  Widget _barList(String title, List<Map<String, dynamic>> data, String labelKey,
      String valueKey, Color color) {
    if (data.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
          ],
          _empty('Sin datos.'),
        ],
      );
    }
    final maxV = data.map((e) => _n(e[valueKey])).fold<num>(1, (p, c) => c > p ? c : p);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
        ],
        for (final e in data.take(10))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('${e[labelKey] ?? '—'}',
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text('${_n(e[valueKey])}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_n(e[valueKey]) / maxV).toDouble().clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: color.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _lineChart(List<double> values, List<String> labels, Color color) {
    double maxY = 0;
    for (final v in values) {
      if (v > maxY) maxY = v;
    }
    maxY = maxY <= 0 ? 1 : maxY * 1.2;
    final step = (values.length / 6).ceil().clamp(1, 999);
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          clipData: const FlClipData.all(),
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey[200]!, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (v, meta) => Text('${v.toInt()}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: 1,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                  if (i % step != 0 && i != labels.length - 1) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(labels[i],
                        style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (int i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
              ],
              isCurved: true,
              color: color,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: color.withOpacity(0.1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lineBadge(String line) {
    final colors = {'L1': _blue, 'L2': _teal, 'L3': const Color(0xFFE65100)};
    final c = colors[line] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(10)),
      child: Text(line.isEmpty ? '—' : line,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _empty(String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(msg, style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic)),
      );
}
