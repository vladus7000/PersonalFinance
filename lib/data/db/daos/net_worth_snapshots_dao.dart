import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../../../domain/entities/net_worth_snapshot.dart';
import '../app_database.dart';

class NetWorthSnapshotsDao {
  const NetWorthSnapshotsDao(this._db);

  final AppDatabase _db;

  Future<void> record(NetWorthSnapshot snapshot) {
    return _db
        .into(_db.netWorthSnapshots)
        .insert(
          NetWorthSnapshotsCompanion.insert(
            date: snapshot.date,
            totalPrimary: snapshot.totalPrimary.toString(),
            breakdown: _encodeBreakdown(snapshot.breakdown),
            source: snapshot.source,
          ),
        );
  }

  /// Snapshots with `date` in `[from, to]` (inclusive), oldest first.
  Future<List<NetWorthSnapshot>> range({required DateTime from, required DateTime to}) async {
    final query = _db.select(_db.netWorthSnapshots)
      ..where((t) => t.date.isBetweenValues(from, to))
      ..orderBy([(t) => OrderingTerm.asc(t.date)]);

    final rows = await query.get();
    return rows.map(_toDomain).toList();
  }

  NetWorthSnapshot _toDomain(NetWorthSnapshotRow row) => NetWorthSnapshot(
    date: row.date,
    totalPrimary: Decimal.parse(row.totalPrimary),
    breakdown: _decodeBreakdown(row.breakdown),
    source: row.source,
  );

  String _encodeBreakdown(Map<String, Decimal> breakdown) =>
      jsonEncode(breakdown.map((category, amount) => MapEntry(category, amount.toString())));

  Map<String, Decimal> _decodeBreakdown(String json) {
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return decoded.map((category, amount) => MapEntry(category, Decimal.parse(amount as String)));
  }
}
