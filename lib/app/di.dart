// Root of the Riverpod provider tree.
//
// Cross-cutting providers (database instance, clock, repositories) are added
// here as their owning epics land (E1: Money/Clock/DB, E2: UserProfile, ...).
// Feature-local providers stay in `features/<feature>/application/` instead
// of being added to this file.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/time/clock.dart';
import '../data/db/app_database.dart';
import '../data/repositories/drift_user_profile_repository.dart';
import '../domain/entities/user_profile.dart';
import '../domain/repositories/user_profile_repository.dart';

part 'di.g.dart';

/// The app-wide time source. Engines/repositories take a [Clock] via
/// constructor injection (keeping the domain layer framework-agnostic);
/// this provider is how the Flutter/Riverpod layer supplies it. Override
/// with a [FixedClock] in widget/integration tests that need determinism.
@Riverpod(keepAlive: true)
Clock clock(Ref ref) => const SystemClock();

/// The app's single database connection — kept alive for the app's
/// lifetime, not recreated per screen.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase(clock: ref.watch(clockProvider));
  ref.onDispose(db.close);
  return db;
}

@Riverpod(keepAlive: true)
UserProfileRepository userProfileRepository(Ref ref) =>
    DriftUserProfileRepository(ref.watch(appDatabaseProvider));

/// The current local user profile, or `null` before onboarding has ever
/// completed (first launch). `appRouter`'s redirect logic watches this via
/// [appRouterProvider]'s `ref.listen` to decide whether to show onboarding.
///
/// Not a reactive stream — after `saveProfile` (E2.T4, onboarding
/// completion), the caller must `ref.invalidate(userProfileProvider)`.
@riverpod
Future<UserProfile?> userProfile(Ref ref) =>
    ref.watch(userProfileRepositoryProvider).getProfile();
