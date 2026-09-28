import 'package:flutter/material.dart';
import 'package:qcf_quran/qcf_quran.dart';

class QcfMushafScreen extends StatefulWidget {
  const QcfMushafScreen({this.initialPage = 1, super.key});

  final int initialPage;

  @override
  State<QcfMushafScreen> createState() => _QcfMushafScreenState();
}

class _QcfMushafScreenState extends State<QcfMushafScreen> {
  late final PageController _controller = PageController(
    initialPage: (widget.initialPage.clamp(1, totalPagesCount)) - 1,
  );
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage.clamp(1, totalPagesCount);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mushaf Utsmani'),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: Center(child: Text('Halaman $_page / $totalPagesCount')),
          ),
        ],
      ),
      body: PageviewQuran(
        controller: _controller,
        initialPageNumber: _page,
        onPageChanged: (page) => setState(() => _page = page),
        theme: QcfThemeData(
          pageBackgroundColor: dark
              ? const Color(0xFF1B1712)
              : const Color(0xFFFFFCF2),
          verseTextColor: dark ? const Color(0xFFF4E9D2) : Colors.black,
          verseNumberColor: dark
              ? const Color(0xFFE2B96B)
              : const Color(0xFF8B4513),
        ),
      ),
    );
  }
}
