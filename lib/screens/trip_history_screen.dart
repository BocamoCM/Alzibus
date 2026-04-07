import 'package:flutter/material.dart';
import 'package:alzitrans/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/trip_history_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/auth_provider.dart';
import '../models/trip_record.dart';
import '../theme/app_theme.dart';
import '../constants/app_config.dart';
import '../widgets/ad_banner_widget.dart';

class TripHistoryScreen extends ConsumerStatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  ConsumerState<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends ConsumerState<TripHistoryScreen> with SingleTickerProviderStateMixin {
  TripHistoryService? _historyService;
  late TabController _tabController;
  bool _isLoading = true;
  String? _token;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadService();
  }

  Future<void> _loadService() async {
    final prefs = await SharedPreferences.getInstance();
    final authService = ref.read(authServiceProvider);
    final token = await authService.getToken();
    final service = TripHistoryService(prefs);
    if (token != null) {
      await service.loadFromApi(token);
    }
    if (!mounted) return;
    setState(() {
      _historyService = service;
      _token = token;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text('📊 ${l.tripHistoryTitle}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(Icons.bar_chart), text: l.tabStats),
            Tab(icon: const Icon(Icons.history), text: l.tabHistory),
          ],
        ),
        actions: [
          if (!_isLoading && _historyService != null)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'clear') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(l.clearHistoryConfirmTitle),
                      content: Text(l.clearHistoryConfirmBody),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(l.cancel),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: Text(l.delete),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && _token != null) {
                    await _historyService!.clearHistory(_token!);
                    setState(() {});
                  }
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_forever, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(l.clearHistory),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildStatsTab(),
                _buildHistoryTab(),
              ],
            ),
    );
  }

  Widget _buildStatsTab() {
    final stats = _historyService!.getStats();
    
    if (stats.totalTrips == 0) {
      final l = AppLocalizations.of(context)!;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_bus, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              l.noTripsRegistered,
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              l.noTripsHint,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    final stats7days = _historyService!.getStats(lastDays: 7);
    final stats30days = _historyService!.getStats(lastDays: 30);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resumen general
          _buildSummaryCard(stats),
          
          const SizedBox(height: 16),
          
          // Racha y comparación mensual
          _buildStreakCard(),
          
          const SizedBox(height: 16),
          
          // Gráfico mensual
          _buildMonthlyChartCard(),
          
          const SizedBox(height: 16),
          
          // Top líneas
          _buildTopLinesCard(stats),
          
          const SizedBox(height: 16),
          
          // Top paradas
          _buildTopStopsCard(stats),
          
          const SizedBox(height: 16),
          
          // Días de la semana
          _buildWeekdayCard(stats),
          
          const SizedBox(height: 16),
          
          // Actividad reciente
          _buildActivityCard(stats7days, stats30days),
        ],
      ),
    );
  }
  
  Widget _buildStreakCard() {
    final currentStreak = _historyService!.getCurrentStreak();
    final bestStreak = _historyService!.getBestStreak();
    final comparison = _historyService!.getMonthComparison();
    
    final isUp = comparison['difference'] > 0;
    final isDown = comparison['difference'] < 0;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔥 ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Builder(builder: (ctx) {
              final l = AppLocalizations.of(ctx)!;
              return Text(l.streakTitle,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
            }),
            const Divider(),
            Row(
              children: [
                // Racha actual
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: currentStreak > 0 ? Colors.orange[50] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: currentStreak >= 3 
                          ? Border.all(color: Colors.orange, width: 2)
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(
                          currentStreak > 0 ? '🔥' : '❄️',
                          style: const TextStyle(fontSize: 24),
                        ),
                        Text(
                          '$currentStreak',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: currentStreak > 0 ? Colors.orange[800] : Colors.grey,
                          ),
                        ),
                        Builder(builder: (ctx) => Text(
                          AppLocalizations.of(ctx)!.streak,
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Mejor racha
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Text('🏆', style: TextStyle(fontSize: 24)),
                        Text(
                          '$bestStreak',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[800],
                          ),
                        ),
                        Builder(builder: (ctx) => Text(
                          AppLocalizations.of(ctx)!.bestStreak,
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Comparación mensual
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isUp ? Colors.green[50] : (isDown ? Colors.red[50] : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          isUp ? '📈' : (isDown ? '📉' : '➡️'),
                          style: const TextStyle(fontSize: 24),
                        ),
                        Text(
                          '${isUp ? '+' : ''}${comparison['difference']}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isUp ? Colors.green[800] : (isDown ? Colors.red[800] : Colors.grey),
                          ),
                        ),
                        Builder(builder: (ctx) => Text(
                          AppLocalizations.of(ctx)!.vsPrevMonth,
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis,
                        )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (currentStreak >= 3)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange[400]!, Colors.red[400]!],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Builder(builder: (ctx) {
                    final l = AppLocalizations.of(ctx)!;
                    return Text(
                      l.streakMessage(currentStreak),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMonthlyChartCard() {
    final monthlyStats = _historyService!.getMonthlyStats(months: 6);
    if (monthlyStats.isEmpty) return const SizedBox.shrink();
    
    final maxTrips = monthlyStats.map((m) => m.tripCount).reduce((a, b) => a > b ? a : b);
    if (maxTrips == 0) return const SizedBox.shrink();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(builder: (ctx) => Text(
              AppLocalizations.of(ctx)!.tripsPerMonth,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            )),
            const Divider(),
            SizedBox(
              height: 140,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: monthlyStats.map((month) {
                  final heightPercent = maxTrips > 0 ? (month.tripCount / maxTrips) : 0.0;
                  final isCurrentMonth = month.month == DateTime.now().month && 
                                         month.year == DateTime.now().year;
                  
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${month.tripCount}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isCurrentMonth ? AlzitransColors.burgundy : Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            height: (heightPercent * 95).toDouble(),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isCurrentMonth ? AlzitransColors.burgundy : AlzitransColors.wine.withOpacity(0.4),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            month.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isCurrentMonth ? FontWeight.bold : FontWeight.normal,
                              color: isCurrentMonth ? AlzitransColors.burgundy : Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildWeekdayCard(TripStats stats) {
    final weekdayStats = stats.getDayOfWeekStats();
    if (weekdayStats.isEmpty) return const SizedBox.shrink();
    
    final maxTrips = weekdayStats.values.reduce((a, b) => a > b ? a : b);
    if (maxTrips == 0) return const SizedBox.shrink();
    
    const dayNames = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    final today = DateTime.now().weekday;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(builder: (ctx) => Text(
              AppLocalizations.of(ctx)!.weekdaysTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            )),
            const Divider(),
            SizedBox(
              height: 110,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (index) {
                  final day = index + 1;
                  final count = weekdayStats[day] ?? 0;
                  final heightPercent = maxTrips > 0 ? (count / maxTrips) : 0.0;
                  final isToday = day == today;
                  final isWeekend = day >= 6;
                  
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (count > 0)
                            Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isToday ? AlzitransColors.burgundy : Colors.grey[700],
                              ),
                            ),
                          const SizedBox(height: 2),
                          Container(
                            height: (heightPercent * 60).toDouble(),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isToday 
                                  ? AlzitransColors.burgundy 
                                  : (isWeekend ? AlzitransColors.lightPurple : AlzitransColors.coral.withOpacity(0.6)),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dayNames[index],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isToday ? AlzitransColors.burgundy : (isWeekend ? AlzitransColors.purple : Colors.grey[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Builder(builder: (ctx) {
                  final l = AppLocalizations.of(ctx)!;
                  return Row(
                    children: [
                      _legendItem(AlzitransColors.coral.withOpacity(0.6), l.weekdays),
                      const SizedBox(width: 16),
                      _legendItem(AlzitransColors.lightPurple, l.weekends),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildSummaryCard(TripStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(builder: (ctx) => Text(
              AppLocalizations.of(ctx)!.summaryTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            )),
            const Divider(),
            Builder(builder: (ctx) {
              final l = AppLocalizations.of(ctx)!;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('🚌', '${stats.totalTrips}', l.totalTripsLabel),
                  _buildStatItem('🚏', stats.mostUsedStop ?? '-', l.favouriteStop),
                  _buildStatItem('⏰', stats.mostFrequentTimeRange, l.usualTime),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String emoji, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTopLinesCard(TripStats stats) {
    final topLines = stats.topLines;
    if (topLines.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(builder: (ctx) => Text(
              AppLocalizations.of(ctx)!.topLines,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            )),
            const Divider(),
            ...topLines.asMap().entries.map((entry) {
              final index = entry.key;
              final line = entry.value;
              final medals = ['🥇', '🥈', '🥉'];
              final maxCount = topLines.first.value;
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Text(medals[index], style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Builder(builder: (ctx) => Text(
                        '${AppLocalizations.of(ctx)!.line} ${line.key}',
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      )),
                    ),
                    Text(
                      '${line.value}',
                      style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 50,
                      child: LinearProgressIndicator(
                        value: line.value / maxCount,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation(
                          index == 0 ? Colors.amber : 
                          index == 1 ? Colors.grey : Colors.brown[300],
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

  Widget _buildTopStopsCard(TripStats stats) {
    final topStops = stats.topStops;
    if (topStops.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(builder: (ctx) => Text(
              AppLocalizations.of(ctx)!.topStops,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            )),
            const Divider(),
            ...topStops.map((stop) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      stop.key,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AlzitransColors.burgundy.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${stop.value}',
                      style: const TextStyle(
                        color: AlzitransColors.burgundy,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(TripStats stats7days, TripStats stats30days) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(builder: (ctx) => Text(
              AppLocalizations.of(ctx)!.recentActivity,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            )),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '${stats7days.totalTrips}',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AlzitransColors.burgundy),
                    ),
                    Builder(builder: (ctx) => Text(
                      AppLocalizations.of(ctx)!.last7days,
                      style: TextStyle(color: Colors.grey[600]),
                    )),
                  ],
                ),
                Container(width: 1, height: 50, color: Colors.grey[300]),
                Column(
                  children: [
                    Text(
                      '${stats30days.totalTrips}',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    Builder(builder: (ctx) => Text(
                      AppLocalizations.of(ctx)!.last30days,
                      style: TextStyle(color: Colors.grey[600]),
                    )),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    final records = _historyService!.allRecords;
    
    if (records.isEmpty) {
      final l = AppLocalizations.of(context)!;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              l.noTripsHistory,
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Agrupar por fecha
    final grouped = <String, List<TripRecord>>{};
    for (final record in records) {
      final dateKey = _formatDate(record.timestamp);
      grouped.putIfAbsent(dateKey, () => []).add(record);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final dateKey = grouped.keys.elementAt(index);
        final trips = grouped[dateKey]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Text(
                dateKey,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
              ),
            ),
            if (AppConfig.showAds && index % 2 == 0 && index != 0) 
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 300, maxHeight: 350),
                  child: AdBannerWidget(
                    key: UniqueKey(),
                    adUnitId: AppConfig.nativeAdId,
                  ),
                ),
              ),
            ...trips.map((trip) => _buildTripTile(trip)),
          ],
        );
      },
    );
  }

  Widget _buildTripTile(TripRecord trip) {
    return Dismissible(
      key: Key(trip.timestamp.toIso8601String()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) async {
        if (_token != null) {
          await _historyService!.deleteTrip(_token!, trip.timestamp);
        }
        setState(() {});
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AlzitransColors.burgundy,
            radius: 18,
            child: Text(
              trip.line,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          title: Text(
            trip.stopName,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(fontSize: 14),
          ),
          subtitle: Text(
            '→ ${trip.destination}',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono de método de pago
              if (trip.paymentMethod != null) ...[
                Icon(
                  trip.paymentMethod == 'card' ? Icons.credit_card : Icons.payments,
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
              ],
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(trip.timestamp),
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                  Icon(
                    trip.confirmed ? Icons.check_circle : Icons.help_outline,
                    size: 16,
                    color: trip.confirmed ? Colors.green : Colors.orange,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return 'Hoy';
    if (dateOnly == yesterday) return 'Ayer';
    
    final weekdays = ['', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final months = ['', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    
    return '${weekdays[date.weekday]} ${date.day} ${months[date.month]}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
