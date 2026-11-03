import 'dart:async';

import 'package:flutter/material.dart';
import 'package:alzitrans/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/feature_tips_service.dart';
import '../services/impact_calculator.dart';

/// Tarjeta animada con un consejo para descubrir funciones de la app.
///
/// Aparece tras [delay] en el mapa, como mucho una vez cada
/// [FeatureTipsService.minInterval], y se va sola tras [visibleFor].
class FeatureTipCard extends StatefulWidget {
  const FeatureTipCard({
    super.key,
    required this.onAction,
    this.loadTotalTrips,
    this.delay = const Duration(seconds: 8),
    this.visibleFor = const Duration(seconds: 15),
    this.now,
  });

  /// Qué hacer al pulsar el botón del consejo (navegar a la función).
  final void Function(FeatureTip tip) onAction;

  /// Viajes totales del usuario (para el consejo del CO₂). Null = no se sabe.
  final Future<int?> Function()? loadTotalTrips;
  final Duration delay;
  final Duration visibleFor;

  /// Para tests.
  final DateTime Function()? now;

  @override
  State<FeatureTipCard> createState() => _FeatureTipCardState();
}

class _FeatureTipCardState extends State<FeatureTipCard> with SingleTickerProviderStateMixin {
  FeatureTip? _tip;
  int _trips = 0;
  Timer? _showTimer;
  Timer? _hideTimer;
  FeatureTipsService? _service;
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

  @override
  void initState() {
    super.initState();
    _showTimer = Timer(widget.delay, _maybeShow);
  }

  Future<void> _maybeShow() async {
    final prefs = await SharedPreferences.getInstance();
    _service = FeatureTipsService(prefs);
    int? trips;
    try {
      trips = await widget.loadTotalTrips?.call();
    } catch (_) {
      trips = null;
    }
    final now = (widget.now ?? DateTime.now)();
    final tip = _service!.pick(now: now, totalTrips: trips);
    if (!mounted || tip == null) return;
    await _service!.markShown(tip, now);
    if (!mounted) return;
    setState(() {
      _tip = tip;
      _trips = trips ?? 0;
    });
    _anim.forward(from: 0);
    _hideTimer = Timer(widget.visibleFor, _hide);
  }

  Future<void> _hide() async {
    _hideTimer?.cancel();
    if (!mounted) return;
    await _anim.reverse();
    if (mounted) setState(() => _tip = null);
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  ({IconData icon, String title, String body, String action}) _content(AppLocalizations l, FeatureTip tip) {
    switch (tip) {
      case FeatureTip.games:
        return (icon: Icons.videogame_asset, title: l.tipGamesTitle, body: l.tipGamesBody, action: l.tipGamesAction);
      case FeatureTip.support:
        return (icon: Icons.support_agent, title: l.tipSupportTitle, body: l.tipSupportBody, action: l.tipSupportAction);
      case FeatureTip.co2:
        return (
          icon: Icons.eco,
          title: l.tipCo2Title,
          body: l.tipCo2Body(_trips, ImpactCalculator(_trips).co2Formatted),
          action: l.tipCo2Action,
        );
      case FeatureTip.alerts:
        return (icon: Icons.notifications_active, title: l.tipAlertsTitle, body: l.tipAlertsBody, action: l.tipAlertsAction);
      case FeatureTip.planner:
        return (icon: Icons.alt_route, title: l.tipPlannerTitle, body: l.tipPlannerBody, action: l.tipPlannerAction);
      case FeatureTip.shop:
        return (icon: Icons.checkroom, title: l.tipShopTitle, body: l.tipShopBody, action: l.tipShopAction);
      case FeatureTip.share:
        return (icon: Icons.share_location, title: l.tipShareTitle, body: l.tipShareBody, action: l.tipShareAction);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tip = _tip;
    if (tip == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final c = _content(l, tip);
    const burgundy = Color(0xFF6B1B3D);
    final curved = CurvedAnimation(parent: _anim, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);

    return SlideTransition(
      position: Tween(begin: const Offset(0, 1.2), end: Offset.zero).animate(curved),
      child: FadeTransition(
        opacity: _anim,
        child: Material(
          key: Key('feature_tip_${tip.name}'),
          elevation: 6,
          borderRadius: BorderRadius.circular(18),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: burgundy.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(c.icon, color: burgundy),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(c.body, style: TextStyle(color: Colors.grey[800], height: 1.3)),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('feature_tip_close'),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: l.tipClose,
                      onPressed: _hide,
                    ),
                  ],
                ),
                // Wrap: si los dos botones no caben (pantalla estrecha, texto
                // grande, idioma), el segundo baja de línea en vez de desbordar.
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    TextButton(
                      key: const Key('feature_tip_never'),
                      onPressed: () async {
                        await _service?.disableForever();
                        _hide();
                      },
                      child: Text(l.tipDontShowAgain, style: TextStyle(color: Colors.grey[600])),
                    ),
                    FilledButton(
                      key: const Key('feature_tip_action'),
                      style: FilledButton.styleFrom(backgroundColor: burgundy),
                      onPressed: () {
                        _hide();
                        if (tip != FeatureTip.alerts) widget.onAction(tip);
                      },
                      child: Text(c.action),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
