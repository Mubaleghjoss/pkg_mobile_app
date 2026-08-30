import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';

void main() {
  runApp(const ProviderScope(child: PkgApp()));
}

class PkgApp extends ConsumerWidget {
  const PkgApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'PKGenerus',
      debugShowCheckedModeBanner: false,
      theme: PkgTheme.light(),
      darkTheme: PkgTheme.dark(),
      routerConfig: router,
    );
  }
}
