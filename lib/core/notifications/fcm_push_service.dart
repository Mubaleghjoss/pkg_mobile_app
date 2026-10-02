import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class FcmPushService {
  FcmPushService({required Dio dio, required NotifikasiLokal notifications})
      : _dio = dio,
        _notifications = notifications;

  final Dio _dio;
  final NotifikasiLokal _notifications;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  void Function(String route)? _routeHandler;
  bool _started = false;
  bool _authenticated = false;

  void setRouteHandler(void Function(String route) handler) {
    _routeHandler = handler;
  }

  Future<void> start() async {
    if (_started || kIsWeb) return;
    _started = true;
    _authenticated = true;
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    await messaging.setAutoInitEnabled(true);

    _foregroundSubscription = FirebaseMessaging.onMessage.listen(_onMessage);
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);
    final initial = await messaging.getInitialMessage();
    if (initial != null) _onOpened(initial);
    await _registerWithRetry();
    _tokenRefreshSubscription = messaging.onTokenRefresh.listen((_) => _registerWithRetry());
  }

  Future<void> _registerWithRetry() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      if (await registerCurrentToken()) return;
      await Future<void>.delayed(Duration(seconds: attempt + 1));
    }
  }

  Future<void> stop() async {
    _authenticated = false;
    try {
      await revokeCurrentToken();
    } catch (error) {
      debugPrint('FCM token revoke failed: ${error.runtimeType}.');
    }
    await _openedSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    _openedSubscription = null;
    _foregroundSubscription = null;
    _tokenRefreshSubscription = null;
    _started = false;
  }

  Future<bool> registerCurrentToken() async {
    if (kIsWeb) return false;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('FCM registration skipped: Firebase returned no token.');
        return false;
      }
      final response = await _dio.post<dynamic>('/mobile/device-token', data: {
        'token': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        'app_version': null,
      });
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        debugPrint('FCM registration rejected by API: HTTP $status.');
        return false;
      }
      debugPrint('FCM device token registered successfully.');
      return true;
    } catch (error) {
      debugPrint('FCM registration failed: ${error.runtimeType}.');
      return false;
    }
  }

  Future<void> revokeCurrentToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    await _dio.delete<dynamic>('/mobile/device-token', data: {'token': token});
  }

  void _onMessage(RemoteMessage message) {
    if (!_authenticated) return;
    final notification = message.notification;
    if (notification == null) return;
    final route = _routeOf(message);
    unawaited(tampilkanDenganRute(
      notifikasi: _notifications,
      id: message.hashCode,
      judul: notification.title ?? 'PKGenerus',
      isi: notification.body ?? '',
      route: route,
    ));
  }

  void _onOpened(RemoteMessage message) {
    final route = _routeOf(message);
    if (route.startsWith('/')) _routeHandler?.call(route);
  }

  String _routeOf(RemoteMessage message) {
    final raw = message.data['route'];
    // Notification routes are semantic app routes, never arbitrary URLs.
    const allowed = <String>{
      '/chat',
      '/tugas',
      '/presensi',
      '/kalender',
      '/quran',
      '/poin',
      '/badge',
      '/verifikasi',
      '/',
    };
    if (raw is String && allowed.contains(raw)) return raw;
    return '/';
  }

  Future<void> dispose() async {
    await _openedSubscription?.cancel();
    await _foregroundSubscription?.cancel();
  }
}
