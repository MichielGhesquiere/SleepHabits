import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_state.dart';
import '../habits/habit_model.dart';
import '../habits/habit_repository.dart';
import 'sleep_repository.dart';

class ManualEntryScreen extends ConsumerStatefulWidget {
  const ManualEntryScreen({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  ConsumerState<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends ConsumerState<ManualEntryScreen> {
  late DateTime selectedDate;
  double sleepScore = 75;
  TimeOfDay bedtime = const TimeOfDay(hour: 22, minute: 30);
  TimeOfDay wakeTime = const TimeOfDay(hour: 6, minute: 30);
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    selectedDate = widget.initialDate ?? DateTime.now();
  }

  int get durationMinutes {
    final bedMinutes = bedtime.hour * 60 + bedtime.minute;
    var wakeMinutes = wakeTime.hour * 60 + wakeTime.minute;
    
    // If wake time is earlier than bedtime, it's the next day
    if (wakeMinutes < bedMinutes) {
      wakeMinutes += 24 * 60;
    }
    
    return wakeMinutes - bedMinutes;
  }

  String get durationFormatted {
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isBedtime) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isBedtime ? bedtime : wakeTime,
    );
    if (picked != null) {
      setState(() {
        if (isBedtime) {
          bedtime = picked;
        } else {
          wakeTime = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      isLoading = true;
    });

    try {
      final authState = ref.read(authControllerProvider);
      final repository = ref.read(sleepRepositoryProvider);

      await repository.addManualEntry(
        token: authState.token ?? '',
        date: selectedDate,
        sleepScore: sleepScore.round(),
        bedtime: '${bedtime.hour.toString().padLeft(2, '0')}:${bedtime.minute.toString().padLeft(2, '0')}',
        wakeTime: '${wakeTime.hour.toString().padLeft(2, '0')}:${wakeTime.minute.toString().padLeft(2, '0')}',
        durationMinutes: durationMinutes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sleep entry saved!')),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final habitsAsync = ref.watch(habitsForDateProvider(selectedDate));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Sleep Entry'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Date selector
          Card(
            child: ListTile(
              leading: Icon(Icons.calendar_today, color: theme.colorScheme.primary),
              title: const Text('Date'),
              subtitle: Text(DateFormat('EEEE, MMM d, y').format(selectedDate)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _selectDate(context),
            ),
          ),
          
          const SizedBox(height: 16),

          // Sleep Score
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sleep Score',
                        style: theme.textTheme.titleMedium,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _scoreColor(sleepScore),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          sleepScore.round().toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: sleepScore,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: sleepScore.round().toString(),
                    onChanged: (value) {
                      setState(() {
                        sleepScore = value;
                      });
                    },
                  ),
                  Text(
                    _scoreLabel(sleepScore),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Bedtime and Wake Time
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.bedtime, color: theme.colorScheme.primary),
                  title: const Text('Bedtime'),
                  subtitle: Text(bedtime.format(context)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _selectTime(context, true),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.wb_sunny, color: theme.colorScheme.secondary),
                  title: const Text('Wake Time'),
                  subtitle: Text(wakeTime.format(context)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _selectTime(context, false),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.schedule, color: theme.colorScheme.tertiary),
                  title: const Text('Total Sleep'),
                  subtitle: Text(durationFormatted),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Habits for this night
          Text(
            'Habits (night before)',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          
          habitsAsync.when(
            data: (habits) => Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: habits.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final habit = habits[index];
                  return _HabitTile(
                    habit: habit,
                    date: selectedDate,
                  );
                },
              ),
            ),
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (err, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error loading habits: $err'),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Save button
          FilledButton.icon(
            onPressed: isLoading ? null : _save,
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(isLoading ? 'Saving...' : 'Save Entry'),
          ),
        ],
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  String _scoreLabel(double score) {
    if (score >= 80) return 'Excellent sleep';
    if (score >= 60) return 'Good sleep';
    if (score >= 40) return 'Fair sleep';
    return 'Poor sleep';
  }
}

class _HabitTile extends ConsumerWidget {
  const _HabitTile({
    required this.habit,
    required this.date,
  });

  final Habit habit;
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isHealthy = habit.type == HabitType.healthy;
    final checked = habit.value == true;

    return CheckboxListTile(
      value: checked,
      onChanged: (value) async {
        final authState = ref.read(authControllerProvider);
        final repository = ref.read(habitRepositoryProvider);
        
        try {
          await repository.checkIn(
            token: authState.token ?? '',
            habitId: habit.id,
            value: value ?? false,
            targetDate: date,
          );
          
          // Refresh habits for this date
          ref.invalidate(habitsForDateProvider(date));
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
          }
        }
      },
      title: Text(habit.name),
      subtitle: Text(
        habit.description ?? '',
        style: theme.textTheme.bodySmall,
      ),
      secondary: Icon(
        _getHabitIcon(habit.name),
        color: isHealthy ? Colors.green : Colors.orange,
      ),
    );
  }

  IconData _getHabitIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('read')) return Icons.book;
    if (lower.contains('meditat')) return Icons.self_improvement;
    if (lower.contains('screen')) return Icons.phone_android;
    if (lower.contains('alcohol')) return Icons.local_bar;
    if (lower.contains('caffeine')) return Icons.coffee;
    if (lower.contains('exercise')) return Icons.fitness_center;
    if (lower.contains('meal')) return Icons.restaurant;
    return Icons.check_circle_outline;
  }
}

// Provider for habits on a specific date
final habitsForDateProvider = FutureProvider.family<List<Habit>, DateTime>((ref, date) async {
  final authState = ref.watch(authControllerProvider);
  final repository = ref.watch(habitRepositoryProvider);
  
  if (authState.status != AuthStatus.authenticated) {
    return [];
  }
  
  return repository.fetchHabits(
    authState.token ?? '',
    targetDate: date,
  );
});
