import 'dart:convert';

import 'package:flutter/widgets.dart' show StringCharacters;

import '../../../core/sync/sync_version.dart';
import '../domain/timetable.dart';
import '../domain/timetable_term.dart';

/// A persisted LWW register. Null is a deletion, not an absent record.
class TimetableSyncValue {
  TimetableSyncValue(Object? value, DateTime? changedAt, this.deviceId)
    : value = _freeze(value),
      changedAt = changedAt?.toUtc() {
    if (changedAt != null && deviceId.isEmpty) {
      throw const FormatException('Missing timetable writer');
    }
  }

  final Object? value;
  final DateTime? changedAt;
  final String deviceId;

  int compareTo(TimetableSyncValue other) {
    if (changedAt == null && other.changedAt != null) return -1;
    if (changedAt != null && other.changedAt == null) return 1;
    final time = (changedAt?.microsecondsSinceEpoch ?? 0).compareTo(
      other.changedAt?.microsecondsSinceEpoch ?? 0,
    );
    if (time != 0) return time;
    final deletion = (value == null ? 1 : 0).compareTo(
      other.value == null ? 1 : 0,
    );
    if (deletion != 0) return deletion;
    final writer = deviceId.compareTo(other.deviceId);
    if (writer != 0) return writer;
    return canonicalSyncJson(value).compareTo(canonicalSyncJson(other.value));
  }

  Map<String, Object?> toJson() => {
    'value': value,
    'changedAt': changedAt?.toIso8601String(),
    'deviceId': deviceId,
  };

  factory TimetableSyncValue.fromJson(Map<String, dynamic> json) {
    if (!json.containsKey('value') ||
        !json.containsKey('changedAt') ||
        json['deviceId'] is! String) {
      throw const FormatException('Invalid timetable register');
    }
    final raw = json['changedAt'];
    DateTime? date;
    if (raw != null) {
      if (raw is! String ||
          !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(raw) ||
          (date = DateTime.tryParse(raw)) == null) {
        throw const FormatException('Invalid timetable revision');
      }
    }
    return TimetableSyncValue(json['value'], date, json['deviceId'] as String);
  }
}

String timetableCourseSyncKey(TimetableClass course) => course.sourceId == null
    ? 'manual/${course.id}'
    : 'source/${jsonEncode([course.academicYear, course.semester, course.sourceId])}';

String timetableTermSyncKey(int year, String semester) =>
    jsonEncode([year, semester]);

Map<String, Object?> _courseValue(TimetableClass course) => {
  ...course.toJson(),
  // Dataset imports on two devices have unrelated editor UUIDs. Their shared
  // record uses a stable ID, while each existing local editor ID is retained.
  if (course.sourceId != null) 'id': timetableCourseSyncKey(course),
};

/// A separate Drive document, never projected into ordinary event sync.
class TimetableSyncDocument {
  const TimetableSyncDocument()
    : courses = const {},
      termNames = const {},
      termPeriods = const {},
      activeTerm = null;

  TimetableSyncDocument.records({
    Map<String, TimetableSyncValue> courses = const {},
    Map<String, TimetableSyncValue> termNames = const {},
    Map<String, TimetableSyncValue> termPeriods = const {},
    this.activeTerm,
  }) : courses = Map.unmodifiable(courses),
       termNames = Map.unmodifiable(termNames),
       termPeriods = Map.unmodifiable(termPeriods) {
    _validate();
  }

  final Map<String, TimetableSyncValue> courses;
  final Map<String, TimetableSyncValue> termNames;
  final Map<String, TimetableSyncValue> termPeriods;
  // Kept only to round-trip and merge older documents. The current selection
  // belongs to each device and must not read or modify this legacy register.
  final TimetableSyncValue? activeTerm;

  bool get isEmpty =>
      courses.isEmpty &&
      termNames.isEmpty &&
      termPeriods.isEmpty &&
      activeTerm == null;

  factory TimetableSyncDocument.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported timetable sync version');
    }
    Map<String, TimetableSyncValue> read(String key) =>
        Map<String, dynamic>.from(json[key] as Map).map(
          (key, value) => MapEntry(
            key,
            TimetableSyncValue.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          ),
        );
    return TimetableSyncDocument.records(
      courses: read('courses'),
      termNames: read('termNames'),
      termPeriods: json.containsKey('termPeriods') ? read('termPeriods') : {},
      activeTerm: json['activeTerm'] == null
          ? null
          : TimetableSyncValue.fromJson(
              Map<String, dynamic>.from(json['activeTerm'] as Map),
            ),
    );
  }

  factory TimetableSyncDocument.legacy({
    required List<TimetableClass> courses,
    required Map<int, Map<String, String>> termNames,
    Map<int, Map<String, TimetablePeriod>> termPeriods = const {},
    required int activeYear,
    required String activeSemester,
  }) => TimetableSyncDocument.records(
    courses: {
      for (final course in courses)
        timetableCourseSyncKey(course): TimetableSyncValue(
          _courseValue(course),
          null,
          '',
        ),
    },
    termNames: {
      for (final year in termNames.entries)
        for (final name in year.value.entries)
          timetableTermSyncKey(year.key, name.key): TimetableSyncValue(
            name.value,
            null,
            '',
          ),
    },
    termPeriods: {
      for (final year in termPeriods.entries)
        for (final period in year.value.entries)
          timetableTermSyncKey(year.key, period.key): TimetableSyncValue(
            period.value.toJson(),
            null,
            '',
          ),
    },
    activeTerm: TimetableSyncValue(
      {'academicYear': activeYear, 'semester': activeSemester},
      null,
      '',
    ),
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'courses': courses.map((key, value) => MapEntry(key, value.toJson())),
    'termNames': termNames.map((key, value) => MapEntry(key, value.toJson())),
    'termPeriods': termPeriods.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
    'activeTerm': activeTerm?.toJson(),
  };

  bool sameAs(TimetableSyncDocument other) =>
      canonicalSyncJson(toJson()) == canonicalSyncJson(other.toJson());

  TimetableSyncDocument merge(TimetableSyncDocument other) =>
      TimetableSyncDocument.records(
        courses: _mergeValues(courses, other.courses),
        termNames: _mergeValues(termNames, other.termNames),
        termPeriods: _mergeValues(termPeriods, other.termPeriods),
        activeTerm: _winner(activeTerm, other.activeTerm),
      );

  DateTime? get latestChangedAt {
    DateTime? latest;
    for (final record in [
      ...courses.values,
      ...termNames.values,
      ...termPeriods.values,
      ?activeTerm,
    ]) {
      final date = record.changedAt;
      if (date != null && (latest == null || date.isAfter(latest))) {
        latest = date;
      }
    }
    return latest;
  }

  TimetableSyncDocument recordChanges({
    required List<TimetableClass> before,
    required List<TimetableClass> after,
    required Map<int, Map<String, String>> beforeNames,
    required Map<int, Map<String, String>> afterNames,
    required Map<int, Map<String, TimetablePeriod>> beforePeriods,
    required Map<int, Map<String, TimetablePeriod>> afterPeriods,
    required DateTime changedAt,
    required String deviceId,
  }) {
    final oldCourses = {
      for (final course in before)
        timetableCourseSyncKey(course): _courseValue(course),
    };
    final nextCourses = {
      for (final course in after)
        timetableCourseSyncKey(course): _courseValue(course),
    };
    final changedCourses = {...courses};
    for (final key in {...oldCourses.keys, ...nextCourses.keys}) {
      if (canonicalSyncJson(oldCourses[key]) !=
          canonicalSyncJson(nextCourses[key])) {
        changedCourses[key] = TimetableSyncValue(
          nextCourses[key],
          changedAt,
          deviceId,
        );
      }
    }
    Map<String, String> flatten(Map<int, Map<String, String>> names) => {
      for (final year in names.entries)
        for (final name in year.value.entries)
          timetableTermSyncKey(year.key, name.key): name.value,
    };
    final oldNames = flatten(beforeNames), nextNames = flatten(afterNames);
    final changedNames = {...termNames};
    for (final key in {...oldNames.keys, ...nextNames.keys}) {
      if (oldNames[key] != nextNames[key]) {
        changedNames[key] = TimetableSyncValue(
          nextNames[key],
          changedAt,
          deviceId,
        );
      }
    }
    Map<String, Object?> flattenPeriods(
      Map<int, Map<String, TimetablePeriod>> periods,
    ) => {
      for (final year in periods.entries)
        for (final period in year.value.entries)
          timetableTermSyncKey(year.key, period.key): period.value.toJson(),
    };
    final oldPeriods = flattenPeriods(beforePeriods);
    final nextPeriods = flattenPeriods(afterPeriods);
    final changedPeriods = {...termPeriods};
    for (final key in {...oldPeriods.keys, ...nextPeriods.keys}) {
      if (canonicalSyncJson(oldPeriods[key]) !=
          canonicalSyncJson(nextPeriods[key])) {
        changedPeriods[key] = TimetableSyncValue(
          nextPeriods[key],
          changedAt,
          deviceId,
        );
      }
    }
    return TimetableSyncDocument.records(
      courses: changedCourses,
      termNames: changedNames,
      termPeriods: changedPeriods,
      activeTerm: activeTerm,
    );
  }

  List<TimetableClass> materializeClasses({
    List<TimetableClass> existing = const [],
  }) {
    final ids = {
      for (final course in existing) timetableCourseSyncKey(course): course.id,
    };
    final keys = courses.keys.toList()..sort();
    return [
      for (final key in keys)
        if (courses[key]!.value != null)
          TimetableClass.fromJson({
            ...Map<String, dynamic>.from(courses[key]!.value as Map),
            if (ids.containsKey(key)) 'id': ids[key],
          }),
    ];
  }

  Map<int, Map<String, String>> materializeNames() {
    final result = <int, Map<String, String>>{};
    for (final entry in termNames.entries) {
      if (entry.value.value == null) continue;
      final term = _readTermKey(entry.key);
      (result[term.$1] ??= {})[term.$2] = entry.value.value as String;
    }
    return result;
  }

  Map<int, Map<String, TimetablePeriod>> materializePeriods() {
    final result = <int, Map<String, TimetablePeriod>>{};
    for (final entry in termPeriods.entries) {
      if (entry.value.value == null) continue;
      final term = _readTermKey(entry.key);
      (result[term.$1] ??= {})[term.$2] = TimetablePeriod.fromJson(
        Map<String, dynamic>.from(entry.value.value as Map),
      );
    }
    return result;
  }

  int? get activeYear => (activeTerm?.value as Map?)?['academicYear'] as int?;
  String? get activeSemester =>
      (activeTerm?.value as Map?)?['semester'] as String?;

  void _validate() {
    for (final entry in courses.entries) {
      if (entry.value.value == null) {
        if (entry.key.startsWith('manual/')) {
          if (entry.key.length <= 'manual/'.length) {
            throw const FormatException('Invalid deleted course identity');
          }
        } else if (entry.key.startsWith('source/')) {
          final identity =
              jsonDecode(entry.key.substring('source/'.length)) as List;
          if (identity.length != 3 ||
              identity[2] is! String ||
              (identity[2] as String).isEmpty) {
            throw const FormatException('Invalid deleted source identity');
          }
          _validateTerm(identity[0], identity[1]);
          if (entry.key != 'source/${jsonEncode(identity)}') {
            throw const FormatException('Noncanonical source identity');
          }
        } else {
          throw const FormatException('Invalid deleted course identity');
        }
        continue;
      }
      final course = TimetableClass.fromJson(
        Map<String, dynamic>.from(entry.value.value as Map),
      );
      if (!course.isValid ||
          course.semester.trim().isEmpty ||
          course.sourceId?.isEmpty == true ||
          entry.key != timetableCourseSyncKey(course) ||
          (course.sourceId != null && course.id != entry.key)) {
        throw const FormatException('Invalid synced course');
      }
      for (final key in course.overrides.keys) {
        final slash = key.lastIndexOf('/');
        final date = slash < 0
            ? null
            : DateTime.tryParse(key.substring(slash + 1));
        final meetings = course.meetings.where(
          (meeting) => meeting.id == key.substring(0, slash < 0 ? 0 : slash),
        );
        if (date == null ||
            key.substring(slash + 1) != timetableDateKey(date) ||
            meetings.isEmpty ||
            meetings.single.weekday != date.weekday) {
          throw const FormatException('Invalid synced class occurrence');
        }
      }
    }
    for (final entry in termNames.entries) {
      _readTermKey(entry.key);
      final name = entry.value.value;
      if (name != null &&
          (name is! String ||
              name.trim().isEmpty ||
              name != name.trim() ||
              name.characters.length > 60)) {
        throw const FormatException('Invalid synced timetable name');
      }
    }
    for (final entry in termPeriods.entries) {
      _readTermKey(entry.key);
      if (entry.value.value != null) {
        TimetablePeriod.fromJson(
          Map<String, dynamic>.from(entry.value.value as Map),
        );
      }
    }
    if (activeTerm != null) {
      final term = activeTerm!.value as Map;
      _validateTerm(term['academicYear'], term['semester']);
    }
    final ids = materializeClasses().map((course) => course.id).toList();
    if (ids.toSet().length != ids.length) {
      throw const FormatException('Duplicate synced course IDs');
    }
  }
}

(int, String) _readTermKey(String key) {
  final term = jsonDecode(key) as List;
  if (term.length != 2 || jsonEncode(term) != key) {
    throw const FormatException('Invalid timetable term key');
  }
  _validateTerm(term[0], term[1]);
  return (term[0] as int, term[1] as String);
}

void _validateTerm(Object? year, Object? semester) {
  if (year is! int ||
      year < 1900 ||
      year > 9999 ||
      semester is! String ||
      semester.trim().isEmpty) {
    throw const FormatException('Invalid timetable term');
  }
}

TimetableSyncValue? _winner(TimetableSyncValue? a, TimetableSyncValue? b) =>
    a == null
    ? b
    : b == null || a.compareTo(b) >= 0
    ? a
    : b;

Map<String, TimetableSyncValue> _mergeValues(
  Map<String, TimetableSyncValue> a,
  Map<String, TimetableSyncValue> b,
) => {
  for (final key in {...a.keys, ...b.keys}) key: _winner(a[key], b[key])!,
};

Object? _freeze(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.unmodifiable(
      value.map((key, value) => MapEntry(key as String, _freeze(value))),
    );
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  throw const FormatException('Invalid timetable JSON value');
}
