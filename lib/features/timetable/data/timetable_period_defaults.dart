import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/timetable_term.dart';
import 'timetable_sync_document.dart';

/// Published university dates, kept as sourced data rather than month guesses.
class TimetablePeriodDefaults {
  TimetablePeriodDefaults._(this._universities);

  final Map<String, Map<String, TimetablePeriod>> _universities;
  Map<String, TimetablePeriod> get periods => periodsFor('smu');

  Map<String, TimetablePeriod> periodsFor(String university) =>
      _universities[university] ?? const {};

  TimetablePeriod? periodFor(
    int year,
    String semester, {
    String university = 'smu',
  }) => periodsFor(university)[timetableTermSyncKey(year, semester)];

  static Future<TimetablePeriodDefaults> load({AssetBundle? bundle}) async {
    final data =
        jsonDecode(
              await (bundle ?? rootBundle).loadString(
                'assets/timetable/term-periods.json',
              ),
            )
            as Map<String, dynamic>;
    if (data['schemaVersion'] != 1 || data['university'] != 'smu') {
      throw const FormatException('Unsupported timetable period defaults');
    }
    final universities = <String, Map<String, TimetablePeriod>>{};
    for (final universityData in [
      data,
      ...?data['additionalUniversities'] as List?,
    ]) {
      final university = universityData['university'] as String;
      if (university.isEmpty || universities.containsKey(university)) {
        throw const FormatException('Invalid default university');
      }
      final periods = <String, TimetablePeriod>{};
      for (final item in universityData['terms'] as List) {
        final term = Map<String, dynamic>.from(item as Map);
        final year = term['year'] as int;
        final semester = term['semester'] as String;
        if (year < 1900 || year > 9999 || semester.trim().isEmpty) {
          throw const FormatException('Invalid default timetable term');
        }
        final key = timetableTermSyncKey(year, semester);
        if (periods.containsKey(key)) {
          throw const FormatException('Duplicate default timetable term');
        }
        periods[key] = TimetablePeriod.fromJson({
          'startDate': term['start'],
          'endDate': term['end'],
        });
      }
      universities[university] = Map.unmodifiable(periods);
    }
    return TimetablePeriodDefaults._(Map.unmodifiable(universities));
  }
}
