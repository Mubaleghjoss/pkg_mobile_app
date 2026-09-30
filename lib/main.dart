import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app/providers.dart';
import 'features/auth/application/auth_controller.dart';
import 'core/notifications/fcm_push_service.dart';
import 'core/notifications/local_notifications.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'app/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // WAJIB sebelum runApp: seluruh layar (Verifikasi, Materi, Quran, Tugas)
  // memformat tanggal dengan `DateFormat(..., 'id')`. Tanpa pemanggilan ini
  // `intl` melempar LocaleDataException dan widget-nya gagal build
  // (terbukti di emulator: layar Verifikasi jadi merah).
  initializeDateFormatting('id');
  Intl.defaultLocale = 'id';

  runApp(const ProviderScope(child: PkgApp()));
}

class PkgApp extends ConsumerWidget {
  const PkgApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final notifikasi = ref.read(notifikasiLokalProvider);
    notifikasi.init();
    notifikasi.setRouteHandler((route) {
      if (route.startsWith('/')) router.go(route);
    });
    final fcm = ref.read(fcmPushServiceProvider);
    fcm.setRouteHandler((route) {
      if (route.startsWith('/')) router.go(route);
    });
    final auth = ref.watch(authControllerProvider);
    if (auth.isAuthenticated) {
      fcm.start();
    }

    return MaterialApp.router(
      title: 'PKG Panunggangan',
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      theme: PkgTheme.light(),
      darkTheme: PkgTheme.dark(),
      locale: const Locale('id'),
      supportedLocales: const [Locale('id'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
