import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../core/sync/sync_version.dart';
import '../domain/timetable.dart';
import '../domain/timetable_term.dart';
import 'timetable_sync_document.dart';

/// Offline cache and outbox for the separate timetable Drive document.
class TimetableStore extends ChangeNotifier {
  TimetableStore(
    this._preferences, {
    DateTime Function()? now,
    String? deviceId,
  }) : _now = now ?? DateTime.now,
       _injectedDeviceId = deviceId {
    _load();
  }
  static const storageKey = 'daily.timetable.v1';
  final SharedPreferences _preferences;
  final DateTime Function() _now;
  final String? _injectedDeviceId;
  String? _deviceId;
  String? _persistedRaw;
  TimetableSyncDocument _document = const TimetableSyncDocument();
  bool _pendingSync = false;
  int _generation = 0;
  final localRevisionNotifier = ValueNotifier<int>(0);
  List<TimetableClass> _classes = const [];
  int? _activeYear;
  String? _activeSemester;
  Map<int, Map<String, String>> _termNames = {};
  Map<int, Map<String, TimetablePeriod>> _termPeriods = {};
  Map<String, TimetablePeriod> _periodDefaults = const {};
  Object? loadError;
  Future<void> _tail = Future.value();
  List<TimetableClass> get classes => List.unmodifiable(_classes);
  int get activeYear => _activeYear ?? _now().year;
  String get activeSemester =>
      _activeSemester ?? (_now().month < 7 ? '1' : '2');
  bool get hasPendingSync => loadError != null || _pendingSync;
  TimetableSyncDocument syncDocument() {
    _requireReadable();
    return _document;
  }

  String? get activeName => _termNames[activeYear]?[activeSemester];
  TimetablePeriod? get activePeriod => periodFor(activeYear, activeSemester);
  TimetablePeriod? periodFor(int year, String semester) =>
      _termPeriods[year]?[semester];

  List<TimetableTerm> get terms {
    final keys = <(int, String)>{
      for (final course in _classes) (course.academicYear, course.semester),
      for (final year in _termNames.entries)
        for (final semester in year.value.keys) (year.key, semester),
      for (final year in _termPeriods.entries)
        for (final semester in year.value.keys) (year.key, semester),
    };
    final result = [
      for (final (year, semester) in keys)
        TimetableTerm(
          year: year,
          semester: semester,
          name: _termNames[year]?[semester],
          courseCount: _classes
              .where((c) => c.academicYear == year && c.semester == semester)
              .length,
          period: periodFor(year, semester),
        ),
    ];
    result.sort((a, b) {
      final year = b.year.compareTo(a.year);
      if (year != 0) return year;
      final semester = _semesterOrder(
        b.semester,
      ).compareTo(_semesterOrder(a.semester));
      return semester != 0 ? semester : b.semester.compareTo(a.semester);
    });
    return List.unmodifiable(result);
  }

  List<TimetableClass> get activeClasses => _classes
      .where(
        (c) => c.academicYear == activeYear && c.semester == activeSemester,
      )
      .toList();
  void _load() {
    try {
      final raw = _preferences.getString(storageKey);
      if (raw == null) return;
      _persistedRaw = raw;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['version'] != 1) {
        throw const FormatException('Unsupported timetable version');
      }
      final courses = (json['classes'] as List)
          .map(
            (c) => TimetableClass.fromJson(Map<String, dynamic>.from(c as Map)),
          )
          .toList();
      if (courses.any((c) => !c.isValid) ||
          courses.map((c) => c.id).toSet().length != courses.length ||
          courses.map(timetableCourseSyncKey).toSet().length !=
              courses.length) {
        throw const FormatException('Invalid timetable data');
      }
      final year = json['activeYear'] as int;
      final semester = json['activeSemester'] as String;
      if (year < 1900 || year > 9999 || semester.trim().isEmpty) {
        throw const FormatException('Invalid active term');
      }
      final names = <int, Map<String, String>>{};
      if (json.containsKey('termNames')) {
        final years = json['termNames'] as Map<String, dynamic>;
        for (final entry in years.entries) {
          final nameYear = int.tryParse(entry.key);
          if (nameYear == null ||
              nameYear < 1900 ||
              nameYear > 9999 ||
              entry.key != nameYear.toString()) {
            throw const FormatException('Invalid timetable name year');
          }
          final semesters = entry.value as Map<String, dynamic>;
          final yearNames = <String, String>{};
          for (final nameEntry in semesters.entries) {
            final name = nameEntry.value as String;
            if (nameEntry.key.trim().isEmpty ||
                name.trim().isEmpty ||
                name != name.trim() ||
                name.characters.length > 60) {
              throw const FormatException('Invalid timetable name');
            }
            yearNames[nameEntry.key] = name;
          }
          names[nameYear] = yearNames;
        }
      }
      final periods = <int, Map<String, TimetablePeriod>>{};
      if (json.containsKey('termPeriods')) {
        final years = json['termPeriods'] as Map<String, dynamic>;
        for (final entry in years.entries) {
          final periodYear = int.tryParse(entry.key);
          if (periodYear == null ||
              periodYear < 1900 ||
              periodYear > 9999 ||
              entry.key != periodYear.toString()) {
            throw const FormatException('Invalid timetable period year');
          }
          final semesters = entry.value as Map<String, dynamic>;
          final yearPeriods = <String, TimetablePeriod>{};
          for (final periodEntry in semesters.entries) {
            if (periodEntry.key.trim().isEmpty) {
              throw const FormatException('Invalid timetable period semester');
            }
            yearPeriods[periodEntry.key] = TimetablePeriod.fromJson(
              Map<String, dynamic>.from(periodEntry.value as Map),
            );
          }
          periods[periodYear] = yearPeriods;
        }
      }
      final TimetableSyncDocument document;
      bool pending;
      String? device;
      if (json.containsKey('sync')) {
        final sync = Map<String, dynamic>.from(json['sync'] as Map);
        document = TimetableSyncDocument.fromJson(
          Map<String, dynamic>.from(sync['document'] as Map),
        );
        pending = sync['pending'] as bool;
        device = sync['deviceId'] as String;
        if (device.isEmpty ||
            !_sameContent(document, courses, names, periods, year, semester)) {
          throw const FormatException('Invalid timetable cache metadata');
        }
      } else {
        // Existing content has no known change time. Do not make migration or
        // upload time win over a real change made on another device.
        document = TimetableSyncDocument.legacy(
          courses: courses,
          termNames: names,
          termPeriods: periods,
          activeYear: year,
          activeSemester: semester,
        );
        pending = !document.isEmpty;
      }
      _classes = courses;
      _activeYear = year;
      _activeSemester = semester;
      _termNames = names;
      _termPeriods = periods;
      _document = document;
      _pendingSync = pending;
      _deviceId = device;
    } catch (error) {
      loadError = error;
    }
  }

  Future<void> _mutate(
    List<TimetableClass> Function() update, {
    int? year,
    String? semester,
    Map<int, Map<String, String>> Function()? updateNames,
    Map<int, Map<String, TimetablePeriod>> Function()? updatePeriods,
  }) {
    return _enqueue((validate) async {
      _requireReadable();
      final next = update();
      final nextYear = year ?? activeYear;
      final nextSemester = semester ?? activeSemester;
      final nextNames = updateNames?.call() ?? _termNames;
      final nextPeriods = updatePeriods?.call() ?? _termPeriods;
      final device = _writerId();
      final document = _withDefaultPeriods(
        _document.recordChanges(
          before: _classes,
          after: next,
          beforeNames: _termNames,
          afterNames: nextNames,
          beforePeriods: _termPeriods,
          afterPeriods: nextPeriods,
          changedAt: _nextTimestamp(),
          deviceId: device,
        ),
      );
      final changed = !document.sameAs(_document);
      // Choosing an already date-derived default still makes that selection
      // explicit on this device, without creating any cloud register.
      final localChanged =
          changed ||
          (year != null &&
              (_activeYear != nextYear || _activeSemester != nextSemester));
      if (!localChanged) return;
      await _persist(
        document,
        classes: next,
        names: nextNames,
        periods: document.materializePeriods(),
        year: nextYear,
        semester: nextSemester,
        pending: changed || _pendingSync,
        device: device,
        validate: validate,
      );
      if (changed) localRevisionNotifier.value++;
    });
  }

  String _writerId() {
    final writer =
        _injectedDeviceId ?? _deviceId ?? _preferences.getString('deviceId');
    if (writer != null && writer.isNotEmpty) return writer;
    return const Uuid().v4();
  }

  DateTime _nextTimestamp() {
    final now = _now().toUtc();
    final latest = _document.latestChangedAt;
    return latest != null && !now.isAfter(latest)
        ? latest.add(const Duration(microseconds: 1))
        : now;
  }

  void _requireReadable() {
    if (loadError != null) {
      throw StateError(
        'Existing timetable could not be read; refusing to overwrite it',
      );
    }
  }

  Future<void> _enqueue(
    Future<void> Function(VoidCallback validate) action, {
    VoidCallback? validateSession,
  }) {
    final generation = _generation;
    void validate() {
      if (generation != _generation) {
        throw StateError('Timetable session changed');
      }
      validateSession?.call();
    }

    final operation = _tail.then((_) async {
      validate();
      await action(validate);
    });
    _tail = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  Future<void> _persist(
    TimetableSyncDocument document, {
    required List<TimetableClass> classes,
    required Map<int, Map<String, String>> names,
    required Map<int, Map<String, TimetablePeriod>> periods,
    required int year,
    required String semester,
    required bool pending,
    required String device,
    required VoidCallback validate,
  }) async {
    final raw = canonicalSyncJson({
      'version': 1,
      'activeYear': year,
      'activeSemester': semester,
      'classes': classes.map((c) => c.toJson()).toList(),
      'termNames': names.map((year, names) => MapEntry('$year', names)),
      'termPeriods': periods.map(
        (year, periods) => MapEntry(
          '$year',
          periods.map(
            (semester, period) => MapEntry(semester, period.toJson()),
          ),
        ),
      ),
      'sync': {
        'document': document.toJson(),
        'pending': pending,
        'deviceId': device,
      },
    });
    if (raw == _persistedRaw) return;
    validate();
    try {
      final saved = await _preferences.setString(storageKey, raw);
      if (!saved) throw StateError('Timetable save failed');
      validate();
    } catch (_) {
      // SharedPreferences updates its memory cache before the platform write.
      // Restore both the cached old value and, where possible, its disk value.
      await _restorePreference(_persistedRaw);
      rethrow;
    }
    _persistedRaw = raw;
    _classes = classes;
    _activeYear = year;
    _activeSemester = semester;
    _termNames = names;
    _termPeriods = periods;
    _document = document;
    _pendingSync = pending;
    _deviceId = device;
    notifyListeners();
  }

  Future<void> mergeSyncDocument(
    TimetableSyncDocument remote, {
    VoidCallback? validateSession,
  }) => _mergeAndPersist(remote, validateSession: validateSession);

  Future<void> acknowledgeSyncDocument(
    TimetableSyncDocument uploaded, {
    VoidCallback? validateSession,
  }) => _mergeAndPersist(uploaded, validateSession: validateSession);

  Future<void> _mergeAndPersist(
    TimetableSyncDocument remote, {
    VoidCallback? validateSession,
  }) => _enqueue((validate) async {
    _requireReadable();
    final merged = _withDefaultPeriods(_document.merge(remote));
    await _persist(
      merged,
      classes: merged.materializeClasses(existing: _classes),
      names: merged.materializeNames(),
      periods: merged.materializePeriods(),
      year: activeYear,
      semester: activeSemester,
      pending: !merged.sameAs(remote),
      device: _writerId(),
      validate: validate,
    );
  }, validateSession: validateSession);

  /// Cancels queued or in-flight work belonging to the previous account session.
  void invalidate() => _generation++;

  /// Clears only this device's cache; it must never emit cloud tombstones.
  Future<void> clearLocal() {
    invalidate();
    return _enqueue((validate) async {
      validate();
      final previous = _preferences.get(storageKey);
      try {
        final removed = await _preferences.remove(storageKey);
        if (!removed) throw StateError('Could not clear timetable cache');
        validate();
      } catch (_) {
        await _restorePreference(previous);
        rethrow;
      }
      _classes = const [];
      _activeYear = null;
      _activeSemester = null;
      _termNames = {};
      _termPeriods = {};
      _document = const TimetableSyncDocument();
      _pendingSync = false;
      _deviceId = null;
      _persistedRaw = null;
      loadError = null;
      notifyListeners();
    });
  }

  Future<void> _restorePreference(Object? value) async {
    try {
      switch (value) {
        case null:
          await _preferences.remove(storageKey);
        case String value:
          await _preferences.setString(storageKey, value);
        case int value:
          await _preferences.setInt(storageKey, value);
        case double value:
          await _preferences.setDouble(storageKey, value);
        case bool value:
          await _preferences.setBool(storageKey, value);
        case List<String> value:
          await _preferences.setStringList(storageKey, value);
      }
    } catch (_) {
      // The failed operation still propagates. SharedPreferences restores its
      // in-memory old value before attempting this best-effort native rollback.
    }
  }

  @override
  void dispose() {
    invalidate();
    localRevisionNotifier.dispose();
    super.dispose();
  }

  Future<void> selectTerm(int year, String semester) {
    _validateTerm(year, semester);
    return _enqueue((validate) async {
      _requireReadable();
      if (_activeYear == year && _activeSemester == semester) return;
      await _persist(
        _document,
        classes: _classes,
        names: _termNames,
        periods: _termPeriods,
        year: year,
        semester: semester,
        pending: _pendingSync,
        device: _writerId(),
        validate: validate,
      );
    });
  }

  /// Persists an empty timetable through its required period and selects it on
  /// this device in the same write, so failed creation cannot move the UI.
  Future<void> createTerm(
    int year,
    String semester, {
    String? name,
    required TimetablePeriod period,
  }) {
    _validateTerm(year, semester);
    final trimmedName = name?.trim();
    if (trimmedName != null &&
        (trimmedName.isEmpty || trimmedName.characters.length > 60)) {
      throw ArgumentError('Timetable name must contain 1 to 60 characters');
    }
    return _mutate(
      () {
        if (terms.any(
          (term) => term.year == year && term.semester == semester,
        )) {
          throw StateError('This timetable already exists');
        }
        return [..._classes];
      },
      year: year,
      semester: semester,
      updateNames: trimmedName == null
          ? null
          : () => {
              ..._termNames,
              year: {...?_termNames[year], semester: trimmedName},
            },
      updatePeriods: () => {
        ..._termPeriods,
        year: {...?_termPeriods[year], semester: period},
      },
    );
  }

  Future<void> setTermPeriod(
    int year,
    String semester,
    TimetablePeriod period,
  ) {
    _validateTerm(year, semester);
    return _mutate(
      () => [..._classes],
      updatePeriods: () => {
        ..._termPeriods,
        year: {...?_termPeriods[year], semester: period},
      },
    );
  }

  /// Official known ranges are migration baselines, not new user edits. A
  /// remote explicit edit (or deletion) always wins over this untimed value.
  Future<void> seedTermPeriods(Map<String, TimetablePeriod> defaults) =>
      _enqueue((validate) async {
        _requireReadable();
        _periodDefaults = Map.unmodifiable(defaults);
        final document = _withDefaultPeriods(_document);
        if (document.sameAs(_document)) return;
        await _persist(
          document,
          classes: _classes,
          names: _termNames,
          periods: document.materializePeriods(),
          year: activeYear,
          semester: activeSemester,
          pending: true,
          device: _writerId(),
          validate: validate,
        );
        localRevisionNotifier.value++;
      });

  TimetableSyncDocument _withDefaultPeriods(TimetableSyncDocument document) {
    if (_periodDefaults.isEmpty) return document;
    final keys = <String>{
      for (final course in document.materializeClasses())
        timetableTermSyncKey(course.academicYear, course.semester),
      for (final entry in document.termNames.entries)
        if (entry.value.value != null) entry.key,
    };
    final records = {...document.termPeriods};
    for (final key in keys) {
      final period = _periodDefaults[key];
      if (period != null && !records.containsKey(key)) {
        records[key] = TimetableSyncValue(period.toJson(), null, '');
      }
    }
    if (records.length == document.termPeriods.length) return document;
    return TimetableSyncDocument.records(
      courses: document.courses,
      termNames: document.termNames,
      termPeriods: records,
      activeTerm: document.activeTerm,
    );
  }

  Future<void> renameActive(String name) =>
      _rename(name, () => (activeYear, activeSemester));

  Future<void> renameTerm(int year, String semester, String name) {
    if (year < 1900 || year > 9999 || semester.trim().isEmpty) {
      throw ArgumentError('Invalid term');
    }
    return _rename(name, () => (year, semester));
  }

  Future<void> _rename(String name, (int, String) Function() target) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.characters.length > 60) {
      throw ArgumentError('Timetable name must contain 1 to 60 characters');
    }
    return _mutate(
      () => [..._classes],
      updateNames: () {
        final (year, semester) = target();
        return {
          ..._termNames,
          year: {...?_termNames[year], semester: trimmed},
        };
      },
    );
  }

  Future<void> save(TimetableClass course) => _mutate(() {
    if (!course.isValid) throw ArgumentError('Invalid class');
    if (course.sourceId != null &&
        _classes.any(
          (c) =>
              c.id != course.id &&
              c.sourceId == course.sourceId &&
              c.academicYear == course.academicYear &&
              c.semester == course.semester,
        )) {
      throw StateError('This section is already in the timetable');
    }
    return [..._classes.where((c) => c.id != course.id), course];
  });
  Future<void> remove(String id) =>
      _mutate(() => _classes.where((c) => c.id != id).toList());
  Future<void> clearActive() => _mutate(
    () => _classes
        .where(
          (c) => c.academicYear != activeYear || c.semester != activeSemester,
        )
        .toList(),
  );
  Future<void> clearTerm(int year, String semester) {
    if (year < 1900 || year > 9999 || semester.trim().isEmpty) {
      throw ArgumentError('Invalid term');
    }
    return _mutate(
      () => _classes
          .where((c) => c.academicYear != year || c.semester != semester)
          .toList(),
    );
  }

  Future<void> setOverride(
    String courseId,
    String meetingId,
    DateTime date,
    LectureMode? mode,
  ) => _mutate(() {
    final course = _classes.firstWhere((c) => c.id == courseId);
    final meeting = course.meetings.firstWhere((m) => m.id == meetingId);
    if (date.weekday != meeting.weekday) {
      throw ArgumentError('Date does not match the meeting');
    }
    return [
      for (final c in _classes)
        if (c.id == course.id) c.withOverride(meeting, date, mode) else c,
    ];
  });
}

bool _sameContent(
  TimetableSyncDocument document,
  List<TimetableClass> courses,
  Map<int, Map<String, String>> names,
  Map<int, Map<String, TimetablePeriod>> periods,
  int year,
  String semester,
) {
  // Compare using sync identities so device-local imported editor IDs may differ.
  final legacy = TimetableSyncDocument.legacy(
    courses: courses,
    termNames: names,
    termPeriods: periods,
    activeYear: year,
    activeSemester: semester,
  );
  Map<String, Object?> liveValues(Map<String, TimetableSyncValue> records) => {
    for (final entry in records.entries)
      if (entry.value.value != null) entry.key: entry.value.value,
  };
  return canonicalSyncJson(liveValues(document.courses)) ==
          canonicalSyncJson(liveValues(legacy.courses)) &&
      canonicalSyncJson(liveValues(document.termNames)) ==
          canonicalSyncJson(liveValues(legacy.termNames)) &&
      canonicalSyncJson(liveValues(document.termPeriods)) ==
          canonicalSyncJson(liveValues(legacy.termPeriods));
}

void _validateTerm(int year, String semester) {
  if (year < 1900 || year > 9999 || semester.trim().isEmpty) {
    throw ArgumentError('Invalid term');
  }
}

int _semesterOrder(String semester) {
  final name = semester.toLowerCase();
  if (name.contains('겨울') || name == 'winter') return 4;
  if (name == '2') return 3;
  if (name.contains('여름') || name == 'summer') return 2;
  if (name == '1') return 1;
  return 0;
}
