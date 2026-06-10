import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:alzitrans/l10n/app_localizations.dart';

import '../core/providers/game_currency_provider.dart';
import '../core/providers/stops_provider.dart';
import '../core/providers/trip_planner_provider.dart';
import '../models/bus_stop.dart';
import '../models/trip_plan.dart';
import '../theme/app_theme.dart';
import '../widgets/albus_mascot.dart';
import 'albus_shop_screen.dart';
import 'share_trip_screen.dart';

/// Pantalla del planificador A → B con Albus de guía.
///
/// Flujo:
/// 1. Usuario abre la pantalla → Albus saluda en estado idle.
/// 2. Usuario selecciona parada de origen y destino con autocompletado.
/// 3. Pulsa "Buscar ruta" → Albus pasa a "pensando" + spinner.
/// 4. Servicio devuelve hasta 3 alternativas → Albus pasa a "hablando" y
///    muestra la primera ruta con pasos. Las otras quedan colapsables abajo.
///
/// Sin backend nuevo — todo en cliente con `assets/stops.json` + `routes/`.
class TripPlannerScreen extends ConsumerStatefulWidget {
  const TripPlannerScreen({super.key});

  @override
  ConsumerState<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends ConsumerState<TripPlannerScreen> {
  BusStop? _origin;
  BusStop? _destination;
  List<TripPlan>? _plans;
  bool _isSearching = false;
  bool _isLocating = false;
  String? _errorMsg;

  /// Coordenadas del usuario cuando el origen es "Mi ubicación". Se pasa al
  /// motor para que añada un WalkStep inicial desde la posición del usuario
  /// hasta la parada más cercana (que es la que se setea como _origin).
  /// Null cuando el usuario elige una parada concreta del picker.
  ({double lat, double lng})? _originUserCoord;

  AlbusState _albusState = AlbusState.idle;
  // Inicializado vacío y rellenado en didChangeDependencies (necesita context).
  String _albusMessage = '';
  bool _albusInitialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_albusInitialised) {
      _albusMessage = AppLocalizations.of(context)!.albusGreeting;
      _albusInitialised = true;
    }
  }

  Future<void> _search() async {
    final l = AppLocalizations.of(context)!;
    if (_origin == null || _destination == null) {
      setState(() {
        _errorMsg = l.chooseOriginAndDest;
        _albusState = AlbusState.sad;
        _albusMessage = l.albusNeedsOriginDest;
      });
      return;
    }
    if (_origin!.id == _destination!.id) {
      setState(() {
        _errorMsg = l.sameStopError;
        _albusState = AlbusState.thinking;
        _albusMessage = l.albusAlreadyThere;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMsg = null;
      _plans = null;
      _albusState = AlbusState.thinking;
      _albusMessage = l.albusSearchingRoute;
    });

    try {
      final service = ref.read(tripPlannerServiceProvider);
      final results = await service.plan(
        originStopId: _origin!.id,
        destinationStopId: _destination!.id,
        // Si el usuario eligió "Mi ubicación", el motor añadirá un WalkStep
        // inicial desde la coordenada GPS hasta la parada origen.
        originCoord: _originUserCoord,
      );

      if (!mounted) return;

      if (results.isEmpty) {
        if (!mounted) return;
        final l2 = AppLocalizations.of(context)!;
        setState(() {
          _isSearching = false;
          _plans = [];
          _albusState = AlbusState.sad;
          _albusMessage = l2.albusNoRoute;
        });
        return;
      }

      if (!mounted) return;
      final l2 = AppLocalizations.of(context)!;
      setState(() {
        _isSearching = false;
        _plans = results;
        _albusState = AlbusState.happy;
        _albusMessage = results.length == 1
            ? l2.albusOneRoute
            : l2.albusMultipleRoutes(results.length);
      });
    } catch (e) {
      if (!mounted) return;
      final l2 = AppLocalizations.of(context)!;
      setState(() {
        _isSearching = false;
        _errorMsg = l2.searchError(e.toString());
        _albusState = AlbusState.sad;
        _albusMessage = l2.albusCantCalculate;
      });
    }
  }

  void _swapOriginDestination() {
    if (_origin == null && _destination == null) return;
    setState(() {
      final tmp = _origin;
      _origin = _destination;
      _destination = tmp;
      _plans = null;
      _errorMsg = null;
      // Al intercambiar perdemos el "Mi ubicación" — el nuevo origen es una
      // parada concreta del usuario, no su GPS.
      _originUserCoord = null;
      _albusState = AlbusState.talking;
      _albusMessage = AppLocalizations.of(context)!.albusSwapped;
    });
  }

  /// Pide GPS, encuentra la parada más cercana, la pone como origen y guarda
  /// las coordenadas exactas del usuario para que el motor añada un WalkStep
  /// inicial. Si algo falla, muestra mensaje con Albus triste.
  Future<void> _useMyLocation(List<BusStop> stops) async {
    final l = AppLocalizations.of(context)!;
    setState(() {
      _isLocating = true;
      _errorMsg = null;
      _albusState = AlbusState.thinking;
      _albusMessage = l.albusFindingYou;
    });

    try {
      // Verificar servicio + permiso.
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw l.enableLocationRetry;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw l.noLocationPermission;
      }

      // Obtener posición actual (con timeout para que no se quede colgado).
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      // Buscar la parada más cercana.
      final nearest = _findNearestStop(stops, pos.latitude, pos.longitude);
      if (nearest == null) {
        throw l.noStopsNearYou;
      }
      final distM = _haversineM(
        pos.latitude, pos.longitude, nearest.lat, nearest.lng);

      if (!mounted) return;
      final l2 = AppLocalizations.of(context)!;
      setState(() {
        _origin = nearest;
        _originUserCoord = (lat: pos.latitude, lng: pos.longitude);
        _isLocating = false;
        _plans = null;
        _albusState = AlbusState.happy;
        _albusMessage = distM < 80
            ? l2.veryCloseToStop(nearest.name)
            : l2.nearestStopIs(nearest.name, distM.round());
      });
    } catch (e) {
      if (!mounted) return;
      final l2 = AppLocalizations.of(context)!;
      setState(() {
        _isLocating = false;
        _errorMsg = e.toString();
        _albusState = AlbusState.sad;
        _albusMessage = l2.couldntFindYou;
      });
    }
  }

  BusStop? _findNearestStop(List<BusStop> stops, double lat, double lng) {
    BusStop? best;
    double bestDist = double.infinity;
    for (final s in stops) {
      final d = _haversineM(lat, lng, s.lat, s.lng);
      if (d < bestDist) {
        bestDist = d;
        best = s;
      }
    }
    // Si la parada más cercana está a >2 km, probablemente no estamos en
    // Alzira → devolvemos null para que el caller muestre un error útil.
    if (bestDist > 2000) return null;
    return best;
  }

  double _haversineM(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    double toRad(double d) => d * math.pi / 180;
    final dLat = toRad(lat2 - lat1);
    final dLng = toRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(toRad(lat1)) * math.cos(toRad(lat2)) *
            math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final stopsAsync = ref.watch(stopsProvider);
    final coins = ref.watch(gameCurrencyProvider);

    return Scaffold(
      backgroundColor: AlzitransColors.background,
      appBar: AppBar(
        title: Text(l.plannerTitle),
        backgroundColor: AlzitransColors.burgundy,
        foregroundColor: Colors.white,
        actions: [
          // Acceso a la tienda de skins de Albus — mismo patrón que en
          // GamesHubScreen para que el usuario pueda cambiar el aspecto
          // sin tener que salir al menú de juegos.
          IconButton(
            icon: const Icon(Icons.checkroom, color: Colors.white, size: 26),
            tooltip: l.wardrobeTooltip,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AlbusShopScreen()),
            ),
          ),
          // Indicador de monedas — visible aquí también porque el
          // planificador es una de las pantallas más visitadas y al
          // usuario le interesa ver su monedero de un vistazo.
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      '$coins',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: stopsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.errorLoadingStops(e.toString()))),
        data: (stops) => _buildBody(stops),
      ),
    );
  }

  Widget _buildBody(List<BusStop> stops) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAlbusHeader(),
          const SizedBox(height: 20),
          _buildStopSelectors(stops),
          const SizedBox(height: 16),
          _buildSearchButton(),
          if (_errorMsg != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: _errorMsg!),
          ],
          const SizedBox(height: 24),
          if (_isSearching) const Center(child: CircularProgressIndicator()),
          if (_plans != null && _plans!.isNotEmpty) _buildResults(_plans!),
        ],
      ),
    );
  }

  Widget _buildAlbusHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AlbusMascot(state: _albusState, size: 110),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 18),
            child: AlbusBubble(text: _albusMessage),
          ),
        ),
      ],
    );
  }

  Widget _buildStopSelectors(List<BusStop> stops) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Botón "Usar mi ubicación" — atajo que rellena el origen con la
            // parada más cercana usando GPS.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLocating ? null : () => _useMyLocation(stops),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AlzitransColors.burgundy,
                  side: const BorderSide(
                    color: AlzitransColors.burgundy, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                ),
                icon: _isLocating
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                          color: AlzitransColors.burgundy, strokeWidth: 2),
                      )
                    : const Icon(Icons.gps_fixed, size: 18),
                label: Text(
                  _isLocating
                      ? AppLocalizations.of(context)!.searchingYourLocation
                      : (_originUserCoord != null
                          ? AppLocalizations.of(context)!.usingYourLocation
                          : AppLocalizations.of(context)!.useMyLocationButton),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _StopPicker(
              label: _originUserCoord != null
                  ? AppLocalizations.of(context)!.fromNearestStop
                  : AppLocalizations.of(context)!.fromLabel,
              icon: _originUserCoord != null ? Icons.gps_fixed : Icons.my_location,
              stops: stops,
              selected: _origin,
              onPicked: (s) => setState(() {
                _origin = s;
                // Si el usuario elige una parada manualmente, dejamos de
                // tratarlo como "Mi ubicación" — ya no añadimos walk inicial.
                _originUserCoord = null;
                _albusState = AlbusState.talking;
                final l = AppLocalizations.of(context)!;
                _albusMessage = _destination == null
                    ? l.okFromStop(s.name)
                    : l.askDestRoute(_destination!.name);
              }),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(child: Divider()),
                IconButton(
                  tooltip: AppLocalizations.of(context)!.swap,
                  onPressed: _swapOriginDestination,
                  icon: const Icon(Icons.swap_vert, color: AlzitransColors.burgundy),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            _StopPicker(
              label: AppLocalizations.of(context)!.toLabel,
              icon: Icons.flag,
              stops: stops,
              selected: _destination,
              onPicked: (s) => setState(() {
                _destination = s;
                _albusState = AlbusState.talking;
                final l = AppLocalizations.of(context)!;
                _albusMessage = _origin == null
                    ? l.okToStop(s.name)
                    : l.readyToSearch;
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchButton() {
    return ElevatedButton.icon(
      onPressed: _isSearching ? null : _search,
      style: ElevatedButton.styleFrom(
        backgroundColor: AlzitransColors.burgundy,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.directions_bus),
      label: Text(AppLocalizations.of(context)!.searchRoute, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildResults(List<TripPlan> plans) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < plans.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _PlanCard(
            plan: plans[i],
            isPrimary: i == 0,
            index: i,
          ),
        ],
      ],
    );
  }
}

/// Selector de parada con un dialog de autocompletado.
class _StopPicker extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<BusStop> stops;
  final BusStop? selected;
  final ValueChanged<BusStop> onPicked;

  const _StopPicker({
    required this.label,
    required this.icon,
    required this.stops,
    required this.selected,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AlzitransColors.burgundy.withValues(alpha: 0.1),
        child: Icon(icon, color: AlzitransColors.burgundy),
      ),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(
        selected?.name ?? 'Toca para elegir',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: selected != null ? Colors.black87 : Colors.grey,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final picked = await showDialog<BusStop>(
          context: context,
          builder: (_) => _StopSearchDialog(stops: stops, title: label),
        );
        if (picked != null) onPicked(picked);
      },
    );
  }
}

class _StopSearchDialog extends StatefulWidget {
  final List<BusStop> stops;
  final String title;
  const _StopSearchDialog({required this.stops, required this.title});

  @override
  State<_StopSearchDialog> createState() => _StopSearchDialogState();
}

class _StopSearchDialogState extends State<_StopSearchDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.stops
        : widget.stops.where((s) => s.name.toLowerCase().contains(q)).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        height: 500,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Text(widget.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.searchStopByName,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final s = filtered[i];
                  return ListTile(
                    leading: const Icon(Icons.directions_bus,
                        color: AlzitransColors.burgundy),
                    title: Text(s.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(AppLocalizations.of(context)!.linesWithList(s.lines.join(", "))),
                    onTap: () => Navigator.of(context).pop(s),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final TripPlan plan;
  final bool isPrimary;
  final int index;
  const _PlanCard({required this.plan, required this.isPrimary, required this.index});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Card(
      elevation: isPrimary ? 6 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isPrimary ? AlzitransColors.burgundy : Colors.transparent,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _planHeader(l),
            const SizedBox(height: 12),
            ...plan.steps.asMap().entries.map((e) => _stepTile(e.key, e.value, l)),
            const SizedBox(height: 8),
            _shareButton(),
          ],
        ),
      ),
    );
  }

  /// Botón "Compartir este viaje" — toma el destino del ÚLTIMO BusStep del
  /// plan (la última parada en la que el usuario se baja) y la línea del
  /// PRIMER BusStep, y abre la pantalla de compartir prerellenada.
  Widget _shareButton() {
    final busSteps = plan.steps.whereType<BusStep>().toList();
    if (busSteps.isEmpty) return const SizedBox.shrink();
    final destination = busSteps.last.toStop;
    final line = busSteps.first.line;

    return Builder(
      builder: (context) => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ShareTripScreen(
                  destinationStop: destination,
                  line: line,
                  // Pasamos el ETA total del plan (incluye walk + bus +
                  // walk final). El backend lo usa como base de countdown
                  // en lugar de calcular straight-line del GPS al destino.
                  initialEtaMin: plan.totalDurationMin,
                ),
              ),
            );
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: AlzitransColors.burgundy,
            side: const BorderSide(color: AlzitransColors.burgundy, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.share_location, size: 18),
          label: Text(AppLocalizations.of(context)!.shareThisTripLive,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _planHeader(AppLocalizations l) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isPrimary
                ? AlzitransColors.burgundy
                : AlzitransColors.lightPurple,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isPrimary ? l.bestOption : l.optionN(index + 1),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Row(children: [
          const Icon(Icons.access_time, size: 16, color: Colors.grey),
          const SizedBox(width: 4),
          Text(l.minutesShort(plan.totalDurationMin),
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(width: 12),
        if (plan.transferCount > 0)
          Row(children: [
            const Icon(Icons.swap_horiz, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              l.transfersCount(plan.transferCount),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ]),
      ],
    );
  }

  Widget _stepTile(int idx, TripStep step, AppLocalizations l) {
    final isLast = idx == plan.steps.length - 1;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Indicador lateral con icono + línea vertical hasta el siguiente paso.
          Column(
            children: [
              _stepIcon(step),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey.shade300,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14, top: 4),
              child: _stepBody(step, l),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepIcon(TripStep step) {
    final (icon, color) = switch (step) {
      WalkStep() => (Icons.directions_walk, Colors.grey.shade600),
      BusStep s => (Icons.directions_bus, _lineColor(s.line)),
      TransferStep _ => (Icons.swap_horiz, AlzitransColors.warning),
      _ => (Icons.circle, Colors.grey),
    };
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _stepBody(TripStep step, AppLocalizations l) {
    if (step is WalkStep) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${step.fromLabel} → ${step.toLabel}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            l.walkingStep(step.distanceM, step.durationMin),
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          _AlbusHint(text: step.albusSays(l)),
        ],
      );
    }
    if (step is BusStep) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _lineColor(step.line),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(step.line,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Text(l.busStepDetail(step.stopsToCount, step.durationMin),
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          Text(l.boardAt(step.fromStop.name),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Text(l.alightAt(step.toStop.name),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 6),
          _AlbusHint(text: step.albusSays(l)),
        ],
      );
    }
    if (step is TransferStep) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.transferAt(step.atStop.name),
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AlzitransColors.warning)),
          const SizedBox(height: 4),
          Text(l.transferStep(step.fromLine, step.toLine, step.durationMin),
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          const SizedBox(height: 6),
          _AlbusHint(text: step.albusSays(l)),
        ],
      );
    }
    return Text(step.albusSays(l));
  }

  Color _lineColor(String line) => switch (line) {
        'L1' => AlzitransColors.lineL1,
        'L2' => AlzitransColors.lineL2,
        'L3' => AlzitransColors.lineL3,
        _ => AlzitransColors.burgundy,
      };
}

/// Burbuja pequeña con el dialogo de Albus para ese paso. Visualmente discreta
/// (no quita protagonismo al dato del paso) pero le da personalidad.
class _AlbusHint extends StatelessWidget {
  final String text;
  const _AlbusHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AlzitransColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Text('🚌', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 12.5,
                color: Color(0xFF555555),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AlzitransColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AlzitransColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AlzitransColors.error),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
