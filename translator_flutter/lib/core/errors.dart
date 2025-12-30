/// App error types for explicit error handling
sealed class AppError {
  const AppError(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'AppError: $message${cause != null ? ' ($cause)' : ''}';
}

/// Firebase sync errors
class SyncError extends AppError {
  const SyncError(super.message, [super.cause]);
}

/// Network connectivity errors
class NetworkError extends AppError {
  const NetworkError(super.message, [super.cause]);
}

/// Local storage errors
class StorageError extends AppError {
  const StorageError(super.message, [super.cause]);
}

/// Validation errors
class ValidationError extends AppError {
  const ValidationError(super.message, [super.cause]);
}
