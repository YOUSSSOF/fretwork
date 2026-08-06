import 'package:flutter/material.dart';
import 'package:fretwork/core/widgets/core_empty_state.dart';
import 'package:fretwork/core/widgets/core_scaffold.dart';

/// Placeholder — filled in by a later phase.
class RoutineScreen extends StatelessWidget {
  const RoutineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CoreScaffold(
      title: 'Routine',
      body: CoreEmptyState(
        icon: Icons.construction_rounded,
        title: 'Not built yet',
        message: "Today's plan arrives with the routine engine.",
      ),
    );
  }
}
