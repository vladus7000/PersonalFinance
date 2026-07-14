// Root of the Riverpod provider tree.
//
// Cross-cutting providers (database instance, clock, repositories) are added
// here as their owning epics land (E1: Money/Clock/DB, E2: UserProfile, ...).
// Feature-local providers stay in `features/<feature>/application/` instead
// of being added to this file.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/time/clock.dart';

part 'di.g.dart';

/// The app-wide time source. Engines/repositories take a [Clock] via
/// constructor injection (keeping the domain layer framework-agnostic);
/// this provider is how the Flutter/Riverpod layer supplies it. Override
/// with a [FixedClock] in widget/integration tests that need determinism.
@Riverpod(keepAlive: true)
Clock clock(Ref ref) => const SystemClock();
