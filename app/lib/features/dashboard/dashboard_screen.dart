import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_state.dart';
import '../habits/habit_model.dart';
import '../habits/habit_repository.dart';
import '../sleep/manual_entry_screen.dart';
import '../sleep/sleep_repository.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _importCsvData(BuildContext context, WidgetRef ref) async {
    try {
      // Pick CSV file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return; // User cancelled
      }

      final file = result.files.first;
      if (file.bytes == null) {
        throw Exception('Could not read file data');
      }

      if (!context.mounted) return;

      // Show loading dialog
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Importing data...'),
            ],
          ),
        ),
      );

      // Import CSV
      final authState = ref.read(authControllerProvider);
      final repository = ref.read(sleepRepositoryProvider);
      
      final response = await repository.importCsv(
        token: authState.token ?? '',
        fileBytes: file.bytes!,
        fileName: file.name,
      );

      if (!context.mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      // Refresh data
      ref.invalidate(sleepSummaryProvider);
      ref.invalidate(habitsProvider);

      // Show success message
      final sleepCount = response['sleep_imported'] ?? 0;
      final habitCount = response['habits_imported'] ?? 0;
      
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Successful!'),
          content: Text(
            'Imported $sleepCount sleep sessions and $habitCount habit checkins.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      
      // Close loading dialog if open
      Navigator.of(context).popUntil((route) => route.isFirst);
      
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import CSV Data',
            onPressed: () => _importCsvData(context, ref),
          ),
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
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          Theme.of(context).colorScheme.secondaryContainer,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.secondary,
                        width: 2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.nights_stay_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No sleep data yet',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Tap the button below to add your first sleep entry.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          Icon(
                            Icons.arrow_downward,
                            color: Theme.of(context).colorScheme.secondary,
                            size: 32,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Last Night Card with gradient
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.primaryContainer,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.nightlight_round,
                                  color: Theme.of(context).colorScheme.secondary,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Last Night',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '${summary.lastNightDurationHours.toStringAsFixed(1)} hours',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.secondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _InfoChip(
                                  icon: Icons.star,
                                  label: 'Score ${summary.lastNightScore ?? 0}',
                                ),
                                const SizedBox(width: 8),
                                _InfoChip(
                                  icon: Icons.bedtime,
                                  label: summary.bedtime,
                                ),
                                const SizedBox(width: 8),
                                _InfoChip(
                                  icon: Icons.wb_sunny,
                                  label: summary.wakeTime,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: Theme.of(context).colorScheme.secondary,
                              width: 4,
                            ),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          leading: Icon(
                            Icons.analytics_outlined,
                            color: Theme.of(context).colorScheme.primary,
                            size: 32,
                          ),
                          title: const Text(
                            '7-day average',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${summary.avgDurationHours7d.toStringAsFixed(1)} h sleep · Score ${summary.avgScore7d.toStringAsFixed(0)}',
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Consistency',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '±${summary.consistencyMinutes} min',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                    Row(
                      children: [
                        Icon(
                          Icons.checklist_rounded,
                          color: Theme.of(context).colorScheme.secondary,
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tonight\'s Checklist',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Healthy habits with yellow border
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.secondary,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white,
                      ),
                      child: Column(
                        children: positive.map((habit) {
                          final isLast = habit == positive.last;
                          return Container(
                            decoration: BoxDecoration(
                              border: !isLast
                                  ? Border(
                                      bottom: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary
                                            .withOpacity(0.3),
                                      ),
                                    )
                                  : null,
                            ),
                            child: CheckboxListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              title: Text(
                                habit.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
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
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Update failed: $err')),
                                    );
                                  }
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    if (negative.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Icon(
                            Icons.remove_red_eye_outlined,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Keep an eye on',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 2,
                        child: Column(
                          children: negative.map((habit) {
                            final isLast = habit == negative.last;
                            return Container(
                              decoration: BoxDecoration(
                                border: !isLast
                                    ? Border(
                                        bottom: BorderSide(
                                          color: Colors.grey[200]!,
                                        ),
                                      )
                                    : null,
                              ),
                              child: SwitchListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                title: Text(
                                  habit.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
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
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Update failed: $err')),
                                      );
                                    }
                                  }
                                },
                              ),
                            );
                          }).toList(),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => const ManualEntryScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Sleep Entry'),
      ),
    );
  }
}

// Info chip widget for sleep stats
class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
