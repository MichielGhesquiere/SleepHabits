import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api_client.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_state.dart';
import 'sleep_models.dart';

final sleepRepositoryProvider = Provider<SleepRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return SleepRepository(client);
});

class SleepRepository {
  const SleepRepository(this._client);

  final ApiClient _client;

  Future<SleepSummary> fetchSummary(String token) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/me/summary',
      token: token,
    );
    final data = response.data ?? <String, dynamic>{};
    return SleepSummary.fromJson(data);
  }

  Future<SleepSummary> refreshFromGarmin(String token) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/me/garmin/pull',
      token: token,
    );
    final data = response.data ?? <String, dynamic>{};
    return SleepSummary.fromJson(data);
  }
}

final sleepSummaryProvider = FutureProvider<SleepSummary?>((ref) async {
  final auth = ref.watch(authControllerProvider);
  if (auth.status != AuthStatus.authenticated ||
      auth.token == null ||
      auth.token!.isEmpty) {
    return null;
  }

  final repository = ref.watch(sleepRepositoryProvider);
  final summary = await repository.fetchSummary(auth.token!);
  if (summary.garminConnected != auth.garminConnected) {
    ref.read(authControllerProvider.notifier).setGarminConnected(
          summary.garminConnected,
        );
  }
  return summary;
});
