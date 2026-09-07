import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/daily_ui.dart';
import '../../../core/theme/event_completion_style.dart';
import '../../events/domain/calendar_event.dart';
import '../../events/presentation/event_completion_action.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  Future<List<CalendarEvent>>? _results;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DailyUi.pageBackground(context),
      appBar: DailyNavigationBar(title: context.tr('검색')),
      body: DailyAdaptiveBody(
        maxWidth: 760,
        padding: EdgeInsets.fromLTRB(
          DailyUi.isDesktop ? 24 : 16,
          8,
          DailyUi.isDesktop ? 24 : 16,
          24,
        ),
        child: Column(
          children: [
            Material(
              color: DailyUi.groupedSurface(context),
              borderRadius: BorderRadius.circular(14),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: context.tr('제목, 메모, 장소 검색'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    tooltip: context.tr('검색'),
                    onPressed: _search,
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                  filled: false,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: DailyUi.separator(context)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: DailyUi.separator(context)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: DailyUi.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<CalendarEvent>>(
                future: _results,
                builder: (context, snapshot) {
                  final events = snapshot.data ?? const <CalendarEvent>[];
                  if (_results == null) {
                    return const SizedBox.shrink();
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (events.isEmpty) {
                    return Center(
                      child: DailyInfoCallout(
                        icon: Icons.search_off_rounded,
                        text: context.tr('검색 결과가 없습니다.'),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemBuilder: (context, index) => _SearchResultTile(
                      event: events[index],
                      onCompletedChanged: _search,
                      onTap: () {
                        final event = events[index];
                        ref.read(visibleMonthProvider.notifier).state =
                            DateTime(event.startAt.year, event.startAt.month);
                        ref
                            .read(selectedDateProvider.notifier)
                            .state = DateTime(
                          event.startAt.year,
                          event.startAt.month,
                          event.startAt.day,
                        );
                        Navigator.of(context).pop();
                      },
                    ),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemCount: events.length,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _search() {
    setState(() {
      _results = ref
          .read(eventRepositoryProvider)
          .search(_controller.text.trim());
    });
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.event,
    required this.onTap,
    required this.onCompletedChanged,
  });

  final CalendarEvent event;
  final VoidCallback onTap;
  final VoidCallback onCompletedChanged;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat.yMMMMd(locale).format(event.startAt);
    final time = event.allDay
        ? context.tr('종일')
        : DateFormat.Hm(locale).format(event.startAt);
    final color = Color(event.colorValue);
    return Material(
      color: DailyUi.groupedSurface(context),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: DailyUi.separator(context)),
      ),
      child: EventCompletionAction(
        event: event,
        onCompletedChanged: (_) => onCompletedChanged(),
        builder: (onDoubleTap) => InkWell(
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 5,
            ),
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.event_outlined, color: color, size: 21),
            ),
            title: Text(
              context.l10n.eventTitle(event.title, holiday: event.holiday),
              style: calendarEventCompletionStyle(
                context,
                Theme.of(context).textTheme.titleMedium,
                completed: event.completed,
                eventColor: color,
              ),
            ),
            subtitle: Text('$date  $time'),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: DailyUi.tertiaryText(context),
            ),
          ),
        ),
      ),
    );
  }
}
