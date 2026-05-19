import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/providers/live_trip_provider.dart';
import '../models/live_trip.dart';
import '../services/live_trip_service.dart';
import '../theme/app_theme.dart';

/// Pantalla con el listado de viajes compartidos pasados del usuario.
///
/// Solo lista los que ya están terminados (`ended` o `expired`) — el activo
/// aparece como banner en home. Datos: GET /api/live-trips/history paginado.
class LiveTripHistoryScreen extends ConsumerStatefulWidget {
  const LiveTripHistoryScreen({super.key});

  @override
  ConsumerState<LiveTripHistoryScreen> createState() =>
      _LiveTripHistoryScreenState();
}

class _LiveTripHistoryScreenState
    extends ConsumerState<LiveTripHistoryScreen> {
  // Formato numérico universal (no requiere inicializar locale data de intl).
  final _dateFormatter = DateFormat('dd/MM/yyyy · HH:mm');
  List<LiveTripHistoryEntry>? _history;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = ref.read(liveTripServiceProvider);
      final list = await svc.getHistory();
      if (!mounted) return;
      setState(() {
        _history = list;
        _loading = false;
      });
    } on LiveTripException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar el histórico: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AlzitransColors.background,
      appBar: AppBar(
        title: const Text('Mis viajes compartidos'),
        backgroundColor: AlzitransColors.burgundy,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _load);
    }
    final list = _history ?? const [];
    if (list.isEmpty) {
      return _EmptyView();
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _TripCard(
        entry: list[i],
        dateFormatter: _dateFormatter,
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final LiveTripHistoryEntry entry;
  final DateFormat dateFormatter;

  const _TripCard({required this.entry, required this.dateFormatter});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  entry.status == LiveTripStatus.expired
                      ? Icons.timer_off
                      : Icons.share_location,
                  color: entry.status == LiveTripStatus.expired
                      ? AlzitransColors.warning
                      : AlzitransColors.success,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.destinationStopName ?? 'Viaje compartido',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (entry.line != null) _LineChip(line: entry.line!),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.event, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  dateFormatter.format(entry.startedAt.toLocal()),
                  style: const TextStyle(color: Colors.grey, fontSize: 12.5),
                ),
                const SizedBox(width: 12),
                if (entry.durationMin != null) ...[
                  const Icon(Icons.timer, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${entry.durationMin} min',
                    style: const TextStyle(color: Colors.grey, fontSize: 12.5),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            _StatusBadge(status: entry.status),
          ],
        ),
      ),
    );
  }
}

class _LineChip extends StatelessWidget {
  final String line;
  const _LineChip({required this.line});

  Color _color() => switch (line) {
        'L1' => AlzitransColors.lineL1,
        'L2' => AlzitransColors.lineL2,
        'L3' => AlzitransColors.lineL3,
        _ => AlzitransColors.burgundy,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _color(),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        line,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final LiveTripStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      LiveTripStatus.ended => ('Finalizado por ti', AlzitransColors.success),
      LiveTripStatus.expired => ('Caducó (6h)', AlzitransColors.warning),
      LiveTripStatus.active => ('Activo', AlzitransColors.burgundy),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      // ListView para que RefreshIndicator funcione aunque esté vacío.
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      children: const [
        Icon(Icons.share_location_outlined, size: 72, color: Colors.grey),
        SizedBox(height: 16),
        Text(
          'Aún no has compartido ningún viaje',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8),
        Text(
          'Cuando uses la opción "Compartir mi viaje" desde el planificador, '
          'verás aquí todos los pasados.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AlzitransColors.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
