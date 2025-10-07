import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_state.dart';
import '../sleep/sleep_repository.dart';
import 'habit_model.dart';
import 'habit_repository.dart';

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth.status != AuthStatus.authenticated) {
      return const Scaffold(
        body: Center(child: Text('Sign in to manage your bedtime habits.')),
      );
    }

    final habitsAsync = ref.watch(habitsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(habitsProvider),
          ),
        ],
      ),
      body: habitsAsync.when(
        data: (habits) {
          final healthy = habits
              .where((habit) => habit.type == HabitType.healthy)
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
          final unhealthy = habits
              .where((habit) => habit.type == HabitType.unhealthy)
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HabitsSection(
                title: 'Positive Sleep Habits',
                habits: healthy,
                onToggle: (habit, newValue) async =>
                    _handleToggle(ref, auth.token!, habit, newValue),
              ),
              const SizedBox(height: 24),
              _HabitsSection(
                title: 'Avoid Late Night Habits',
                habits: unhealthy,
                onToggle: (habit, newValue) async =>
                    _handleToggle(ref, auth.token!, habit, newValue),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Failed to load habits: $error'),
          ),
        ),
      ),
    );
  }

  Future<void> _handleToggle(
    WidgetRef ref,
    String token,
    Habit habit,
    bool value,
  ) async {
    await ref.read(habitRepositoryProvider).checkIn(
          token: token,
          habitId: habit.id,
          value: value,
        );
    ref.invalidate(habitsProvider);
    ref.invalidate(sleepSummaryProvider);
  }
}

class _HabitsSection extends StatelessWidget {
  const _HabitsSection({
    required this.title,
    required this.habits,
    required this.onToggle,
  });

  final String title;
  final List<Habit> habits;
  final Future<void> Function(Habit habit, bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    if (habits.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('No habits configured yet.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ...habits.map(
          (habit) => Card(
            child: CheckboxListTile(
              title: Text(habit.name),
              subtitle: habit.description != null
                  ? Text(habit.description!)
                  : null,
              value: habit.boolValue,
              onChanged: (value) async {
                if (value == null) {
                  return;
                }
                try {
                  await onToggle(habit, value);
                } catch (err) {
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    SnackBar(content: Text('Update failed: $err')),
                  );
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
