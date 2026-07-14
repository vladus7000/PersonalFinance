import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_shell.dart';
import '../../features/accounts/presentation/accounts_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/decisions/presentation/decisions_screen.dart';
import '../../features/onboarding/presentation/onboarding_flow_screen.dart';
import '../../features/plan/presentation/plan_screen.dart';
import '../../features/settings/presentation/more_screen.dart';
import '../di.dart';

part 'app_router.g.dart';

/// Route paths, exposed as constants so features can deep-link without
/// depending on string literals scattered across the codebase.
abstract final class AppRoutes {
  static const overview = '/overview';
  static const plan = '/plan';
  static const accounts = '/accounts';
  static const decisions = '/decisions';
  static const more = '/more';
  static const onboarding = '/onboarding';
}

/// A [GoRouter] as a provider (not a static global) so its `redirect` logic
/// can react to [userProfileProvider] — first launch (no profile, or
/// `onboardingCompleted == false`) redirects to onboarding; a completed
/// profile redirects away from it. See BUILD_PLAN.md E2.T4.
///
/// `ref.watch(userProfileProvider)` is deliberately NOT called at the top
/// level here — that would recreate the whole [GoRouter] (losing navigation
/// state) every time the profile changes. Instead `ref.listen` pings a
/// [refreshListenable] so go_router just re-runs `redirect`, and `redirect`
/// itself reads the latest value with `ref.read`.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final refresh = _RouterRefreshNotifier();
  ref.listen(userProfileProvider, (previous, next) => refresh.ping());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.overview,
    refreshListenable: refresh,
    redirect: (context, state) {
      final profileAsync = ref.read(userProfileProvider);
      return profileAsync.when(
        data: (profile) {
          final completed = profile?.onboardingCompleted ?? false;
          final onOnboarding = state.matchedLocation == AppRoutes.onboarding;
          if (!completed && !onOnboarding) return AppRoutes.onboarding;
          if (completed && onOnboarding) return AppRoutes.overview;
          return null;
        },
        // Stay put while the profile is loading (app start) or if loading
        // it failed — a broken redirect must never trap the user.
        loading: () => null,
        error: (_, _) => null,
      );
    },
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingFlowScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.overview,
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: AppRoutes.plan, builder: (context, state) => const PlanScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.accounts,
                builder: (context, state) => const AccountsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.decisions,
                builder: (context, state) => const DecisionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: AppRoutes.more, builder: (context, state) => const MoreScreen()),
            ],
          ),
        ],
      ),
    ],
  );
}

class _RouterRefreshNotifier extends ChangeNotifier {
  void ping() => notifyListeners();
}
