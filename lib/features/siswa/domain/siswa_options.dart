/// Opsi referensi yang HARUS cocok dengan validasi backend.
///
/// Sumber (dibaca langsung dari repo Laravel, bukan diasumsikan):
/// - `app/Support/TargetGrade.php` → nilai `school_grade` / `target_grade_override`
/// - `app/Support/ParticipantProfileOptions.php` → nilai `kelompok`
/// - `app/Http/Requests/Siswa/UpdateSiswaRequest.php` → nilai `status`
///
/// Bila backend menambah opsi baru, daftar ini harus diperbarui; mengirim nilai
/// di luar daftar akan ditolak HTTP 422.
class SiswaOptions {
  const SiswaOptions._();

  /// `school_grade`: kode → label ringkas.
  static const schoolGrades = <String, String>{
    'smp_7': 'SMP 7',
    'smp_8': 'SMP 8',
    'smp_9': 'SMP 9',
    'sma_10': 'SMA 10',
    'sma_11': 'SMA 11',
    'sma_12': 'SMA 12',
    'pranikah': 'Pranikah (Selesai SMA/K)',
  };

  /// `kelompok`: kode (huruf kecil, mengandung spasi) → label tampilan.
  static const kelompok = <String, String>{
    'sawah dalam 1': 'Sawah Dalam 1',
    'sawah dalam 2': 'Sawah Dalam 2',
    'panunggangan utara': 'Panunggangan Utara',
    'pakulonan': 'Pakulonan',
  };

  /// `status` siswa (hanya pada endpoint update).
  static const status = <String, String>{
    'active': 'Aktif',
    'inactive': 'Tidak aktif',
    'graduated': 'Lulus',
    'transferred': 'Pindah',
  };

  static const jenisKelamin = <String, String>{
    'L': 'Laki-laki',
    'P': 'Perempuan',
  };
}
