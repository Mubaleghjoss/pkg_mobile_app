import 'package:shared_preferences/shared_preferences.dart';

import 'local_notifications.dart';

/// Mendeteksi tugas PKG yang *baru* diverifikasi pamong lalu memunculkan
/// notifikasi lokal.
///
/// Backend PKGenerus tidak punya push server (tidak ada FCM), jadi deteksinya
/// dilakukan di klien: setiap kali daftar tugas harian dimuat, id checklist
/// yang `is_verified` dibandingkan dengan id yang sudah pernah diberitahukan
/// dan dipersist di `SharedPreferences`. Yang belum pernah tercatat itulah yang
/// dinotifikasi, sehingga membuka layar berulang kali tidak membuat notifikasi
/// ganda dan restart aplikasi tidak mengulang notifikasi lama.
///
/// Batasan yang disengaja: notifikasi hanya muncul saat aplikasi dibuka (tidak
/// ada background fetch). Ini cukup untuk kebutuhan "siswa tahu tugasnya sudah
/// diverifikasi" tanpa menambah infrastruktur push.
class VerifikasiWatcher {
  VerifikasiWatcher({
    required NotifikasiLokal notifikasi,
    SharedPreferences? prefs,
  })  : _notifikasi = notifikasi,
        _prefs = prefs;

  static const _key = 'pkg_verifikasi_terlihat';

  /// Batas id yang disimpan supaya preferensi tidak tumbuh tanpa batas.
  static const _maksSimpan = 300;

  final NotifikasiLokal _notifikasi;
  SharedPreferences? _prefs;

  Future<SharedPreferences> _resolvePrefs() async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// [terverifikasi] = pasangan id checklist dan nama karakternya yang sudah
  /// diverifikasi pamong pada data terbaru.
  ///
  /// Mengembalikan jumlah notifikasi yang benar-benar ditampilkan.
  Future<int> periksa(List<({int id, String nama})> terverifikasi) async {
    final prefs = await _resolvePrefs();

    // Tetapkan garis dasar meski belum ada satu pun verifikasi. Tanpa ini,
    // kunci baru lahir saat verifikasi pertama muncul sehingga verifikasi itu
    // dianggap "riwayat lama" dan notifikasinya ikut ditelan.
    if (terverifikasi.isEmpty) {
      if (!prefs.containsKey(_key)) {
        await prefs.setStringList(_key, const <String>[]);
      }
      return 0;
    }

    final terlihat = prefs.getStringList(_key)?.toSet() ?? <String>{};

    final baru = terverifikasi
        .where((e) => e.id > 0 && !terlihat.contains('${e.id}'))
        .toList(growable: false);

    // Pertama kali dipakai (belum ada catatan sama sekali): jangan membanjiri
    // pengguna dengan notifikasi untuk riwayat lama — cukup catat sebagai
    // sudah terlihat.
    final pertamaKali = !prefs.containsKey(_key);

    if (baru.isNotEmpty) {
      terlihat.addAll(baru.map((e) => '${e.id}'));
      // Simpan hanya id terbaru bila melebihi batas.
      final disimpan = terlihat.toList();
      if (disimpan.length > _maksSimpan) {
        disimpan.removeRange(0, disimpan.length - _maksSimpan);
      }
      await prefs.setStringList(_key, disimpan);
    } else if (pertamaKali) {
      await prefs.setStringList(_key, terlihat.toList());
    }

    if (pertamaKali || baru.isEmpty) return 0;

    if (baru.length == 1) {
      await _notifikasi.tampilkan(
        id: baru.first.id,
        judul: 'Tugas diverifikasi pamong',
        isi: '"${baru.first.nama}" sudah diverifikasi. Poinnya masuk.',
      );
      return 1;
    }

    await _notifikasi.tampilkan(
      id: baru.first.id,
      judul: '${baru.length} tugas diverifikasi pamong',
      isi: baru.map((e) => e.nama).take(3).join(', ') +
          (baru.length > 3 ? ', dan lainnya' : ''),
    );
    return baru.length;
  }
}
