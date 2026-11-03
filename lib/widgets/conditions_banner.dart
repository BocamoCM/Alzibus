import 'dart:async';

import 'package:flutter/material.dart';
import 'package:alzitrans/l10n/app_localizations.dart';

import '../models/albus_skin.dart';
import '../services/traffic_service.dart';
import '../services/weather_service.dart';
import 'albus_mascot.dart';

/// Aviso de lluvia o tráfico denso en la pantalla del mapa.
///
/// Entra deslizándose con Albus (con chubasquero si llueve), se queda unos
/// segundos y luego se encoge a un chip que se puede tocar para volver a
/// verlo. Se actualiza cada [refreshEvery]. Si no llueve ni hay tráfico (o no
/// se pudo consultar) no ocupa nada.
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

class _ConditionsBannerState extends State<ConditionsBanner> with SingleTickerProviderStateMixin {
  bool _raining = false;
  bool _traffic = false;
  bool _expanded = true;
  Timer? _refresh;
  Timer? _collapse;
  late final AnimationController _entry = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));

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

  @override
  Widget build(BuildContext context) {
    if (!_raining && !_traffic) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final rain = _raining;
    final color = rain ? const Color(0xFF1565C0) : const Color(0xFFB26A00);
    final soft = rain ? const Color(0xFFE3F2FD) : const Color(0xFFFFF3E0);
    final text = [if (_raining) l.weatherRainLine, if (_traffic) l.trafficDelayLine].join('\n');

    final curved = CurvedAnimation(parent: _entry, curve: Curves.easeOutBack);
    return SlideTransition(
      position: Tween(begin: const Offset(0, -0.6), end: Offset.zero).animate(curved),
      child: FadeTransition(
        opacity: _entry,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: Alignment.topLeft,
          child: _expanded ? _card(context, text, color, soft, rain) : _chip(context, color, soft),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, String text, Color color, Color soft, bool rain) {
    final l = AppLocalizations.of(context);
    return Container(
      key: const Key('conditions_card'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: AlbusMascot(
              state: rain ? AlbusState.idle : AlbusState.thinking,
              size: 52,
              animated: true,
              skinOverride: rain ? AlbusSkin.findById('lluvia') : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color, height: 1.3, fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            key: const Key('conditions_close'),
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close, size: 18, color: color),
            tooltip: l.tipClose,
            onPressed: () {
              _collapse?.cancel();
              setState(() => _expanded = false);
            },
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, Color color, Color soft) {
    final l = AppLocalizations.of(context);
    final label = [if (_raining) '☔ ${l.conditionsRainChip}', if (_traffic) '🚗 ${l.conditionsTrafficChip}'].join('  ·  ');
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Material(
          color: soft,
          shape: StadiumBorder(side: BorderSide(color: color.withValues(alpha: 0.35))),
          elevation: 2,
          child: InkWell(
            key: const Key('conditions_chip'),
            customBorder: const StadiumBorder(),
            onTap: () => setState(() => _expanded = true),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(label, semanticsLabel: l.conditionsShowMore, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ),
    );
  }
}
