import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkgenerus_app/core/network/api_client.dart';
import 'package:pkgenerus_app/core/storage/session_store.dart';
import 'package:pkgenerus_app/features/dashboard/data/dashboard_repository.dart';
import 'package:pkgenerus_app/features/presensi/data/presensi_repository.dart';
import 'package:pkgenerus_app/features/siswa/data/siswa_repository.dart';

/// Payload di bawah ini dipotong dari respons NYATA backend lokal
/// (http://127.0.0.1:8010/api/v1/...) agar parser diuji terhadap bentuk asli.
const _siswaPayload = '''
{"success":true,"data":[{"id":1,"nis":"2024001","nama":"Ahmad Rizki Pratama",
"jenis_kelamin":"L","tanggal_lahir":"2010-01-15","kelompok":null,
"kelompok_label":null,"school_grade":null,"school_grade_label":null,
"effective_pkg_level":"sma_11","effective_pkg_level_label":"SMA 11",
"pamong":[],"foto_url":null,"status":"active","is_active":true,
"nama_wali":"Budi Pratama","phone_wali":"081234567890","age":16,
"full_identity":"Ahmad Rizki Pratama (2024001)",
"kelas":{"id":1,"nama":"Kelas 1A","tingkat":"1","kapasitas":30}}],
"meta":{"current_page":1,"last_page":1,"per_page":15,"total":10,"from":1,"to":10}}
''';

const _presensiPayload = '''
{"success":true,"data":[{"id":69,"tanggal":"2026-08-29","jam_masuk":"07:30:41",
"jam_keluar":"15:30:41","status":"hadir","keterangan":"Scan QR Code berhasil",
"is_verified":true,"duration_minutes":480,
"siswa":{"id":9,"nis":"2024009","nama":"Kevin Ananda","jenis_kelamin":null}}],
"meta":{"current_page":1,"last_page":5,"per_page":15,"total":70}}
''';

const _statsPayload =
    '{"success":true,"data":{"total_students":10,"present_today":0,'
    '"absent_today":0,"late_today":0}}';

const _siswaStatsPayload =
    '{"success":true,"data":{"total":10,"aktif":10,"non_aktif":0,'
    '"per_jenis_kelamin":{"L":5,"P":5}}}';

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
  test('SiswaRepository mengurai payload nyata + meta paginasi', () async {
    final result = await SiswaRepository(_dioWith(_siswaPayload)).list();

    expect(result.ok, isTrue);
    final page = result.data!;
    expect(page.items.single.nama, 'Ahmad Rizki Pratama');
    expect(page.items.single.jenjangLabel, 'SMA 11');
    expect(page.items.single.kelasNama, 'Kelas 1A');
    expect(page.meta.total, 10);
    expect(page.meta.hasMore, isFalse);
  });

  test('SiswaRepository.statistics mengurai per_jenis_kelamin', () async {
    final result =
        await SiswaRepository(_dioWith(_siswaStatsPayload)).statistics();

    expect(result.ok, isTrue);
    expect(result.data!.total, 10);
    expect(result.data!.perJenisKelamin['L'], 5);
  });

  test('PresensiRepository membaca nama siswa dari objek nested', () async {
    final result = await PresensiRepository(_dioWith(_presensiPayload)).list();

    expect(result.ok, isTrue);
    final p = result.data!.items.single;
    expect(p.siswaNama, 'Kevin Ananda');
    expect(p.status, 'hadir');
    expect(p.durationMinutes, 480);
    expect(result.data!.meta.hasMore, isTrue, reason: 'last_page 5 > page 1');
  });

  test('DashboardRepository mengurai stats', () async {
    final result = await DashboardRepository(_dioWith(_statsPayload)).stats();

    expect(result.ok, isTrue);
    expect(result.data!.totalStudents, 10);
  });

  test('403 tanpa permission dilaporkan sebagai failure, bukan exception',
      () async {
    final result = await SiswaRepository(
      _dioWith('{"message":"Forbidden"}', status: 403),
    ).list();

    expect(result.ok, isFalse);
    expect(result.isForbidden, isTrue);
    expect(result.error, 'Forbidden');
  });
}
