import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/money/currency_code.dart';

part 'exchange_rate.freezed.dart';

/// A stored currency conversion rate, valid as of [effectiveDate].
///
/// [source] is a free-form string (`'manual'` in MVP — see BUILD_PLAN.md
/// §0.1 compat principle #2: this stays a pluggable source identifier, not
/// an enum, so NBU/bank-rate sources can be added later without a schema
/// change).
@freezed
sealed class ExchangeRate with _$ExchangeRate {
  const factory ExchangeRate({
    required CurrencyCode from,
    required CurrencyCode to,
    required Decimal rate,
    required DateTime effectiveDate,
    required String source,
    required bool isFinal,
  }) = _ExchangeRate;
}
