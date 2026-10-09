import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alzitrans/l10n/app_localizations.dart';

import '../core/providers/auth_provider.dart';
import '../models/travel_habit.dart';
import '../services/habit_service.dart';
import '../services/notification_service.dart';
import '../services/trip_history_service.dart';
import '../theme/app_theme.dart';
import 'albus_mascot.dart';

/// Tarjeta "Tus rutinas": Albus muestra los trayectos habituales que ha
/// aprendido del historial y deja activar un aviso proactivo para cada uno.
class HabitsCard extends ConsumerStatefulWidget {
  const HabitsCard({super.key});

  @override
  ConsumerState<HabitsCard> createState() => _HabitsCardState();
}

class _HabitsCardState extends ConsumerState<HabitsCard> {
  HabitService? _service;
  List<TravelHabit> _habits = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final token = await ref.read(authServiceProvider).getToken();
      final prefs = await SharedPreferences.getInstance();
      final history = TripHistoryService(prefs);
      if (token != null) await history.loadFromApi(token);

      final service = HabitService(
          prefs, NotificationService(FlutterLocalNotificationsPlugin()));
      final habits = service.detectHabits(history.allRecords);

      // Reprograma los avisos activados (se pierden al reiniciar el móvil).
      await service.rescheduleEnabled(habits);

      if (!mounted) return;
      setState(() {
        _service = service;
        _habits = habits;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(TravelHabit habit, bool value) async {
    await _service?.setEnabled(habit, value);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Mientras carga o si no hay ninguna rutina aún, no ocupamos espacio con
    // un spinner: solo mostramos la tarjeta cuando hay algo que enseñar.
    if (_loading || _habits.isEmpty) return const SizedBox.shrink();

    final locale = Localizations.localeOf(context).languageCode;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: AlbusMascot(
                  state: AlbusState.thinking,
                  size: 44,
                  animated: false,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.habitsTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AlzitransColors.burgundy,
                      ),
                    ),
                    Text(
                      l.habitsSubtitle,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._habits.map((h) => _habitRow(theme, l, h, locale)),
        ],
      ),
    );
  }

  Widget _habitRow(
      ThemeData theme, AppLocalizations l, TravelHabit habit, String locale) {
    final dayName = DateFormat.EEEE(locale)
        .format(DateTime(2024, 1, habit.weekday)); // 1-ene-2024 = lunes
    final time =
        '${habit.hour.toString().padLeft(2, '0')}:${habit.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AlzitransColors.burgundy.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              habit.line,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AlzitransColors.burgundy,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.stopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${_capitalize(dayName)} · ~$time',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Switch(
            value: _service?.isEnabled(habit) ?? false,
            activeThumbColor: AlzitransColors.burgundy,
            onChanged: (v) => _toggle(habit, v),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
