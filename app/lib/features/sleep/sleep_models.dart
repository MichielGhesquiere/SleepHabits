class SleepSummary {
  SleepSummary({
    required this.lastNightDate,
    required this.lastNightDurationMinutes,
    required this.lastNightScore,
    required this.bedtime,
    required this.wakeTime,
    required this.stageMinutes,
    required this.avgDurationMinutes7d,
    required this.avgScore7d,
    required this.sleepMidpoint,
    required this.consistencyMinutes,
    required this.positiveHabitsCompleted,
    required this.positiveHabitsTotal,
    required this.negativeHabitsAvoided,
    required this.negativeHabitsTotal,
    required this.garminConnected,
  });

  factory SleepSummary.fromJson(Map<String, dynamic> json) {
    final lastNight = json['last_night'] as Map<String, dynamic>? ?? {};
    final trailing = json['trailing_7d'] as Map<String, dynamic>? ?? {};
    final habits = json['habits'] as Map<String, dynamic>? ?? {};
    final user = json['user'] as Map<String, dynamic>? ?? {};

    return SleepSummary(
      lastNightDate: DateTime.tryParse(lastNight['date'] as String? ?? '') ??
          DateTime.now(),
      lastNightDurationMinutes:
          (lastNight['duration_minutes'] as num?)?.toInt() ?? 0,
      lastNightScore: (lastNight['sleep_score'] as num?)?.toInt(),
      bedtime: lastNight['bedtime'] as String? ?? '--:--',
      wakeTime: lastNight['wake_time'] as String? ?? '--:--',
      stageMinutes: (lastNight['stages'] as Map<String, dynamic>?)
              ?.map((key, value) => MapEntry(key, (value as num).toInt())) ??
          const {},
      avgDurationMinutes7d:
          (trailing['avg_duration_minutes'] as num?)?.toDouble() ?? 0,
      avgScore7d: (trailing['avg_score'] as num?)?.toDouble() ?? 0,
      sleepMidpoint: trailing['midpoint'] as String? ?? '--:--',
      consistencyMinutes:
          (trailing['consistency_minutes'] as num?)?.toInt() ?? 0,
      positiveHabitsCompleted:
          (habits['positive_completed'] as num?)?.toInt() ?? 0,
      positiveHabitsTotal: (habits['positive_total'] as num?)?.toInt() ?? 0,
      negativeHabitsAvoided:
          (habits['negative_completed'] as num?)?.toInt() ?? 0,
      negativeHabitsTotal: (habits['negative_total'] as num?)?.toInt() ?? 0,
      garminConnected: user['garmin_connected'] as bool? ?? false,
    );
  }

  final DateTime lastNightDate;
  final int lastNightDurationMinutes;
  final int? lastNightScore;
  final String bedtime;
  final String wakeTime;
  final Map<String, int> stageMinutes;
  final double avgDurationMinutes7d;
  final double avgScore7d;
  final String sleepMidpoint;
  final int consistencyMinutes;
  final int positiveHabitsCompleted;
  final int positiveHabitsTotal;
  final int negativeHabitsAvoided;
  final int negativeHabitsTotal;
  final bool garminConnected;

  double get lastNightDurationHours => lastNightDurationMinutes / 60;
  double get avgDurationHours7d => avgDurationMinutes7d / 60;
}
