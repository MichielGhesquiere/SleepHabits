import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/auth_screen.dart';
import '../features/auth/auth_state.dart';
import '../features/home/home_shell.dart';

class SleepHabitsApp extends ConsumerWidget {
  const SleepHabitsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4E6AF1)),
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'SleepHabits',
      theme: theme,
      home: const _AppRoot(),
    );
  }
}

class _AppRoot extends ConsumerWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    if (authState.status == AuthStatus.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (authState.status == AuthStatus.authenticated) {
      return const HomeShell();
    }

    return const AuthScreen();
  }
}
