import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../theme/app_theme.dart';

class RankingScreen extends ConsumerStatefulWidget {
  const RankingScreen({super.key});

  @override
  ConsumerState<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends ConsumerState<RankingScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _ranking = [];
  int? _myPosition;
  int _myTrips = 0;
  String _period = 'month'; // 'month' | 'all'

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadRanking();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadRanking() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await ApiClient().get(
        '/ranking',
        queryParameters: {'period': _period},
      );

      if (response.statusCode != 200) throw Exception('Error ${response.statusCode}');

      final data = response.data as Map<String, dynamic>;
      setState(() {
        _ranking = List<Map<String, dynamic>>.from(data['ranking'] ?? []);
        _myPosition = data['myPosition'] as int?;
        _myTrips = data['myTrips'] as int? ?? 0;
        _isLoading = false;
      });
      _animController.forward(from: 0);
    } catch (e) {
      setState(() {
        _error = 'No se pudo cargar el ranking';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('🏆 Ranking de Viajeros'),
        backgroundColor: AlzitransColors.burgundy,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRanking,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildPeriodToggle(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : _ranking.isEmpty
                        ? _buildEmpty()
                        : _buildList(),
          ),
          if (_myPosition != null) _buildMyPositionBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AlzitransColors.burgundy,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: [
          const Text(
            'Compite con otros viajeros de Alzira',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          if (_myPosition != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Tu posición: #$_myPosition · $_myTrips viajes',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPeriodToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: _PeriodButton(
              label: 'Este mes',
              icon: Icons.calendar_month,
              selected: _period == 'month',
              onTap: () {
                if (_period != 'month') {
                  setState(() => _period = 'month');
                  _loadRanking();
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PeriodButton(
              label: 'Todo el tiempo',
              icon: Icons.emoji_events,
              selected: _period == 'all',
              onTap: () {
                if (_period != 'all') {
                  setState(() => _period = 'all');
                  _loadRanking();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    // Separar podio (top 3) del resto
    final podium = _ranking.where((e) => (e['position'] as int) <= 3).toList();
    final rest = _ranking.where((e) => (e['position'] as int) > 3).toList();

    return FadeTransition(
      opacity: _fadeAnim,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (podium.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildPodium(podium),
            const SizedBox(height: 16),
          ],
          ...rest.map((entry) => _buildEntryRow(entry)),
        ],
      ),
    );
  }

  Widget _buildPodium(List<Map<String, dynamic>> podium) {
    // Ordenar: 2° - 1° - 3°
    final sorted = [...podium]..sort((a, b) {
        final pa = a['position'] as int;
        final pb = b['position'] as int;
        final order = {1: 1, 2: 0, 3: 2};
        return (order[pa] ?? pa).compareTo(order[pb] ?? pb);
      });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: sorted.map((e) => Expanded(child: _buildPodiumEntry(e))).toList(),
      ),
    );
  }

  Widget _buildPodiumEntry(Map<String, dynamic> entry) {
    final pos = entry['position'] as int;
    final isMe = entry['isMe'] as bool? ?? false;
    final medal = pos == 1 ? '🥇' : pos == 2 ? '🥈' : '🥉';
    final height = pos == 1 ? 90.0 : pos == 2 ? 70.0 : 55.0;
    final color = pos == 1
        ? const Color(0xFFFFD700)
        : pos == 2
            ? const Color(0xFFC0C0C0)
            : const Color(0xFFCD7F32);

    return Column(
      children: [
        Text(medal, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        CircleAvatar(
          radius: 22,
          backgroundColor: isMe ? AlzitransColors.burgundy : color.withOpacity(0.3),
          child: Text(
            (entry['name'] as String).substring(0, 1).toUpperCase(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isMe ? Colors.white : color,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          entry['name'] as String,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
            color: isMe ? AlzitransColors.burgundy : Colors.grey[700],
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Container(
          height: height,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isMe ? AlzitransColors.burgundy.withOpacity(0.15) : color.withOpacity(0.15),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            border: isMe ? Border.all(color: AlzitransColors.burgundy, width: 1.5) : null,
          ),
          child: Center(
            child: Text(
              '${entry['trips']}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isMe ? AlzitransColors.burgundy : color,
              ),
            ),
          ),
        ),
        Container(
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isMe ? AlzitransColors.burgundy : color,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEntryRow(Map<String, dynamic> entry) {
    final pos = entry['position'] as int;
    final isMe = entry['isMe'] as bool? ?? false;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isMe ? AlzitransColors.burgundy.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isMe ? Border.all(color: AlzitransColors.burgundy, width: 1.5) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: isMe
              ? AlzitransColors.burgundy
              : Colors.grey[100],
          child: Text(
            '#$pos',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isMe ? Colors.white : Colors.grey[600],
            ),
          ),
        ),
        title: Text(
          entry['name'] as String,
          style: TextStyle(
            fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
            color: isMe ? AlzitransColors.burgundy : Colors.black87,
            fontSize: 14,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isMe
                ? AlzitransColors.burgundy
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${entry['trips']} 🚌',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isMe ? Colors.white : Colors.grey[700],
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyPositionBar() {
    if (_ranking.any((e) => e['isMe'] == true)) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AlzitransColors.burgundy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_pin, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tu posición: #$_myPosition · $_myTrips viajes este ${_period == 'month' ? 'mes' : 'tiempo'}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadRanking, child: const Text('Reintentar')),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🚌', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            _period == 'month'
                ? 'Nadie ha viajado este mes aún.\n¡Sé el primero!'
                : 'Aún no hay viajes registrados.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AlzitransColors.burgundy : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AlzitransColors.burgundy : Colors.grey[300]!,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AlzitransColors.burgundy.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : Colors.grey[600]),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey[700],
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
