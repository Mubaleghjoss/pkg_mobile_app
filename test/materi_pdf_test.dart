import 'package:flutter_test/flutter_test.dart';
import 'package:pkgenerus_app/features/materi/data/materi.dart';
import 'package:pkgenerus_app/features/materi/presentation/materi_pdf_reader_screen.dart';

void main() {
  test('MateriPdf membaca nama dokumen dari payload API Laravel', () {
    final pdf = MateriPdf.fromJson({
      'nama': 'Panduan Pembinaan.pdf',
      'url': 'https://pkgenerus.my.id/storage/materi/panduan.pdf',
    });

    expect(pdf.name, 'Panduan Pembinaan.pdf');
    expect(pdf.url, contains('/storage/materi/'));
  });

  test(
    'share URL production mengganti host emulator dengan HTTPS production',
    () {
      final url = materiShareUrl(
        'http://10.0.2.2:8010/storage/materi/file.pdf',
        baseUrl: 'https://pkgenerus.my.id',
      );

      expect(url, 'https://pkgenerus.my.id/storage/materi/file.pdf');
      expect(url, isNot(contains('10.0.2.2')));
    },
  );

  test('share URL production melengkapi URL relatif', () {
    expect(
      materiShareUrl(
        '/storage/materi/file.pdf',
        baseUrl: 'https://pkgenerus.my.id',
      ),
      'https://pkgenerus.my.id/storage/materi/file.pdf',
    );
  });

  test('share URL lokal tetap lokal pada build emulator', () {
    expect(
      materiShareUrl(
        'http://10.0.2.2:8010/storage/materi/file.pdf',
        baseUrl: 'http://10.0.2.2:8010',
      ),
      'http://10.0.2.2:8010/storage/materi/file.pdf',
    );
  });
}
