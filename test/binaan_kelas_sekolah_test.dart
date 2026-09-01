import 'package:flutter_test/flutter_test.dart';
import 'package:pkgenerus_app/features/kelas/domain/binaan.dart';

/// Sumber data AKTIF: `GET /binaan-pamong` + `GET /kelas-sekolah`.
///
/// Temuan nyata yang dikunci di sini: di DB kolom `school_grade` banyak yang
/// kosong, sehingga kelas sekolah hanya terisi lewat level EFEKTIF (override →
/// school_grade → taksiran tanggal lahir). Kalau UI hanya membaca
/// `jumlah_siswa`, seluruh kelas tampil 0 dan layar jadi tidak berguna.
void main() {
  group('BinaanPamong', () {
    test('parsing lengkap dari respons server', () {
      final p = BinaanPamong.fromJson({
        'pamong_id': 6,
        'nama': 'Tester Pamong',
        'username': 'tester_pamong',
        'is_active': true,
        'jumlah_binaan': 4,
      });

      expect(p.pamongId, 6);
      expect(p.nama, 'Tester Pamong');
      expect(p.username, 'tester_pamong');
      expect(p.isActive, isTrue);
      expect(p.jumlahBinaan, 4);
    });

    test('field hilang tidak melempar, jatuh ke nilai aman', () {
      final p = BinaanPamong.fromJson(const {});

      expect(p.pamongId, 0);
      expect(p.nama, '');
      expect(p.isActive, isFalse);
      expect(p.jumlahBinaan, 0);
    });

    test('jumlah_binaan berupa string tetap terbaca sebagai angka', () {
      // MySQL COUNT lewat pluck bisa datang sebagai string.
      expect(BinaanPamong.fromJson({'jumlah_binaan': '7'}).jumlahBinaan, 7);
    });

    test('scope sendiri menandai pamong hanya melihat binaannya', () {
      const sendiri = BinaanPamongRingkasan(
        items: [],
        totalPamong: 1,
        totalBinaan: 4,
        scope: 'sendiri',
      );
      const semua = BinaanPamongRingkasan(
        items: [],
        totalPamong: 9,
        totalBinaan: 40,
        scope: 'semua',
      );

      expect(sendiri.hanyaSendiri, isTrue);
      expect(semua.hanyaSendiri, isFalse);
    });
  });

  group('KelasSekolah', () {
    test('memakai jumlah kolom bila school_grade terisi', () {
      final k = KelasSekolah.fromJson({
        'kode': 'sma_11',
        'label': 'SMA/SMK Kelas 2 (Kelas 11)',
        'label_singkat': 'SMA 11',
        'jumlah_siswa': 3,
        'jumlah_efektif': 3,
      });

      expect(k.jumlahTampil, 3);
      expect(k.dariTaksiran, isFalse,
          reason: 'kolom terisi, tidak perlu ditandai perkiraan');
    });

    test('jatuh ke level efektif saat school_grade kosong', () {
      // Kondisi nyata DB dev: jumlah_siswa 0, jumlah_efektif 3.
      final k = KelasSekolah.fromJson({
        'kode': 'sma_11',
        'label': 'SMA/SMK Kelas 2 (Kelas 11)',
        'jumlah_siswa': 0,
        'jumlah_efektif': 3,
      });

      expect(k.jumlahTampil, 3);
      expect(k.dariTaksiran, isTrue,
          reason: 'angka hanya taksiran, UI wajib menandainya');
    });

    test('kelas benar-benar kosong tidak ditandai perkiraan', () {
      final k = KelasSekolah.fromJson({
        'kode': 'smp_7',
        'jumlah_siswa': 0,
        'jumlah_efektif': 0,
      });

      expect(k.jumlahTampil, 0);
      expect(k.dariTaksiran, isFalse);
    });

    test('label_singkat jatuh ke label bila server tidak mengirimnya', () {
      final k = KelasSekolah.fromJson({
        'kode': 'smp_8',
        'label': 'SMP Kelas 2 (Kelas 8)',
      });

      expect(k.labelSingkat, 'SMP Kelas 2 (Kelas 8)');
    });
  });
}
