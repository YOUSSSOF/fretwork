import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:fretwork/core/models/practice_category.dart';
import 'package:fretwork/core/motion/motion_scope.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/utils/date_x.dart';
import 'package:fretwork/core/widgets/core_text.dart';

/// Minutes per day over the selected range.
class MinutesOverTimeChart extends StatelessWidget {
  const MinutesOverTimeChart({required this.minutesByDay, super.key});

  final Map<DateTime, int> minutesByDay;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final days = minutesByDay.keys.toList()..sort();
    if (days.length < 2) {
      return const _ChartPlaceholder(
        message: 'A couple more days and this becomes a line.',
      );
    }

    final spots = [
      for (var i = 0; i < days.length; i++)
        FlSpot(i.toDouble(), (minutesByDay[days[i]] ?? 0).toDouble()),
    ];
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY <= 0 ? 10 : maxY * 1.2,
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: colors.border, strokeWidth: 1),
          ),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.22,
              barWidth: 2,
              color: colors.accentStrong,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colors.accentStrong.withValues(alpha: 0.25),
                    colors.accentStrong.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ],
        ),
        // Draw-in only on first mount, and not at all under reduced motion.
        duration: context.motion(const Duration(milliseconds: 420)),
      ),
    );
  }
}

/// Category split as a donut, with the total in the hole.
class CategoryDonut extends StatelessWidget {
  const CategoryDonut({required this.minutesByCategory, super.key});

  final Map<PracticeCategory, int> minutesByCategory;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final entries = minutesByCategory.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return const _ChartPlaceholder(
        message: 'Nothing logged in this range yet.',
      );
    }

    final total = entries.fold<int>(0, (sum, e) => sum + e.value);

    return Row(
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 46,
                  sections: [
                    for (final entry in entries)
                      PieChartSectionData(
                        value: entry.value.toDouble(),
                        color: colors.categoryColor(
                          entry.key.index,
                          PracticeCategory.values.length,
                        ),
                        radius: 20,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CoreText.h3('$total', tabular: true),
                  const CoreText.caption('MIN'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: Sp.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: Sp.xs),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        color: colors.categoryColor(
                          entry.key.index,
                          PracticeCategory.values.length,
                        ),
                      ),
                      const SizedBox(width: Sp.sm),
                      Expanded(
                        child: CoreText.bodySm(entry.key.label, maxLines: 1),
                      ),
                      CoreText.caption('${entry.value}'),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Average minutes per weekday — this is the chart that exposes the day the
/// user keeps skipping.
class WeekdayBars extends StatelessWidget {
  const WeekdayBars({required this.minutesByWeekday, super.key});

  final Map<int, double> minutesByWeekday;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final values = kAllWeekdays.map((d) => minutesByWeekday[d] ?? 0).toList();
    final maxValue = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a > b ? a : b);

    if (maxValue <= 0) {
      return const _ChartPlaceholder(
        message: 'No practice recorded in this range.',
      );
    }

    return SizedBox(
      height: 150,
      child: BarChart(
        BarChartData(
          maxY: maxValue * 1.2,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(),
            topTitles: AxisTitles(),
            rightTitles: AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, _) => Padding(
                  padding: const EdgeInsets.only(top: Sp.xs),
                  child: CoreText.caption(
                    weekdayShortName(kAllWeekdays[value.toInt()]),
                  ),
                ),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < values.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: values[i],
                    width: 14,
                    borderRadius: BorderRadius.zero,
                    color: values[i] == maxValue
                        ? colors.accentStrong
                        : colors.accentStrong.withValues(alpha: 0.4),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Session starts by hour — surfaces whether the user practises better in the
/// morning.
class TimeOfDayHistogram extends StatelessWidget {
  const TimeOfDayHistogram({required this.sessionsByHour, super.key});

  final Map<int, int> sessionsByHour;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (sessionsByHour.isEmpty) {
      return const _ChartPlaceholder(message: 'No sessions in this range.');
    }
    final peak = sessionsByHour.values.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 64,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var hour = 0; hour < 24; hour++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: FractionallySizedBox(
                      heightFactor: peak == 0
                          ? 0.02
                          : ((sessionsByHour[hour] ?? 0) / peak).clamp(
                              0.02,
                              1.0,
                            ),
                      alignment: Alignment.bottomCenter,
                      child: ColoredBox(
                        color: (sessionsByHour[hour] ?? 0) == peak
                            ? colors.accentStrong
                            : colors.accentStrong.withValues(alpha: 0.35),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Sp.xs),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CoreText.caption('00'),
            CoreText.caption('06'),
            CoreText.caption('12'),
            CoreText.caption('18'),
            CoreText.caption('23'),
          ],
        ),
      ],
    );
  }
}

class _ChartPlaceholder extends StatelessWidget {
  const _ChartPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: Center(
        child: CoreText.bodySm(
          message,
          align: TextAlign.center,
          color: context.colors.textTertiary,
        ),
      ),
    );
  }
}
