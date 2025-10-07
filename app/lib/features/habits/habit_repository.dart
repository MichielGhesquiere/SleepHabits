import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api_client.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_state.dart';
import 'habit_model.dart';

final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return HabitRepository(client);
});

class HabitRepository {
  const HabitRepository(this._client);

  final ApiClient _client;

  Future<List<Habit>> fetchHabits(String token) async {
    final response = await _client.get<List<dynamic>>(
      '/me/habits',
      token: token,
    );
    final raw = response.data ?? <dynamic>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(Habit.fromJson)
        .toList();
  }

  Future<Habit> checkIn({
    required String token,
    required String habitId,
    required Object value,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/me/habits/checkin',
      token: token,
      data: {
        'habit_id': habitId,
        'value': value,
      },
    );
    final data = response.data ?? <String, dynamic>{};
    return Habit.fromJson(data);
  }
}

final habitsProvider = FutureProvider<List<Habit>>((ref) async {
  final auth = ref.watch(authControllerProvider);
  if (auth.status != AuthStatus.authenticated ||
      auth.token == null ||
      auth.token!.isEmpty) {
    return <Habit>[];
  }
  final repository = ref.watch(habitRepositoryProvider);
  return repository.fetchHabits(auth.token!);
});
