import 'dart:convert';

/// Navigation intents accepted from notification payloads.
///
/// Keep this list deliberately small: notification data is untrusted input and
/// must not be able to navigate to arbitrary application routes.
enum NotificationIntent { tugas, kalender, chat }

/// Maps a parsed notification intent to its allowlisted application route.
String notificationRouteFor(NotificationIntent intent) => switch (intent) {
  NotificationIntent.tugas => '/tugas',
  NotificationIntent.kalender => '/kalender',
  NotificationIntent.chat => '/chat',
};

/// Parses notification navigation data without depending on Flutter or a push
/// provider.
///
/// Accepted forms are an allowlisted route/intent string, a JSON object, or a
/// map containing `route`, `path`, `intent`, or `type`. A common nested `data`
/// object is also accepted. Query strings, fragments, absolute URLs, unknown
/// routes, and conflicting navigation fields are rejected.
NotificationIntent? parseNotificationIntent(Object? payload) {
  if (payload is String) {
    // Deliberately do not trim or normalize. Only canonical values are safe;
    // accepting whitespace/case/URI variations would silently broaden the
    // allowlist and could behave differently when handed to the router.
    if (payload.isEmpty) return null;

    if (payload.startsWith('{')) {
      try {
        return parseNotificationIntent(jsonDecode(payload));
      } on FormatException {
        return null;
      }
    }
    return _intentFromValue(payload);
  }

  if (payload is! Map) return null;

  final candidates = <NotificationIntent>{};
  for (final key in const ['route', 'path', 'intent', 'type']) {
    final value = payload[key];
    if (value == null) continue;
    if (value is! String) return null;
    final intent = _intentFromValue(value);
    if (intent == null) return null;
    candidates.add(intent);
  }

  final data = payload['data'];
  if (data != null) {
    if (data is! Map) return null;
    final nested = parseNotificationIntent(data);
    if (nested == null) return null;
    candidates.add(nested);
  }

  return candidates.length == 1 ? candidates.single : null;
}

NotificationIntent? _intentFromValue(String value) => switch (value) {
  '/tugas' || 'tugas' => NotificationIntent.tugas,
  '/kalender' || 'kalender' => NotificationIntent.kalender,
  '/chat' || 'chat' => NotificationIntent.chat,
  _ => null,
};
