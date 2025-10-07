import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_state.dart';
import '../connect/garmin_repository.dart';
import '../habits/habit_model.dart';
import '../habits/habit_repository.dart';
import '../sleep/sleep_repository.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    if (authState.status != AuthStatus.authenticated) {
      return const Scaffold(
        body: Center(
          child: Text('Sign in to see today\'s plan.'),
        ),
      );
    }

    final summaryAsync = ref.watch(sleepSummaryProvider);
    final habitsAsync = ref.watch(habitsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(sleepSummaryProvider);
          ref.invalidate(habitsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            summaryAsync.when(
              data: (summary) {
                if (summary == null) {
                  return _EmptySummaryCard(
                    onConnect: () => _connectGarmin(context, ref, authState),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!summary.garminConnected)
                      _ConnectCard(
                        onConnect: () =>
                            _connectGarmin(context, ref, authState),
                      ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Last Night',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${summary.lastNightDurationHours.toStringAsFixed(1)} h sleep',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Score ${summary.lastNightScore ?? 0} · Bed ${summary.bedtime} · Wake ${summary.wakeTime}',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        title: const Text('7-day average'),
                        subtitle: Text(
                          '${summary.avgDurationHours7d.toStringAsFixed(1)} h sleep · Score ${summary.avgScore7d.toStringAsFixed(0)}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Consistency'),
                            Text('±${summary.consistencyMinutes} min'),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Failed to load stats: $error'),
                ),
              ),
            ),
            const SizedBox(height: 24),
            habitsAsync.when(
              data: (habits) {
                if (habits.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No habits yet. Configure them in the Habits tab.'),
                    ),
                  );
                }
                final positive = habits
                    .where((habit) => habit.type == HabitType.healthy)
                    .take(3)
                    .toList();
                final negative = habits
                    .where((habit) => habit.type == HabitType.unhealthy)
                    .take(3)
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tonight\'s Checklist',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    ...positive.map(
                      (habit) => CheckboxListTile(
                        title: Text(habit.name),
                        subtitle: habit.description != null
                            ? Text(habit.description!)
                            : null,
                        value: habit.boolValue,
                        onChanged: (value) async {
                          if (value == null) return;
                          try {
                            await ref.read(habitRepositoryProvider).checkIn(
                                  token: authState.token!,
                                  habitId: habit.id,
                                  value: value,
                                );
                            ref.invalidate(habitsProvider);
                            ref.invalidate(sleepSummaryProvider);
                          } catch (err) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Update failed: $err')),
                            );
                          }
                        },
                      ),
                    ),
                    if (negative.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Keep an eye on',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      ...negative.map(
                        (habit) => SwitchListTile(
                          title: Text(habit.name),
                          subtitle: habit.description != null
                              ? Text(habit.description!)
                              : null,
                          value: !habit.boolValue,
                          onChanged: (value) async {
                            try {
                              await ref.read(habitRepositoryProvider).checkIn(
                                    token: authState.token!,
                                    habitId: habit.id,
                                    value: !value,
                                  );
                              ref.invalidate(habitsProvider);
                              ref.invalidate(sleepSummaryProvider);
                            } catch (err) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Update failed: $err')),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Failed to load habits: $error'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _connectGarmin(
    BuildContext context,
    WidgetRef ref,
    AuthState authState,
  ) async {
    try {
      await ref.read(garminRepositoryProvider).connect(authState.token!);
      ref.invalidate(sleepSummaryProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Garmin connected!')),
        );
      }
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connect failed: $err')),
        );
      }
    }
  }
}

class _EmptySummaryCard extends StatelessWidget {
  const _EmptySummaryCard({required this.onConnect});

  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('No sleep data yet.'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: onConnect,
              child: const Text('Connect Garmin'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectCard extends StatelessWidget {
  const _ConnectCard({required this.onConnect});

  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Expanded(
              child: Text('Connect your Garmin to sync sleep data.'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: onConnect,
              child: const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }
}

