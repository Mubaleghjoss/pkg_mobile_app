import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app/router.dart';
import 'app/theme.dart';

Future<void> main() async {
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

    return MaterialApp.router(
      title: 'PKG Panunggangan',
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
