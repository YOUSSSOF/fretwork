import 'package:flutter/material.dart';
import 'package:fretwork/core/widgets/core_empty_state.dart';
import 'package:fretwork/core/widgets/core_scaffold.dart';

/// Placeholder — filled in by a later phase.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CoreScaffold(
      title: 'Welcome',
      body: CoreEmptyState(
        icon: Icons.construction_rounded,
        title: 'Not built yet',
        message: 'Onboarding arrives in a later phase.',
      ),
    );
  }
}
