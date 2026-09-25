import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../events/domain/calendar_event.dart';
import '../../events/domain/event_category.dart';
import '../domain/timetable.dart';
import 'timetable_page.dart';

/// Transient render projections. Never inserted into the event repository.
class TimetableSchedule extends ConsumerWidget {
  const TimetableSchedule({
    super.key,
    required this.days,
    required this.events,
    required this.builder,
    this.includeUnscheduled = false,
  });
  final List<DateTime> days;
  final List<CalendarEvent> events;
  final bool includeUnscheduled;
  final Widget Function(List<CalendarEvent>, Map<String, VoidCallback>) builder;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(timetableStoreProvider);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final occurrences = classOccurrences(
          store.classes,
          days,
          includeUnscheduled: includeUnscheduled,
          periodFor: (course) =>
              store.periodFor(course.academicYear, course.semester),
        );
        final projected = [
          for (final o in occurrences)
            CalendarEvent(
              id: o.id,
              title: o.course.title,
              startAt: o.start,
              endAt: o.end,
              allDay: false,
              category: EventCategory(
                id: 'timetable',
                label: context.tr('시간표'),
                colorValue: o.course.colorValue,
              ),
              colorValue: o.course.colorValue,
              createdAt: o.date,
              updatedAt: o.date,
              readOnly: true,
              systemEvent: true,
              location: o.meeting.classroom,
              memo: context.tr(lectureModeLabel(o.mode)),
            ),
        ];
        return builder(
          [...events, ...projected],
          {
            for (final o in occurrences)
              o.id: () => showClassOccurrence(context, store, o),
          },
        );
      },
    );
  }
}
