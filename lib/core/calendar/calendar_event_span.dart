import '../../features/events/domain/calendar_event.dart';

/// A visible, inclusive date span. The event itself keeps its exclusive end.
class CalendarEventSpan {
  const CalendarEventSpan({
    required this.event,
    required this.startCol,
    required this.endCol,
    this.lane = 0,
  });

  final CalendarEvent event;
  final int startCol;
  final int endCol;
  final int lane;

  int get span => endCol - startCol + 1;

  static CalendarEventSpan? fromEvent(
    CalendarEvent event,
    DateTime firstDay, {
    int dayCount = 7,
  }) {
    // UTC date ordinals avoid losing a column across a daylight-saving change.
    DateTime ordinal(DateTime date) =>
        DateTime.utc(date.year, date.month, date.day);
    final origin = ordinal(firstDay);
    final start = ordinal(event.startAt).difference(origin).inDays;
    final end = ordinal(
      event.endAt.subtract(const Duration(microseconds: 1)),
    ).difference(origin).inDays;
    if (dayCount <= 0 || end < 0 || start >= dayCount || end < start) {
      return null;
    }
    return CalendarEventSpan(
      event: event,
      startCol: start.clamp(0, dayCount - 1),
      endCol: end.clamp(0, dayCount - 1),
    );
  }

  CalendarEventSpan copyWith({int? startCol, int? endCol, int? lane}) =>
      CalendarEventSpan(
        event: event,
        startCol: startCol ?? this.startCol,
        endCol: endCol ?? this.endCol,
        lane: lane ?? this.lane,
      );
}

/// Keeps the caller's event ordering and uses the first non-overlapping lane.
List<CalendarEventSpan> layoutCalendarEventLanes(
  Iterable<CalendarEventSpan> spans,
) {
  final lanes = <List<CalendarEventSpan>>[];
  final result = <CalendarEventSpan>[];
  for (final span in spans) {
    var index = lanes.indexWhere(
      (lane) => lane.every(
        (placed) =>
            span.endCol < placed.startCol || span.startCol > placed.endCol,
      ),
    );
    if (index < 0) {
      index = lanes.length;
      lanes.add([]);
    }
    lanes[index].add(span);
    result.add(span.copyWith(lane: index));
  }
  return result;
}
