import 'package:shared_preferences/shared_preferences.dart';

/// Menyimpan progres baca materi 29 karakter secara lokal.
///
/// Backend tidak punya tabel "sudah dibaca" untuk karakter luhur, jadi status
/// bacaan disimpan di perangkat. Nilainya per-slug supaya tetap benar meski
/// urutan daftar berubah.
class BacaProgressStore {
  static const _prefixDibaca = 'karakter_dibaca_';
  static const _keyTutorialSelesai = 'karakter_tutorial_selesai';

  Future<Set<String>> dibaca() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs
        .getKeys()
        .where((k) => k.startsWith(_prefixDibaca) && prefs.getBool(k) == true)
        .map((k) => k.substring(_prefixDibaca.length))
        .toSet();
  }

  Future<void> tandaiDibaca(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefixDibaca$slug', true);
  }

  Future<bool> sudahDibaca(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefixDibaca$slug') ?? false;
  }

  /// Tutorial pembaca hanya ditampilkan sekali; tombol "Lewati" juga menandai
  /// selesai supaya tidak mengganggu di kunjungan berikutnya.
  Future<bool> tutorialSelesai() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyTutorialSelesai) ?? false;
  }

  Future<void> setTutorialSelesai() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTutorialSelesai, true);
  }

  /// Dipakai tombol "Ulangi tutorial" di layar daftar.
  Future<void> resetTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyTutorialSelesai);
  }
}
