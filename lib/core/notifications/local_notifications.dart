import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notifikasi lokal (tanpa server push).
///
/// Dipakai untuk memberi tahu siswa saat tugas PKG-nya diverifikasi pamong.
/// Backend PKGenerus tidak punya FCM, jadi deteksinya dilakukan di klien:
/// [VerifikasiWatcher] membandingkan daftar checklist terverifikasi terbaru
/// dengan yang sudah pernah dilihat, lalu memanggil [tampilkan].
///
/// Semua metode aman dipanggil di platform tanpa dukungan (mis. unit test /
/// desktop): kegagalan inisialisasi hanya dicatat, tidak melempar, sehingga
/// tidak pernah menjatuhkan alur utama aplikasi.
abstract class NotifikasiLokal {
  /// Siapkan channel & minta izin bila perlu. Idempoten.
  Future<void> init();

  /// Tampilkan satu notifikasi.
  Future<void> tampilkan({
    required int id,
    required String judul,
    required String isi,
  });
}

class FlutterLocalNotifikasi implements NotifikasiLokal {
  FlutterLocalNotifikasi([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'pkg_verifikasi';
  static const _channelNama = 'Verifikasi tugas PKG';
  static const _channelDeskripsi =
      'Pemberitahuan saat tugas PKG diverifikasi pamong.';

  final FlutterLocalNotificationsPlugin _plugin;

  bool _siap = false;
  bool _gagal = false;

  @override
  Future<void> init() async {
    if (_siap || _gagal) return;
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );

      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await android?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelNama,
            description: _channelDeskripsi,
            importance: Importance.high,
          ),
        );
        // Android 13+ mewajibkan izin runtime; ditolak pun aplikasi tetap
        // berjalan, hanya notifikasinya tidak tampil.
        await android?.requestNotificationsPermission();
      } else if (Platform.isIOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }
      _siap = true;
    } catch (e) {
      // Platform tanpa dukungan / plugin belum terdaftar: jangan ganggu UI.
      _gagal = true;
      debugPrint('NotifikasiLokal.init dilewati: $e');
    }
  }

  @override
  Future<void> tampilkan({
    required int id,
    required String judul,
    required String isi,
  }) async {
    await init();
    if (!_siap) return;
    try {
      await _plugin.show(
        id,
        judul,
        isi,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelNama,
            channelDescription: _channelDeskripsi,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('NotifikasiLokal.tampilkan gagal: $e');
    }
  }
}

/// Implementasi kosong untuk test & platform tanpa notifikasi.
class NotifikasiLokalNoop implements NotifikasiLokal {
  const NotifikasiLokalNoop();

  @override
  Future<void> init() async {}

  @override
  Future<void> tampilkan({
    required int id,
    required String judul,
    required String isi,
  }) async {}
}
