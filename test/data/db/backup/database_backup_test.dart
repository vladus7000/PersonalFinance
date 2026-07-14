import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_assistant/core/time/clock.dart';
import 'package:personal_finance_assistant/data/db/app_database.dart';
import 'package:personal_finance_assistant/data/db/backup/database_backup.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pfa_backup_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('does nothing when the database file does not exist yet (first launch)', () async {
    final dbFile = File('${tempDir.path}/pfa.sqlite'); // never created
    final backupsDir = Directory('${tempDir.path}/backups');

    final result = await backupIfExists(
      databaseFile: dbFile,
      backupsDirectory: backupsDir,
      clock: FixedClock(DateTime.utc(2026, 7, 15)),
    );

    expect(result, isNull);
    expect(await backupsDir.exists(), isFalse);
  });

  test('backs up an existing file even when no real migration will occur (v1 -> v1)', () async {
    final dbPath = '${tempDir.path}/pfa.sqlite';
    final backupsDir = Directory('${tempDir.path}/backups');

    // Simulate a prior install: open a real v1 database, write a row, close.
    var db = AppDatabase.forTesting(NativeDatabase(File(dbPath)));
    await db.into(db.exchangeRates).insert(
      ExchangeRatesCompanion.insert(
        fromCurrency: 'USD',
        toCurrency: 'UAH',
        rate: '41.70',
        effectiveDate: DateTime.utc(2026, 7, 1),
      ),
    );
    await db.close();

    // Reopening at the SAME schema version (1 -> 1, a no-op for Drift's own
    // migration hooks) must still produce a backup — see BUILD_PLAN.md
    // E1.T7: we back up unconditionally, not only on a real version bump.
    final backup = await backupIfExists(
      databaseFile: File(dbPath),
      backupsDirectory: backupsDir,
      clock: FixedClock(DateTime.utc(2026, 7, 15, 12, 0, 0)),
    );

    expect(backup, isNotNull);
    expect(await backup!.exists(), isTrue);
    expect(backup.path, contains('backups'));
    expect(backup.path, contains('2026-07-15'));

    // The "migration" must not have corrupted the original: the row is
    // still there when we reopen the original file.
    db = AppDatabase.forTesting(NativeDatabase(File(dbPath)));
    final rows = await db.select(db.exchangeRates).get();
    expect(rows, hasLength(1));
    expect(rows.single.rate, '41.70');
    await db.close();

    // The backup itself is a faithful, independently-openable copy.
    final backupDb = AppDatabase.forTesting(NativeDatabase(backup));
    final backupRows = await backupDb.select(backupDb.exchangeRates).get();
    expect(backupRows, hasLength(1));
    expect(backupRows.single.rate, '41.70');
    await backupDb.close();
  });

  test('two backups on the same day get distinct filenames (no silent overwrite)', () async {
    final dbPath = '${tempDir.path}/pfa.sqlite';
    await File(dbPath).writeAsString('not actually sqlite, just needs to exist');
    final backupsDir = Directory('${tempDir.path}/backups');

    final first = await backupIfExists(
      databaseFile: File(dbPath),
      backupsDirectory: backupsDir,
      clock: FixedClock(DateTime.utc(2026, 7, 15, 9, 0, 0)),
    );
    final second = await backupIfExists(
      databaseFile: File(dbPath),
      backupsDirectory: backupsDir,
      clock: FixedClock(DateTime.utc(2026, 7, 15, 18, 30, 0)),
    );

    expect(first!.path, isNot(second!.path));
    expect(await backupsDir.list().length, 2);
  });
}
