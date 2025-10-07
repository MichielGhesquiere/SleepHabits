import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api_client.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_state.dart';
import '../sleep/sleep_repository.dart';

final garminRepositoryProvider = Provider<GarminRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return GarminRepository(client, ref);
});

class GarminRepository {
  GarminRepository(this._client, this._ref);

  final ApiClient _client;
  final Ref _ref;

  Future<GarminConnectResult> connect(String token) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/me/garmin/connect',
      token: token,
    );
    final data = response.data ?? <String, dynamic>{};
    final result = GarminConnectResult.fromJson(data);
    if (result.connected) {
      _ref.read(authControllerProvider.notifier).setGarminConnected(true);
      _ref.invalidate(sleepSummaryProvider);
    }
    return result;
  }
}

class GarminConnectResult {
  const GarminConnectResult({
    required this.connected,
    this.message,
  });

  factory GarminConnectResult.fromJson(Map<String, dynamic> json) {
    return GarminConnectResult(
      connected: json['connected'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }

  final bool connected;
  final String? message;
}
