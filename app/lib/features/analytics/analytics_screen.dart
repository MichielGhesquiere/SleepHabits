import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_state.dart';
import '../sleep/sleep_repository.dart';

// Analytics data model
class HabitCorrelation {
  const HabitCorrelation({
    required this.habitId,
    required this.habitName,
    required this.habitType,
    required this.avgScoreWithHabit,
    required this.avgScoreWithoutHabit,
    required this.difference,
    required this.sampleSizeWith,
    required this.sampleSizeWithout,
  });

  factory HabitCorrelation.fromJson(Map<String, dynamic> json) {
    return HabitCorrelation(
      habitId: json['habit_id'] as String,
      habitName: json['habit_name'] as String,
      habitType: json['habit_type'] as String,
      avgScoreWithHabit: (json['avg_score_with_habit'] as num).toDouble(),
      avgScoreWithoutHabit: (json['avg_score_without_habit'] as num).toDouble(),
      difference: (json['difference'] as num).toDouble(),
      sampleSizeWith: json['sample_size_with'] as int,
      sampleSizeWithout: json['sample_size_without'] as int,
    );
  }

  final String habitId;
  final String habitName;
  final String habitType;
  final double avgScoreWithHabit;
  final double avgScoreWithoutHabit;
  final double difference;
  final int sampleSizeWith;
  final int sampleSizeWithout;

  bool get isHealthy => habitType == 'healthy';
  
  Color get impactColor {
    if (difference > 5) return Colors.green;
    if (difference > 0) return Colors.lightGreen;
    if (difference > -5) return Colors.orange;
    return Colors.red;
  }

  String get impactLabel {
    if (difference.abs() < 2) return 'Minimal impact';
    if (difference > 10) return 'Very positive';
    if (difference > 5) return 'Positive';
    if (difference > 0) return 'Slightly positive';
    if (difference > -5) return 'Slightly negative';
    if (difference > -10) return 'Negative';
    return 'Very negative';
  }
}

class AnalyticsData {
  const AnalyticsData({
    required this.message,
    required this.correlations,
    required this.totalSessions,
  });

  factory AnalyticsData.fromJson(Map<String, dynamic> json) {
    final correlationsList = json['correlations'] as List? ?? [];
    return AnalyticsData(
      message: json['message'] as String? ?? '',
      correlations: correlationsList
          .map((e) => HabitCorrelation.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalSessions: json['total_sessions'] as int? ?? 0,
    );
  }

  final String message;
  final List<HabitCorrelation> correlations;
  final int totalSessions;
}

// Provider for analytics data
final analyticsProvider = FutureProvider<AnalyticsData>((ref) async {
  final auth = ref.watch(authControllerProvider);
  final repository = ref.watch(sleepRepositoryProvider);
  
  if (auth.status != AuthStatus.authenticated || auth.token == null) {
    return const AnalyticsData(
      message: 'Please sign in to view analytics',
      correlations: [],
      totalSessions: 0,
    );
  }
  
  final response = await repository.fetchAnalytics(auth.token!);
  return AnalyticsData.fromJson(response);
});

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(analyticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(analyticsProvider);
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: analyticsAsync.when(
        data: (analytics) {
          if (analytics.correlations.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.analytics_outlined,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      analytics.message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Track your sleep and habits for at least a week to see insights.',
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

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header card
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.psychology,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Habit Impact Analysis',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        analytics.message,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'How your habits affect your sleep',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Higher numbers mean better sleep quality',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              
              const SizedBox(height: 16),
              
              // Correlations list
              ...analytics.correlations.map((correlation) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: correlation.isHealthy
                                    ? Colors.green.shade100
                                    : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                correlation.isHealthy
                                    ? Icons.check_circle
                                    : Icons.warning_amber_rounded,
                                color: correlation.isHealthy
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                correlation.habitName,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: correlation.impactColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: correlation.impactColor,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                '${correlation.difference > 0 ? '+' : ''}${correlation.difference.toStringAsFixed(1)}',
                                style: TextStyle(
                                  color: correlation.impactColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 12),
                        
                        Text(
                          correlation.impactLabel,
                          style: TextStyle(
                            color: correlation.impactColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Comparison bars
                        _ComparisonBar(
                          label: 'With this habit',
                          score: correlation.avgScoreWithHabit,
                          count: correlation.sampleSizeWith,
                          color: Colors.blue,
                        ),
                        
                        const SizedBox(height: 4),
                        
                        _ComparisonBar(
                          label: 'Without this habit',
                          score: correlation.avgScoreWithoutHabit,
                          count: correlation.sampleSizeWithout,
                          color: Colors.grey,
                        ),
                        
                        const SizedBox(height: 8),
                        
                        Text(
                          _getInsight(correlation),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          final errorMessage = error.toString();
          final isAuthError = errorMessage.contains('401') || 
                             errorMessage.contains('Unauthorized') ||
                             errorMessage.contains('authentication');
          
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isAuthError ? Icons.login : Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isAuthError ? 'Session expired' : 'Failed to load analytics',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAuthError 
                        ? 'Please reload the page or sign in again'
                        : errorMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (isAuthError) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        // Trigger a re-auth by invalidating the auth provider
                        ref.invalidate(authControllerProvider);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reload'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getInsight(HabitCorrelation correlation) {
    if (correlation.difference.abs() < 2) {
      return 'This habit doesn\'t seem to significantly affect your sleep.';
    }
    
    if (correlation.isHealthy && correlation.difference > 5) {
      return 'Great! This habit is helping you sleep better. Keep it up!';
    }
    
    if (correlation.isHealthy && correlation.difference > 0) {
      return 'This habit seems to improve your sleep slightly.';
    }
    
    if (!correlation.isHealthy && correlation.difference < -5) {
      return 'This habit significantly worsens your sleep. Consider avoiding it.';
    }
    
    if (!correlation.isHealthy && correlation.difference < 0) {
      return 'This habit may be affecting your sleep negatively.';
    }
    
    return 'Keep tracking to gather more data.';
  }
}

class _ComparisonBar extends StatelessWidget {
  const _ComparisonBar({
    required this.label,
    required this.score,
    required this.count,
    required this.color,
  });

  final String label;
  final double score;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: score / 100,
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: Text(
                    '${score.toStringAsFixed(1)} (${count}x)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      shadows: [
                        Shadow(
                          color: Colors.black45,
                          offset: Offset(1, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
