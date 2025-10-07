import 'package:dio/dio.dart';
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
      '/garmin/pull',
      token: token,
    );
    final data = response.data ?? <String, dynamic>{};
    final summaryJson =
        data['summary'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return SleepSummary.fromJson(summaryJson);
  }

  Future<SleepSummary> addManualEntry({
    required String token,
    required DateTime date,
    required int sleepScore,
    required String bedtime,
    required String wakeTime,
    required int durationMinutes,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/me/sleep/manual',
      token: token,
      data: {
        'local_date': date.toIso8601String().split('T')[0],
        'sleep_score': sleepScore,
        'bedtime': bedtime,
        'wake_time': wakeTime,
        'duration_minutes': durationMinutes,
      },
    );
    final data = response.data ?? <String, dynamic>{};
    return SleepSummary.fromJson(data);
  }

  Future<SleepSummary> fetchSummaryForDate({
    required String token,
    required DateTime date,
  }) async {
    final dateStr = date.toIso8601String().split('T')[0];
    final response = await _client.get<Map<String, dynamic>>(
      '/me/sleep/date/$dateStr',
      token: token,
    );
    final data = response.data ?? <String, dynamic>{};
    return SleepSummary.fromJson(data);
  }

  Future<Map<String, dynamic>> fetchAnalytics(String token) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/me/analytics',
      token: token,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> importCsv({
    required String token,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        fileBytes,
        filename: fileName,
      ),
    });

    final response = await _client.postMultipart<Map<String, dynamic>>(
      '/me/import/csv',
      formData: formData,
      token: token,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> fetchTimeline(String token, String range) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/me/sleep/timeline?range=$range',
      token: token,
    );
    return response.data ?? <String, dynamic>{};
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
