import 'package:flutter_test/flutter_test.dart';
import 'package:pkgenerus_app/core/notifications/notification_intent.dart';

void main() {
  group('parseNotificationIntent', () {
    test('menerima ketiga route yang diizinkan', () {
      expect(
        parseNotificationIntent(const {'route': '/tugas'}),
        NotificationIntent.tugas,
      );
      expect(
        parseNotificationIntent(const {'route': '/kalender'}),
        NotificationIntent.kalender,
      );
      expect(
        parseNotificationIntent(const {'route': '/chat'}),
        NotificationIntent.chat,
      );
    });

    test('memetakan hasil ke route aplikasi yang tepat', () {
      expect(notificationRouteFor(NotificationIntent.tugas), '/tugas');
      expect(notificationRouteFor(NotificationIntent.kalender), '/kalender');
      expect(notificationRouteFor(NotificationIntent.chat), '/chat');
    });

    test('menerima nama intent eksplisit dan key yang didukung', () {
      expect(
        parseNotificationIntent(const {'intent': 'tugas'}),
        NotificationIntent.tugas,
      );
      expect(
        parseNotificationIntent(const {'path': '/kalender'}),
        NotificationIntent.kalender,
      );
      expect(
        parseNotificationIntent(const {'type': 'chat'}),
        NotificationIntent.chat,
      );
    });

    test('menerima data nested dan payload JSON/string', () {
      expect(
        parseNotificationIntent(const {
          'data': {'route': '/chat'},
        }),
        NotificationIntent.chat,
      );
      expect(
        parseNotificationIntent('{"data":{"route":"/tugas"}}'),
        NotificationIntent.tugas,
      );
      expect(parseNotificationIntent('/kalender'), NotificationIntent.kalender);
    });

    test('menolak payload kosong, hilang, atau bertipe salah', () {
      for (final payload in <Object?>[
        null,
        '',
        const {},
        const {'title': 'Halo'},
        const {'route': 123},
        const {'data': 'bukan object'},
        const [],
        '{invalid json}',
      ]) {
        expect(parseNotificationIntent(payload), isNull, reason: '$payload');
      }
    });

    test('menolak URL eksternal, scheme, dan route arbitrary', () {
      for (final value in [
        'https://example.com/tugas',
        'http://example.com/chat',
        'pkgenerus://tugas',
        '//example.com/tugas',
        '/login',
        '/profil',
        '/tugas/riwayat',
      ]) {
        expect(
          parseNotificationIntent({'route': value}),
          isNull,
          reason: value,
        );
      }
    });

    test('menolak query, fragment, slash tambahan, case, dan spasi', () {
      for (final value in [
        '/tugas?id=1',
        '/kalender#hari-ini',
        '/chat/',
        '/Tugas',
        ' /tugas',
        '/chat ',
      ]) {
        expect(
          parseNotificationIntent({'route': value}),
          isNull,
          reason: value,
        );
      }
    });

    test('menolak field navigasi invalid atau saling bertentangan', () {
      expect(
        parseNotificationIntent(const {'route': '/tugas', 'intent': 'chat'}),
        isNull,
      );
      expect(
        parseNotificationIntent(const {
          'route': '/tugas',
          'data': {'route': '/kalender'},
        }),
        isNull,
      );
      expect(
        parseNotificationIntent(const {'route': '/tugas', 'path': '/login'}),
        isNull,
      );
    });

    test('menerima field navigasi berulang jika hasilnya sama', () {
      expect(
        parseNotificationIntent(const {
          'route': '/tugas',
          'intent': 'tugas',
          'data': {'path': '/tugas'},
        }),
        NotificationIntent.tugas,
      );
    });
  });
}
