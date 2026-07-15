/// Broad category of an [IncomeSource] — doc.md §4.2 `type`. A closed set
/// (unlike `institution`, which stays a free string — compat principle #3):
/// income type drives `SalaryCalculator` behavior (E3.T2), so it must be a
/// fixed vocabulary the engine can switch on.
enum IncomeType { salary, freelance, business, rental, dividend, other }
