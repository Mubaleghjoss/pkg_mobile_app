import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/calendar/presentation/calendar_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/game/presentation/arcade_screen.dart';
import '../features/game/presentation/game_screen.dart';
import '../features/gamifikasi/presentation/badge_screen.dart';
import '../features/gamifikasi/presentation/poin_screen.dart';
import '../features/karakter/presentation/karakter_reader_screen.dart';
import '../features/karakter/presentation/karakter_screen.dart';
import '../features/kelas/presentation/kelas_screen.dart';
import '../features/materi/presentation/materi_detail_screen.dart';
import '../features/materi/presentation/materi_screen.dart';
import '../features/ortu/presentation/ortu_monitoring_screen.dart';
import '../features/presensi/presentation/presensi_form_screen.dart';
import '../features/presensi/presentation/presensi_screen.dart';
import '../features/presensi/presentation/presensi_statistik_screen.dart';
import '../features/presensi/presentation/scan_qr_screen.dart';
import '../features/profil/presentation/change_password_screen.dart';
import '../features/profil/presentation/profil_screen.dart';
import '../features/quran/presentation/quran_barcode_screen.dart';
import '../features/quran/presentation/quran_form_screen.dart';
import '../features/quran/presentation/quran_screen.dart';
import '../features/siswa/presentation/siswa_detail_screen.dart';
import '../features/siswa/presentation/siswa_form_screen.dart';
import '../features/siswa/presentation/siswa_qr_screen.dart';
import '../features/server_features/presentation/server_feature_detail_screen.dart';
import '../features/server_features/presentation/server_features_screen.dart';
import '../features/siswa/presentation/siswa_screen.dart';
import '../features/tugas/presentation/tugas_riwayat_screen.dart';
import '../features/tugas/presentation/tugas_screen.dart';
import '../features/verifikasi/presentation/verifikasi_screen.dart';
import '../core/api_config.dart';
import '../core/storage/session_store.dart';
import '../shared/widgets/animations.dart';
import '../shared/widgets/floating_menu.dart';
import '../shared/widgets/pkg_logo.dart';
import '../shared/widgets/web_page_screen.dart';

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
          position: Tween<Offset>(
            begin: begin,
            end: Offset.zero,
          ).animate(curved),
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
}) => _slidePage<T>(child: child, state: state, begin: const Offset(0, 0.10));

/// Router aplikasi.
///
/// Redirect memakai [AuthState]: selama status `unknown` tampilkan splash,
/// `unauthenticated` paksa ke /login, `authenticated` blokir akses /login.
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ValueNotifier<AuthState>(ref.read(authControllerProvider));
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
      // Dasbor '/' memanggil /dashboard/stats + /dashboard/recent-activities
      // yang lingkupnya seluruh sekolah (total siswa, nama siswa lain), dan
      // backend menolak token siswa/ortu di sana dengan 403 STAFF_ONLY.
      // Jadi kedua aktor itu diarahkan ke beranda masing-masing.
      final actor = auth.session?.actor ?? AuthActor.staff;
      final berandaAktor = switch (actor) {
        AuthActor.ortu => '/monitoring',
        AuthActor.siswa => '/tugas',
        AuthActor.staff => '/',
      };
      if (loc == '/login' || loc == '/splash') return berandaAktor;
      if (loc == '/' && actor != AuthActor.staff) return berandaAktor;
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
      GoRoute(
        path: '/fitur-server',
        pageBuilder: (_, state) =>
            _slidePage(child: const ServerFeaturesScreen(), state: state),
      ),
      // Detail satu fitur server: daftar aksi yang benar-benar membuka fitur
      // (layar aplikasi, halaman web ber-sesi, atau halaman web publik).
      GoRoute(
        path: '/fitur-server/:kode',
        pageBuilder: (_, state) => _slidePage(
          state: state,
          child: ServerFeatureDetailScreen(
            kode: state.pathParameters['kode'] ?? '',
          ),
        ),
      ),
      // Game Petualangan 29 Karakter. Server hanya menyediakan halaman web
      // (`/game-29-karakter`, publik tanpa login) — tidak ada endpoint API v1
      // untuk RPG — jadi dibuka sebagai WebView in-app.
      GoRoute(
        path: '/petualangan',
        pageBuilder: (_, state) => _slidePage(
          state: state,
          child: WebPageScreen(
            title: 'Petualangan',
            subtitle: '/game-29-karakter',
            url: ApiConfig.webUrl('/game-29-karakter'),
          ),
        ),
      ),
      // Pembaca materi 29 karakter (halaman penuh, di luar shell).
      GoRoute(
        path: '/karakter/:slug',
        pageBuilder: (_, state) => _slidePage(
          state: state,
          child: KarakterReaderScreen(slug: state.pathParameters['slug'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/materi/:id',
        pageBuilder: (_, state) => _slidePage(
          state: state,
          child: MateriDetailScreen(id: _idOf(state)),
        ),
      ),
      GoRoute(
        path: '/quran/baru',
        pageBuilder: (_, state) =>
            _sheetPage(child: const QuranFormScreen(), state: state),
      ),
      GoRoute(
        path: '/quran/tracer',
        pageBuilder: (_, state) =>
            _sheetPage(child: const QuranBarcodeScreen(), state: state),
      ),
      // Gamifikasi & game: Scaffold + AppBar sendiri, jadi di luar ShellRoute.
      GoRoute(
        path: '/poin',
        pageBuilder: (_, state) =>
            _slidePage(child: const PoinScreen(), state: state),
      ),
      GoRoute(
        path: '/game',
        pageBuilder: (_, state) =>
            _slidePage(child: const GameScreen(), state: state),
      ),
      GoRoute(
        path: '/arcade',
        pageBuilder: (_, state) =>
            _slidePage(child: const ArcadeScreen(), state: state),
      ),
      GoRoute(
        path: '/badge',
        pageBuilder: (_, state) =>
            _slidePage(child: const BadgeScreen(), state: state),
      ),
      // Riwayat tugas PKG (siswa & ortu) — Scaffold sendiri, di luar shell.
      GoRoute(
        path: '/tugas/riwayat',
        pageBuilder: (_, state) =>
            _slidePage(child: const TugasRiwayatScreen(), state: state),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            HomeShell(state: state, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
          GoRoute(path: '/siswa', builder: (_, _) => const SiswaScreen()),
          GoRoute(path: '/presensi', builder: (_, _) => const PresensiScreen()),
          GoRoute(path: '/kelas', builder: (_, _) => const KelasScreen()),
          GoRoute(path: '/karakter', builder: (_, _) => const KarakterScreen()),
          GoRoute(path: '/materi', builder: (_, _) => const MateriScreen()),
          GoRoute(path: '/kalender', builder: (_, _) => const CalendarScreen()),
          GoRoute(path: '/tugas', builder: (_, _) => const TugasScreen()),
          GoRoute(path: '/quran', builder: (_, _) => const QuranScreen()),
          // Pamong/admin: antrean verifikasi tugas PKG siswa binaan.
          GoRoute(
            path: '/verifikasi',
            builder: (_, _) => const VerifikasiScreen(),
          ),
          // Orang tua: dasbor monitoring anak (read-only).
          GoRoute(
            path: '/monitoring',
            builder: (_, _) => const OrtuMonitoringScreen(),
          ),
          // Gamifikasi & game dipasang di luar ShellRoute karena keduanya
          // membawa Scaffold + AppBar sendiri (PoinScreen punya TabBar).
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
              scale: Tween<double>(
                begin: 0.92,
                end: 1.04,
              ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
              child: const PkgLogo(size: 132),
            ),
            const SizedBox(height: 28),
            Text(
              'PKGenerus',
              style: Theme.of(context).textTheme.titleLarge
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
///
/// Bilah bawah sengaja dibatasi 3 tab utama + satu slot "Lainnya". Slot itu
/// tidak berpindah halaman, tetapi membuka panel mengambang
/// ([showFloatingMenu]) berisi menu sisanya, sehingga navigasi tetap ringkas
/// tanpa menyembunyikan fitur.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.state, required this.child});

  final GoRouterState state;
  final Widget child;

  static const _dashboard = (
    path: '/',
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
  );

  /// Aksi utama berdasarkan rute aktual, termasuk rute dari menu Lainnya.
  static String? fabActionPathForLocation(String location) =>
      switch (location) {
        '/presensi' => '/scan-qr',
        '/siswa' => '/siswa/baru',
        _ => null,
      };

  /// Orang tua hanya dapat memantau progres Quran anaknya.
  static bool canScanQuranBarcode(AuthActor actor) =>
      actor == AuthActor.staff || actor == AuthActor.siswa;

  /// Tab dibedakan per aktor supaya tiap peran hanya melihat menu yang
  /// endpoint-nya memang boleh dia panggil:
  /// - siswa  : tugas PKG, materi, karakter, tracer Quran
  /// - ortu   : monitoring (read-only) + materi/karakter
  /// - staff  : data sekolah + antrean verifikasi tugas + materi
  ///
  /// Materi sengaja jadi tab utama untuk ketiga aktor (dulu terkubur di panel
  /// "Lainnya" untuk siswa & staff) karena bahan ajar/bacaan adalah menu yang
  /// paling sering dibuka.
  ///
  /// Daftar staff sengaja tidak digerbangi permission di sini; layar di
  /// dalamnya sudah menampilkan pesan galat backend bila aksesnya ditolak.
  static List<({String path, String label, IconData icon})> tabsFor(
    AuthSession? session,
  ) {
    switch (session?.actor ?? AuthActor.staff) {
      case AuthActor.siswa:
        // Tanpa _dashboard: endpoint /dashboard/* khusus staf (403 STAFF_ONLY).
        return const [
          (path: '/tugas', label: 'Tugas', icon: Icons.checklist_outlined),
          (path: '/materi', label: 'Materi', icon: Icons.folder_open_outlined),
          (
            path: '/karakter',
            label: 'Karakter',
            icon: Icons.auto_stories_outlined,
          ),
          (path: '/quran', label: 'Quran', icon: Icons.menu_book_outlined),
        ];
      case AuthActor.ortu:
        return const [
          (
            path: '/monitoring',
            label: 'Monitoring',
            icon: Icons.insights_outlined,
          ),
          (
            path: '/karakter',
            label: 'Karakter',
            icon: Icons.auto_stories_outlined,
          ),
          (path: '/materi', label: 'Materi', icon: Icons.folder_open_outlined),
        ];
      case AuthActor.staff:
        return const [
          _dashboard,
          (
            path: '/verifikasi',
            label: 'Verifikasi',
            icon: Icons.verified_outlined,
          ),
          (path: '/siswa', label: 'Siswa', icon: Icons.groups_outlined),
          (path: '/materi', label: 'Materi', icon: Icons.folder_open_outlined),
        ];
    }
  }

  /// Menu tambahan di balik slot "Lainnya".
  ///
  /// `inShell: true` berarti rutenya anak [ShellRoute] sehingga dibuka dengan
  /// `context.go` dan bilah navigasi tetap terlihat; sisanya halaman penuh
  /// (`context.push`) yang membawa Scaffold sendiri.
  static List<
    ({
      String path,
      String label,
      IconData icon,
      String? deskripsi,
      bool inShell,
    })
  >
  extrasFor(AuthSession? session) {
    switch (session?.actor ?? AuthActor.staff) {
      case AuthActor.siswa:
        return const [
          (
            path: '/kalender',
            label: 'Kalender',
            icon: Icons.calendar_month_outlined,
            deskripsi: 'Agenda & kegiatan',
            inShell: true,
          ),
          (
            path: '/petualangan',
            label: 'Petualangan',
            icon: Icons.explore_outlined,
            deskripsi: 'Game 29 karakter',
            inShell: false,
          ),
          (
            path: '/tugas/riwayat',
            label: 'Riwayat',
            icon: Icons.history_outlined,
            deskripsi: 'Pengerjaan lampau',
            inShell: false,
          ),
          (
            path: '/poin',
            label: 'Poin',
            icon: Icons.leaderboard_outlined,
            deskripsi: 'Level & peringkat',
            inShell: false,
          ),
          (
            path: '/badge',
            label: 'Badge',
            icon: Icons.emoji_events_outlined,
            deskripsi: 'Koleksi lencana',
            inShell: false,
          ),
          (
            path: '/game',
            label: 'Game',
            icon: Icons.sports_esports_outlined,
            deskripsi: 'Tebak & rangkai',
            inShell: false,
          ),
          (
            path: '/arcade',
            label: 'Arcade',
            icon: Icons.timer_outlined,
            deskripsi: 'Rangkai bertempo',
            inShell: false,
          ),
          (
            path: '/fitur-server',
            label: 'Fitur server',
            icon: Icons.integration_instructions_outlined,
            deskripsi: '10 fitur tambahan',
            inShell: false,
          ),
          (
            path: '/profil',
            label: 'Profil',
            icon: Icons.account_circle_outlined,
            deskripsi: 'Akun saya',
            inShell: false,
          ),
        ];
      case AuthActor.ortu:
        return const [
          (
            path: '/kalender',
            label: 'Kalender',
            icon: Icons.calendar_month_outlined,
            deskripsi: 'Agenda anak',
            inShell: true,
          ),
          (
            path: '/tugas',
            label: 'Tugas anak',
            icon: Icons.checklist_outlined,
            deskripsi: 'Hanya memantau',
            inShell: true,
          ),
          (
            path: '/tugas/riwayat',
            label: 'Riwayat tugas',
            icon: Icons.history_outlined,
            deskripsi: 'Pengerjaan anak',
            inShell: false,
          ),
          (
            path: '/poin',
            label: 'Poin',
            icon: Icons.leaderboard_outlined,
            deskripsi: 'Level & peringkat',
            inShell: false,
          ),
          (
            path: '/badge',
            label: 'Badge',
            icon: Icons.emoji_events_outlined,
            deskripsi: 'Koleksi lencana',
            inShell: false,
          ),
          (
            path: '/game',
            label: 'Papan skor',
            icon: Icons.sports_esports_outlined,
            deskripsi: 'Hasil game anak',
            inShell: false,
          ),
          (
            path: '/petualangan',
            label: 'Petualangan',
            icon: Icons.explore_outlined,
            deskripsi: 'Game 29 karakter',
            inShell: false,
          ),
          (
            path: '/fitur-server',
            label: 'Fitur server',
            icon: Icons.integration_instructions_outlined,
            deskripsi: '10 fitur tambahan',
            inShell: false,
          ),
          (
            path: '/profil',
            label: 'Profil',
            icon: Icons.account_circle_outlined,
            deskripsi: 'Akun saya',
            inShell: false,
          ),
        ];
      case AuthActor.staff:
        return const [
          (
            path: '/quran/tracer',
            label: 'Tracer Quran',
            icon: Icons.qr_code_scanner_outlined,
            deskripsi: 'Scan lembar binaan',
            inShell: false,
          ),
          (
            path: '/kalender',
            label: 'Kalender',
            icon: Icons.calendar_month_outlined,
            deskripsi: 'Agenda pembinaan',
            inShell: true,
          ),
          (
            path: '/presensi',
            label: 'Presensi',
            icon: Icons.fact_check_outlined,
            deskripsi: 'Catatan harian',
            inShell: true,
          ),
          (
            path: '/kelas',
            label: 'Kelas',
            icon: Icons.class_outlined,
            deskripsi: 'Data kelas',
            inShell: true,
          ),
          (
            path: '/karakter',
            label: 'Karakter',
            icon: Icons.auto_stories_outlined,
            deskripsi: '29 karakter',
            inShell: true,
          ),
          (
            path: '/petualangan',
            label: 'Petualangan',
            icon: Icons.explore_outlined,
            deskripsi: 'Game 29 karakter',
            inShell: false,
          ),
          (
            path: '/presensi/statistik',
            label: 'Statistik',
            icon: Icons.query_stats_outlined,
            deskripsi: 'Rekap kehadiran',
            inShell: false,
          ),
          (
            path: '/fitur-server',
            label: 'Fitur server',
            icon: Icons.integration_instructions_outlined,
            deskripsi: '10 fitur tambahan',
            inShell: false,
          ),
          (
            path: '/profil',
            label: 'Profil',
            icon: Icons.account_circle_outlined,
            deskripsi: 'Akun saya',
            inShell: false,
          ),
        ];
    }
  }

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _previousIndex = 0;

  /// Daftar tab aktif mengikuti aktor yang sedang login.
  List<({String path, String label, IconData icon})> get _tabs =>
      HomeShell.tabsFor(ref.read(authControllerProvider).session);

  List<
    ({
      String path,
      String label,
      IconData icon,
      String? deskripsi,
      bool inShell,
    })
  >
  get _extras => HomeShell.extrasFor(ref.read(authControllerProvider).session);

  /// Indeks tab utama; -1 bila lokasi sekarang berasal dari menu "Lainnya".
  int get _tabIndex =>
      _tabs.indexWhere((t) => t.path == widget.state.matchedLocation);

  int get _index {
    final i = _tabIndex;
    return i < 0 ? 0 : i;
  }

  /// Slot yang disorot di bilah navigasi. Rute dari menu "Lainnya" menyorot
  /// slot "Lainnya" itu sendiri, bukan tab pertama.
  int get _selectedSlot => _tabIndex < 0 ? _tabs.length : _tabIndex;

  /// Label untuk subtitle AppBar, termasuk saat berada di rute "Lainnya".
  String get _labelAktif {
    final i = _tabIndex;
    if (i >= 0) return _tabs[i].label;
    final extra = _extras
        .where((e) => e.path == widget.state.matchedLocation)
        .firstOrNull;
    return extra?.label ?? _tabs[_index].label;
  }

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = _tabs.indexWhere(
      (t) => t.path == oldWidget.state.matchedLocation,
    );
    if (old >= 0 && old != _index) _previousIndex = old;
  }

  void _goTab(int i) {
    if (i == _index && _tabIndex >= 0) return;
    _previousIndex = _index;
    context.go(_tabs[i].path);
  }

  /// Slot terakhir bukan halaman: ia membuka panel menu mengambang.
  void _onSlotSelected(int slot) {
    if (slot >= _tabs.length) {
      _bukaMenuLainnya();
      return;
    }
    _goTab(slot);
  }

  Future<void> _bukaMenuLainnya() async {
    final lokasi = widget.state.matchedLocation;
    await showFloatingMenu(
      context,
      items: [
        for (final e in _extras)
          FloatingMenuItem(
            label: e.label,
            icon: e.icon,
            deskripsi: e.deskripsi,
            aktif: e.path == lokasi,
            onTap: () {
              if (e.inShell) {
                context.go(e.path);
              } else {
                context.push(e.path);
              }
            },
          ),
      ],
    );
  }

  void _onHorizontalDrag(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v.abs() < 220) return;
    // Geser ke kiri (velocity negatif) = maju ke tab berikutnya.
    final next = v < 0 ? _index + 1 : _index - 1;
    if (next < 0 || next >= _tabs.length) return;
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
              position: Tween<Offset>(begin: begin, end: Offset.zero).animate(
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
        title: PkgWordmark(subtitle: _labelAktif),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: SafeArea(child: body),
      floatingActionButton: _fabFor(auth),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _selectedSlot,
              onDestinationSelected: _onSlotSelected,
              destinations: [
                ..._tabs.map(
                  (t) =>
                      NavigationDestination(icon: Icon(t.icon), label: t.label),
                ),
                // Slot terakhir: pembuka panel menu mengambang.
                const NavigationDestination(
                  icon: Icon(Icons.apps_outlined),
                  selectedIcon: Icon(Icons.apps),
                  label: 'Lainnya',
                ),
              ],
            ),
    );

    if (!wide) return scaffold;

    return Row(
      children: [
        NavigationRail(
          selectedIndex: _selectedSlot,
          onDestinationSelected: _onSlotSelected,
          leading: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: PkgLogo(size: 36),
          ),
          labelType: NavigationRailLabelType.all,
          destinations: [
            ..._tabs.map(
              (t) => NavigationRailDestination(
                icon: Icon(t.icon),
                label: Text(t.label),
              ),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.apps_outlined),
              selectedIcon: Icon(Icons.apps),
              label: Text('Lainnya'),
            ),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: scaffold),
      ],
    );
  }

  /// FAB kontekstual berdasarkan rute aktual. Aksi tulis digerbangi
  /// permission dari `/me`.
  Widget? _fabFor(AuthState auth) {
    final action = HomeShell.fabActionPathForLocation(
      widget.state.matchedLocation,
    );
    if (action == '/scan-qr') {
      // Scan QR: endpoint publik di backend, jadi tidak digerbangi permission.
      return FloatingActionButton.extended(
        heroTag: 'fab-scan',
        onPressed: () => context.push(action!),
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan QR'),
      );
    }
    if (action == '/siswa/baru' && auth.can('manage_students')) {
      return FloatingActionButton.extended(
        heroTag: 'fab-siswa',
        onPressed: () => context.push(action!),
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
