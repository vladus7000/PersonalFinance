/// How a payment date that falls on a weekend is adjusted — doc.md §4.3
/// `shiftFromWeekendRule` (§2.3 "перенос выплаты с выходного дня").
enum WeekendShiftRule {
  /// The payment date is used as-is, even if it falls on a weekend.
  none,

  /// Move to the closest earlier business day.
  moveToPreviousBusinessDay,

  /// Move to the closest later business day.
  moveToNextBusinessDay,
}
