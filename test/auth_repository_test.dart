import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkgenerus_app/core/network/api_client.dart';
import 'package:pkgenerus_app/core/storage/session_store.dart';
import 'package:pkgenerus_app/features/auth/data/auth_repository.dart';

/// Interceptor palsu: mengembalikan respons yang sudah disiapkan tanpa jaringan.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }
}

ResponseBody _json(String body, int status) => ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  late MemorySessionStore store;

  ({Dio dio, _StubAdapter adapter}) build(
    ResponseBody Function(RequestOptions options) handler, {
    UnauthorizedCallback? onUnauthorized,
  }) {
    final adapter = _StubAdapter(handler);
    final factory = ApiClientFactory(
      sessionStore: store,
      onUnauthorized: onUnauthorized,
    );
    factory.dio.httpClientAdapter = adapter;
    return (dio: factory.dio, adapter: adapter);
  }

  setUp(() => store = MemorySessionStore());

  test('login mengirim field username dan menyimpan sesi', () async {
    final env = build((options) => _json(
          '{"user":{"id":1,"username":"tester_admin","role":"admin",'
          '"permissions":["view_students"]},"token":"tok-123",'
          '"expires_at":"2099-01-01T00:00:00.000Z"}',
          200,
        ));
    final repo = AuthRepository(dio: env.dio, sessionStore: store);

    final result =
        await repo.login(username: 'tester_admin', password: 'tester123');

    expect(result.ok, isTrue);
    expect(result.data!.token, 'tok-123');
    expect(result.data!.can('view_students'), isTrue);

    final sent = env.adapter.requests.single;
    expect(sent.path, '/login');
    expect(sent.data, containsPair('username', 'tester_admin'));
    expect((sent.data as Map).containsKey('email'), isFalse);

    // Sesi tersimpan sehingga request berikutnya membawa bearer token.
    expect((await store.read())!.token, 'tok-123');
  });

  test('request terproteksi menyertakan Authorization Bearer', () async {
    await store.write(const AuthSession(
      token: 'tok-abc',
      expiresAt: null,
      username: 'tester_admin',
      role: 'admin',
      permissions: ['view_students'],
    ));

    final env = build((_) => _json('{"success":true,"data":[]}', 200));
    await env.dio.get<dynamic>('/siswa');

    expect(
      env.adapter.requests.single.headers['Authorization'],
      'Bearer tok-abc',
    );
    expect(env.adapter.requests.single.headers['Accept'], 'application/json');
  });

  test('HTTP 401 membersihkan sesi dan memicu callback', () async {
    await store.write(const AuthSession(
      token: 'expired',
      expiresAt: null,
      username: 'x',
      role: 'admin',
      permissions: [],
    ));

    var called = false;
    final env = build(
      (_) => _json('{"message":"Unauthenticated."}', 401),
      onUnauthorized: () async => called = true,
    );

    final response = await env.dio.get<dynamic>('/me');

    expect(response.statusCode, 401);
    expect(called, isTrue);
    expect(await store.read(), isNull);
  });

  test('HTTP 422 dipetakan menjadi fieldErrors tanpa exception', () async {
    final env = build((_) => _json(
          '{"success":false,"error":"Validation failed",'
          '"errors":{"username":["The username field is required."]}}',
          422,
        ));

    final mapped =
        ApiResponseMapper.map(await env.dio.post<dynamic>('/login', data: {}));

    expect(mapped.ok, isFalse);
    expect(mapped.isValidationError, isTrue);
    expect(mapped.fieldErrors!['username'], isNotEmpty);
  });

  test('HTTP 429 rate limit login terdeteksi', () async {
    final env = build((_) => _json(
          '{"error":"Too many login attempts. Please try again in 300 seconds."}',
          429,
        ));
    final repo = AuthRepository(dio: env.dio, sessionStore: store);

    final result = await repo.login(username: 'a', password: 'b');

    expect(result.ok, isFalse);
    expect(result.isRateLimited, isTrue);
    expect(result.error, contains('Too many login attempts'));
  });

  test('logout tetap membersihkan sesi walau server error', () async {
    await store.write(const AuthSession(
      token: 'tok',
      expiresAt: null,
      username: 'x',
      role: 'admin',
      permissions: [],
    ));
    final env = build((_) => _json('{"message":"Server Error"}', 500));
    final repo = AuthRepository(dio: env.dio, sessionStore: store);

    await repo.logout();

    expect(await store.read(), isNull);
  });
}
