import 'package:flutter/material.dart';
import 'package:fretwork/core/widgets/core_empty_state.dart';
import 'package:fretwork/core/widgets/core_scaffold.dart';

/// Placeholder — filled in by a later phase.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CoreScaffold(
      title: 'History',
      body: CoreEmptyState(
        icon: Icons.construction_rounded,
        title: 'Not built yet',
        message: 'The calendar heat map arrives in a later phase.',
      ),
    );
  }
}
