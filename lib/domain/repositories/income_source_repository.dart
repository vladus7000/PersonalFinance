import '../entities/income_source.dart';

/// Reads/writes [IncomeSource] aggregates (source + its schedule rules
/// together — see [IncomeSource] doc).
abstract class IncomeSourceRepository {
  Future<List<IncomeSource>> getAll();

  Future<IncomeSource?> getById(int id);

  /// Inserts [source] (its `id` is ignored) and returns the generated id.
  Future<int> create(IncomeSource source);

  /// Replaces the stored source and its schedule rules with [source] in
  /// full. Requires `source.id != null`.
  Future<void> update(IncomeSource source);

  Future<void> delete(int id);
}
