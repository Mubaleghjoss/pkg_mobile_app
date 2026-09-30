import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

abstract class NotifikasiLokal {
  Future<void> init();

  Future<void> tampilkan({
    required int id,
    required String judul,
    required String isi,
  });
}

extension NotifikasiRouteHandlerExtension on NotifikasiLokal {
  void setRouteHandler(void Function(String route) handler) {
    if (this is FlutterLocalNotifikasi) {
      (this as FlutterLocalNotifikasi).setRouteHandler(handler);
    }
  }

  Future<void> tampilkanDenganRute({
    required int id,
    required String judul,
    required String isi,
    required String route,
  }) async {
    if (this is FlutterLocalNotifikasi) {
      await (this as FlutterLocalNotifikasi).tampilkanDenganRute(
        id: id,
        judul: judul,
        isi: isi,
        route: route,
      );
    } else {
      await tampilkan(id: id, judul: judul, isi: isi);
    }
  }
}

class FlutterLocalNotifikasi implements NotifikasiLokal {
  FlutterLocalNotifikasi([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'pkg_aktivitas';
  static const _channelNama = 'Aktivitas PKGenerus';
  static const _channelDeskripsi = 'Pemberitahuan aktivitas PKGenerus.';

  final FlutterLocalNotificationsPlugin _plugin;
  void Function(String route)? _routeHandler;
  bool _siap = false;
  bool _gagal = false;

  void setRouteHandler(void Function(String route) handler) {
    _routeHandler = handler;
  }

  @override
  Future<void> init() async {
    if (_siap || _gagal) return;
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (response) {
          final route = response.payload;
          if (route != null && route.startsWith('/')) {
            _routeHandler?.call(route);
          }
        },
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
        await android?.requestNotificationsPermission();
      } else if (Platform.isIOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }
      _siap = true;
    } catch (e) {
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
    await _tampilkan(id: id, judul: judul, isi: isi);
  }

  Future<void> tampilkanDenganRute({
    required int id,
    required String judul,
    required String isi,
    required String route,
  }) async {
    await _tampilkan(id: id, judul: judul, isi: isi, route: route);
  }

  Future<void> _tampilkan({
    required int id,
    required String judul,
    required String isi,
    String? route,
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
        payload: route,
      );
    } catch (e) {
      debugPrint('NotifikasiLokal.tampilkan gagal: $e');
    }
  }
}

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

Future<void> tampilkanDenganRute({
  required NotifikasiLokal notifikasi,
  required int id,
  required String judul,
  required String isi,
  required String route,
}) async {
  if (notifikasi is FlutterLocalNotifikasi) {
    await notifikasi.tampilkanDenganRute(
      id: id,
      judul: judul,
      isi: isi,
      route: route,
    );
  } else {
    await notifikasi.tampilkan(id: id, judul: judul, isi: isi);
  }
}
