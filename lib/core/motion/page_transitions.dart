import 'package:flutter/material.dart';
import 'package:fretwork/core/motion/motion_scope.dart';
import 'package:fretwork/core/motion/motion_tokens.dart';
import 'package:go_router/go_router.dart';

/// Route transitions.
///
/// Three, deliberately: shared-axis X between shell branches, shared-axis Z for
/// push and pop inside a branch, and a vertical cover for the session, which is
/// modal in intent — you enter it, you finish, you come back.
abstract final class PageTransitions {
  /// Push/pop within a branch. Scale plus fade reads as moving *into* the
  /// content rather than sliding sideways past it.
  static CustomTransitionPage<T> sharedAxisZ<T>({
    required Widget child,
    required GoRouterState state,
  }) => CustomTransitionPage<T>(
    key: state.pageKey,
    transitionDuration: Motion.page,
    reverseTransitionDuration: Motion.base,
    child: child,
    transitionsBuilder: (context, animation, secondary, child) {
      if (context.reduceMotion) return child;
      final entering = CurvedAnimation(
        parent: animation,
        curve: Motion.emphasize,
        reverseCurve: Motion.exit,
      );
      final leaving = CurvedAnimation(
        parent: secondary,
        curve: Motion.emphasize,
        reverseCurve: Motion.exit,
      );
      return FadeTransition(
        opacity: entering,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(entering),
          child: ScaleTransition(
            // The outgoing page recedes slightly, so the two are never
            // ambiguous about which is on top.
            scale: Tween<double>(begin: 1, end: 1.04).animate(leaving),
            child: FadeTransition(
              opacity: Tween<double>(begin: 1, end: 0).animate(leaving),
              child: child,
            ),
          ),
        ),
      );
    },
  );

  /// The session route: covers the shell from below.
  static CustomTransitionPage<T> verticalCover<T>({
    required Widget child,
    required GoRouterState state,
  }) => CustomTransitionPage<T>(
    key: state.pageKey,
    transitionDuration: Motion.page,
    reverseTransitionDuration: Motion.base,
    fullscreenDialog: true,
    child: child,
    transitionsBuilder: (context, animation, secondary, child) {
      if (context.reduceMotion) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: Motion.emphasize,
        reverseCurve: Motion.exit,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );

  /// No transition — used for the shell branches themselves, whose crossfade is
  /// handled by [BranchSwitcher] so it can key off travel direction.
  static NoTransitionPage<T> none<T>({
    required Widget child,
    required GoRouterState state,
  }) => NoTransitionPage<T>(key: state.pageKey, child: child);
}

/// Shared-axis X between shell branches.
///
/// Direction matters: moving right along the nav bar should look like moving
/// right, which an [IndexedStack] alone cannot express.
class BranchSwitcher extends StatefulWidget {
  const BranchSwitcher({required this.index, required this.child, super.key});

  final int index;
  final Widget child;

  @override
  State<BranchSwitcher> createState() => _BranchSwitcherState();
}

class _BranchSwitcherState extends State<BranchSwitcher> {
  late int _previousIndex = widget.index;

  @override
  void didUpdateWidget(BranchSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) _previousIndex = oldWidget.index;
  }

  @override
  Widget build(BuildContext context) {
    final forwards = widget.index >= _previousIndex;
    return AnimatedSwitcher(
      duration: context.motion(Motion.base),
      switchInCurve: Motion.standard,
      switchOutCurve: Motion.exit,
      layoutBuilder: (current, previous) =>
          Stack(children: [...previous, ?current]),
      transitionBuilder: (child, animation) {
        final incoming = child.key == ValueKey(widget.index);
        final begin = incoming
            ? Offset(forwards ? 0.06 : -0.06, 0)
            : Offset(forwards ? -0.04 : 0.04, 0);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: begin,
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(key: ValueKey(widget.index), child: widget.child),
    );
  }
}
