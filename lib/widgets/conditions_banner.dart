import 'dart:async';

import 'package:flutter/material.dart';
import 'package:alzitrans/l10n/app_localizations.dart';

import '../services/traffic_service.dart';
import '../services/weather_service.dart';

/// Aviso de lluvia o tráfico denso en la pantalla del mapa.
///
/// Tarjeta blanca y compacta con una franja de color: entra deslizándose, se
/// queda unos segundos y luego se encoge a un chip que se puede tocar para
/// volver a verla. Se actualiza cada [refreshEvery]. Si no llueve ni hay
/// tráfico (o no se pudo consultar) no ocupa nada.
class ConditionsBanner extends StatefulWidget {
  const ConditionsBanner({
    super.key,
    this.loadWeather,
    this.loadTraffic,
    this.refreshEvery = const Duration(minutes: 10),
    this.collapseAfter = const Duration(seconds: 10),
  });

  /// Para tests: sustituyen a las consultas reales.
  final Future<WeatherStatus> Function()? loadWeather;
  final Future<TrafficStatus> Function()? loadTraffic;
  final Duration refreshEvery;
  final Duration collapseAfter;

  @override
  State<ConditionsBanner> createState() => _ConditionsBannerState();
}

class _Condition {
  const _Condition(this.icon, this.color, this.title, this.body, this.chip);
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String chip;
}

class _ConditionsBannerState extends State<ConditionsBanner> with SingleTickerProviderStateMixin {
  bool _raining = false;
  bool _traffic = false;
  bool _expanded = true;
  Timer? _refresh;
  Timer? _collapse;
  late final AnimationController _entry = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

  static const _rainColor = Color(0xFF1565C0);
  static const _trafficColor = Color(0xFFE65100);

  @override
  void initState() {
    super.initState();
    _load();
    _refresh = Timer.periodic(widget.refreshEvery, (_) => _load());
  }

  /// Nunca lanza: si una consulta falla se trata como "sin datos".
  static Future<T> _safe<T>(Future<T> Function() load, T fallback) async {
    try {
      return await load();
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _load() async {
    final weatherF = _safe<WeatherStatus>(widget.loadWeather ?? WeatherService().fetchAlzira, const WeatherStatus.unknown());
    final trafficF = _safe<TrafficStatus>(widget.loadTraffic ?? TrafficService().fetchAlzira, const TrafficStatus.unknown());
    final weather = await weatherF;
    final traffic = await trafficF;
    if (!mounted) return;
    final raining = weather.isRaining;
    final busy = traffic.hasIncidents;
    final isNew = (raining && !_raining) || (busy && !_traffic);
    setState(() {
      _raining = raining;
      _traffic = busy;
      if (isNew) _expanded = true;
    });
    if (isNew) _show();
  }

  void _show() {
    _entry.forward(from: 0);
    _collapse?.cancel();
    _collapse = Timer(widget.collapseAfter, () {
      if (mounted) setState(() => _expanded = false);
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _collapse?.cancel();
    _entry.dispose();
    super.dispose();
  }

  List<_Condition> _conditions(AppLocalizations l) => [
        if (_raining) _Condition(Icons.water_drop_rounded, _rainColor, l.conditionsRainTitle, l.conditionsRainBody, l.conditionsRainChip),
        if (_traffic) _Condition(Icons.traffic_rounded, _trafficColor, l.conditionsTrafficTitle, l.conditionsTrafficBody, l.conditionsTrafficChip),
      ];

  @override
  Widget build(BuildContext context) {
    if (!_raining && !_traffic) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final items = _conditions(l);
    final curved = CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic);
    return SlideTransition(
      position: Tween(begin: const Offset(0, -0.4), end: Offset.zero).animate(curved),
      child: FadeTransition(
        opacity: _entry,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: Alignment.topLeft,
          child: _expanded ? _card(context, items) : _chip(context, items),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, List<_Condition> items) {
    final l = AppLocalizations.of(context);
    final accent = items.first.color;
    return Container(
      key: const Key('conditions_card'),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 0, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final c in items)
                      Padding(
                        padding: EdgeInsets.only(bottom: c == items.last ? 0 : 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(color: c.color.withValues(alpha: 0.12), shape: BoxShape.circle),
                              child: Icon(c.icon, size: 18, color: c.color),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF2D1B25))),
                                  const SizedBox(height: 1),
                                  Text(c.body, style: TextStyle(fontSize: 12.5, height: 1.25, color: Colors.grey[700])),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              key: const Key('conditions_close'),
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded, size: 18, color: Colors.grey[500]),
              tooltip: l.tipClose,
              onPressed: () {
                _collapse?.cancel();
                setState(() => _expanded = false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, List<_Condition> items) {
    final l = AppLocalizations.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Material(
          color: Colors.white,
          shape: const StadiumBorder(),
          elevation: 2,
          shadowColor: Colors.black26,
          child: InkWell(
            key: const Key('conditions_chip'),
            customBorder: const StadiumBorder(),
            onTap: () => setState(() => _expanded = true),
            child: Semantics(
              label: l.conditionsShowMore,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final c in items) ...[
                      if (c != items.first) const SizedBox(width: 10),
                      Icon(c.icon, size: 16, color: c.color),
                      const SizedBox(width: 4),
                      Text(c.chip, style: TextStyle(color: c.color, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
