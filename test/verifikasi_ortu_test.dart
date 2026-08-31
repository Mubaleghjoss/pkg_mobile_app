import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkgenerus_app/core/network/api_client.dart';
import 'package:pkgenerus_app/core/storage/session_store.dart';
import 'package:pkgenerus_app/features/ortu/data/ortu_repository.dart';
import 'package:pkgenerus_app/features/verifikasi/data/verifikasi_repository.dart';

/// Semua payload di file ini DIPOTONG DARI RESPONS NYATA backend lokal
/// (http://127.0.0.1:8010/api/v1/...), hasil skrip uji
/// `E:/hermes/scripts/pkg_e2e_{tugas,pamong}.sh`. Tidak ada payload karangan,
/// supaya parser diuji terhadap bentuk data yang benar-benar dikirim server.

const _verlistPayload = '''
{"success":true,"data":[{"id":68,"siswa_id":1,"siswa_nama":"Ahmad Rizki Pratama",
"siswa_nis":"2024001","kelas":"Kelas 1A","karakter_id":6,
"karakter_nama":"Belajar Materi 30 Menit","kategori":"kemandirian","poin":15,
"checked_at":"2026-08-30T23:52:33+07:00",
"hasil_teks":"Saya belajar materi Akhlak selama 30 menit dan mencatat 3 poin penting.",
"student_note":"Dikerjakan pagi ini.","is_verified":false,"verified_at":null,
"verified_by":null,"notes":null,"has_proof_photo":false,"has_proof_voice":false,
"proof_requirement":"optional"}],
"meta":{"current_page":1,"last_page":3,"per_page":5,"total":11,
"status":"unverified","terverifikasi":51,"menunggu":11,"scope":"assigned"}}
''';

const _verifyPayload = '''
{"success":true,"message":"Tugas berhasil diverifikasi. +15 poin diberikan.",
"data":{"id":68,"siswa_id":1,"siswa_nama":"Ahmad Rizki Pratama",
"siswa_nis":"2024001","kelas":"Kelas 1A","karakter_id":6,
"karakter_nama":"Belajar Materi 30 Menit","kategori":"kemandirian","poin":15,
"checked_at":"2026-08-30T23:52:33+07:00","hasil_teks":"Sudah saya kerjakan.",
"student_note":"Dikerjakan pagi ini.","is_verified":true,
"verified_at":"2026-08-30T23:52:35+07:00","verified_by":"Tester Pamong",
"notes":"Terverifikasi pamong via aplikasi mobile. Pertahankan.",
"has_proof_photo":false,"has_proof_voice":false,
"proof_requirement":"optional"},"meta":{"poin_diberikan":15}}
''';

const _bulkPayload = '''
{"success":true,"message":"3 tugas diverifikasi, 0 dilewati.",
"data":{"berhasil":[{"id":61,"poin":10},{"id":60,"poin":20},{"id":1,"poin":20}],
"gagal":[]},"meta":{"total_poin":50}}
''';

const _bulkSebagianPayload = '''
{"success":true,"message":"1 tugas diverifikasi, 1 dilewati.",
"data":{"berhasil":[{"id":68,"poin":15}],
"gagal":[{"id":9,"alasan":"Bukan siswa binaan Anda."}]},"meta":{"total_poin":15}}
''';

const _oringPayload = '''
{"success":true,"data":{"siswa":{"id":1,"nama":"Ahmad Rizki Pratama",
"nis":"2024001","kelas":"Kelas 1A","is_ortu_view":true},
"tugas":{"total_tugas_aktif":6,"terverifikasi":5,"menunggu_verifikasi":1,
"poin_terverifikasi":255,"persentase":83.3},
"presensi":{"hadir":7,"terlambat":1,"izin":0,"sakit":0,"alpha":0,"total":8},
"quran":{"terverifikasi_total":4,"terverifikasi_bulan_ini":4,
"menunggu_verifikasi":2,"ditolak":0,"terakhir_membaca":"2026-08-27"}}}
''';

const _otugasPayload = '''
{"success":true,"data":[{"id":68,"karakter_nama":"Belajar Materi 30 Menit",
"kategori":"kemandirian","poin":15,"checked_at":"2026-08-30T23:52:33+07:00",
"hasil_teks":"Sudah saya kerjakan.","is_verified":true,
"verified_at":"2026-08-30T23:52:35+07:00","verified_by":"Tester Pamong",
"notes":"Terverifikasi pamong via aplikasi mobile. Pertahankan."}],
"meta":{"current_page":1,"last_page":4,"per_page":5,"total":17,"status":"all",
"total_tugas_aktif":6,"terverifikasi":5,"menunggu_verifikasi":1,
"poin_terverifikasi":255,"persentase":83.3}}
''';

const _opresPayload = '''
{"success":true,"data":[{"id":71,"tanggal":"2026-08-30","status":"terlambat",
"jam_masuk":"2026-08-30T07:12:48.000000Z","jam_keluar":null,
"is_verified":false,"verified_at":null,"keterangan":null}],
"meta":{"current_page":1,"last_page":3,"per_page":3,"total":8,
"totals":{"hadir":7,"terlambat":1,"izin":0,"sakit":0,"alpha":0,"total":8},
"bulanan":[{"periode":"2026-08","hadir":7,"terlambat":1,"izin":0,"sakit":0,
"alpha":0,"total":8}]}}
''';

const _oquranPayload =
    '{"success":true,"data":{"terverifikasi_total":4,'
    '"terverifikasi_bulan_ini":4,"menunggu_verifikasi":2,"ditolak":0,'
    '"terakhir_membaca":"2026-08-27"}}';

/// 403 nyata saat token ortu mencoba menulis (submit/komentar).
const _ortuReadOnlyPayload =
    '{"success":false,"message":"Akun orang tua hanya dapat memantau.",'
    '"error_code":"ORTU_READ_ONLY"}';

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
  group('VerifikasiRepository', () {
    test('antrean: item + meta scope binaan', () async {
      final r = await VerifikasiRepository(_dioWith(_verlistPayload)).list();

      expect(r.ok, isTrue);
      final h = r.data!;
      final item = h.page.items.single;
      expect(item.id, 68);
      expect(item.siswaNama, 'Ahmad Rizki Pratama');
      expect(item.karakterNama, 'Belajar Materi 30 Menit');
      expect(item.poin, 15);
      expect(item.isVerified, isFalse);
      expect(item.adaBukti, isFalse);
      expect(item.checkedAt, isNotNull);
      expect(h.page.meta.total, 11);
      expect(h.page.meta.hasMore, isTrue);
      expect(h.ringkasan.menunggu, 11);
      expect(h.ringkasan.terverifikasi, 51);
      expect(h.ringkasan.seluruhSiswa, isFalse, reason: 'scope=assigned');
    });

    test('verify: item terverifikasi + poin diberikan dari meta', () async {
      final r = await VerifikasiRepository(_dioWith(_verifyPayload))
          .verify(68, notes: 'ok');

      expect(r.ok, isTrue);
      expect(r.data!.item!.isVerified, isTrue);
      expect(r.data!.item!.verifiedBy, 'Tester Pamong');
      expect(r.data!.poin, 15);
    });

    test('bulk: berhasil berisi objek {id, poin}, id diurai benar', () async {
      final r = await VerifikasiRepository(_dioWith(_bulkPayload))
          .bulkVerify(const [61, 60, 1]);

      expect(r.ok, isTrue);
      expect(r.data!.berhasil, [61, 60, 1]);
      expect(r.data!.gagal, isEmpty);
      expect(r.data!.totalPoin, 50);
    });

    test('bulk sebagian: entri gagal membawa alasan', () async {
      final r = await VerifikasiRepository(_dioWith(_bulkSebagianPayload))
          .bulkVerify(const [68, 9]);

      expect(r.ok, isTrue);
      expect(r.data!.berhasil, [68]);
      expect(r.data!.gagal.single.id, 9);
      expect(r.data!.gagal.single.alasan, contains('binaan'));
      expect(r.data!.totalPoin, 15);
    });
  });

  group('OrtuRepository', () {
    test('ringkasan: tugas, presensi, dan Quran anak', () async {
      final r = await OrtuRepository(_dioWith(_oringPayload)).ringkasan();

      expect(r.ok, isTrue);
      final d = r.data!;
      expect(d.siswa.nama, 'Ahmad Rizki Pratama');
      expect(d.siswa.kelas, 'Kelas 1A');
      expect(d.tugas.totalTugasAktif, 6);
      expect(d.tugas.terverifikasi, 5);
      expect(d.tugas.poinTerverifikasi, 255);
      expect(d.tugas.persentase, closeTo(83.3, 0.01));
      expect(d.presensi.hadir, 7);
      expect(d.presensi.total, 8);
      expect(d.presensi.persentaseKehadiran, closeTo(100.0, 0.01),
          reason: 'hadir + terlambat = 8 dari 8 catatan');
      expect(d.quran.terverifikasiTotal, 4);
      expect(d.quran.menungguVerifikasi, 2);
      expect(d.quran.terakhirMembaca, '2026-08-27');
    });

    test('tugas: daftar + rekap di meta', () async {
      final r = await OrtuRepository(_dioWith(_otugasPayload)).tugas();

      expect(r.ok, isTrue);
      expect(r.data!.page.items.single.karakterNama, 'Belajar Materi 30 Menit');
      expect(r.data!.page.items.single.verifiedBy, 'Tester Pamong');
      expect(r.data!.rekap.persentase, closeTo(83.3, 0.01));
      expect(r.data!.page.meta.total, 17);
    });

    test('presensi: totals + rekap bulanan', () async {
      final r = await OrtuRepository(_dioWith(_opresPayload)).presensi();

      expect(r.ok, isTrue);
      final h = r.data!;
      expect(h.page.items.single.status, 'terlambat');
      expect(h.page.items.single.jamKeluar, isNull);
      expect(h.totals.terlambat, 1);
      expect(h.bulanan.single.periode, '2026-08');
      expect(h.bulanan.single.totals.hadir, 7);
    });

    test('quran: ringkasan bacaan', () async {
      final r = await OrtuRepository(_dioWith(_oquranPayload)).quran();

      expect(r.ok, isTrue);
      expect(r.data!.terverifikasiBulanIni, 4);
      expect(r.data!.ditolak, 0);
    });

    test('403 ORTU_READ_ONLY dilaporkan sebagai failure, bukan exception',
        () async {
      final r = await OrtuRepository(_dioWith(_ortuReadOnlyPayload, status: 403))
          .ringkasan();

      expect(r.ok, isFalse);
      expect(r.error, contains('memantau'));
    });
  });
}
