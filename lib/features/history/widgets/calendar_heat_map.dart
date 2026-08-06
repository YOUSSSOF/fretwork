import 'package:flutter/material.dart';
import 'package:fretwork/core/models/day_record.dart';
import 'package:fretwork/core/motion/motion_scope.dart';
import 'package:fretwork/core/motion/motion_tokens.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/utils/date_x.dart';
import 'package:fretwork/core/widgets/core_pressable.dart';
import 'package:fretwork/core/widgets/core_text.dart';

/// A month of practice, one cell per day.
///
/// Missed days are drawn with a visible outline rather than left blank: the
/// whole point of recording empty days is that they show up.
class CalendarHeatMap extends StatelessWidget {
  const CalendarHeatMap({
    required this.month,
    required this.records,
    required this.today,
    this.onDaySelected,
    super.key,
  });

  final DateTime month;
  final Map<String, DayRecord> records;
  final DateTime today;
  final ValueChanged<DateTime>? onDaySelected;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Monday-first grid.
    final leadingBlanks = first.weekday - DateTime.monday;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final weekday in kAllWeekdays)
              Expanded(
                child: Center(
                  child: CoreText.caption(weekdayShortName(weekday)),
                ),
              ),
          ],
        ),
        const SizedBox(height: Sp.sm),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: Sp.xs,
          crossAxisSpacing: Sp.xs,
          children: [
            for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
            for (var day = 1; day <= daysInMonth; day++)
              _DayCell(
                date: DateTime(month.year, month.month, day),
                record: records[DateTime(month.year, month.month, day).dayKey],
                today: today,
                onPressed: onDaySelected,
              ),
          ],
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.record,
    required this.today,
    required this.onPressed,
  });

  final DateTime date;
  final DayRecord? record;
  final DateTime today;
  final ValueChanged<DateTime>? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isToday = date.isSameDayAs(today);
    final future = date.isAfter(today) && !isToday;
    final status = record?.status;

    final (Color fill, Color border, Color ink) = switch (status) {
      DayStatus.completed => (
        colors.accentStrong,
        colors.accentStrong,
        Colors.white,
      ),
      DayStatus.partial => (
        colors.accentStrong.withValues(alpha: 0.35),
        colors.accentStrong.withValues(alpha: 0.6),
        colors.textPrimary,
      ),
      // Visible, never blank.
      DayStatus.missed => (
        Colors.transparent,
        colors.danger.withValues(alpha: 0.45),
        colors.textTertiary,
      ),
      DayStatus.rest => (colors.surface2, colors.border, colors.textTertiary),
      _ => (
        Colors.transparent,
        future ? Colors.transparent : colors.border,
        colors.textTertiary,
      ),
    };

    return CorePressable(
      onPressed: onPressed == null || future ? null : () => onPressed!(date),
      pressedScale: 0.88,
      dim: 0,
      semanticLabel: '${date.shortDayLabel}, ${status?.label ?? 'no record'}',
      child: AnimatedContainer(
        duration: context.motion(Motion.fast),
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(
            color: isToday ? colors.textPrimary : border,
            width: isToday ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: CoreText.caption('${date.day}', color: ink),
      ),
    );
  }
}

/// Legend for the heat map. Small, but without it the colours are a guess.
class CalendarLegend extends StatelessWidget {
  const CalendarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Wrap(
      spacing: Sp.md,
      runSpacing: Sp.sm,
      children: [
        _LegendKey(color: colors.accentStrong, label: 'Completed'),
        _LegendKey(
          color: colors.accentStrong.withValues(alpha: 0.35),
          label: 'Partial',
        ),
        _LegendKey(
          color: Colors.transparent,
          border: colors.danger.withValues(alpha: 0.45),
          label: 'Missed',
        ),
        _LegendKey(color: colors.surface2, label: 'Rest'),
      ],
    );
  }
}

class _LegendKey extends StatelessWidget {
  const _LegendKey({required this.color, required this.label, this.border});

  final Color color;
  final Color? border;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: border ?? color),
          ),
        ),
        const SizedBox(width: Sp.xs),
        CoreText.caption(label),
      ],
    );
  }
}
