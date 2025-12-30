import 'errors.dart';

/// Result type for explicit error handling
/// Use this instead of throwing exceptions for expected errors
sealed class Result<T> {
  const Result();
}

/// Success result containing data
class Success<T> extends Result<T> {
  const Success(this.data);

  final T data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T> &&
          runtimeType == other.runtimeType &&
          data == other.data;

  @override
  int get hashCode => data.hashCode;
}

/// Failure result containing error
class Failure<T> extends Result<T> {
  const Failure(this.error);

  final AppError error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T> &&
          runtimeType == other.runtimeType &&
          error == other.error;

  @override
  int get hashCode => error.hashCode;
}

/// Extension methods for Result
extension ResultExtension<T> on Result<T> {
  /// Pattern match on success/failure
  R when<R>({
    required R Function(T data) success,
    required R Function(AppError error) failure,
  }) {
    return switch (this) {
      Success(:final data) => success(data),
      Failure(:final error) => failure(error),
    };
  }

  /// Map the success value
  Result<R> map<R>(R Function(T data) mapper) {
    return switch (this) {
      Success(:final data) => Success(mapper(data)),
      Failure(:final error) => Failure(error),
    };
  }

  /// FlatMap the success value
  Result<R> flatMap<R>(Result<R> Function(T data) mapper) {
    return switch (this) {
      Success(:final data) => mapper(data),
      Failure(:final error) => Failure(error),
    };
  }

  /// Get the data or null
  T? getOrNull() {
    return switch (this) {
      Success(:final data) => data,
      Failure() => null,
    };
  }

  /// Get the data or a default value
  T getOrElse(T defaultValue) {
    return switch (this) {
      Success(:final data) => data,
      Failure() => defaultValue,
    };
  }

  /// Check if result is success
  bool get isSuccess => this is Success<T>;

  /// Check if result is failure
  bool get isFailure => this is Failure<T>;
}
