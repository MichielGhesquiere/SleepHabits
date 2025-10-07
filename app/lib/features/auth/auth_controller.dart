import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';
import 'auth_state.dart';

final authErrorProvider = StateProvider<String?>((_) => null);

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthController(ref, repository);
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref, this._repository)
      : super(const AuthState.unauthenticated());

  final Ref _ref;
  final AuthRepository _repository;

  Future<void> signIn(String email) async {
    _ref.read(authErrorProvider.notifier).state = null;
    state = const AuthState.loading();
    try {
      final response = await _repository.signInWithEmail(email);
      if (response.token.isEmpty) {
        throw Exception('Missing access token');
      }
      state = AuthState(
        status: AuthStatus.authenticated,
        email: response.email,
        token: response.token,
        garminConnected: response.garminConnected,
      );
    } catch (err) {
      _ref.read(authErrorProvider.notifier).state = err.toString();
      state = const AuthState.unauthenticated();
    }
  }

  void signOut() {
    state = const AuthState.unauthenticated();
  }

  void setGarminConnected(bool connected) {
    state = state.copyWith(garminConnected: connected);
  }
}
