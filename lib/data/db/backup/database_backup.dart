import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/time/clock.dart';

/// Copies [databaseFile] into [backupsDirectory] before it is opened, if it
/// already exists. Runs unconditionally — not only when a schema migration
/// is actually about to happen — because data loss is catastrophic and
/// there is no server copy to fall back to (doc.md §1.3, BUILD_PLAN.md
/// E1.T7). A brand-new install has no file yet, so there is nothing to
/// back up and this is a no-op.
///
/// Kept independent of `path_provider` so it can be exercised with plain
/// `dart:io` temp directories in a fast unit test, instead of requiring an
/// on-device integration test.
Future<File?> backupIfExists({
  required File databaseFile,
  required Directory backupsDirectory,
  required Clock clock,
}) async {
  if (!await databaseFile.exists()) return null;

  await backupsDirectory.create(recursive: true);

  final timestamp = clock.now().toUtc().toIso8601String().replaceAll(RegExp('[:.]'), '-');
  final backupPath = p.join(backupsDirectory.path, '${p.basenameWithoutExtension(databaseFile.path)}_$timestamp.sqlite');

  return databaseFile.copy(backupPath);
}
