import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../storage/session_store.dart';
import 'local_notifications.dart';
import 'notification_intent.dart';

int _notificationId(String value) => value.hashCode & 0x7fffffff;

/// Handles native FCM without making Firebase configuration a startup hard
/// dependency. Firebase credentials/configuration are supplied by the platform
/// project and are intentionally not stored in this repository.
class PushNotificationService {
  PushNotificationService({required Dio dio, NotifikasiLokal? localNotifications})
      : _dio = dio,
        _localNotifications = localNotifications ?? FlutterLocalNotifikasi();

  final Dio _dio;
  final NotifikasiLokal _localNotifications;
  bool _initialized = false;
  bool _configured = false;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  NotificationIntent? _initialIntent;
  void Function(NotificationIntent intent)? onIntent;

  bool get configured => _configured;

  NotificationIntent? consumeInitialIntent() {
    final intent = _initialIntent;
    _initialIntent = null;
    return intent;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await Firebase.initializeApp();
      _configured = true;
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      _messageSubscription = FirebaseMessaging.onMessage.listen(_onMessage);
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _initialIntent = _parse(initial.data);
    } catch (error) {
      // Missing platform Firebase config is a deployment/configuration state,
      // not a reason to prevent login or render the application.
      debugPrint('FCM disabled: Firebase platform configuration unavailable.');
    }
  }

  Future<void> register(AuthSession session) async {
    await initialize();
    if (!_configured) return;

    final initialIntent = consumeInitialIntent();
    if (initialIntent != null) onIntent?.call(initialIntent);

    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) await _registerToken(token, session);
      await _tokenSubscription?.cancel();
      _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
        (next) => _registerToken(next, session),
      );
    } catch (_) {
      debugPrint('FCM token registration unavailable.');
    }
  }

  Future<void> unregister() async {
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
    if (!_configured) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _dio.delete<dynamic>('/mobile/device-token', data: {'token': token});
      }
    } catch (_) {
      debugPrint('FCM token revoke unavailable.');
    }
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _openedSubscription?.cancel();
  }

  Future<void> _registerToken(String token, AuthSession session) async {
    try {
      await _dio.post<dynamic>('/mobile/device-token', data: {
        'token': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        'app_version': 'mobile',
      });
    } catch (_) {
      debugPrint('FCM token sync failed.');
    }
  }

  void _onMessage(RemoteMessage message) {
    final title = message.notification?.title ?? message.data['title']?.toString();
    final body = message.notification?.body ?? message.data['body']?.toString();
    if (title != null && body != null && title.isNotEmpty && body.isNotEmpty) {
      unawaited(_localNotifications.tampilkan(
        id: _notificationId(message.data['notification_id']?.toString() ?? body),
        judul: title,
        isi: body,
      ));
    }
  }

  void _onOpened(RemoteMessage message) => _parseAndEmit(message.data);

  NotificationIntent? _parse(Map<String, dynamic> data) =>
      parseNotificationIntent(data);

  void _parseAndEmit(Map<String, dynamic> data) {
    final intent = _parse(data);
    if (intent != null) onIntent?.call(intent);
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Platform configuration is validated again by the foreground process.
  }
}
