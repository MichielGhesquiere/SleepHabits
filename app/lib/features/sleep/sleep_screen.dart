import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_state.dart';
import 'sleep_repository.dart';
import 'sleep_timeline_chart.dart';

// Timeline data provider
final timelineRangeProvider = StateProvider<String>((ref) => 'week');

final sleepTimelineProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final auth = ref.watch(authControllerProvider);
  final range = ref.watch(timelineRangeProvider);
  
  if (auth.status != AuthStatus.authenticated || auth.token == null) {
    return <String, dynamic>{'timeline': <dynamic>[], 'total_sessions': 0};
  }
  
  return await ref.read(sleepRepositoryProvider).fetchTimeline(auth.token!, range);
});

class SleepScreen extends ConsumerWidget {
  const SleepScreen({super.key});

    @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth.status != AuthStatus.authenticated) {
      return const Scaffold(
        body: Center(
          child: Text('Sign in to view your sleep history.'),
        ),
      );
    }

    final summaryAsync = ref.watch(sleepSummaryProvider);
    final timelineAsync = ref.watch(sleepTimelineProvider);
    final selectedRange = ref.watch(timelineRangeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep Overview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh data',
            onPressed: () {
              ref.invalidate(sleepSummaryProvider);
              ref.invalidate(sleepTimelineProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(sleepSummaryProvider);
          ref.invalidate(sleepTimelineProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Summary stats
            summaryAsync.when(
              data: (summary) {
                if (summary == null) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.nightlight_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No sleep data yet',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Connect your Garmin account or add manual entries to see your sleep overview.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                return Column(
                  children: [
                    _SleepStatCard(
                      title: 'Last Night',
                      value:
                          '${summary.lastNightDurationHours.toStringAsFixed(1)} h',
                      subtitle:
                          'Score: ${summary.lastNightScore?.toString() ?? 'n/a'}',
                      footer:
                          'Bedtime ${summary.bedtime} · Wake ${summary.wakeTime}',
                    ),
                    const SizedBox(height: 12),
                    _SleepStatCard(
                      title: '7-day Average',
                      value: '${summary.avgDurationHours7d.toStringAsFixed(1)} h',
                      subtitle:
                          'Score: ${summary.avgScore7d.toStringAsFixed(0)} · Midpoint ${summary.sleepMidpoint}',
                      footer:
                          'Consistency ±${summary.consistencyMinutes} min',
                    ),
                    const SizedBox(height: 12),
                    _StageBreakdown(stageMinutes: summary.stageMinutes),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Failed to load summary: $error'),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Timeline section header with range selector
            Row(
              children: [
                Icon(
                  Icons.timeline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  'Sleep Timeline',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'week', label: Text('Week')),
                    ButtonSegment(value: 'month', label: Text('Month')),
                    ButtonSegment(value: 'year', label: Text('Year')),
                  ],
                  selected: {selectedRange},
                  onSelectionChanged: (Set<String> newSelection) {
                    ref.read(timelineRangeProvider.notifier).state = newSelection.first;
                  },
                  style: ButtonStyle(
                    textStyle: WidgetStateProperty.all(
                      const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Timeline charts
            timelineAsync.when(
              data: (data) {
                final timeline = data['timeline'] as List<dynamic>? ?? [];
                if (timeline.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.show_chart,
                            size: 48,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No data for this period',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add more sleep entries to see timeline charts',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                return SleepTimelineChart(
                  timeline: timeline,
                  range: selectedRange,
                );
              },
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (error, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Failed to load timeline: $error'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepStatCard extends StatelessWidget {
  const _SleepStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    this.footer,
  });

  final String title;
  final String value;
  final String subtitle;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            if (footer != null) ...[
              const SizedBox(height: 8),
              Text(footer!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _StageBreakdown extends StatelessWidget {
  const _StageBreakdown({required this.stageMinutes});

  final Map<String, int> stageMinutes;

  @override
  Widget build(BuildContext context) {
    if (stageMinutes.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sleep Stages',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...stageMinutes.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key.toUpperCase()),
                    Text('${entry.value} min'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
