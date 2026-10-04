import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pkgenerus_app/core/notifications/push_notification_service.dart';

void main() {
  test('service starts disabled when Firebase platform config is absent', () async {
    final service = PushNotificationService(dio: Dio());

    await service.initialize();

    expect(service.configured, isFalse);
    await service.dispose();
  });
}
