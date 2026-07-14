import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_assistant/data/db/app_database.dart';
import 'package:personal_finance_assistant/data/db/daos/net_worth_snapshots_dao.dart';
import 'package:personal_finance_assistant/domain/entities/net_worth_snapshot.dart';

void main() {
  late AppDatabase db;
  late NetWorthSnapshotsDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = NetWorthSnapshotsDao(db);
  });

  tearDown(() => db.close());

  test('record then range round-trips the breakdown map exactly', () async {
    final snapshot = NetWorthSnapshot(
      date: DateTime.utc(2026, 7, 15),
      totalPrimary: Decimal.parse('56340.00'),
      breakdown: {
        'investments': Decimal.parse('34250.00'),
        'cushion': Decimal.parse('11860.00'),
        'cash': Decimal.parse('6230.00'),
        'other': Decimal.parse('4000.00'),
      },
      source: 'manual',
    );

    await dao.record(snapshot);

    final results = await dao.range(
      from: DateTime.utc(2026, 7, 1),
      to: DateTime.utc(2026, 7, 31),
    );

    expect(results, hasLength(1));
    expect(results.single.totalPrimary, Decimal.parse('56340.00'));
    expect(results.single.breakdown, snapshot.breakdown);
    expect(results.single.source, 'manual');
  });

  test('range excludes snapshots outside the requested window', () async {
    await dao.record(
      NetWorthSnapshot(
        date: DateTime.utc(2026, 6, 30),
        totalPrimary: Decimal.fromInt(100),
        breakdown: const {},
        source: 'manual',
      ),
    );
    await dao.record(
      NetWorthSnapshot(
        date: DateTime.utc(2026, 7, 15),
        totalPrimary: Decimal.fromInt(200),
        breakdown: const {},
        source: 'manual',
      ),
    );
    await dao.record(
      NetWorthSnapshot(
        date: DateTime.utc(2026, 8, 1),
        totalPrimary: Decimal.fromInt(300),
        breakdown: const {},
        source: 'manual',
      ),
    );

    final results = await dao.range(
      from: DateTime.utc(2026, 7, 1),
      to: DateTime.utc(2026, 7, 31),
    );

    expect(results, hasLength(1));
    expect(results.single.totalPrimary, Decimal.fromInt(200));
  });

  test('range returns results ordered oldest first', () async {
    await dao.record(
      NetWorthSnapshot(
        date: DateTime.utc(2026, 7, 20),
        totalPrimary: Decimal.fromInt(2),
        breakdown: const {},
        source: 'manual',
      ),
    );
    await dao.record(
      NetWorthSnapshot(
        date: DateTime.utc(2026, 7, 10),
        totalPrimary: Decimal.fromInt(1),
        breakdown: const {},
        source: 'manual',
      ),
    );

    final results = await dao.range(
      from: DateTime.utc(2026, 7, 1),
      to: DateTime.utc(2026, 7, 31),
    );

    expect(results.map((s) => s.totalPrimary).toList(), [Decimal.fromInt(1), Decimal.fromInt(2)]);
  });
}
