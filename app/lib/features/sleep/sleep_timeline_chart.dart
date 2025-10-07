import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SleepTimelineChart extends StatelessWidget {
  const SleepTimelineChart({
    required this.timeline,
    required this.range,
    super.key,
  });

  final List<dynamic> timeline;
  final String range;

  @override
  Widget build(BuildContext context) {
    if (timeline.isEmpty) {
      return const Center(
        child: Text('No sleep data available for this period'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Bedtime/Waketime chart
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sleep & Wake Times',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 250,
                  child: _buildTimeChart(context),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Sleep duration chart
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sleep Duration',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: _buildDurationChart(context),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Sleep score chart
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sleep Score',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: _buildScoreChart(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeChart(BuildContext context) {
    final spots = <ScatterSpot>[];
    final wakeSpots = <ScatterSpot>[];

    for (var i = 0; i < timeline.length; i++) {
      final entry = timeline[i];
      final bedtime = _parseTime(entry['bedtime'] as String);
      final waketime = _parseTime(entry['wake_time'] as String);

      // Convert to hours from midnight (handle times past midnight)
      var bedtimeHours = bedtime.hour + bedtime.minute / 60.0;
      if (bedtimeHours < 12) bedtimeHours += 24; // Late bedtime (past midnight)
      
      final waketimeHours = waketime.hour + waketime.minute / 60.0;

      spots.add(ScatterSpot(i.toDouble(), bedtimeHours));
      wakeSpots.add(ScatterSpot(i.toDouble(), waketimeHours));
    }

    return ScatterChart(
      ScatterChartData(
        scatterSpots: spots,
        minY: 0,
        maxY: 32, // 0-32 hours to show late bedtimes
        minX: -0.5,
        maxX: timeline.length - 0.5,
        borderData: FlBorderData(show: true),
        gridData: FlGridData(
          drawVerticalLine: true,
          horizontalInterval: 2,
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value >= timeline.length) return const SizedBox();
                final entry = timeline[value.toInt()];
                final date = DateTime.parse(entry['date'] as String);
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('M/d').format(date),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
              interval: timeline.length > 30 ? 7 : (timeline.length > 7 ? 3 : 1),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final hour = value.toInt() % 24;
                return Text(
                  '${hour.toString().padLeft(2, '0')}:00',
                  style: const TextStyle(fontSize: 10),
                );
              },
              interval: 2,
              reservedSize: 40,
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        scatterTouchData: ScatterTouchData(enabled: true),
      ),
      swapAnimationDuration: const Duration(milliseconds: 600),
    );
  }

  Widget _buildDurationChart(BuildContext context) {
    final spots = <FlSpot>[];

    for (var i = 0; i < timeline.length; i++) {
      final entry = timeline[i];
      final durationHours = (entry['duration_minutes'] as int) / 60.0;
      spots.add(FlSpot(i.toDouble(), durationHours));
    }

    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withOpacity(0.2),
            ),
          ),
        ],
        minY: 0,
        maxY: 12,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value >= timeline.length) return const SizedBox();
                final entry = timeline[value.toInt()];
                final date = DateTime.parse(entry['date'] as String);
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('M/d').format(date),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
              interval: timeline.length > 30 ? 7 : (timeline.length > 7 ? 3 : 1),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}h',
                  style: const TextStyle(fontSize: 10),
                );
              },
              interval: 2,
              reservedSize: 35,
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          horizontalInterval: 2,
        ),
        borderData: FlBorderData(show: true),
      ),
    );
  }

  Widget _buildScoreChart(BuildContext context) {
    final spots = <FlSpot>[];

    for (var i = 0; i < timeline.length; i++) {
      final entry = timeline[i];
      final score = entry['sleep_score'] as int?;
      if (score != null) {
        spots.add(FlSpot(i.toDouble(), score.toDouble()));
      }
    }

    if (spots.isEmpty) {
      return const Center(child: Text('No sleep score data available'));
    }

    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.green,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.green.withOpacity(0.2),
            ),
          ),
        ],
        minY: 0,
        maxY: 100,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value >= timeline.length) return const SizedBox();
                final entry = timeline[value.toInt()];
                final date = DateTime.parse(entry['date'] as String);
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('M/d').format(date),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
              interval: timeline.length > 30 ? 7 : (timeline.length > 7 ? 3 : 1),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
              interval: 20,
              reservedSize: 30,
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          horizontalInterval: 20,
        ),
        borderData: FlBorderData(show: true),
      ),
    );
  }

  TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }
}
