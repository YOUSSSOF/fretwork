import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fretwork/core/motion/motion_scope.dart';
import 'package:fretwork/core/motion/motion_tokens.dart';
import 'package:fretwork/core/motion/page_transitions.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/theme/glass.dart';
import 'package:fretwork/core/widgets/core_pressable.dart';
import 'package:fretwork/core/widgets/core_text.dart';
import 'package:go_router/go_router.dart';

@immutable
class NavDestination {
  const NavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

const List<NavDestination> kNavDestinations = [
  NavDestination(
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    label: 'Home',
  ),
  NavDestination(
    icon: Icons.event_note_outlined,
    activeIcon: Icons.event_note_rounded,
    label: 'Routine',
  ),
  NavDestination(
    icon: Icons.av_timer_outlined,
    activeIcon: Icons.av_timer_rounded,
    label: 'Click',
  ),
  NavDestination(
    icon: Icons.library_music_outlined,
    activeIcon: Icons.library_music_rounded,
    label: 'Library',
  ),
  NavDestination(
    icon: Icons.insights_outlined,
    activeIcon: Icons.insights_rounded,
    label: 'Analytics',
  ),
  NavDestination(
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings_rounded,
    label: 'Settings',
  ),
];

/// Height of the nav bar's content, before the device's own bottom inset.
const double kNavBarHeight = 60;

/// Publishes how much of the bottom of the screen the nav bar covers.
///
/// The shell deliberately extends the body behind the glass nav bar, so
/// scrolling content passes under it. That only works if the scroll views know
/// to end above it — otherwise the last card sits permanently behind the bar.
class ShellInsets extends InheritedWidget {
  const ShellInsets({required this.bottom, required super.child, super.key});

  final double bottom;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellInsets>()?.bottom ?? 0;

  @override
  bool updateShouldNotify(ShellInsets oldWidget) => oldWidget.bottom != bottom;
}

extension ShellInsetsX on BuildContext {
  /// Bottom padding a scroll view needs to clear the nav bar. Zero outside the
  /// shell, so full-screen routes are unaffected.
  double get shellBottomInset => ShellInsets.of(this);
}

/// How long the second back press has to land to count as "yes, exit".
const Duration kExitConfirmWindow = Duration(seconds: 2);

class AppShell extends StatefulWidget {
  const AppShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  DateTime? _lastBackPress;

  /// Back walks out the way you came in: out of a detail screen, then back to
  /// Home, and only then out of the app — and that last step needs saying
  /// twice, because a stray back press should never end a practice day.
  void _handleBack() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }

    if (widget.shell.currentIndex != 0) {
      widget.shell.goBranch(0);
      return;
    }

    final now = DateTime.now();
    final last = _lastBackPress;
    if (last != null && now.difference(last) < kExitConfirmWindow) {
      SystemNavigator.pop();
      return;
    }

    _lastBackPress = now;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('Press back again to exit'),
          duration: kExitConfirmWindow,
          behavior: SnackBarBehavior.floating,
          backgroundColor: context.colors.surface2,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: context.colors.surface0,
        extendBody: true,
        body: ShellInsets(
          bottom: kNavBarHeight + MediaQuery.paddingOf(context).bottom,
          child: BranchSwitcher(
            index: widget.shell.currentIndex,
            child: widget.shell,
          ),
        ),
        bottomNavigationBar: _NavBar(
          currentIndex: widget.shell.currentIndex,
          onSelected: (index) => widget.shell.goBranch(
            index,
            // Tapping the current tab again pops that branch back to its root,
            // which is what every platform's tab bar does.
            initialLocation: index == widget.shell.currentIndex,
          ),
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.currentIndex, required this.onSelected});

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GlassSurface(
      bordered: false,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: kNavBarHeight,
            child: Row(
              children: [
                for (var i = 0; i < kNavDestinations.length; i++)
                  Expanded(
                    child: _NavItem(
                      destination: kNavDestinations[i],
                      selected: i == currentIndex,
                      onPressed: () => onSelected(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onPressed,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onPressed;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(
      vsync: this,
      duration: Motion.snappyCurve.settleDuration,
    );
  }

  @override
  void didUpdateWidget(_NavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected && !context.reduceMotion) {
      _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ink = widget.selected ? colors.textPrimary : colors.textTertiary;

    return CorePressable(
      onPressed: () {
        HapticFeedback.selectionClick();
        widget.onPressed();
      },
      haptic: false,
      pressedScale: 0.92,
      dim: 0,
      semanticLabel: widget.destination.label,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pop,
            builder: (context, child) {
              // 1.0 → 0.86 → 1.0, driven by the spring so the return
              // overshoots very slightly.
              final t = Motion.snappyCurve.transform(
                _pop.value.clamp(0.0, 1.0),
              );
              final dip = 1 - 0.14 * (1 - (2 * t - 1).abs());
              return Transform.scale(scale: dip, child: child);
            },
            child: Icon(
              widget.selected
                  ? widget.destination.activeIcon
                  : widget.destination.icon,
              size: 22,
              color: ink,
            ),
          ),
          const SizedBox(height: Sp.xs),
          AnimatedSlide(
            duration: context.motion(Motion.fast),
            curve: Motion.standard,
            offset: widget.selected ? const Offset(0, -0.12) : Offset.zero,
            child: CoreText.caption(widget.destination.label, color: ink),
          ),
        ],
      ),
    );
  }
}
