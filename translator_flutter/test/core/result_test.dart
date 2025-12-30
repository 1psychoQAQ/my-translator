import 'package:flutter_test/flutter_test.dart';
import 'package:translator_flutter/core/errors.dart';
import 'package:translator_flutter/core/result.dart';

void main() {
  group('Result', () {
    test('Success holds data', () {
      const result = Success<int>(42);
      expect(result.data, 42);
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
    });

    test('Failure holds error', () {
      const error = SyncError('Test error');
      final result = Failure<int>(error);
      expect(result.error, error);
      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
    });

    test('when handles success', () {
      const result = Success<int>(42);
      final value = result.when(
        success: (data) => 'success: $data',
        failure: (error) => 'failure: ${error.message}',
      );
      expect(value, 'success: 42');
    });

    test('when handles failure', () {
      final result = Failure<int>(const SyncError('Test error'));
      final value = result.when(
        success: (data) => 'success: $data',
        failure: (error) => 'failure: ${error.message}',
      );
      expect(value, 'failure: Test error');
    });

    test('map transforms success value', () {
      const result = Success<int>(42);
      final mapped = result.map((data) => data * 2);
      expect(mapped, isA<Success<int>>());
      expect((mapped as Success<int>).data, 84);
    });

    test('map preserves failure', () {
      final result = Failure<int>(const SyncError('Test error'));
      final mapped = result.map((data) => data * 2);
      expect(mapped, isA<Failure<int>>());
    });

    test('getOrNull returns data for success', () {
      const result = Success<int>(42);
      expect(result.getOrNull(), 42);
    });

    test('getOrNull returns null for failure', () {
      final result = Failure<int>(const SyncError('Test error'));
      expect(result.getOrNull(), isNull);
    });

    test('getOrElse returns data for success', () {
      const result = Success<int>(42);
      expect(result.getOrElse(0), 42);
    });

    test('getOrElse returns default for failure', () {
      final result = Failure<int>(const SyncError('Test error'));
      expect(result.getOrElse(0), 0);
    });
  });
}
