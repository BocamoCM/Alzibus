import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/premium_service.dart';

final premiumServiceProvider = Provider<PremiumService>((ref) {
  return PremiumService();
});
