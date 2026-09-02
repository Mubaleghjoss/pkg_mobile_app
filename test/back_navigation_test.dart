import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pkgenerus_app/app/router.dart';

void main() {
  late GoRouter router;

  Future<void> pasangAplikasi(
    WidgetTester tester, {
    required String lokasiAwal,
  }) async {
    router = GoRouter(
      initialLocation: lokasiAwal,
      routes: [
        ShellRoute(
          builder: (_, state, child) => HomeShell(state: state, child: child),
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Center(child: Text('tab pertama')),
            ),
            GoRoute(
              path: '/kalender',
              builder: (_, _) => const Center(child: Text('kalender')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('back dari rute Lainnya kembali ke tab pertama shell', (
    tester,
  ) async {
    await pasangAplikasi(tester, lokasiAwal: '/kalender');

    expect(router.state.uri.path, '/kalender');
    expect(tester.widget<PopScope<Object?>>(_popScopeShell).canPop, isFalse);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/');
    expect(find.text('tab pertama'), findsOneWidget);
  });

  testWidgets('di tab pertama back diizinkan menutup aplikasi', (tester) async {
    await pasangAplikasi(tester, lokasiAwal: '/');

    expect(tester.widget<PopScope<Object?>>(_popScopeShell).canPop, isTrue);
  });
}

final _popScopeShell = find.byWidgetPredicate(
  (widget) =>
      widget is PopScope<Object?> &&
      (widget.child is Scaffold || widget.child is Row),
  description: 'PopScope milik HomeShell',
);
