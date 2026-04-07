import 'package:flutter/material.dart';
import 'package:alzitrans/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/bus_alert_service.dart';
import '../services/bus_times_service.dart';
import '../theme/app_theme.dart';
import '../constants/app_config.dart';
import '../widgets/ad_banner_widget.dart';

class ActiveAlertsScreen extends StatefulWidget {
  final Function(int stopId, String stopName)? onViewStop;
  
  const ActiveAlertsScreen({super.key, this.onViewStop});

  @override
  State<ActiveAlertsScreen> createState() => _ActiveAlertsScreenState();
}

class _ActiveAlertsScreenState extends State<ActiveAlertsScreen> {
  final BusAlertService _alertService = BusAlertService();
  final BusTimesService _busTimesService = BusTimesService();
  List<BusAlert> _alerts = [];
  Map<String, List<BusArrival>> _arrivalTimes = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    
    final prefs = await SharedPreferences.getInstance();
    await _alertService.loadAlertsFromPrefs(prefs);
    final alerts = _alertService.getActiveAlerts();
    
    // Cargar tiempos de llegada para cada alerta
    final arrivals = <String, List<BusArrival>>{};
    for (final alert in alerts) {
      try {
        final times = await _busTimesService.getArrivalTimes(alert.stopId);
        arrivals['${alert.stopId}'] = times;
      } catch (e) {
        arrivals['${alert.stopId}'] = [];
      }
    }
    
    setState(() {
      _alerts = alerts;
      _arrivalTimes = arrivals;
      _isLoading = false;
    });
  }

  Future<void> _cancelAlert(BusAlert alert) async {
    final l = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.cancelAlert),
        content: Text(l.cancelAlertBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.no),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l.cancelAlertYes),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await _alertService.removeAlert(alert.key);
      _loadAlerts();
    }
  }

  String _getTimeForAlert(BusAlert alert) {
    final arrivals = _arrivalTimes['${alert.stopId}'] ?? [];
    final matching = arrivals.where(
      (a) => a.line == alert.line && a.destination == alert.destination
    ).toList();
    
    if (matching.isEmpty) return 'Sin datos';
    
    final time = matching.first.time;
    // Manejar casos especiales
    if (time.contains('>>>') || time.contains('---') || time.trim().isEmpty) {
      return 'Sin servicio';
    }
    return time;
  }

  String _getAlertStatus(BusAlert alert) {
    if (alert.notifiedArriving) return '🔔 Llegando';
    if (alert.notified2min) return '⚠️ Muy cerca';
    if (alert.notified5min) return '✅ Avisado';
    return '⏳ Esperando';
  }

  Color _getStatusColor(BusAlert alert) {
    if (alert.notifiedArriving) return Colors.red;
    if (alert.notified2min) return Colors.orange;
    if (alert.notified5min) return AlzitransColors.success;
    return AlzitransColors.burgundy;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text('🔔 ${l.activeAlertsTitle}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAlerts,
            tooltip: l.refreshButton,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _alerts.isEmpty
              ? _buildEmptyState()
              : _buildAlertsList(),
    );
  }

  Widget _buildEmptyState() {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            l.noActiveAlerts,
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            l.noActiveAlertsHint,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.map),
            label: Text(l.goToMap),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsList() {
    return RefreshIndicator(
      onRefresh: _loadAlerts,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: AppConfig.showAds ? _alerts.length + 1 : _alerts.length,
        itemBuilder: (context, index) {
          if (AppConfig.showAds && index == _alerts.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 300, maxHeight: 350),
                child: AdBannerWidget(
                  key: UniqueKey(),
                  adUnitId: AppConfig.nativeAdId,
                ),
              ),
            );
          }
          final alert = _alerts[index];
          return _buildAlertCard(alert);
        },
      ),
    );
  }

  Widget _buildAlertCard(BusAlert alert) {
    final time = _getTimeForAlert(alert);
    final status = _getAlertStatus(alert);
    final statusColor = _getStatusColor(alert);
    final timeAgo = DateTime.now().difference(alert.createdAt).inMinutes;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      elevation: 2,
      child: InkWell(
        onTap: widget.onViewStop != null 
            ? () {
                Navigator.pop(context);
                widget.onViewStop!(alert.stopId, alert.stopName);
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera con línea y estado
              Row(
                children: [
                  // Badge de línea
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AlzitransColors.burgundy,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      alert.line,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Destino
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '→ ${alert.destination}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          alert.stopName,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Botón cancelar
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => _cancelAlert(alert),
                    tooltip: AppLocalizations.of(context)!.cancelAlertTooltip,
                  ),
                ],
              ),
              
              const Divider(height: 16),
              
              // Info de tiempo y estado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Tiempo de llegada
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 18, color: AlzitransColors.burgundy),
                      const SizedBox(width: 6),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  // Estado
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.5)),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              
              // Tiempo desde que se activó
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.alertActivatedMinAgo(timeAgo),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
              
              // Botón ver parada
              if (widget.onViewStop != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onViewStop!(alert.stopId, alert.stopName);
                    },
                    icon: const Icon(Icons.location_on, size: 18),
                    label: Text(AppLocalizations.of(context)!.viewStopOnMap),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
