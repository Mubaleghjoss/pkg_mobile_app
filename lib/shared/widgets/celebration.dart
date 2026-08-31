import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Perayaan sederhana tanpa dependensi tambahan: kepingan warna yang jatuh
/// digambar langsung dengan [CustomPainter], plus dialog "selamat".
///
/// Sengaja tidak memakai paket confetti/lottie supaya tidak menambah
/// dependensi pihak ketiga hanya untuk satu efek.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({
    super.key,
    this.pieces = 60,
    this.duration = const Duration(milliseconds: 2600),
  });

  final int pieces;
  final Duration duration;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  late final List<_Piece> _list = _build();

  List<_Piece> _build() {
    final rnd = math.Random(7);
    return List<_Piece>.generate(widget.pieces, (i) {
      return _Piece(
        x: rnd.nextDouble(),
        delay: rnd.nextDouble() * 0.35,
        speed: 0.65 + rnd.nextDouble() * 0.5,
        drift: (rnd.nextDouble() - 0.5) * 0.35,
        size: 6 + rnd.nextDouble() * 7,
        spin: (rnd.nextDouble() - 0.5) * 10,
        colorIndex: i % 5,
        square: i.isEven,
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = <Color>[
      scheme.primary,
      scheme.tertiary,
      scheme.secondary,
      const Color(0xFFF6C445),
      const Color(0xFF4CAF7D),
    ];

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _ConfettiPainter(_list, _c.value, palette),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.drift,
    required this.size,
    required this.spin,
    required this.colorIndex,
    required this.square,
  });

  final double x;
  final double delay;
  final double speed;
  final double drift;
  final double size;
  final double spin;
  final int colorIndex;
  final bool square;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t, this.palette);

  final List<_Piece> pieces;
  final double t;
  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;

      // Memudar di 25% terakhir supaya berakhir halus.
      final fade = local > 0.75 ? (1 - (local - 0.75) / 0.25) : 1.0;
      final y = (local * p.speed) * (size.height + 80) - 40;
      final x = (p.x + math.sin(local * math.pi * 2) * p.drift) * size.width;

      paint.color = palette[p.colorIndex].withValues(alpha: fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(local * p.spin);
      if (p.square) {
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 0.6),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, p.size / 2.4, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// Lencana bintang yang berdenyut, dipakai di dialog perayaan.
class PulsingBadge extends StatefulWidget {
  const PulsingBadge({super.key, this.icon = Icons.emoji_events, this.size = 78});

  final IconData icon;
  final double size;

  @override
  State<PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<PulsingBadge>
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
    final scheme = Theme.of(context).colorScheme;
    return ScaleTransition(
      scale: Tween<double>(begin: 0.92, end: 1.06).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [scheme.primary, scheme.tertiary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Icon(widget.icon, size: widget.size * 0.5, color: Colors.white),
      ),
    );
  }
}

/// Dialog "Selamat, kamu berhasil membaca materi ini".
///
/// Mengembalikan `true` bila pengguna memilih lanjut ke materi berikutnya.
Future<bool> showMateriSelesaiDialog(
  BuildContext context, {
  required String judul,
  String? nextLabel,
  int? poin,
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tutup',
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (context, a1, a2) => const SizedBox.shrink(),
    transitionBuilder: (context, anim, _, _) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return Stack(
        children: [
          const Positioned.fill(child: ConfettiOverlay()),
          Center(
            child: FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.85, end: 1).animate(curved),
                child: _SelesaiCard(
                  judul: judul,
                  nextLabel: nextLabel,
                  poin: poin,
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

class _SelesaiCard extends StatelessWidget {
  const _SelesaiCard({required this.judul, this.nextLabel, this.poin});

  final String judul;
  final String? nextLabel;
  final int? poin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PulsingBadge(),
              const SizedBox(height: 18),
              Text(
                'Selamat, kamu berhasil membaca materi ini!',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                judul,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Silakan lanjutkan ke materi berikutnya sampai semua selesai '
                'agar ilmumu bertambah. Jangan lupa dipraktikkan ya!',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              if (poin != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Progres bacaan tersimpan · $poin materi tuntas',
                    style: theme.textTheme.labelMedium,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Nanti dulu'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: Text(nextLabel ?? 'Materi berikutnya'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
