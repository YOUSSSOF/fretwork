import 'package:flutter/material.dart';
import 'package:fretwork/core/widgets/core_empty_state.dart';
import 'package:fretwork/core/widgets/core_scaffold.dart';

/// Placeholder — filled in by a later phase.
///
/// The ad-hoc parameters let the exercise detail screen start a one-item
/// session without going through today's routine.
class SessionScreen extends StatelessWidget {
  const SessionScreen({this.adHocExerciseId, this.adHocVariantId, super.key});

  final String? adHocExerciseId;
  final String? adHocVariantId;

  @override
  Widget build(BuildContext context) {
    return const CoreScaffold(
      title: 'Session',
      showBack: true,
      body: CoreEmptyState(
        icon: Icons.construction_rounded,
        title: 'Not built yet',
        message: 'The session runner arrives in a later phase.',
      ),
    );
  }
}
