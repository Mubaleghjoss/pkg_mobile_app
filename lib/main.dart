import 'dart:async';

import 'package:flutter/material.dart';

import 'core/notifications/notification_intent.dart';
import 'app/providers.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'app/theme_controller.dart';

Future<void> main() async {
  // WAJIB sebelum runApp: seluruh layar (Verifikasi, Materi, Quran, Tugas)
  // memformat tanggal dengan `DateFormat(..., 'id')`. Tanpa pemanggilan ini
  // `intl` melempar LocaleDataException dan widget-nya gagal build
  // (terbukti di emulator: layar Verifikasi jadi merah).
  initializeDateFormatting('id');
  Intl.defaultLocale = 'id';

  runApp(const ProviderScope(child: PkgApp()));
}

class PkgApp extends ConsumerStatefulWidget {
  const PkgApp({super.key});

  @override
  ConsumerState<PkgApp> createState() => _PkgAppState();
}

class _PkgAppState extends ConsumerState<PkgApp> {
  @override
  void initState() {
    super.initState();
    final push = ref.read(pushNotificationServiceProvider);
    push.onIntent = (intent) {
      if (!mounted) return;
      ref.read(routerProvider).go(notificationRouteFor(intent));
    };
    unawaited(push.initialize());
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

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
