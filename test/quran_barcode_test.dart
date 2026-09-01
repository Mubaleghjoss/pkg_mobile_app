import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkgenerus_app/app/providers.dart';
import 'package:pkgenerus_app/core/network/api_client.dart';
import 'package:pkgenerus_app/features/quran/presentation/quran_barcode_screen.dart';
import 'package:pkgenerus_app/core/storage/session_store.dart';
import 'package:pkgenerus_app/features/quran/data/quran_models.dart';
import 'package:pkgenerus_app/features/quran/data/quran_repository.dart';

class _BarcodeAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final body = switch (options.path) {
      '/quran/barcode/identify' => {
          'success': true,
          'data': {
            'flow_id': 'flow123',
            'expires_at': '2026-09-01T02:30:00Z',
            'student': {
              'name': 'Ahmad Generus',
              'masked_nis': '••••001',
              'school_grade': 'XI',
              'group': 'Kelompok A',
            },
          },
        },
      '/quran/surahs' => {
          'success': true,
          'data': [
            {'nomor': 1, 'nama': 'Al-Fatihah', 'ayah_count': 7},
            {'nomor': 2, 'nama': 'Al-Baqarah', 'ayah_count': 286},
          ],
        },
      _ => {
          'success': true,
          'data': {
            'entry_id': 99,
            'status': 'pending',
            'entry': {
              'id': 99,
              'reading_date': '2026-09-01',
              'surah_start': 2,
              'ayah_start': 1,
              'surah_end': 2,
              'ayah_end': 20,
              'status': 'pending',
            },
          },
        },
    };
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }
}

(Dio, _BarcodeAdapter) _client() {
  final dio = ApiClientFactory(sessionStore: MemorySessionStore()).dio;
  final adapter = _BarcodeAdapter();
  dio.httpClientAdapter = adapter;
  return (dio, adapter);
}

void main() {
  test('QuranBarcodeFlow mengurai identitas server dan expiry ke waktu lokal', () {
    final flow = QuranBarcodeFlow.fromJson({
      'flow_id': 'abc123',
      'expires_at': '2026-09-01T02:30:00.000000Z',
      'student': {
        'name': 'Ahmad Generus',
        'masked_nis': '••••001',
        'school_grade': 'XI',
        'group': 'Kelompok A',
      },
    });

    expect(flow.id, 'abc123');
    expect(flow.student.name, 'Ahmad Generus');
    expect(flow.student.maskedNis, '••••001');
    expect(flow.student.schoolGrade, 'XI');
    expect(flow.expiresAt?.isUtc, isFalse);
  });

  test('QuranBarcodeSubmission hanya mengirim flow dan rentang bacaan', () {
    const submission = QuranBarcodeSubmission(
      flowId: 'flow123',
      surahStart: 2,
      ayahStart: 1,
      surahEnd: 2,
      ayahEnd: 20,
      pageStart: 2,
      pageEnd: 3,
      notes: 'Lancar',
    );

    final payload = submission.toJson();

    expect(payload, {
      'flow_id': 'flow123',
      'surah_start': 2,
      'ayah_start': 1,
      'surah_end': 2,
      'ayah_end': 20,
      'page_start': 2,
      'page_end': 3,
      'notes': 'Lancar',
    });
    expect(payload.containsKey('siswa_id'), isFalse);
    expect(payload.containsKey('student_id'), isFalse);
  });

  test('QuranBarcodeSubmission menghilangkan field opsional kosong', () {
    const submission = QuranBarcodeSubmission(
      flowId: 'flow123',
      surahStart: 1,
      ayahStart: 1,
      surahEnd: 1,
      ayahEnd: 7,
      notes: '   ',
    );

    final payload = submission.toJson();

    expect(payload.containsKey('page_start'), isFalse);
    expect(payload.containsKey('page_end'), isFalse);
    expect(payload.containsKey('notes'), isFalse);
  });

  test('validator tracer menolak rentang surah ayat dan halaman tidak valid', () {
    const alFatihah = QuranSurah(number: 1, nama: 'Al-Fatihah', ayahTotal: 7);
    const alBaqarah = QuranSurah(number: 2, nama: 'Al-Baqarah', ayahTotal: 286);
    const surahs = [alFatihah, alBaqarah];

    expect(
      QuranBarcodeFormValidator.validate(
        surahs: surahs,
        surahStart: 1,
        ayahStart: 8,
        surahEnd: 1,
        ayahEnd: 8,
      ),
      contains('Ayat awal'),
    );
    expect(
      QuranBarcodeFormValidator.validate(
        surahs: surahs,
        surahStart: 2,
        ayahStart: 20,
        surahEnd: 1,
        ayahEnd: 7,
      ),
      contains('Surat akhir'),
    );
    expect(
      QuranBarcodeFormValidator.validate(
        surahs: surahs,
        surahStart: 1,
        ayahStart: 5,
        surahEnd: 1,
        ayahEnd: 4,
      ),
      contains('Ayat akhir'),
    );
    expect(
      QuranBarcodeFormValidator.validate(
        surahs: surahs,
        surahStart: 1,
        ayahStart: 1,
        surahEnd: 1,
        ayahEnd: 7,
        pageStart: 1,
      ),
      contains('Halaman awal dan akhir'),
    );
    expect(
      QuranBarcodeFormValidator.validate(
        surahs: surahs,
        surahStart: 1,
        ayahStart: 1,
        surahEnd: 2,
        ayahEnd: 20,
        pageStart: 1,
        pageEnd: 2,
      ),
      isNull,
    );
  });

  test('repository identify mengirim raw sheet payload dan mengurai flow',
      () async {
    final (dio, adapter) = _client();

    final result =
        await QuranRepository(dio).identifyBarcode('PKG-QURAN-SHEET:token');

    expect(result.ok, isTrue);
    expect(result.data!.id, 'flow123');
    expect(result.data!.student.name, 'Ahmad Generus');
    expect(adapter.requests.single.path, '/quran/barcode/identify');
    expect(adapter.requests.single.data, {
      'sheet_payload': 'PKG-QURAN-SHEET:token',
    });
  });

  test('repository store tidak mengirim identitas siswa dan mengurai entry',
      () async {
    final (dio, adapter) = _client();

    final result = await QuranRepository(dio).storeBarcode(
      const QuranBarcodeSubmission(
        flowId: 'flow123',
        surahStart: 2,
        ayahStart: 1,
        surahEnd: 2,
        ayahEnd: 20,
      ),
    );

    expect(result.ok, isTrue);
    expect(result.data!.id, 99);
    expect(result.data!.status, 'pending');
    final request = adapter.requests.single;
    expect(request.path, '/quran/barcode/store');
    expect((request.data as Map).containsKey('siswa_id'), isFalse);
    expect((request.data as Map).containsKey('student_id'), isFalse);
  });

  testWidgets('scan payload menampilkan siswa dan menyimpan rentang bacaan',
      (tester) async {
    final (dio, adapter) = _client();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quranRepositoryProvider.overrideWithValue(QuranRepository(dio)),
        ],
        child: const MaterialApp(
          home: QuranBarcodeScreen(initialPayload: 'PKG-QURAN-SHEET:token'),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Ahmad Generus'), findsOneWidget);
    expect(find.textContaining('••••001'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('ayah-start')), '1');
    await tester.enterText(find.byKey(const Key('ayah-end')), '7');
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Simpan tracer'), findsOneWidget);
    await tester.tap(find.text('Simpan tracer'));
    await tester.pumpAndSettle();

    expect(find.textContaining('pending'), findsOneWidget);
    final store = adapter.requests.last;
    expect(store.path, '/quran/barcode/store');
    expect((store.data as Map).containsKey('siswa_id'), isFalse);
  });
}
