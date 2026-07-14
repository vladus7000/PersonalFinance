import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'net_worth_snapshot.freezed.dart';

/// A point-in-time total capital figure plus its breakdown by category
/// (e.g. investments/cushion/cash/other — see doc.md §6.7.1), in the
/// user's primary currency at the time. See BUILD_PLAN.md E1.T6.
@freezed
sealed class NetWorthSnapshot with _$NetWorthSnapshot {
  const factory NetWorthSnapshot({
    required DateTime date,
    required Decimal totalPrimary,
    required Map<String, Decimal> breakdown,
    required String source,
  }) = _NetWorthSnapshot;
}
