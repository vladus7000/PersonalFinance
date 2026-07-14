import 'dart:developer';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/time/clock.dart';
import 'backup/database_backup.dart';
import 'tables/exchange_rates_table.dart';
import 'tables/net_worth_snapshots_table.dart';

part 'app_database.g.dart';

/// The app's single local database. Offline-first — see doc.md §7.7.
///
/// Tables are added incrementally by later BUILD_PLAN tasks (E2.T1 user
/// profile, ...).
@DriftDatabase(tables: [ExchangeRates, NetWorthSnapshots])
class AppDatabase extends _$AppDatabase {
  AppDatabase({Clock clock = const SystemClock()}) : super(_openConnection(clock));

  /// A private, non-persistent database for tests.
  @visibleForTesting
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      log('Creating schema at v$schemaVersion', name: 'AppDatabase');
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      log('Migrating schema v$from -> v$to', name: 'AppDatabase');
      // Per-version steps land here as schemaVersion increases past 1.
    },
  );
}

LazyDatabase _openConnection(Clock clock) {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'pfa.sqlite'));

    await backupIfExists(
      databaseFile: file,
      backupsDirectory: Directory(p.join(dir.path, 'backups')),
      clock: clock,
    );

    return NativeDatabase.createInBackground(file);
  });
}
