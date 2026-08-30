import 'dart:convert';

/// Payload QR presensi PKGenerus.
///
/// Backend membuat isi QR di `QrTokenService::buildPayload()` dengan format
/// pipe-delimited:
///
///     PREFIX|VERSION|STUDENT_ID|TOKEN|HASH
///     contoh: PKG|1|123|45faab9b…|f7a8b9c0d1e2f3g4
///
/// `ScanQrRequest` sendiri hanya memvalidasi `token` sebagai string bebas
/// (min 10 karakter), dan komentarnya menyebut dua kemungkinan isi: format PKG
/// di atas atau JSON `{"student_id": …, "token": …}`. Parser ini menangani
/// keduanya dan selalu menghasilkan `studentId` + `token` eksplisit, sehingga
/// aplikasi tidak bergantung pada backend mem-parse string mentah.
class QrPayload {
  const QrPayload({
    required this.studentId,
    required this.token,
    this.raw,
  });

  /// Mengurai isi QR. Mengembalikan null bila bentuknya tidak dikenali.
  static QrPayload? parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // Bentuk 1: PKG|VERSION|STUDENT_ID|TOKEN|HASH
    if (trimmed.contains('|')) {
      final parts = trimmed.split('|');
      if (parts.length >= 4) {
        final id = int.tryParse(parts[2].trim());
        final token = parts[3].trim();
        if (id != null && id > 0 && token.length >= 10) {
          return QrPayload(studentId: id, token: token, raw: trimmed);
        }
      }
      return null;
    }

    // Bentuk 2: JSON {"student_id": …, "token": …}
    if (trimmed.startsWith('{')) {
      final map = _decodeMap(trimmed);
      final id = _asInt(map?['student_id']);
      final token = map?['token']?.toString().trim();
      if (id != null && id > 0 && token != null && token.length >= 10) {
        return QrPayload(studentId: id, token: token, raw: trimmed);
      }
    }

    return null;
  }

  static Map<String, dynamic>? _decodeMap(String source) {
    try {
      final decoded = jsonDecode(source);
      return decoded is Map ? decoded.cast<String, dynamic>() : null;
    } on FormatException {
      return null;
    }
  }

  static int? _asInt(Object? value) => switch (value) {
        final int v => v,
        final num v => v.toInt(),
        final String v => int.tryParse(v),
        _ => null,
      };

  final int studentId;
  final String token;

  /// String asli dari QR. Dikirim apa adanya sebagai `token` agar backend yang
  /// mem-parse sendiri tetap menerima bentuk yang ia hasilkan.
  final String? raw;

  /// Body request untuk `POST /api/v1/presensi/scan-qr`.
  ///
  /// Dikirim dalam tiga bentuk sekaligus karena backend tidak konsisten:
  /// `ScanQrRequest` hanya memvalidasi `token`, `PresensiController::scanQr()`
  /// membaca `qr_data['student_id']`, dan `ScanQrDTO::fromRequest()` membaca
  /// `student_id` datar.
  Map<String, dynamic> toRequestBody({String? location}) => {
        'token': raw ?? token,
        'student_id': studentId,
        'qr_data': {'student_id': studentId, 'token': token},
        if (location != null && location.isNotEmpty) 'location': location,
      };
}
