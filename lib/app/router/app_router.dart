import 'package:go_router/go_router.dart';

import 'app_shell.dart';
import '../../features/accounts/presentation/accounts_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/decisions/presentation/decisions_screen.dart';
import '../../features/plan/presentation/plan_screen.dart';
import '../../features/settings/presentation/more_screen.dart';

/// Route paths, exposed as constants so features can deep-link without
/// depending on string literals scattered across the codebase.
abstract final class AppRoutes {
  static const overview = '/overview';
  static const plan = '/plan';
  static const accounts = '/accounts';
  static const decisions = '/decisions';
  static const more = '/more';
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.overview,
  routes: [
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
            GoRoute(
              path: AppRoutes.plan,
              builder: (context, state) => const PlanScreen(),
            ),
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
            GoRoute(
              path: AppRoutes.more,
              builder: (context, state) => const MoreScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
