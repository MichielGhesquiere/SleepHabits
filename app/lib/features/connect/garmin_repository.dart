import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api_client.dart';
import '../auth/auth_controller.dart';
import '../sleep/sleep_models.dart';
import '../sleep/sleep_repository.dart';

final garminRepositoryProvider = Provider<GarminRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return GarminRepository(client, ref);
});

class GarminRepository {
  GarminRepository(this._client, this._ref);

  final ApiClient _client;
  final Ref _ref;

  Future<GarminConnectResult> connect({
    required String token,
    required String email,
    required String password,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/garmin/connect',
      token: token,
      data: {
        'email': email,
        'password': password,
      },
    );
    final result = GarminConnectResult.fromJson(response.data);
    _handleResult(result);
    return result;
  }

  Future<GarminConnectResult> completeMfa({
    required String token,
    required String mfaToken,
    required String code,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/garmin/connect',
      token: token,
      data: {
        'mfa_token': mfaToken,
        'mfa_code': code,
      },
    );
    final result = GarminConnectResult.fromJson(response.data);
    _handleResult(result);
    return result;
  }

  Future<SleepSummary> pullLatest(String token) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/garmin/pull',
      token: token,
    );
    final data = response.data ?? <String, dynamic>{};
    final summaryJson =
        data['summary'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final summary = SleepSummary.fromJson(summaryJson);
    _ref
        .read(authControllerProvider.notifier)
        .setGarminConnected(summary.garminConnected);
    _ref.invalidate(sleepSummaryProvider);
    return summary;
  }

  void _handleResult(GarminConnectResult result) {
    if (result.summary != null) {
      _ref
          .read(authControllerProvider.notifier)
          .setGarminConnected(result.summary!.garminConnected);
      _ref.invalidate(sleepSummaryProvider);
    }
  }
}

class GarminConnectResult {
  const GarminConnectResult({
    required this.connected,
    required this.mfaRequired,
    required this.message,
    this.summary,
    this.mfaToken,
  });

  factory GarminConnectResult.fromJson(Map<String, dynamic>? json) {
    final safe = json ?? <String, dynamic>{};
    final summaryJson = safe['summary'] as Map<String, dynamic>?;
    return GarminConnectResult(
      connected: safe['connected'] as bool? ?? false,
      mfaRequired: safe['mfa_required'] as bool? ?? false,
      message: safe['message'] as String? ?? '',
      mfaToken: safe['mfa_token'] as String?,
      summary: summaryJson != null ? SleepSummary.fromJson(summaryJson) : null,
    );
  }

  final bool connected;
  final bool mfaRequired;
  final String message;
  final String? mfaToken;
  final SleepSummary? summary;
}
