/// Hasil pemanggilan API tanpa melempar exception untuk status 4xx/5xx.
///
/// Semua repository mengembalikan tipe ini supaya lapisan UI tidak perlu
/// menangkap `DioException`.
class ApiResult<T> {
  const ApiResult._({
    required this.ok,
    required this.statusCode,
    this.data,
    this.error,
    this.fieldErrors,
  });

  factory ApiResult.success(T data, {int statusCode = 200}) =>
      ApiResult._(ok: true, statusCode: statusCode, data: data);

  factory ApiResult.failure(
    String error, {
    int statusCode = 0,
    Map<String, List<String>>? fieldErrors,
  }) =>
      ApiResult._(
        ok: false,
        statusCode: statusCode,
        error: error,
        fieldErrors: fieldErrors,
      );

  final bool ok;
  final int statusCode;
  final T? data;
  final String? error;

  /// Isi `errors` dari respons validasi Laravel (HTTP 422).
  final Map<String, List<String>>? fieldErrors;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isValidationError => statusCode == 422;
  bool get isRateLimited => statusCode == 429;

  /// True bila kegagalan berasal dari jaringan/timeout, bukan dari server.
  bool get isNetworkError => !ok && statusCode == 0;

  R when<R>({
    required R Function(T data) success,
    required R Function(ApiResult<T> failure) failure,
  }) {
    if (ok && data != null) return success(data as T);
    return failure(this);
  }
}
