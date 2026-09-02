import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkgenerus_app/core/network/api_client.dart';

void main() {
  Response<dynamic> respons(int status, Map<String, dynamic> data) => Response(
    requestOptions: RequestOptions(path: '/login'),
    statusCode: status,
    data: data,
  );

  test('422 menerjemahkan galat validasi dan menyebut nama field', () {
    final hasil = ApiResponseMapper.map(
      respons(422, {
        'message': 'Validation failed',
        'errors': {
          'nis': ['The nis field is required.'],
        },
      }),
    );

    expect(hasil.error, contains('NIS'));
    expect(hasil.error, contains('wajib diisi'));
    expect(hasil.error, isNot(contains('Validation failed')));
  });

  test('422 tanpa errors memakai pesan fallback bahasa Indonesia', () {
    final hasil = ApiResponseMapper.map(
      respons(422, {'message': 'Validation failed'}),
    );

    expect(hasil.error, 'Data yang dikirim tidak valid.');
  });

  test('401 memakai pesan login yang jelas', () {
    final hasil = ApiResponseMapper.map(
      respons(401, {'message': 'Unauthenticated.'}),
    );

    expect(hasil.error, 'NIS atau kata sandi salah.');
  });
}
