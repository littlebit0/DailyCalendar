import '../../features/events/domain/calendar_event.dart';
import '../settings/app_settings.dart';
import 'calendar_event_ordering.dart';

/// The calendar's display policy (hidden categories, holidays, D-day only and
/// the current search). The month grid and the day panel both apply it, so a
/// live database result never shows what the calendar itself hides.
List<CalendarEvent> filterVisibleCalendarEvents(
  Iterable<CalendarEvent> events,
  AppSettings settings,
  String searchQuery,
) {
  final hidden = settings.hiddenCategoryIds.toSet();
  final query = searchQuery.trim().toLowerCase();
  final filtered = events.where((event) {
    if (!settings.calendarShowHolidays && event.holiday) {
      return false;
    }
    if (hidden.contains(event.category.id)) {
      return false;
    }
    if (settings.calendarDdayOnly && !event.showDday) {
      return false;
    }
    if (query.isEmpty) {
      return true;
    }
    final searchable = [
      event.title,
      event.memo,
      event.location,
      event.url,
      event.weather,
      event.category.label,
    ].whereType<String>().join(' ').toLowerCase();
    return searchable.contains(query);
  });
  return sortedCalendarEvents(
    filtered,
    priority: settings.calendarEventSortPriority,
    categoryOrder: settings.categories.map((category) => category.id).toList(),
  );
}
