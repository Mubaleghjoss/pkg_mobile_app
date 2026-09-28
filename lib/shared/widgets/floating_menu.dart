import 'package:flutter/material.dart';

import 'animations.dart';

/// Satu entri pada menu "Lainnya".
class FloatingMenuItem {
  const FloatingMenuItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.deskripsi,
    this.warna,
    this.aktif = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final String? deskripsi;
  final Color? warna;

  /// Menandai entri yang sedang dibuka (diberi latar terpilih).
  final bool aktif;
}

/// Menu mengambang di atas NavigationBar.
///
/// Dipakai supaya bilah navigasi tetap ringkas (maksimal 4 slot) tanpa
/// menyembunyikan menu lain: slot terakhir "Lainnya" membuka panel ini.
/// Panel muncul dengan fade + skala dari bawah, menempel di atas navbar, dan
/// menutup saat area gelap disentuh.
///
/// Memakai [showGeneralDialog] (bukan bottom sheet) supaya bentuknya bisa
/// mengambang dengan margin dan sudut membulat di semua sisi.
Future<void> showFloatingMenu(
  BuildContext context, {
  required List<FloatingMenuItem> items,
  String judul = 'Menu lainnya',
  double? bottomInset,
}) {
  final calculatedInset =
      bottomInset ??
      ((NavigationBarTheme.of(context).height ?? 80) +
          MediaQuery.viewPaddingOf(context).bottom +
          8);
  // Minimum 128 dp menjaga panel tetap di atas NavigationBar + system inset
  // pada emulator/perangkat yang menggunakan navigasi tiga tombol.
  final insetUntukPanel = calculatedInset < 128 ? 128.0 : calculatedInset;
  return showGeneralDialog<void>(
    context: context,
    barrierLabel: judul,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    transitionDuration: PkgMotion.tab,
    pageBuilder: (ctx, _, _) => _FloatingMenuPanel(
      judul: judul,
      items: items,
      bottomInset: insetUntukPanel,
    ),
    transitionBuilder: (ctx, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: PkgMotion.curve,
        reverseCurve: PkgMotion.reverseCurve,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.12),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _FloatingMenuPanel extends StatelessWidget {
  const _FloatingMenuPanel({
    required this.judul,
    required this.items,
    required this.bottomInset,
  });

  final String judul;
  final List<FloatingMenuItem> items;
  final double? bottomInset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lebar = MediaQuery.sizeOf(context).width;
    final tinggi = MediaQuery.sizeOf(context).height;
    // Tinggi bilah navigasi aplikasi = tinggi NavigationBar (80 dp default M3)
    // + viewPadding bawah yang ditambahkan Scaffold untuk bilah sistem
    // (48 dp pada mode 3 tombol, 24 dp pada mode gesture). Memakai
    // viewPadding, bukan padding, supaya nilainya tidak menyusut jadi 0
    // saat papan ketik terbuka.
    // Sisakan ruang untuk NavigationBar aplikasi dan bilah navigasi sistem.
    // Ini menjaga kartu terakhir tetap dapat disentuh pada perangkat 3 tombol.
    final viewPaddingBawah = MediaQuery.viewPaddingOf(context).bottom;
    final insetEfektif =
        bottomInset ??
        ((NavigationBarTheme.of(context).height ?? 80) + viewPaddingBawah + 8);
    // Dua kolom di ponsel, tiga saat layar cukup lebar.
    final kolom = lebar >= 520 ? 3 : 2;
    final maxPanelHeight = (tinggi - insetEfektif - 24).clamp(160.0, tinggi);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 24, 12, insetEfektif),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxPanelHeight),
          child: Material(
            color: scheme.surfaceContainerHigh,
            elevation: 12,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            // Tidak memakai SafeArea karena insetEfektif sudah mengangkat panel
            // di atas bilah sistem, agar viewPadding bawah tidak dihitung dua kali.
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          judul,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Tutup menu',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: GridView.count(
                      crossAxisCount: kolom,
                      // Flexible sudah memberi batas tinggi; jangan shrink-wrap
                      // agar scroll extent seluruh grid tetap terhitung di layar
                      // landscape pendek.
                      shrinkWrap: false,
                      physics: const ClampingScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.55,
                      children: [
                        for (var i = 0; i < items.length; i++)
                          FadeSlideIn(
                            index: i,
                            duration: const Duration(milliseconds: 260),
                            offset: const Offset(0, 0.14),
                            child: _MenuKotak(item: items[i]),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuKotak extends StatelessWidget {
  const _MenuKotak({required this.item});

  final FloatingMenuItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final warna = item.warna ?? scheme.primary;

    return Semantics(
      button: true,
      selected: item.aktif,
      label: item.deskripsi == null
          ? item.label
          : '${item.label}. ${item.deskripsi}',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Tutup panel dulu supaya navigasi tidak menumpuk di atas dialog.
          Navigator.of(context).pop();
          item.onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: item.aktif
                ? warna.withValues(alpha: 0.16)
                : scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.aktif ? warna : scheme.outlineVariant,
              width: item.aktif ? 1.4 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.icon, color: warna, size: 22),
              const SizedBox(height: 8),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (item.deskripsi != null)
                Text(
                  item.deskripsi!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.outline),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
