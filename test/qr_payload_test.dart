import 'package:flutter_test/flutter_test.dart';
import 'package:pkgenerus_app/features/presensi/data/qr_payload.dart';

/// Payload di test ini disalin dari format asli backend
/// (`QrTokenService::buildPayload()` → PREFIX|VERSION|STUDENT_ID|TOKEN|HASH)
/// dan token 64-hex sungguhan dari `GET /api/v1/siswa/1/qr-code`.
void main() {
  const realToken =
      '45faab9b5dcd5febc3fa51e5666a0419cf0d5c55e556f309151c6b612bbb5560';

  group('QrPayload.parse - format PKG', () {
    test('mengurai payload lengkap dari backend', () {
      final p = QrPayload.parse('PKG|1|1|$realToken|f7a8b9c0d1e2f3g4');

      expect(p, isNotNull);
      expect(p!.studentId, 1);
      expect(p.token, realToken);
      expect(p.raw, 'PKG|1|1|$realToken|f7a8b9c0d1e2f3g4');
    });

    test('menerima payload tanpa segmen hash', () {
      final p = QrPayload.parse('PKG|1|42|$realToken');

      expect(p?.studentId, 42);
      expect(p?.token, realToken);
    });

    test('menolak student_id bukan angka', () {
      expect(QrPayload.parse('PKG|1|abc|$realToken|hash'), isNull);
    });

    test('menolak token lebih pendek dari batas validasi backend (min 10)', () {
      expect(QrPayload.parse('PKG|1|1|short|hash'), isNull);
    });

    test('menolak segmen kurang dari 4', () {
      expect(QrPayload.parse('PKG|1|1'), isNull);
    });
  });

  group('QrPayload.parse - format JSON', () {
    test('mengurai student_id numerik', () {
      final p = QrPayload.parse('{"student_id":7,"token":"$realToken"}');

      expect(p?.studentId, 7);
      expect(p?.token, realToken);
    });

    test('mengurai student_id berupa string', () {
      final p = QrPayload.parse('{"student_id":"7","token":"$realToken"}');

      expect(p?.studentId, 7);
    });

    test('menolak JSON rusak', () {
      expect(QrPayload.parse('{"student_id":7,'), isNull);
    });

    test('menolak JSON tanpa token', () {
      expect(QrPayload.parse('{"student_id":7}'), isNull);
    });
  });

  group('QrPayload.parse - input lain', () {
    test('menolak string kosong', () {
      expect(QrPayload.parse('   '), isNull);
    });

    test('menolak QR acak bukan milik PKGenerus', () {
      expect(QrPayload.parse('https://example.com/promo'), isNull);
    });
  });

  group('toRequestBody', () {
    test('mengirim token mentah, student_id datar, dan qr_data sekaligus', () {
      final raw = 'PKG|1|1|$realToken|f7a8b9c0d1e2f3g4';
      final body = QrPayload.parse(raw)!.toRequestBody();

      // Backend membaca ketiga bentuk ini di tempat berbeda:
      // ScanQrRequest (token), PresensiController (qr_data), ScanQrDTO (flat).
      expect(body['token'], raw);
      expect(body['student_id'], 1);
      expect(body['qr_data'], {'student_id': 1, 'token': realToken});
      expect(body.containsKey('location'), isFalse);
    });

    test('menyertakan location hanya bila tidak kosong', () {
      final p = QrPayload.parse('PKG|1|1|$realToken|hash')!;

      expect(p.toRequestBody(location: 'Aula')['location'], 'Aula');
      expect(p.toRequestBody(location: '').containsKey('location'), isFalse);
    });
  });
}
