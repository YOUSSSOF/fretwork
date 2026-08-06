import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretwork/core/motion/page_transitions.dart';
import 'package:fretwork/features/analytics/analytics_screen.dart';
import 'package:fretwork/features/debug/gallery_screen.dart';
import 'package:fretwork/features/history/history_screen.dart';
import 'package:fretwork/features/home/home_screen.dart';
import 'package:fretwork/features/library/exercise_detail_screen.dart';
import 'package:fretwork/features/library/library_screen.dart';
import 'package:fretwork/features/onboarding/onboarding_screen.dart';
import 'package:fretwork/features/progress/milestone_screen.dart';
import 'package:fretwork/features/progress/progress_controller.dart';
import 'package:fretwork/features/routine/routine_screen.dart';
import 'package:fretwork/features/session/session_screen.dart';
import 'package:fretwork/features/settings/settings_screen.dart';
import 'package:fretwork/features/shell/app_shell.dart';
import 'package:go_router/go_router.dart';

abstract final class Routes {
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String progress = '/home/progress';
  static const String routine = '/routine';
  static const String session = '/routine/session';
  static const String library = '/library';
  static const String analytics = '/analytics';
  static const String history = '/analytics/history';
  static const String settings = '/settings';
  static const String gallery = '/debug/gallery';

  static String exercise(String id) => '/library/exercise/$id';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Built once. The redirect reads the profile through `ref.read` and the router
/// is re-evaluated by [_OnboardingRefresh]; watching the profile here instead
/// would rebuild the whole router — and lose all navigation state — every time
/// the user changed their session length.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _OnboardingRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final onboarded = ref.read(profileProvider).onboardingComplete;
      final path = state.uri.path;
      // The gallery is reachable at any time; it is a development surface and
      // gating it behind onboarding would defeat the point.
      if (path.startsWith('/debug')) return null;
      if (!onboarded && !path.startsWith(Routes.onboarding)) {
        return Routes.onboarding;
      }
      if (onboarded && path.startsWith(Routes.onboarding)) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.onboarding,
        pageBuilder: (context, state) =>
            PageTransitions.none(state: state, child: const OnboardingScreen()),
      ),
      GoRoute(
        path: Routes.gallery,
        pageBuilder: (context, state) => PageTransitions.sharedAxisZ(
          state: state,
          child: const GalleryScreen(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                pageBuilder: (context, state) => PageTransitions.none(
                  state: state,
                  child: const HomeScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'progress',
                    pageBuilder: (context, state) =>
                        PageTransitions.sharedAxisZ(
                          state: state,
                          child: const MilestoneScreen(),
                        ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.routine,
                pageBuilder: (context, state) => PageTransitions.none(
                  state: state,
                  child: const RoutineScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'session',
                    // Pushed above the shell so the nav bar is hidden: a
                    // running session is not a place to tab away from.
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (context, state) =>
                        PageTransitions.verticalCover(
                          state: state,
                          child: SessionScreen(
                            adHocExerciseId:
                                state.uri.queryParameters['exercise'],
                            adHocVariantId:
                                state.uri.queryParameters['variant'],
                          ),
                        ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.library,
                pageBuilder: (context, state) => PageTransitions.none(
                  state: state,
                  child: const LibraryScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'exercise/:id',
                    pageBuilder: (context, state) =>
                        PageTransitions.sharedAxisZ(
                          state: state,
                          child: ExerciseDetailScreen(
                            exerciseId: state.pathParameters['id'] ?? '',
                          ),
                        ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.analytics,
                pageBuilder: (context, state) => PageTransitions.none(
                  state: state,
                  child: const AnalyticsScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'history',
                    pageBuilder: (context, state) =>
                        PageTransitions.sharedAxisZ(
                          state: state,
                          child: const HistoryScreen(),
                        ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                pageBuilder: (context, state) => PageTransitions.none(
                  state: state,
                  child: const SettingsScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Notifies go_router only when the onboarding flag actually flips.
class _OnboardingRefresh extends ChangeNotifier {
  _OnboardingRefresh(Ref ref) {
    _subscription = ref.listen<bool>(
      profileProvider.select((p) => p.onboardingComplete),
      (_, _) => notifyListeners(),
    );
  }

  late final ProviderSubscription<bool> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
