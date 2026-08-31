import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkgenerus_app/core/network/api_client.dart';
import 'package:pkgenerus_app/core/storage/session_store.dart';
import 'package:pkgenerus_app/features/game/data/game_models.dart';
import 'package:pkgenerus_app/features/game/data/game_repository.dart';
import 'package:pkgenerus_app/features/gamifikasi/data/gamifikasi_repository.dart';

/// Payload di file ini DIPOTONG DARI RESPONS NYATA backend lokal
/// (http://127.0.0.1:8010/api/v1/gamifikasi/*, /game/*), tersimpan di
/// $LOCALAPPDATA/Temp/pkg_gam/*.json saat uji e2e curl. Token sesi game
/// disamarkan; struktur dan nama field tidak diubah.

const _ringkasanPayload = '''
{"success":true,"data":{"siswa":{"id":1,"nama":"Ahmad Rizki Pratama",
"nis":"2024001","is_ortu_view":false},
"poin":{"total":270,"kehadiran":5,"karakter":165,"bonus":100,"terpakai":30},
"level":{"angka":2,"nama":"Berkembang","warna":"#C0C0C0","level_berikutnya":3,
"nama_berikutnya":"Baik","progres_persen":85,"poin_ke_berikutnya":30},
"peringkat":1,"streak":{"kehadiran":1,"karakter":0},"total_badge":0,
"periode_aktif":null,"poin_periode_aktif":270,
"rekap_sumber":{"tugas_terverifikasi":17,"hadir":7,"terlambat":1,"izin":0,
"sakit":0,"alpha":0}}}
''';

const _leaderboardPayload = '''
{"success":true,"data":{"periode":"all","entries":[
{"peringkat":1,"siswa_id":1,"nama":"Ahmad Rizki Pratama","kelas":null,
"total_poin":270,"poin_periode":null,"level":2,"nama_level":"Berkembang",
"is_saya":true},
{"peringkat":2,"siswa_id":5,"nama":"Bayu Setiawan","kelas":null,
"total_poin":25,"poin_periode":null,"level":1,"nama_level":"Pemula",
"is_saya":false}],
"saya":{"siswa_id":1,"nama":"Ahmad Rizki Pratama","total_poin":270,
"peringkat":1,"masuk_daftar":true}}}
''';

const _historyPayload = '''
{"success":true,"data":[{"id":24,"tipe":"earned","sumber":"game",
"sumber_label":"Game","poin":5,
"keterangan":"Latihan game Rangkai Kata (5/5 benar) — aplikasi mobile",
"tanggal":"2026-08-31T10:28:27+07:00"}],
"meta":{"current_page":1,"last_page":1,"per_page":20,"total":1,
"filter_sumber":"game",
"rekap_sumber":{"tugas_terverifikasi":17,"hadir":7,"terlambat":1,"izin":0,
"sakit":0,"alpha":0}}}
''';

const _badgesPayload = '''
{"success":true,"data":[{"id":2,"nama":"Tepat Waktu",
"deskripsi":"Hadir tepat waktu 20 kali berturut-turut","icon":null,
"kategori":"attendance","warna":"#3B82F6","poin_reward":30,
"sudah_didapat":false,"progres_persen":35,"didapat_pada":null}]}
''';

const _gameInfoPayload = '''
{"success":true,"data":{"jumlah_karakter":29,"siap":true,
"mode":[{"kode":"tebak","nama":"Tebak Karakter",
"deskripsi":"Pilih karakter yang sesuai studi kasus."},
{"kode":"rangkai","nama":"Rangkai Kata",
"deskripsi":"Susun huruf teracak jadi nama karakter."}],
"poin_per_kemenangan":5,"ambang_lulus_persen":60,"hanya_memantau":false,
"arcade":{"skor_terbaik":0,"combo_terbaik":0}}}
''';

const _soloMulaiPayload = '''
{"success":true,"data":{"token":"TOKENSESIDISAMARKAN","mode":"rangkai","soal":[
{"clue":"Kemandirian adalah keberanian mengelola diri, tugas, dan kebutuhan.",
"scrambled":"nMriiad","word_lengths":[7],"hint_arab":"الاِسْتِقْلَال"},
{"clue":"Syukur adalah mengakui nikmat dengan hati, memuji dengan lisan.",
"scrambled":"yukrsBure","word_lengths":[9],"hint_arab":"الشُّكْر"}],
"kedaluwarsa_menit":30}}
''';

const _soloSubmitPayload = '''
{"success":true,"data":{"mode":"rangkai","benar":5,"total":5,"lulus":true,
"poin_didapat":5,"rincian":[
{"nomor":1,"jawaban_saya":"Tidak Menyakiti / Merusak Sesama",
"kunci":"Tidak Menyakiti / Merusak Sesama","benar":true},
{"nomor":2,"jawaban_saya":"Mandiri","kunci":"Mandiri","benar":true}],
"total_poin_sekarang":275}}
''';

const _arcadeLbPayload = '''
{"success":true,"data":[{"peringkat":1,"nama":"Ahmad Rizki Pratama",
"skor":1200,"combo":9,"is_saya":true}],"meta":{"total":1}}
''';

const _staffOnlyPayload =
    '{"success":false,"message":"Endpoint ini hanya untuk akun siswa/orang tua.",'
    '"error_code":"STAFF_TOKEN_NOT_ALLOWED"}';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body, {this.status = 200});

  final String body;
  final int status;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString(body, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });
}

Dio _dioWith(String body, {int status = 200}) {
  final factory = ApiClientFactory(sessionStore: MemorySessionStore());
  factory.dio.httpClientAdapter = _StubAdapter(body, status: status);
  return factory.dio;
}

void main() {
  group('GamifikasiRepository', () {
    test('ringkasan: poin, level, peringkat, rekap sumber', () async {
      final r =
          await GamifikasiRepository(_dioWith(_ringkasanPayload)).ringkasan();

      expect(r.ok, isTrue);
      final g = r.data!;
      expect(g.nama, 'Ahmad Rizki Pratama');
      expect(g.nis, '2024001');
      expect(g.isOrtuView, isFalse);
      expect(g.poin.total, 270);
      expect(g.poin.kehadiran, 5);
      expect(g.poin.karakter, 165);
      expect(g.poin.bonus, 100);
      expect(g.poin.terpakai, 30);
      expect(g.level.angka, 2);
      expect(g.level.nama, 'Berkembang');
      expect(g.level.progresPersen, 85);
      expect(g.level.poinKeBerikutnya, 30);
      expect(g.level.namaBerikutnya, 'Baik');
      expect(g.peringkat, 1);
      expect(g.streakKehadiran, 1);
      expect(g.poinPeriodeAktif, 270);
      expect(g.namaPeriodeAktif, isNull,
          reason: 'tidak ada periode poin aktif di data dummy');
      // Rekap inilah yang menjawab "poin datang dari mana".
      expect(g.rekap.tugasTerverifikasi, 17);
      expect(g.rekap.hadir, 7);
      expect(g.rekap.terlambat, 1);
      expect(g.rekap.alpha, 0);
      expect(g.rekap.totalCatatanPresensi, 8);
    });

    test('leaderboard: entri terurut + posisi saya ditandai', () async {
      final r = await GamifikasiRepository(_dioWith(_leaderboardPayload))
          .leaderboard();

      expect(r.ok, isTrue);
      final lb = r.data!;
      expect(lb.periode, 'all');
      expect(lb.entries, hasLength(2));
      expect(lb.entries.first.peringkat, 1);
      expect(lb.entries.first.nama, 'Ahmad Rizki Pratama');
      expect(lb.entries.first.totalPoin, 270);
      expect(lb.entries.first.namaLevel, 'Berkembang');
      expect(lb.entries.first.isSaya, isTrue);
      expect(lb.entries.last.isSaya, isFalse);
      expect(lb.peringkatSaya, 1);
      expect(lb.poinSaya, 270);
      expect(lb.masukDaftar, isTrue);
    });

    test('history: transaksi poin + meta paginasi', () async {
      final r = await GamifikasiRepository(_dioWith(_historyPayload))
          .history(sumber: 'game');

      expect(r.ok, isTrue);
      final page = r.data!;
      final item = page.items.single;
      expect(item.id, 24);
      expect(item.sumber, 'game');
      expect(item.sumberLabel, 'Game');
      expect(item.poin, 5);
      expect(item.bertambah, isTrue, reason: 'tipe=earned, poin positif');
      expect(item.keterangan, contains('Rangkai Kata'));
      expect(item.tanggal, isNotNull);
      expect(page.meta.total, 1);
      expect(page.meta.currentPage, 1);
      expect(page.meta.lastPage, 1);
    });

    test('badges: progres persen terurai', () async {
      final r = await GamifikasiRepository(_dioWith(_badgesPayload)).badges();

      expect(r.ok, isTrue);
      final b = r.data!.single;
      expect(b.nama, 'Tepat Waktu');
      expect(b.kategori, 'attendance');
      expect(b.poinReward, 30);
      expect(b.sudahDidapat, isFalse);
      expect(b.progresPersen, 35);
      expect(b.didapatPada, isNull);
    });

    test('token staf ditolak 403 tanpa melempar exception', () async {
      final r =
          await GamifikasiRepository(_dioWith(_staffOnlyPayload, status: 403))
              .ringkasan();

      expect(r.ok, isFalse);
      expect(r.isForbidden, isTrue);
      expect(r.error, contains('hanya untuk akun siswa'));
    });
  });

  group('GameRepository', () {
    test('info: 29 karakter, siap, poin & ambang lulus', () async {
      final r = await GameRepository(_dioWith(_gameInfoPayload)).info();

      expect(r.ok, isTrue);
      final g = r.data!;
      expect(g.jumlahKarakter, 29);
      expect(g.siap, isTrue);
      expect(g.poinPerKemenangan, 5);
      expect(g.ambangLulusPersen, 60);
      expect(g.hanyaMemantau, isFalse);
      expect(g.skorTerbaikArcade, 0);
      expect(g.comboTerbaikArcade, 0);
    });

    test('mulaiSolo: soal rangkai tanpa kunci jawaban', () async {
      final r = await GameRepository(_dioWith(_soloMulaiPayload))
          .mulaiSolo(mode: GameMode.rangkai);

      expect(r.ok, isTrue);
      final s = r.data!;
      expect(s.token, isNotEmpty);
      expect(s.mode, GameMode.rangkai);
      expect(s.jumlahSoal, 2);
      expect(s.kedaluwarsaMenit, 30);

      final soal = s.soal.first;
      expect(soal.scrambled, 'nMriiad');
      expect(soal.wordLengths, [7]);
      expect(soal.hintArab, isNotNull);
      expect(soal.pertanyaan, contains('Kemandirian'));
      // Mode rangkai tidak mengirim pilihan; kunci disimpan server.
      expect(soal.options, isEmpty);
      expect(soal.prompt, isNull);
    });

    test('submitSolo: hasil, poin, rincian dengan kunci', () async {
      final r = await GameRepository(_dioWith(_soloSubmitPayload))
          .submitSolo(token: 'TOKENSESIDISAMARKAN', jawaban: const ['a', 'b']);

      expect(r.ok, isTrue);
      final h = r.data!;
      expect(h.mode, GameMode.rangkai);
      expect(h.benar, 5);
      expect(h.total, 5);
      expect(h.lulus, isTrue);
      expect(h.persenBenar, 100);
      expect(h.poinDidapat, 5);
      expect(h.totalPoinSekarang, 275);
      expect(h.rincian.first.kunci, 'Tidak Menyakiti / Merusak Sesama');
      expect(h.rincian.first.nomor, 1);
      expect(h.rincian.first.benar, isTrue);
    });

    test('arcade leaderboard: baris skor + penanda saya', () async {
      final r =
          await GameRepository(_dioWith(_arcadeLbPayload)).arcadeLeaderboard();

      expect(r.ok, isTrue);
      final s = r.data!.single;
      expect(s.peringkat, 1);
      expect(s.nama, 'Ahmad Rizki Pratama');
      expect(s.skor, 1200);
      expect(s.combo, 9);
      expect(s.isSaya, isTrue);
    });
  });
}
