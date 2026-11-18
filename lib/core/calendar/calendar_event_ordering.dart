import '../../features/events/domain/calendar_event.dart';
import '../settings/app_settings.dart';

Comparator<CalendarEvent> calendarEventComparator({
  required CalendarEventSortPriority priority,
  required List<String> categoryOrder,
  List<String> manualOrder = const <String>[],
}) {
  final categoryRanks = <String, int>{
    for (var index = 0; index < categoryOrder.length; index++)
      categoryOrder[index]: index,
  };
  final manualRanks = _manualRanks(manualOrder);
  return (first, second) => _compareCalendarEvents(
    first,
    second,
    priority,
    categoryRanks,
    manualRanks,
  );
}

int _compareCalendarEvents(
  CalendarEvent first,
  CalendarEvent second,
  CalendarEventSortPriority priority,
  Map<String, int> categoryRanks,
  Map<String, int> manualRanks,
) {
  final firstManualRank = manualRanks[calendarEventOrderKey(first)];
  final secondManualRank = manualRanks[calendarEventOrderKey(second)];
  if (firstManualRank != null || secondManualRank != null) {
    final manualComparison = (firstManualRank ?? manualRanks.length).compareTo(
      secondManualRank ?? manualRanks.length,
    );
    if (manualComparison != 0) {
      return manualComparison;
    }
  }

  final categoryComparison = _categoryRank(
    first,
    categoryRanks,
  ).compareTo(_categoryRank(second, categoryRanks));
  final startComparison = first.startAt.compareTo(second.startAt);

  if (priority == CalendarEventSortPriority.category) {
    if (categoryComparison != 0) {
      return categoryComparison;
    }
    if (startComparison != 0) {
      return startComparison;
    }
  } else {
    if (startComparison != 0) {
      return startComparison;
    }
    if (categoryComparison != 0) {
      return categoryComparison;
    }
  }

  final endComparison = first.endAt.compareTo(second.endAt);
  if (endComparison != 0) {
    return endComparison;
  }
  final titleComparison = first.title.toLowerCase().compareTo(
    second.title.toLowerCase(),
  );
  if (titleComparison != 0) {
    return titleComparison;
  }
  return first.id.compareTo(second.id);
}

List<CalendarEvent> sortedCalendarEvents(
  Iterable<CalendarEvent> events, {
  required CalendarEventSortPriority priority,
  required List<String> categoryOrder,
  List<String> manualOrder = const <String>[],
}) {
  return events.toList()..sort(
    calendarEventComparator(
      priority: priority,
      categoryOrder: categoryOrder,
      manualOrder: manualOrder,
    ),
  );
}

String calendarDateKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String calendarEventOrderKey(CalendarEvent event) =>
    event.occurrenceId ?? event.id;

Map<String, int> _manualRanks(List<String> manualOrder) => <String, int>{
  for (var index = 0; index < manualOrder.length; index++)
    manualOrder[index]: index,
};

int _categoryRank(CalendarEvent event, Map<String, int> categoryRanks) {
  return categoryRanks[event.category.id] ?? categoryRanks.length;
}
