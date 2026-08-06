import 'package:flutter/material.dart';
import 'package:fretwork/core/widgets/core_empty_state.dart';
import 'package:fretwork/core/widgets/core_scaffold.dart';

/// Placeholder — filled in by a later phase.
class ExerciseDetailScreen extends StatelessWidget {
  const ExerciseDetailScreen({required this.exerciseId, super.key});

  final String exerciseId;

  @override
  Widget build(BuildContext context) {
    return CoreScaffold(
      title: 'Exercise',
      subtitle: exerciseId,
      showBack: true,
      body: const CoreEmptyState(
        icon: Icons.construction_rounded,
        title: 'Not built yet',
        message: 'Exercise detail arrives in a later phase.',
      ),
    );
  }
}
