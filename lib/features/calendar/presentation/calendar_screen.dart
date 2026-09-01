import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../domain/calendar_event.dart';

/// Dapat di-override test agar judul bulan deterministik.
final calendarInitialMonthProvider = Provider<DateTime>(
  (ref) => DateTime.now(),
);

class CalendarViewState {
  const CalendarViewState({
    required this.month,
    required this.selectedDate,
    this.type,
  });

  final DateTime month;
  final DateTime selectedDate;
  final String? type;

  CalendarViewState copyWith({
    DateTime? month,
    DateTime? selectedDate,
    String? type,
    bool clearType = false,
  }) => CalendarViewState(
    month: month ?? this.month,
    selectedDate: selectedDate ?? this.selectedDate,
    type: clearType ? null : (type ?? this.type),
  );
}

class CalendarViewController extends Notifier<CalendarViewState> {
  @override
  CalendarViewState build() {
    final now = ref.watch(calendarInitialMonthProvider);
    final month = DateTime(now.year, now.month);
    return CalendarViewState(month: month, selectedDate: dateOnly(now));
  }

  void moveMonth(int offset) {
    final month = DateTime(state.month.year, state.month.month + offset);
    state = state.copyWith(month: month, selectedDate: month);
  }

  void selectDate(DateTime value) =>
      state = state.copyWith(selectedDate: dateOnly(value));

  void selectType(String? value) => value == null
      ? state = state.copyWith(clearType: true)
      : state = state.copyWith(type: value);
}

final calendarViewProvider =
    NotifierProvider<CalendarViewController, CalendarViewState>(
      CalendarViewController.new,
    );

final calendarEventsProvider = FutureProvider<List<CalendarEvent>>((ref) async {
  final month = ref.watch(calendarViewProvider.select((state) => state.month));
  final start = DateTime(month.year, month.month);
  final end = DateTime(month.year, month.month + 1, 0);
  final result = await ref
      .watch(calendarRepositoryProvider)
      .events(start: start, end: end);
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat kalender');
  }
  return result.data!;
});

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calendarViewProvider);
    final asyncEvents = ref.watch(calendarEventsProvider);
    return asyncEvents.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorPanel(
        message: '$error'.replaceFirst('Exception: ', ''),
        onRetry: () => ref.invalidate(calendarEventsProvider),
      ),
      data: (events) => RefreshIndicator(
        onRefresh: () => ref.refresh(calendarEventsProvider.future),
        child: _CalendarContent(state: state, events: events),
      ),
    );
  }
}

class _CalendarContent extends ConsumerWidget {
  const _CalendarContent({required this.state, required this.events});

  final CalendarViewState state;
  final List<CalendarEvent> events;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(calendarViewProvider.notifier);
    final types = events.map((event) => event.type).toSet().toList()..sort();
    final filtered = state.type == null
        ? events
        : events.where((event) => event.type == state.type).toList();
    final grouped = groupCalendarEvents(filtered);
    final selected = grouped[state.selectedDate] ?? const <CalendarEvent>[];
    final upcoming =
        filtered
            .where((event) => !event.start.isBefore(state.selectedDate))
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              tooltip: 'Bulan sebelumnya',
              onPressed: () => controller.moveMonth(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                _monthLabel(state.month),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Bulan berikutnya',
              onPressed: () => controller.moveMonth(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _MonthGrid(
          month: state.month,
          selectedDate: state.selectedDate,
          grouped: grouped,
          onSelect: controller.selectDate,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: const Text('Semua'),
                  selected: state.type == null,
                  onSelected: (_) => controller.selectType(null),
                ),
              ),
              ...types.map(
                (type) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(_typeLabel(type)),
                    selected: state.type == type,
                    onSelected: (_) => controller.selectType(type),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Agenda tanggal terpilih',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        if (selected.isEmpty)
          const Text('Tidak ada agenda pada tanggal ini.')
        else
          ...selected.map(_EventTile.new),
        const SizedBox(height: 20),
        Text('Agenda terdekat', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        if (events.isEmpty)
          const Text('Belum ada agenda pada bulan ini.')
        else if (upcoming.isEmpty)
          const Text('Tidak ada agenda terdekat dengan filter ini.')
        else
          ...upcoming.take(5).map(_EventTile.new),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selectedDate,
    required this.grouped,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selectedDate;
  final Map<DateTime, List<CalendarEvent>> grouped;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final firstOffset = DateTime(month.year, month.month).weekday - 1;
    final dayCount = DateTime(month.year, month.month + 1, 0).day;
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            for (final day in <String>[
              'Sen',
              'Sel',
              'Rab',
              'Kam',
              'Jum',
              'Sab',
              'Min',
            ])
              Expanded(child: Center(child: Text(day))),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1,
          ),
          itemCount: firstOffset + dayCount,
          itemBuilder: (context, index) {
            if (index < firstOffset) return const SizedBox.shrink();
            final date = DateTime(
              month.year,
              month.month,
              index - firstOffset + 1,
            );
            final events = grouped[date] ?? const <CalendarEvent>[];
            final selected = date == selectedDate;
            return InkWell(
              onTap: () => onSelect(date),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text('${date.day}'),
                    if (events.isNotEmpty)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 3),
                        decoration: BoxDecoration(
                          color: _parseColor(events.first.color),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile(this.event);

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(radius: 6, backgroundColor: _parseColor(event.color)),
    title: Text(event.title),
    subtitle: Text(
      event.allDay
          ? '${DateFormat('dd MMM yyyy').format(event.start)} · Sepanjang hari'
          : DateFormat('dd MMM yyyy · HH:mm').format(event.start),
    ),
  );
}

String _monthLabel(DateTime value) {
  const months = <String>[
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  return '${months[value.month - 1]} ${value.year}';
}

String _typeLabel(String value) {
  if (value.isEmpty) return 'Lainnya';
  return value[0].toUpperCase() + value.substring(1).replaceAll('_', ' ');
}

Color _parseColor(String value) {
  final clean = value.replaceFirst('#', '');
  final parsed = int.tryParse(clean, radix: 16);
  return parsed == null || clean.length != 6
      ? Colors.blueGrey
      : Color(0xFF000000 | parsed);
}
