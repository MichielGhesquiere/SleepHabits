import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_state.dart';
import 'sleep_repository.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep Overview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Pull latest from Garmin',
            onPressed: () async {
              final token = auth.token;
              if (token == null) {
                return;
              }
              try {
                await ref
                    .read(sleepRepositoryProvider)
                    .refreshFromGarmin(token);
                ref.invalidate(sleepSummaryProvider);
              } catch (err) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sync failed: $err')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: summaryAsync.when(
        data: (summary) {
          if (summary == null) {
            return const Center(child: Text('No sleep data yet.'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              final token = auth.token;
              if (token == null) {
                return;
              }
              await ref
                  .read(sleepRepositoryProvider)
                  .refreshFromGarmin(token);
              ref.invalidate(sleepSummaryProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
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
                const SizedBox(height: 24),
                Text(
                  summary.garminConnected
                      ? 'Garmin account connected'
                      : 'Connect your Garmin account from the Today tab to sync automatically.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Failed to load sleep data: $error'),
          ),
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
