import 'package:drift/drift.dart';

/// A point-in-time capital snapshot, written whenever something that
/// affects net worth happens (income confirmed, balance updated, cycle
/// closed — see BUILD_PLAN.md E4.T3, E5.T2, E4.T4). Powers the Dashboard
/// capital chart (doc.md §3.4, §6.7.1) — without this table, net worth
/// history cannot be reconstructed from current balances alone.
///
/// `total_primary` and `breakdown` are TEXT (canonical Decimal strings; no
/// `REAL`, see §0.1 п.1). There is no currency column — the amount is
/// always in whatever the user's primary currency was at snapshot time.
@DataClassName('NetWorthSnapshotRow')
class NetWorthSnapshots extends Table {
  IntColumn get id => integer().autoIncrement()();

  DateTimeColumn get date => dateTime()();

  TextColumn get totalPrimary => text().named('total_primary')();

  /// JSON-encoded `{category: decimalAmountString}`, e.g.
  /// `{"investments":"34250.00","cushion":"11860.00"}`.
  TextColumn get breakdown => text()();

  TextColumn get source => text()();
}
