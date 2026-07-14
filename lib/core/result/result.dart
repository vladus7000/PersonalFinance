import 'failure.dart';

/// A computation that either succeeds with a [T] or fails with a [Failure].
///
/// Application-layer code returns this instead of throwing — see
/// BUILD_PLAN.md §0.1 п.8. Exceptions remain reserved for true anomalies
/// (e.g. database corruption).
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;

  const factory Result.err(Failure failure) = Err<T>;

  bool get isOk => this is Ok<T>;

  bool get isErr => this is Err<T>;

  T? get valueOrNull => switch (this) {
    Ok<T>(value: final v) => v,
    Err<T>() => null,
  };

  Failure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(failure: final f) => f,
  };

  /// Pattern-matches on the result, forcing both branches to be handled.
  R when<R>({
    required R Function(T value) ok,
    required R Function(Failure failure) err,
  }) => switch (this) {
    Ok<T>(value: final v) => ok(v),
    Err<T>(failure: final f) => err(f),
  };

  /// Transforms the success value, passing failures through unchanged.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T>(value: final v) => Result.ok(transform(v)),
    Err<T>(failure: final f) => Result.err(f),
  };

  /// Chains another [Result]-returning computation onto a success value.
  Result<R> flatMap<R>(Result<R> Function(T value) transform) => switch (this) {
    Ok<T>(value: final v) => transform(v),
    Err<T>(failure: final f) => Result.err(f),
  };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  bool operator ==(Object other) => other is Ok<T> && other.value == value;

  @override
  int get hashCode => Object.hash(Ok<T>, value);

  @override
  String toString() => 'Ok($value)';
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) => other is Err<T> && other.failure == failure;

  @override
  int get hashCode => Object.hash(Err<T>, failure);

  @override
  String toString() => 'Err($failure)';
}
