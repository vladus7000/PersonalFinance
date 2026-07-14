import 'currency_code.dart';

/// A starting reference list for currency pickers — not exhaustive and not
/// an enum (compat principle #3, BUILD_PLAN.md §0.1): any [CurrencyCode]
/// can still be constructed freely from a free-form string; this only
/// seeds UI dropdowns with sensible defaults.
final List<CurrencyCode> commonCurrencyCodes = [
  CurrencyCode('USD'),
  CurrencyCode('EUR'),
  CurrencyCode('UAH'),
  CurrencyCode('GBP'),
  CurrencyCode('PLN'),
  CurrencyCode('CZK'),
  CurrencyCode('CHF'),
];
