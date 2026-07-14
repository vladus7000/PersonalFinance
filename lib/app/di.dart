// Root of the Riverpod provider tree.
//
// Cross-cutting providers (database instance, clock, repositories) are added
// here as their owning epics land (E1: Money/Clock/DB, E2: UserProfile, ...).
// Feature-local providers stay in `features/<feature>/application/` instead
// of being added to this file.
