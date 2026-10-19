enum CalendarImportProvider { apple, samsung, google }

extension CalendarImportProviderX on CalendarImportProvider {
  String get label => switch (this) {
    CalendarImportProvider.apple => 'Apple 캘린더',
    CalendarImportProvider.samsung => 'Samsung 캘린더',
    CalendarImportProvider.google => 'Google 캘린더',
  };
}

class ImportableCalendar {
  const ImportableCalendar({
    required this.id,
    required this.title,
    required this.provider,
    this.accountName,
    this.colorValue,
    this.defaultReminderMinutes = const <int>[],
  });

  final String id;
  final String title;
  final CalendarImportProvider provider;
  final String? accountName;
  final int? colorValue;
  final List<int> defaultReminderMinutes;

  String get selectionKey => '${provider.name}:$id';
}

class ExternalCalendarEvent {
  const ExternalCalendarEvent({
    required this.sourceId,
    required this.calendarId,
    required this.provider,
    required this.title,
    required this.startAt,
    required this.endAt,
    required this.allDay,
    this.memo,
    this.location,
    this.url,
    this.recurrenceRule,
    this.excludedDates = const <DateTime>[],
    this.colorValue,
    this.reminderMinutesBeforeList = const <int>[],
  });

  final String sourceId;
  final String calendarId;
  final CalendarImportProvider provider;
  final String title;
  final String? memo;
  final String? location;
  final String? url;
  final DateTime startAt;
  final DateTime endAt;
  final bool allDay;
  final String? recurrenceRule;

  /// Local dates of repeat occurrences the source removed (EXDATE, cancelled
  /// or moved instances). Empty for single events.
  final List<DateTime> excludedDates;
  final int? colorValue;
  final List<int> reminderMinutesBeforeList;
}

class CalendarImportResult {
  const CalendarImportResult({
    required this.imported,
    required this.skipped,
    required this.failed,
    this.unsupportedRecurrence = 0,
  });

  final int imported;
  final int skipped;
  final int failed;

  /// Imported once, because their repeat rule cannot be represented.
  final int unsupportedRecurrence;
}
