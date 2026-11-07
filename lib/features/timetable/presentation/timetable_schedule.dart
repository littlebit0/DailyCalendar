import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/update/update_required_view.dart';
import '../../events/domain/calendar_event.dart';
import '../../events/domain/event_category.dart';
import '../data/timetable_store.dart';
import '../domain/timetable.dart';
import 'timetable_page.dart';

const _projectionIdPrefix = 'timetable/';

/// True for a transient timetable render projection (never a stored event).
bool isTimetableProjection(CalendarEvent event) =>
    event.systemEvent && event.id.startsWith(_projectionIdPrefix);

/// A dated meeting whose lecture mode differs from the course default (#771).
bool isLectureModeChange(ClassOccurrence occurrence) =>
    occurrence.mode != occurrence.course.defaultMode;

/// Lecture-mode change occurrences on [days], within each course's term.
List<ClassOccurrence> lectureModeChangeOccurrences(
  TimetableStore store,
  Iterable<DateTime> days,
) => [
  for (final o in classOccurrences(
    store.classes,
    days,
    includeUnscheduled: true,
    periodFor: (course) =>
        store.periodFor(course.academicYear, course.semester),
  ))
    if (isLectureModeChange(o)) o,
];

/// Read-only render projection of a class occurrence. A changed mode is shown
/// in the title ('강의명 영상 강의') so the change is visible without opening it.
CalendarEvent timetableOccurrenceEvent(
  BuildContext context,
  ClassOccurrence o,
) => CalendarEvent(
  id: o.id,
  title: isLectureModeChange(o)
      ? '${o.course.title} ${context.tr(lectureModeLabel(o.mode))}'
      : o.course.title,
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
);

/// Search results and D-day-only views list stored events only, so
/// lecture-mode changes stay out of them.
bool lectureModeChangesShown(AppSettings settings, String searchQuery) =>
    searchQuery.trim().isEmpty && !settings.calendarDdayOnly;

/// [events] without earlier projections, plus lecture-mode changes on [days].
List<CalendarEvent> withLectureModeChanges(
  BuildContext context,
  TimetableStore store,
  Iterable<DateTime> days,
  List<CalendarEvent> events,
) => [
  for (final event in events)
    if (!isTimetableProjection(event)) event,
  for (final o in lectureModeChangeOccurrences(store, days))
    timetableOccurrenceEvent(context, o),
];

/// Opens the occurrence behind a timetable projection. Returns false when
/// [event] is not one (or its class no longer exists).
bool openTimetableProjection(
  BuildContext context,
  WidgetRef ref,
  CalendarEvent event,
) {
  if (!isTimetableProjection(event)) return false;
  final store = ref.read(timetableStoreProvider);
  final day = DateTime(
    event.startAt.year,
    event.startAt.month,
    event.startAt.day,
  );
  for (final o in classOccurrences(store.classes, [
    day,
  ], includeUnscheduled: true)) {
    if (o.id == event.id) {
      if (!blockedByRequiredUpdate(context, ref)) {
        showClassOccurrence(context, store, o);
      }
      return true;
    }
  }
  return false;
}

/// Rebuilds [builder] with lecture-mode change projections for [days]
/// appended to [events], following timetable edits and sync immediately.
class LectureModeChanges extends ConsumerWidget {
  const LectureModeChanges({
    super.key,
    required this.days,
    required this.events,
    required this.builder,
  });
  final List<DateTime> days;
  final List<CalendarEvent> events;
  final Widget Function(List<CalendarEvent>) builder;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(timetableStoreProvider);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) =>
          builder(withLectureModeChanges(context, store, days, events)),
    );
  }
}

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
        // Changed occurrences (휴강·영상 included) keep their one block (#771).
        final occurrences = [
          for (final o in classOccurrences(
            store.classes,
            days,
            includeUnscheduled: true,
            periodFor: (course) =>
                store.periodFor(course.academicYear, course.semester),
          ))
            if (includeUnscheduled ||
                isLectureModeChange(o) ||
                (o.mode != LectureMode.cancelled &&
                    o.mode != LectureMode.video))
              o,
        ];
        return builder(
          [
            for (final event in events)
              if (!isTimetableProjection(event)) event,
            for (final o in occurrences) timetableOccurrenceEvent(context, o),
          ],
          {
            for (final o in occurrences)
              o.id: () => showClassOccurrence(context, store, o),
          },
        );
      },
    );
  }
}
