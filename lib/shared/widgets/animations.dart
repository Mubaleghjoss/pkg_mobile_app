import 'package:flutter/material.dart';

/// Durasi & kurva animasi standar aplikasi, dikumpulkan di satu tempat supaya
/// seluruh layar terasa konsisten.
class PkgMotion {
  const PkgMotion._();

  /// Transisi antar halaman penuh (push/pop).
  static const page = Duration(milliseconds: 320);

  /// Perpindahan antar tab di dalam shell.
  static const tab = Duration(milliseconds: 260);

  /// Munculnya elemen daftar / kartu.
  static const enter = Duration(milliseconds: 380);

  /// Jeda bertingkat antar item daftar.
  static const stagger = Duration(milliseconds: 45);

  /// Kurva masuk cepat di awal lalu melandai.
  static const curve = Curves.easeOutCubic;
  static const reverseCurve = Curves.easeInCubic;
}

/// Item yang muncul dengan fade + geser halus.
///
/// Dipakai untuk kartu dashboard dan baris daftar. [index] menghasilkan jeda
/// bertingkat sehingga daftar tampak mengalir, bukan muncul serentak.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = const Offset(0, 0.08),
    this.duration = PkgMotion.enter,
    this.maxStaggerIndex = 12,
  });

  final Widget child;
  final int index;

  /// Arah awal geseran, dalam satuan fraksi ukuran anak.
  final Offset offset;
  final Duration duration;

  /// Batas jeda: item ke-13 dan seterusnya tidak menambah delay lagi supaya
  /// daftar panjang tidak terasa lambat.
  final int maxStaggerIndex;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late final Animation<double> _curved = CurvedAnimation(
    parent: _controller,
    curve: PkgMotion.curve,
  );

  @override
  void initState() {
    super.initState();
    final steps = widget.index.clamp(0, widget.maxStaggerIndex);
    final delay = PkgMotion.stagger * steps;
    if (delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curved,
      child: SlideTransition(
        position:
            Tween<Offset>(begin: widget.offset, end: Offset.zero).animate(_curved),
        child: widget.child,
      ),
    );
  }
}

/// Kartu yang sedikit mengecil saat ditekan — umpan balik sentuh.
class PressableCard extends StatefulWidget {
  const PressableCard({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: widget.onTap == null ? null : (_) => _set(true),
      onTapUp: widget.onTap == null ? null : (_) => _set(false),
      onTapCancel: widget.onTap == null ? null : () => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Angka yang berhitung naik dari 0 ke [value] saat pertama tampil.
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.suffix = '',
    this.decimals = 0,
  });

  final num value;
  final TextStyle? style;
  final String suffix;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) =>
          Text('${v.toStringAsFixed(decimals)}$suffix', style: style),
    );
  }
}

/// Muncul dengan fade + skala halus (dipakai untuk kartu QR, panel hasil).
class PopIn extends StatefulWidget {
  const PopIn({
    super.key,
    required this.child,
    this.duration = PkgMotion.enter,
    this.beginScale = 0.92,
  });

  final Widget child;
  final Duration duration;
  final double beginScale;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  late final Animation<double> _curved =
      CurvedAnimation(parent: _c, curve: PkgMotion.curve);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: widget.beginScale, end: 1).animate(_curved),
        child: widget.child,
      ),
    );
  }
}

/// Bar progres yang tumbuh dari 0 ke [value] (0..1).
class AnimatedBar extends StatelessWidget {
  const AnimatedBar({
    super.key,
    required this.value,
    this.color,
    this.height = 8,
  });

  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.clamp(0, 1)),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          value: v,
          minHeight: height,
          backgroundColor: scheme.surfaceContainerHighest,
          valueColor:
              AlwaysStoppedAnimation<Color>(color ?? scheme.primary),
        ),
      ),
    );
  }
}
