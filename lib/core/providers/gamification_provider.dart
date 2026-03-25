import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/gamification_service.dart';

final gamificationProvider = Provider<GamificationService>((ref) {
  return GamificationService();
});
