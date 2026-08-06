import 'package:flutter/material.dart';
import 'package:fretwork/core/widgets/core_empty_state.dart';
import 'package:fretwork/core/widgets/core_scaffold.dart';

/// Placeholder — filled in by a later phase.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CoreScaffold(
      title: 'Today',
      body: CoreEmptyState(
        icon: Icons.construction_rounded,
        title: 'Not built yet',
        message: 'The home cards arrive with the routine engine.',
      ),
    );
  }
}
