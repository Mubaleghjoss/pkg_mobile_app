import 'package:flutter_test/flutter_test.dart';
import 'package:pkgenerus_app/features/materi/data/materi.dart';

/// Folder materi: backend mengirim 34 folder tapi hanya sebagian berisi materi.
/// Chip filter harus menyaring yang kosong, dan tetap aman bila backend lama
/// tidak mengirim `materi_count`.
void main() {
  group('MateriFolder.fromJson', () {
    test('membaca materi_count dan parent_id', () {
      final f = MateriFolder.fromJson(<String, dynamic>{
        'id': 34,
        'nama': 'Materi Pembinaan Generus',
        'parent_id': null,
        'materi_count': 5,
      });

      expect(f.id, 34);
      expect(f.name, 'Materi Pembinaan Generus');
      expect(f.materiCount, 5);
      expect(f.parentId, isNull);
    });

    test('folder yang menempel pada materi tanpa materi_count', () {
      final f = MateriFolder.fromJson(<String, dynamic>{
        'id': 34,
        'nama': 'Materi Pembinaan Generus',
      });

      expect(f.materiCount, isNull);
      expect(f.parentId, isNull);
    });

    test('nama kosong jatuh ke label aman', () {
      final f = MateriFolder.fromJson(<String, dynamic>{'id': 2});
      expect(f.name, 'Tanpa folder');
    });
  });

  group('penyaringan folder untuk chip filter', () {
    // Meniru logika materiFoldersProvider tanpa menyentuh jaringan.
    List<MateriFolder> pilih(List<MateriFolder> semua) {
      final berisi = semua.where((f) => (f.materiCount ?? 0) > 0).toList();
      final dipakai = berisi.isEmpty ? semua : berisi;
      return dipakai
        ..sort((a, b) => (b.materiCount ?? 0).compareTo(a.materiCount ?? 0));
    }

    test('folder kosong dibuang, sisanya urut menurun', () {
      final hasil = pilih([
        const MateriFolder(id: 1, name: '29 Karakter Luhur', materiCount: 0),
        const MateriFolder(id: 34, name: 'Materi Pembinaan', materiCount: 5),
        const MateriFolder(id: 2, name: 'PKG', materiCount: 0),
        const MateriFolder(id: 5, name: 'Akhlaqul Karimah', materiCount: 2),
      ]);

      expect(hasil.map((f) => f.id).toList(), [34, 5]);
    });

    test('backend tanpa materi_count: semua folder tetap tampil', () {
      final hasil = pilih([
        const MateriFolder(id: 1, name: 'A'),
        const MateriFolder(id: 2, name: 'B'),
      ]);

      expect(hasil.length, 2);
    });
  });
}
