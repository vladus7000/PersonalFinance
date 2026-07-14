import 'package:freezed_annotation/freezed_annotation.dart';

part 'failure.freezed.dart';

/// Domain-level failure returned by [Result]. Application code branches on
/// this instead of catching exceptions — see BUILD_PLAN.md §0.1 п.8.
@freezed
sealed class Failure with _$Failure {
  /// Input failed a domain invariant (e.g. negative quantity, empty name).
  const factory Failure.validation(String message) = ValidationFailure;

  /// A referenced entity does not exist (e.g. account id not found).
  const factory Failure.notFound(String message) = NotFoundFailure;

  /// The operation conflicts with existing state (e.g. selling more than held).
  const factory Failure.conflict(String message) = ConflictFailure;

  /// The data layer (database, filesystem) could not complete the operation.
  const factory Failure.storage(String message) = StorageFailure;

  /// Attempted an operation (e.g. [Money] addition) across two currencies.
  const factory Failure.currencyMismatch({
    required String expected,
    required String actual,
  }) = CurrencyMismatchFailure;
}
