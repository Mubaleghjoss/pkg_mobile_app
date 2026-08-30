/// Konfigurasi endpoint backend Laravel PKGenerus.
///
/// Backend TIDAK diubah: Flutter hanya konsumen API v1 (Sanctum bearer token).
/// Override saat run/build:
///   flutter run --dart-define=PKG_API_BASE=http://10.0.2.2:8010
class ApiConfig {
  /// Base URL backend.
  ///
  /// Default 127.0.0.1:8010 = `php artisan serve` di laptop.
  /// Untuk emulator Android pakai 10.0.2.2 (alias host dari dalam emulator).
  /// Untuk HP fisik pakai IP LAN laptop + `artisan serve --host=0.0.0.0`.
  static const String baseUrl = String.fromEnvironment(
    'PKG_API_BASE',
    defaultValue: 'http://127.0.0.1:8010',
  );

  static String get apiV1 => '$baseUrl/api/v1';

  /// Timeout koneksi/terima. Backend lokal cepat, produksi shared hosting lambat.
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Sanctum token dibuat dengan masa berlaku 7 hari oleh AuthController.
  /// Refresh proaktif bila sisa umur token di bawah ambang ini.
  static const Duration refreshThreshold = Duration(days: 1);
}
