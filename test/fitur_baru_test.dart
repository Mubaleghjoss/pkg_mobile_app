import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkgenerus_app/core/notifications/local_notifications.dart';
import 'package:pkgenerus_app/core/notifications/verifikasi_watcher.dart';
import 'package:pkgenerus_app/features/ortu/data/ortu_models.dart';
import 'package:pkgenerus_app/features/presensi/data/presensi_repository.dart';
import 'package:pkgenerus_app/shared/widgets/floating_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Notifikasi palsu: mencatat apa yang ditampilkan, tanpa menyentuh plugin.
class _NotifikasiPalsu implements NotifikasiLokal {
  final List<({int id, String judul, String isi})> dipanggil = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> tampilkan({
    required int id,
    required String judul,
    required String isi,
  }) async {
    dipanggil.add((id: id, judul: judul, isi: isi));
  }
}

void main() {
  group('kehadiran: terlambat tetap hadir tapi tetap tercatat', () {
    // Angka ini menirukan temuan nyata di monitoring ortu:
    // rekap_sumber = 7 hadir + 1 terlambat, ditampilkan sebagai 100%.
    const totals = PresensiTotals(
      hadir: 7,
      terlambat: 1,
      izin: 0,
      sakit: 0,
      alpha: 0,
      total: 8,
    );

    test('persentase kehadiran tetap 100% (terlambat dihitung masuk)', () {
      expect(totals.jumlahMasuk, 8);
      expect(totals.persentaseKehadiran, 100.0);
    });

    test('keterlambatan tetap terbaca sebagai data terpisah', () {
      expect(totals.adaKeterlambatan, isTrue);
      expect(totals.jumlahTerlambat, 1);
      expect(totals.persentaseTepatWaktu, closeTo(87.5, 0.001));
    });

    test('tanpa keterlambatan, tepat waktu = kehadiran', () {
      const bersih = PresensiTotals(
        hadir: 8,
        terlambat: 0,
        izin: 0,
        sakit: 0,
        alpha: 0,
        total: 8,
      );
      expect(bersih.adaKeterlambatan, isFalse);
      expect(bersih.persentaseTepatWaktu, bersih.persentaseKehadiran);
    });

    test('total 0 tidak membagi nol', () {
      const kosong = PresensiTotals(
        hadir: 0,
        terlambat: 0,
        izin: 0,
        sakit: 0,
        alpha: 0,
        total: 0,
      );
      expect(kosong.persentaseKehadiran, 0);
      expect(kosong.persentaseTepatWaktu, 0);
    });

    test('PresensiStatistics: persentase backend dipakai apa adanya', () {
      // Payload meniru GET /presensi/statistics: backend sudah mengirim 100.
      final stat = PresensiStatistics.fromJson(const {
        'total': 8,
        'hadir': 7,
        'terlambat': 1,
        'izin': 0,
        'sakit': 0,
        'tidak_hadir': 0,
        'alpha': 0,
        'verified': 8,
        'persentase_kehadiran': 100,
      });
      expect(stat.persentaseKehadiran, 100.0);
      expect(stat.adaKeterlambatan, isTrue);
      expect(stat.persentaseTepatWaktu, closeTo(87.5, 0.001));
      // Rincian untuk grafik tetap memuat baris terlambat.
      expect(stat.breakdown, contains(('Terlambat', 1)));
    });
  });

  group('VerifikasiWatcher', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('pemakaian pertama hanya mencatat, tidak membanjiri notifikasi',
        () async {
      final notif = _NotifikasiPalsu();
      final prefs = await SharedPreferences.getInstance();
      final watcher = VerifikasiWatcher(notifikasi: notif, prefs: prefs);

      final n = await watcher.periksa([
        (id: 1, nama: 'Salat Subuh'),
        (id: 2, nama: 'Mengaji'),
      ]);

      expect(n, 0);
      expect(notif.dipanggil, isEmpty);
    });

    test('hanya id baru yang dinotifikasi, tidak berulang', () async {
      final notif = _NotifikasiPalsu();
      final prefs = await SharedPreferences.getInstance();
      final watcher = VerifikasiWatcher(notifikasi: notif, prefs: prefs);

      // Baseline pertama.
      await watcher.periksa([(id: 1, nama: 'Salat Subuh')]);
      expect(notif.dipanggil, isEmpty);

      // id 2 baru → satu notifikasi.
      final n1 = await watcher.periksa([
        (id: 1, nama: 'Salat Subuh'),
        (id: 2, nama: 'Mengaji'),
      ]);
      expect(n1, 1);
      expect(notif.dipanggil.single.judul, 'Tugas diverifikasi pamong');
      expect(notif.dipanggil.single.isi, contains('Mengaji'));

      // Payload sama dimuat ulang → tidak ada notifikasi tambahan.
      final n2 = await watcher.periksa([
        (id: 1, nama: 'Salat Subuh'),
        (id: 2, nama: 'Mengaji'),
      ]);
      expect(n2, 0);
      expect(notif.dipanggil.length, 1);
    });

    test('beberapa verifikasi baru digabung jadi satu notifikasi', () async {
      final notif = _NotifikasiPalsu();
      final prefs = await SharedPreferences.getInstance();
      final watcher = VerifikasiWatcher(notifikasi: notif, prefs: prefs);

      await watcher.periksa([(id: 1, nama: 'Salat Subuh')]);
      final n = await watcher.periksa([
        (id: 1, nama: 'Salat Subuh'),
        (id: 2, nama: 'Mengaji'),
        (id: 3, nama: 'Sedekah'),
        (id: 4, nama: 'Bantu Orang Tua'),
        (id: 5, nama: 'Salat Duha'),
      ]);

      expect(n, 4);
      expect(notif.dipanggil.length, 1);
      expect(notif.dipanggil.single.judul, '4 tugas diverifikasi pamong');
      expect(notif.dipanggil.single.isi, contains('dan lainnya'));
    });

    test('daftar kosong tidak menyentuh penyimpanan', () async {
      final notif = _NotifikasiPalsu();
      final prefs = await SharedPreferences.getInstance();
      final watcher = VerifikasiWatcher(notifikasi: notif, prefs: prefs);

      expect(await watcher.periksa([]), 0);
      expect(prefs.getStringList('pkg_verifikasi_terlihat'), isNull);
    });
  });

  group('menu "Lainnya" mengambang', () {
    testWidgets('menampilkan item dan mengembalikan tap', (tester) async {
      var ditekan = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showFloatingMenu(
                    context,
                    items: [
                      FloatingMenuItem(
                        label: 'Badge',
                        icon: Icons.emoji_events_outlined,
                        deskripsi: 'Koleksi lencana',
                        onTap: () => ditekan++,
                      ),
                      FloatingMenuItem(
                        label: 'Arcade',
                        icon: Icons.timer_outlined,
                        onTap: () {},
                      ),
                    ],
                  ),
                  child: const Text('buka'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      expect(find.text('Badge'), findsOneWidget);
      expect(find.text('Koleksi lencana'), findsOneWidget);
      expect(find.text('Arcade'), findsOneWidget);

      await tester.tap(find.text('Badge'));
      await tester.pumpAndSettle();

      expect(ditekan, 1);
      // Panel tertutup setelah memilih.
      expect(find.text('Arcade'), findsNothing);
    });
  });
}
