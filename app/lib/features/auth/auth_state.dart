enum AuthStatus { unauthenticated, loading, authenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.email,
    this.token,
    this.garminConnected = false,
  });

  const AuthState.unauthenticated()
      : status = AuthStatus.unauthenticated,
        email = null,
        token = null,
        garminConnected = false;

  const AuthState.loading()
      : status = AuthStatus.loading,
        email = null,
        token = null,
        garminConnected = false;

  const AuthState.authenticated({
    required this.email,
    required this.token,
    this.garminConnected = false,
  }) : status = AuthStatus.authenticated;

  final AuthStatus status;
  final String? email;
  final String? token;
  final bool garminConnected;

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    String? token,
    bool? garminConnected,
  }) {
    return AuthState(
      status: status ?? this.status,
      email: email ?? this.email,
      token: token ?? this.token,
      garminConnected: garminConnected ?? this.garminConnected,
    );
  }
}
