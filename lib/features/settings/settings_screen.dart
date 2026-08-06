import 'package:flutter/material.dart';
import 'package:fretwork/core/widgets/core_empty_state.dart';
import 'package:fretwork/core/widgets/core_scaffold.dart';

/// Placeholder — filled in by a later phase.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CoreScaffold(
      title: 'Settings',
      body: CoreEmptyState(
        icon: Icons.construction_rounded,
        title: 'Not built yet',
        message: 'Preferences arrive in a later phase.',
      ),
    );
  }
}
