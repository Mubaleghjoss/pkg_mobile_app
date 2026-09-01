import 'package:flutter_test/flutter_test.dart';
import 'package:pkgenerus_app/features/tugas/data/tugas_pkg.dart';

/// Tes untuk kemampuan yang baru diselaraskan dengan server:
/// komentar orang tua pada checklist, dan konversi timestamp ke zona lokal.
void main() {
  group('TugasChecklist: komentar ortu', () {
    test('memuat daftar komentar_ortu dari payload backend', () {
      final c = TugasChecklist.fromJson(<String, dynamic>{
        'id': 72,
        'karakter_id': 6,
        'karakter_nama': 'Sholat 5 Waktu Tepat Waktu',
        'poin': 20,
        'checked_at': '2026-08-31T10:22:00+07:00',
        'is_verified': false,
        'komentar_ortu': [
          {
            'id': 8,
            'comment': 'Uji komentar ortu dari API',
            'created_at': '2026-08-31T17:35:10+07:00',
          },
          {'id': 9, 'comment': 'Komentar kedua'},
        ],
      });

      expect(c.id, 72);
      expect(c.komentarOrtu.length, 2);
      expect(c.komentarOrtu.first.comment, 'Uji komentar ortu dari API');
      expect(c.komentarOrtu.first.id, 8);
      // Komentar tanpa created_at tidak boleh membuat parsing gagal.
      expect(c.komentarOrtu.last.createdAt, isNull);
    });

    test('payload tanpa komentar_ortu menghasilkan daftar kosong', () {
      final c = TugasChecklist.fromJson(<String, dynamic>{
        'id': 70,
        'karakter_nama': 'Dzikir Pagi 33x',
      });

      expect(c.komentarOrtu, isEmpty);
    });

    test('checked_at/verified_at dikonversi ke zona lokal perangkat', () {
      final c = TugasChecklist.fromJson(<String, dynamic>{
        'id': 71,
        'karakter_nama': 'Membaca Al-Quran 1 Halaman',
        // Sengaja UTC: sebelum perbaikan, jam tampil geser dari waktu server.
        'checked_at': '2026-08-31T03:21:00Z',
        'is_verified': true,
        'verified_at': '2026-08-31T04:00:00Z',
      });

      expect(c.checkedAt!.isUtc, isFalse);
      expect(c.verifiedAt!.isUtc, isFalse);
      // Nilai absolutnya tetap sama, hanya representasinya lokal.
      expect(
        c.checkedAt!.toUtc().toIso8601String(),
        DateTime.utc(2026, 8, 31, 3, 21).toIso8601String(),
      );
    });
  });

  group('OrtuKomentar', () {
    test('created_at menjadi waktu lokal', () {
      final k = OrtuKomentar.fromJson(<String, dynamic>{
        'id': 1,
        'comment': 'Semangat ya',
        'created_at': '2026-08-31T10:35:10Z',
      });

      expect(k.createdAt!.isUtc, isFalse);
      expect(k.comment, 'Semangat ya');
    });
  });
}
