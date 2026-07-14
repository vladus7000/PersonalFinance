import '../entities/user_profile.dart';

/// Reads/writes the single local [UserProfile] row. `null` from
/// [getProfile] means "no profile yet" — the app should route to
/// onboarding (E2.T4).
abstract class UserProfileRepository {
  Future<UserProfile?> getProfile();

  /// Creates the profile on first call, updates it on every later call —
  /// there is exactly one profile row (see [UserProfile] doc).
  Future<void> saveProfile(UserProfile profile);
}
