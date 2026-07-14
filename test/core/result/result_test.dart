import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_assistant/core/result/failure.dart';
import 'package:personal_finance_assistant/core/result/result.dart';

void main() {
  group('Result', () {
    test('ok exposes its value and no failure', () {
      const result = Result<int>.ok(42);

      expect(result.isOk, isTrue);
      expect(result.isErr, isFalse);
      expect(result.valueOrNull, 42);
      expect(result.failureOrNull, isNull);
    });

    test('err exposes its failure and no value', () {
      const result = Result<int>.err(Failure.validation('bad input'));

      expect(result.isOk, isFalse);
      expect(result.isErr, isTrue);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, const Failure.validation('bad input'));
    });

    test('when dispatches to the matching branch', () {
      const ok = Result<int>.ok(1);
      const err = Result<int>.err(Failure.storage('disk full'));

      expect(ok.when(ok: (v) => 'ok:$v', err: (f) => 'err'), 'ok:1');
      expect(err.when(ok: (v) => 'ok', err: (f) => 'err:${f.toString()}'), startsWith('err:'));
    });

    test('map transforms a success value and passes through a failure', () {
      const ok = Result<int>.ok(2);
      const err = Result<int>.err(Failure.conflict('busy'));

      expect(ok.map((v) => v * 10), const Result<int>.ok(20));
      expect(err.map((v) => v * 10), const Result<int>.err(Failure.conflict('busy')));
    });

    test('flatMap chains success results and short-circuits on failure', () {
      Result<int> halve(int v) =>
          v.isEven ? Result.ok(v ~/ 2) : const Result.err(Failure.validation('odd'));

      expect(const Result<int>.ok(10).flatMap(halve), const Result<int>.ok(5));
      expect(const Result<int>.ok(7).flatMap(halve), const Result<int>.err(Failure.validation('odd')));
      expect(
        const Result<int>.err(Failure.notFound('x')).flatMap(halve),
        const Result<int>.err(Failure.notFound('x')),
      );
    });
  });

  group('Failure', () {
    test('variants are equal by value', () {
      expect(
        const Failure.currencyMismatch(expected: 'USD', actual: 'EUR'),
        const Failure.currencyMismatch(expected: 'USD', actual: 'EUR'),
      );
      expect(
        const Failure.currencyMismatch(expected: 'USD', actual: 'EUR'),
        isNot(const Failure.currencyMismatch(expected: 'USD', actual: 'UAH')),
      );
    });

    test('supports exhaustive pattern matching', () {
      String describe(Failure failure) => switch (failure) {
        ValidationFailure(:final message) => 'validation: $message',
        NotFoundFailure(:final message) => 'notFound: $message',
        ConflictFailure(:final message) => 'conflict: $message',
        StorageFailure(:final message) => 'storage: $message',
        CurrencyMismatchFailure(:final expected, :final actual) =>
          'currencyMismatch: $expected != $actual',
      };

      expect(describe(const Failure.validation('bad')), 'validation: bad');
      expect(
        describe(const Failure.currencyMismatch(expected: 'USD', actual: 'EUR')),
        'currencyMismatch: USD != EUR',
      );
    });
  });
}
