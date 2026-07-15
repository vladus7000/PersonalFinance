/// How [IncomeSource.nominalAmount] translates into an actual payout —
/// doc.md §4.2 `calculationMode` (§2.3 scenarios "фиксированная зарплата"
/// vs "зарплата, зависящая от рабочих дней"). Subsumes the doc.md
/// `workdayCalculationEnabled` field — that boolean would only ever
/// duplicate `this == byWorkingDays`, so it is not modeled separately.
enum IncomeCalculationMode {
  /// The full nominal amount is paid regardless of days worked.
  fixed,

  /// Prorated by worked-days / total-working-days in the period
  /// (`SalaryCalculator`, E3.T2, resolves the actual day counts).
  byWorkingDays,
}
