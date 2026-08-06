import 'package:flutter/material.dart';
import 'package:fretwork/core/data/course_providers.dart';
import 'package:fretwork/core/data/providers.dart';
import 'package:fretwork/core/models/day_record.dart';
import 'package:fretwork/core/motion/motion_scope.dart';
import 'package:fretwork/core/motion/motion_tokens.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/utils/date_x.dart';
import 'package:fretwork/core/widgets/core_badge.dart';
import 'package:fretwork/core/widgets/core_card.dart';
import 'package:fretwork/core/widgets/core_divider.dart';
import 'package:fretwork/core/widgets/core_icon_button.dart';
import 'package:fretwork/core/widgets/core_scaffold.dart';
import 'package:fretwork/core/widgets/core_section_header.dart';
import 'package:fretwork/core/widgets/core_sheet.dart';
import 'package:fretwork/core/widgets/core_text.dart';
import 'package:fretwork/features/history/history_controller.dart';
import 'package:fretwork/features/history/widgets/calendar_heat_map.dart';
import 'package:fretwork/features/session/records_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  DateTime? _month;
  int _direction = 1;

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(clockProvider).now().dayStart;
    final month = _month ?? DateTime(today.year, today.month);
    final records = ref.watch(dayRecordsProvider);

    final monthRecords = records.values.where(
      (r) => r.date.year == month.year && r.date.month == month.month,
    );
    final practised = monthRecords.where((r) => r.completedMinutes > 0).length;
    final missed = monthRecords
        .where((r) => r.status == DayStatus.missed)
        .length;
    final minutes = monthRecords.fold<int>(
      0,
      (sum, r) => sum + r.completedMinutes,
    );

    return CoreScaffold(
      title: 'History',
      subtitle: month.monthLabel,
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.only(bottom: Sp.huge),
        children: [
          _MonthBar(
            month: month,
            canGoForward: month.isBefore(DateTime(today.year, today.month)),
            onChanged: (next, direction) => setState(() {
              _month = next;
              _direction = direction;
            }),
          ),
          // Paging slides horizontally in the direction of travel, so moving
          // back through the year reads as moving back.
          AnimatedSwitcher(
            duration: context.motion(Motion.base),
            switchInCurve: Motion.standard,
            transitionBuilder: (child, animation) => SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0.12 * _direction, 0),
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: CalendarHeatMap(
              key: ValueKey(month),
              month: month,
              records: records,
              today: today,
              onDaySelected: (date) => _openDay(context, date),
            ),
          ),
          const SizedBox(height: Sp.lg),
          const CalendarLegend(),
          const CoreSectionHeader(title: 'This month'),
          Row(
            children: [
              Expanded(
                child: _Stat(label: 'Minutes', value: '$minutes'),
              ),
              Expanded(
                child: _Stat(label: 'Practised', value: '$practised'),
              ),
              Expanded(
                child: _Stat(label: 'Missed', value: '$missed'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openDay(BuildContext context, DateTime date) =>
      showCoreSheet<void>(
        context: context,
        title: date.shortDayLabel,
        builder: (_) => _DayDetailSheet(date: date),
      );
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.month,
    required this.canGoForward,
    required this.onChanged,
  });

  final DateTime month;
  final bool canGoForward;
  final void Function(DateTime month, int direction) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sp.md),
      child: Row(
        children: [
          CoreIconButton(
            icon: Icons.chevron_left_rounded,
            semanticLabel: 'Previous month',
            onPressed: () =>
                onChanged(DateTime(month.year, month.month - 1), -1),
          ),
          Expanded(child: Center(child: CoreText.title(month.monthLabel))),
          CoreIconButton(
            icon: Icons.chevron_right_rounded,
            semanticLabel: 'Next month',
            onPressed: canGoForward
                ? () => onChanged(DateTime(month.year, month.month + 1), 1)
                : null,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: Sp.sm),
      child: CoreCard(
        padding: const EdgeInsets.all(Sp.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoreText.caption(label.toUpperCase()),
            const SizedBox(height: Sp.xs),
            CoreText.h2(value, tabular: true),
          ],
        ),
      ),
    );
  }
}

class _DayDetailSheet extends ConsumerWidget {
  const _DayDetailSheet({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(dayDetailProvider(date));
    final index = ref.watch(exerciseIndexProvider);
    final record = detail.record;

    if (!detail.hasAnything) {
      return const CoreText.body(
        'Nothing was recorded for this day — it is before you started using '
        'Fretwork.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (record != null) CoreBadge(record.status.label),
            const Spacer(),
            CoreText.mono(
              '${detail.completedMinutes} / ${record?.plannedMinutes ?? 0} min',
            ),
          ],
        ),
        if (detail.routine != null) ...[
          const SizedBox(height: Sp.lg),
          const CoreText.label('PLANNED'),
          const SizedBox(height: Sp.sm),
          for (final block in detail.routine!.blocks)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.xs),
              child: Row(
                children: [
                  Expanded(child: CoreText.bodySm(block.label)),
                  CoreText.caption('${block.minutes} min'),
                ],
              ),
            ),
        ],
        if (detail.sessions.isEmpty) ...[
          const SizedBox(height: Sp.lg),
          CoreText.bodySm(
            record?.status == DayStatus.rest
                ? 'A rest day. Nothing was scheduled.'
                : 'No session was logged on this day.',
            color: context.colors.textTertiary,
          ),
        ] else
          for (final session in detail.sessions) ...[
            const SizedBox(height: Sp.lg),
            const CoreDivider(),
            const SizedBox(height: Sp.md),
            Row(
              children: [
                Expanded(
                  child: CoreText.label(
                    session.abandoned ? 'Session (ended early)' : 'Session',
                  ),
                ),
                CoreText.mono('${session.actualMinutes} min'),
              ],
            ),
            const SizedBox(height: Sp.sm),
            for (final item in session.items)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: CoreText.bodySm(
                        index[item.exerciseId]?.label ?? item.exerciseId,
                        color: item.skipped
                            ? context.colors.textTertiary
                            : null,
                      ),
                    ),
                    if (item.clean)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: Sp.sm),
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 12,
                          color: context.colors.success,
                        ),
                      ),
                    CoreText.caption(
                      item.skipped
                          ? 'skipped'
                          : '${item.endTempo > 0 ? '${item.endTempo} bpm · ' : ''}'
                                '${item.minutes} min',
                    ),
                  ],
                ),
              ),
          ],
        const SizedBox(height: Sp.lg),
      ],
    );
  }
}
