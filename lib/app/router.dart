import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/kelas/presentation/kelas_detail_screen.dart';
import '../features/kelas/presentation/kelas_screen.dart';
import '../features/presensi/presentation/presensi_form_screen.dart';
import '../features/presensi/presentation/presensi_screen.dart';
import '../features/presensi/presentation/presensi_statistik_screen.dart';
import '../features/presensi/presentation/scan_qr_screen.dart';
import '../features/profil/presentation/change_password_screen.dart';
import '../features/profil/presentation/profil_screen.dart';
import '../features/siswa/presentation/siswa_detail_screen.dart';
import '../features/siswa/presentation/siswa_form_screen.dart';
import '../features/siswa/presentation/siswa_qr_screen.dart';
import '../features/siswa/presentation/siswa_screen.dart';
import '../shared/widgets/animations.dart';
import '../shared/widgets/pkg_logo.dart';

/// Halaman dengan transisi geser+fade dari kanan (Material 3 style).
///
/// Dipakai untuk semua rute penuh di luar shell sehingga push/pop terasa
/// beranimasi, tidak "jump cut".
CustomTransitionPage<T> _slidePage<T>({
  required Widget child,
  required GoRouterState state,
  Offset begin = const Offset(0.06, 0),
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    transitionDuration: PkgMotion.page,
    reverseTransitionDuration: PkgMotion.page,
    child: child,
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: PkgMotion.curve,
        reverseCurve: PkgMotion.reverseCurve,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position:
              Tween<Offset>(begin: begin, end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Halaman modal: masuk dari bawah. Untuk form & scanner.
CustomTransitionPage<T> _sheetPage<T>({
  required Widget child,
  required GoRouterState state,
}) =>
    _slidePage<T>(child: child, state: state, begin: const Offset(0, 0.10));

/// Router aplikasi.
///
/// Redirect memakai [AuthState]: selama status `unknown` tampilkan splash,
/// `unauthenticated` paksa ke /login, `authenticated` blokir akses /login.
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ValueNotifier<AuthState>(
    ref.read(authControllerProvider),
  );
  ref.listen<AuthState>(
    authControllerProvider,
    (_, next) => notifier.value = next,
  );
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final auth = notifier.value;
      final loc = state.matchedLocation;

      if (auth.status == AuthStatus.unknown) {
        return loc == '/splash' ? null : '/splash';
      }
      if (!auth.isAuthenticated) {
        return loc == '/login' ? null : '/login';
      }
      if (loc == '/login' || loc == '/splash') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const PkgSplashScreen()),
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) =>
            _slidePage(child: const LoginScreen(), state: state),
      ),
      // Di luar ShellRoute: layar ini punya Scaffold + AppBar sendiri sehingga
      // tampil sebagai halaman penuh dengan tombol back, bukan tab.
      GoRoute(
        path: '/siswa/baru',
        pageBuilder: (_, state) =>
            _sheetPage(child: const SiswaFormScreen(), state: state),
      ),
      GoRoute(
        path: '/siswa/:id',
        pageBuilder: (_, state) => _slidePage(
          state: state,
          child: SiswaDetailScreen(id: _idOf(state)),
        ),
      ),
      GoRoute(
        path: '/siswa/:id/edit',
        pageBuilder: (_, state) => _sheetPage(
          state: state,
          child: SiswaFormScreen(id: _idOf(state)),
        ),
      ),
      GoRoute(
        path: '/siswa/:id/qr',
        pageBuilder: (_, state) => _sheetPage(
          state: state,
          child: SiswaQrScreen(id: _idOf(state)),
        ),
      ),
      GoRoute(
        path: '/kelas/:id',
        pageBuilder: (_, state) => _slidePage(
          state: state,
          child: KelasDetailScreen(id: _idOf(state)),
        ),
      ),
      GoRoute(
        path: '/presensi/baru',
        pageBuilder: (_, state) =>
            _sheetPage(child: const PresensiFormScreen(), state: state),
      ),
      GoRoute(
        path: '/presensi/statistik',
        pageBuilder: (_, state) =>
            _slidePage(child: const PresensiStatistikScreen(), state: state),
      ),
      GoRoute(
        path: '/presensi/:id/edit',
        pageBuilder: (_, state) => _sheetPage(
          state: state,
          child: PresensiFormScreen(id: _idOf(state)),
        ),
      ),
      GoRoute(
        path: '/scan-qr',
        pageBuilder: (_, state) =>
            _sheetPage(child: const ScanQrScreen(), state: state),
      ),
      GoRoute(
        path: '/profil',
        pageBuilder: (_, state) =>
            _slidePage(child: const ProfilScreen(), state: state),
      ),
      GoRoute(
        path: '/profil/password',
        pageBuilder: (_, state) =>
            _sheetPage(child: const ChangePasswordScreen(), state: state),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            HomeShell(state: state, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
          GoRoute(path: '/siswa', builder: (_, _) => const SiswaScreen()),
          GoRoute(path: '/presensi', builder: (_, _) => const PresensiScreen()),
          GoRoute(path: '/kelas', builder: (_, _) => const KelasScreen()),
        ],
      ),
    ],
  );
});

int _idOf(GoRouterState state) =>
    int.tryParse(state.pathParameters['id'] ?? '') ?? 0;

/// Splash bermerek PKG dengan logo yang membesar + berdenyut halus.
class PkgSplashScreen extends StatefulWidget {
  const PkgSplashScreen({super.key});

  @override
  State<PkgSplashScreen> createState() => _PkgSplashScreenState();
}

class _PkgSplashScreenState extends State<PkgSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1.04).animate(
                CurvedAnimation(parent: _c, curve: Curves.easeInOut),
              ),
              child: const PkgLogo(size: 132),
            ),
            const SizedBox(height: 28),
            Text(
              'PKGenerus',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 120,
              child: LinearProgressIndicator(minHeight: 3),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kerangka navigasi utama: NavigationBar di ponsel, NavigationRail di lebar.
///
/// Isi tab dianimasikan: berpindah tab menggeser konten ke arah yang sesuai,
/// dan usap (swipe) horizontal pada body memindahkan tab seperti PageView.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.state, required this.child});

  final GoRouterState state;
  final Widget child;

  static const tabs = <({String path, String label, IconData icon})>[
    (path: '/', label: 'Dashboard', icon: Icons.dashboard_outlined),
    (path: '/siswa', label: 'Siswa', icon: Icons.groups_outlined),
    (path: '/presensi', label: 'Presensi', icon: Icons.fact_check_outlined),
    (path: '/kelas', label: 'Kelas', icon: Icons.class_outlined),
  ];

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _previousIndex = 0;

  int get _index {
    final i = HomeShell.tabs
        .indexWhere((t) => t.path == widget.state.matchedLocation);
    return i < 0 ? 0 : i;
  }

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = HomeShell.tabs
        .indexWhere((t) => t.path == oldWidget.state.matchedLocation);
    if (old >= 0 && old != _index) _previousIndex = old;
  }

  void _goTab(int i) {
    if (i == _index) return;
    _previousIndex = _index;
    context.go(HomeShell.tabs[i].path);
  }

  void _onHorizontalDrag(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v.abs() < 220) return;
    // Geser ke kiri (velocity negatif) = maju ke tab berikutnya.
    final next = v < 0 ? _index + 1 : _index - 1;
    if (next < 0 || next >= HomeShell.tabs.length) return;
    _goTab(next);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final auth = ref.watch(authControllerProvider);
    final forward = _index >= _previousIndex;

    final body = GestureDetector(
      // Hanya usap horizontal; scroll vertikal daftar tidak terganggu.
      onHorizontalDragEnd: _onHorizontalDrag,
      child: AnimatedSwitcher(
        duration: PkgMotion.tab,
        switchInCurve: PkgMotion.curve,
        switchOutCurve: PkgMotion.reverseCurve,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, ?current],
        ),
        transitionBuilder: (child, animation) {
          final isIncoming = child.key == ValueKey(_index);
          final begin = isIncoming
              ? Offset(forward ? 0.12 : -0.12, 0)
              : Offset(forward ? -0.08 : 0.08, 0);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(begin: begin, end: Offset.zero).animate(
                CurvedAnimation(parent: animation, curve: PkgMotion.curve),
              ),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(key: ValueKey(_index), child: widget.child),
      ),
    );

    final scaffold = Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: PkgWordmark(subtitle: HomeShell.tabs[_index].label),
        actions: [
          IconButton(
            tooltip: 'Profil saya',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push('/profil'),
          ),
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: SafeArea(child: body),
      floatingActionButton: _fabFor(_index, auth),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _goTab,
              destinations: HomeShell.tabs
                  .map((t) => NavigationDestination(
                        icon: Icon(t.icon),
                        label: t.label,
                      ))
                  .toList(growable: false),
            ),
    );

    if (!wide) return scaffold;

    return Row(
      children: [
        NavigationRail(
          selectedIndex: _index,
          onDestinationSelected: _goTab,
          leading: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: PkgLogo(size: 36),
          ),
          labelType: NavigationRailLabelType.all,
          destinations: HomeShell.tabs
              .map((t) => NavigationRailDestination(
                    icon: Icon(t.icon),
                    label: Text(t.label),
                  ))
              .toList(growable: false),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: scaffold),
      ],
    );
  }

  /// FAB kontekstual per tab. Aksi tulis digerbangi permission dari `/me`.
  Widget? _fabFor(int index, AuthState auth) {
    final path = HomeShell.tabs[index].path;
    if (path == '/presensi') {
      // Scan QR: endpoint publik di backend, jadi tidak digerbangi permission.
      return FloatingActionButton.extended(
        heroTag: 'fab-scan',
        onPressed: () => context.push('/scan-qr'),
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan QR'),
      );
    }
    if (path == '/siswa' && auth.can('manage_students')) {
      return FloatingActionButton.extended(
        heroTag: 'fab-siswa',
        onPressed: () => context.push('/siswa/baru'),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Siswa baru'),
      );
    }
    return null;
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Token akses akan dicabut di server.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }
}
