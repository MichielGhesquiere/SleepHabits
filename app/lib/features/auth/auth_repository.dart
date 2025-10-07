import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api_client.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return AuthRepository(client);
});

class AuthRepository {
  const AuthRepository(this._client);

  final ApiClient _client;

  Future<AuthResponse> signInWithEmail(String email) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email.trim()},
    );

    final data = response.data ?? <String, dynamic>{};
    return AuthResponse(
      token: data['access_token'] as String? ?? '',
      email: data['email'] as String? ?? email,
      userId: data['user_id'] as String?,
      garminConnected: data['garmin_connected'] as bool? ?? false,
    );
  }
}

class AuthResponse {
  const AuthResponse({
    required this.token,
    required this.email,
    this.userId,
    this.garminConnected = false,
  });

  final String token;
  final String email;
  final String? userId;
  final bool garminConnected;
}
