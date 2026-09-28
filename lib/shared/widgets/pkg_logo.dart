import 'package:flutter/material.dart';

/// Logo PKG sebagai widget.
///
/// Memakai aset `assets/branding/pkg-logo-trimmed.png` (emblem sudah dipangkas
/// dari margin krem oleh `scripts/pkg_gen_icons.py`), jadi ukuran yang diminta
/// benar-benar terpakai penuh oleh emblem.
class PkgLogo extends StatelessWidget {
  const PkgLogo({super.key, this.size = 96, this.showRing = false});

  final double size;

  /// Tambahkan cincin tipis di sekeliling logo. Berguna saat logo diletakkan
  /// di atas warna yang kontras dengan latar krem emblem.
  final bool showRing;

  static const asset = 'assets/branding/pkg-logo-trimmed.png';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final image = Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      // Kalau aset gagal dimuat, jangan tampilkan kotak merah Flutter.
      errorBuilder: (_, _, _) => Icon(
        Icons.school_outlined,
        size: size * 0.7,
        color: scheme.primary,
      ),
    );

    if (!showRing) return image;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF8F6E8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: EdgeInsets.all(size * 0.04),
      child: image,
    );
  }
}

/// Logo + nama aplikasi, dipakai di AppBar dan header login.
class PkgWordmark extends StatelessWidget {
  const PkgWordmark({
    super.key,
    this.logoSize = 28,
    this.title = 'PKG Panunggangan',
    this.subtitle,
  });

  final double logoSize;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PkgLogo(size: logoSize),
        const SizedBox(width: 10),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: text.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
