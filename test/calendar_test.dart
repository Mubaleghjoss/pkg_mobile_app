import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkgenerus_app/app/providers.dart';
import 'package:pkgenerus_app/core/network/api_client.dart';
import 'package:pkgenerus_app/core/network/api_result.dart';
import 'package:pkgenerus_app/core/storage/session_store.dart';
import 'package:pkgenerus_app/features/calendar/data/calendar_repository.dart';
import 'package:pkgenerus_app/features/calendar/domain/calendar_event.dart';
import 'package:pkgenerus_app/features/calendar/presentation/calendar_screen.dart';

class _CalendarAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      '{"success":true,"data":[{"id":"1","title":"Rapat",'
      '"start":"2026-09-08T08:00:00Z","end":null,"all_day":false,'
      '"type":"jadwal","color":"#123456","details":{}}],'
      '"meta":{"start":"2026-09-01","end":"2026-09-30"}}',
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }
}

class _FakeCalendarRepository extends CalendarRepository {
  _FakeCalendarRepository(this.result) : super(Dio());

  final ApiResult<List<CalendarEvent>> result;
  int calls = 0;

  @override
  Future<ApiResult<List<CalendarEvent>>> events({
    required DateTime start,
    required DateTime end,
  }) async {
    calls++;
    return result;
  }
}

void main() {
  test('CalendarEvent mengurai timestamp ke waktu lokal dan semua field', () {
    final event = CalendarEvent.fromJson(<String, dynamic>{
      'id': 'task-7',
      'title': 'Setor tugas',
      'start': '2026-09-01T23:30:00Z',
      'end': '2026-09-02T00:30:00Z',
      'all_day': false,
      'type': 'tugas',
      'color': '#3366FF',
      'details': <String, dynamic>{'status': 'pending'},
    });

    expect(event.id, 'task-7');
    expect(event.title, 'Setor tugas');
    expect(event.start, DateTime.parse('2026-09-01T23:30:00Z').toLocal());
    expect(event.end, DateTime.parse('2026-09-02T00:30:00Z').toLocal());
    expect(event.allDay, isFalse);
    expect(event.type, 'tugas');
    expect(event.color, '#3366FF');
    expect(event.details, <String, dynamic>{'status': 'pending'});
  });

  test('groupCalendarEvents mengelompokkan berdasarkan tanggal lokal', () {
    final events = <CalendarEvent>[
      CalendarEvent.fromJson(<String, dynamic>{
        'id': '1',
        'title': 'A',
        'start': '2026-09-01T23:30:00Z',
        'end': null,
        'all_day': true,
        'type': 'presensi',
        'color': '#00AA00',
        'details': <String, dynamic>{},
      }),
      CalendarEvent.fromJson(<String, dynamic>{
        'id': '2',
        'title': 'B',
        'start': '2026-09-02T01:00:00Z',
        'end': null,
        'all_day': false,
        'type': 'tugas',
        'color': '#AA0000',
        'details': <String, dynamic>{},
      }),
    ];

    final grouped = groupCalendarEvents(events);
    final expectedKey = dateOnly(
      DateTime.parse('2026-09-01T23:30:00Z').toLocal(),
    );

    expect(grouped[expectedKey], hasLength(2));
  });

  test(
    'CalendarRepository mengirim rentang bulan dan memetakan data',
    () async {
      final adapter = _CalendarAdapter();
      final factory = ApiClientFactory(sessionStore: MemorySessionStore());
      factory.dio.httpClientAdapter = adapter;

      final result = await CalendarRepository(factory.dio)
          .events(start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 30));

      expect(result.ok, isTrue);
      expect(result.data!.single.title, 'Rapat');
      expect(adapter.request!.path, '/calendar/events');
      expect(adapter.request!.queryParameters, <String, dynamic>{
        'start': '2026-09-01',
        'end': '2026-09-30',
      });
    },
  );

  testWidgets('kalender menampilkan bulan, filter, agenda, dan ganti bulan', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeCalendarRepository(
      ApiResult.success(<CalendarEvent>[
        CalendarEvent(
          id: '1',
          title: 'Rapat pamong',
          start: DateTime(2026, 9, 8, 15),
          end: null,
          allDay: false,
          type: 'jadwal',
          color: '#123456',
          details: const <String, dynamic>{},
        ),
        CalendarEvent(
          id: '2',
          title: 'Kumpulkan tugas',
          start: DateTime(2026, 9, 9, 9),
          end: null,
          allDay: false,
          type: 'tugas',
          color: '#AA0000',
          details: const <String, dynamic>{},
        ),
      ]),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(repository),
          calendarInitialMonthProvider.overrideWithValue(DateTime(2026, 9, 1)),
        ],
        child: const MaterialApp(home: Scaffold(body: CalendarScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('Jadwal'), findsOneWidget);
    expect(find.text('Agenda tanggal terpilih'), findsOneWidget);
    expect(find.text('Agenda terdekat'), findsOneWidget);
    expect(find.text('Rapat pamong'), findsWidgets);

    await tester.tap(find.text('8'));
    await tester.pump();
    expect(find.text('Rapat pamong'), findsNWidgets(2));

    await tester.tap(find.text('Tugas'));
    await tester.pump();
    expect(find.text('Rapat pamong'), findsNothing);
    expect(find.text('Kumpulkan tugas'), findsOneWidget);

    await tester.tap(find.text('Jadwal'));
    await tester.pump();
    expect(find.text('Rapat pamong'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Bulan berikutnya'));
    await tester.pumpAndSettle();
    expect(find.text('Oktober 2026'), findsOneWidget);
    expect(repository.calls, 2);
  });

  testWidgets('kalender menampilkan empty dan error dengan retry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final empty = _FakeCalendarRepository(
      ApiResult.success(const <CalendarEvent>[]),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(empty),
          calendarInitialMonthProvider.overrideWithValue(DateTime(2026, 9, 1)),
        ],
        child: const MaterialApp(home: Scaffold(body: CalendarScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Belum ada agenda pada bulan ini.'), findsOneWidget);

    final failed = _FakeCalendarRepository(
      ApiResult.failure('Server kalender gagal'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(failed),
          calendarInitialMonthProvider.overrideWithValue(DateTime(2026, 9, 1)),
        ],
        child: const MaterialApp(home: Scaffold(body: CalendarScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Server kalender gagal'), findsOneWidget);
    final callsBeforeRetry = failed.calls;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(failed.calls, greaterThan(callsBeforeRetry));
  });
}
