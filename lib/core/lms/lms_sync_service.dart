import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../features/events/application/event_command_service.dart';
import '../../features/events/domain/calendar_event.dart';
import '../../features/events/domain/event_category.dart';
import '../../features/events/domain/event_repository.dart';
import '../../features/events/domain/recurrence_rule.dart';
import '../settings/settings_repository.dart';
import 'coursemos_parser.dart';
import 'lms_models.dart';

class LmsSyncSession {
  LmsSyncSession({
    required this.schoolId,
    required String ownerId,
    required this.lmsUserId,
    required this.baseUrl,
    required this.generation,
  }) : ownerId = normalizeLmsOwner(ownerId);
  final String schoolId;
  final String ownerId;
  final String lmsUserId;
  final Uri baseUrl;
  final int generation;

  bool sameAs(LmsSyncSession? other) =>
      other != null &&
      schoolId == other.schoolId &&
      ownerId == other.ownerId &&
      lmsUserId == other.lmsUserId &&
      baseUrl == other.baseUrl &&
      generation == other.generation;
}

enum LmsSyncState { idle, loading, ready, fallback, needsLogin, unsupported }

class LmsSyncResult {
  const LmsSyncResult({
    required this.courses,
    required this.activities,
    required this.unscheduled,
    required this.added,
    required this.updated,
    required this.deleted,
    required this.unchanged,
  });
  final int courses,
      activities,
      unscheduled,
      added,
      updated,
      deleted,
      unchanged;
}

typedef LmsFetchHtml = Future<LmsHtmlPage> Function(Uri url);

/// A complete read of the dashboard and both indexes precedes every mutation.
/// Authentication, lifecycle scheduling and browser ownership stay with the host.
class LmsSyncService extends ChangeNotifier {
  LmsSyncService({
    required SettingsRepository settings,
    required EventRepository repository,
    required EventCommandService commands,
    required LmsFetchHtml fetchHtml,
    required LmsSyncSession? Function() readSession,
    bool Function(Object error)? isAuthenticationError,
    DateTime Function()? now,
    Future<void> Function(Duration duration)? wait,
    CoursemosParser parser = const CoursemosParser(),
  }) : _settings = settings,
       _repository = repository,
       _commands = commands,
       _fetchHtml = fetchHtml,
       _readSession = readSession,
       _isAuthenticationError = isAuthenticationError ?? ((_) => false),
       _now = now ?? DateTime.now,
       _wait = wait ?? Future<void>.delayed,
       _parser = parser;

  final SettingsRepository _settings;
  final EventRepository _repository;
  final EventCommandService _commands;
  final LmsFetchHtml _fetchHtml;
  final LmsSyncSession? Function() _readSession;
  final bool Function(Object) _isAuthenticationError;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _wait;
  final CoursemosParser _parser;

  static const requestSpacing = Duration(milliseconds: 400);
  static const refreshInterval = Duration(minutes: 5);
  LmsSyncState _state = LmsSyncState.idle;
  LmsSyncState get state => _state;
  String? errorCode;
  DateTime? lastSuccess;
  DateTime? retryAfter;
  LmsSyncResult? lastResult;
  List<CoursemosActivity> _activities = const [];
  List<CoursemosActivity> get activities => _activities;
  Future<LmsSyncResult?>? _inFlight;
  LmsSyncSession? _activeSession;
  LmsSyncSession? _displaySession;
  LmsSyncSession? _lastSession;
  int _epoch = 0;
  int _activeEpoch = 0;
  int _failures = 0;
  DateTime? _lastResponseAt;
  Set<String>? _visibleIds;
  bool _disposed = false;

  static String eventId(LmsEventMetadata metadata) =>
      'lms:${sha256.convert(utf8.encode(jsonEncode([metadata.provider, metadata.schoolId, metadata.ownerId, metadata.lmsUserId, metadata.courseId, metadata.activityType, metadata.activityId])))}';

  bool _ownerMatches(LmsSyncSession session) =>
      session.ownerId.isNotEmpty &&
      normalizeLmsOwner(_settings.dailyAccount()?.googleAccount?.email ?? '') ==
          session.ownerId;

  bool _current(LmsSyncSession session, int epoch) =>
      !_disposed &&
      epoch == _epoch &&
      session.sameAs(_readSession()) &&
      _ownerMatches(session);

  void _check(LmsSyncSession session, int epoch) {
    if (!_current(session, epoch)) throw const _Cancelled();
  }

  /// No LMS cache is shown during initial restoration or an active fresh read.
  /// A failed network/parse read may show the same verified owner's last data.
  bool isEventVisible(CalendarEvent event) {
    final owner = _settings.dailyAccount()?.googleAccount?.email;
    if (!event.isVisibleToOwner(owner)) return false;
    if (event.lms == null) return true;
    final session = _readSession();
    if (session == null ||
        !_ownerMatches(session) ||
        _displaySession?.sameAs(session) != true ||
        (_state != LmsSyncState.ready && _state != LmsSyncState.fallback)) {
      return false;
    }
    return _managed(event, session) &&
        (_visibleIds == null || _visibleIds!.contains(event.id));
  }

  bool _managed(CalendarEvent event, LmsSyncSession session) {
    final metadata = event.lms;
    return metadata != null &&
        metadata.provider == 'coursemos' &&
        metadata.schoolId == session.schoolId &&
        metadata.ownerId == session.ownerId &&
        metadata.lmsUserId == session.lmsUserId &&
        const {'assignment', 'quiz'}.contains(metadata.activityType);
  }

  /// Called when the browser or Google account changes. It does not delete data.
  void invalidateSession() {
    _epoch++;
    _state = _readSession() == null
        ? LmsSyncState.needsLogin
        : LmsSyncState.idle;
    _displaySession = null;
    _lastSession = null;
    _visibleIds = null;
    _activities = const [];
    _failures = 0;
    retryAfter = null;
    lastSuccess = null;
    lastResult = null;
    errorCode = null;
    _notify();
  }

  /// The host may supply a previously verified, locally retained principal only
  /// after browser restoration failed. An explicit login failure hides its cache.
  void markRestoreFailed({bool authenticationRequired = false}) {
    _epoch++;
    final session = _readSession();
    if (session == null || !_ownerMatches(session) || authenticationRequired) {
      _state = LmsSyncState.needsLogin;
      _displaySession = null;
      errorCode = 'authentication_required';
    } else if (session.schoolId != 'smu' ||
        session.baseUrl.origin != 'https://ecampus.smu.ac.kr') {
      _state = LmsSyncState.unsupported;
      _displaySession = null;
      errorCode = 'unsupported';
    } else {
      if (_lastSession?.sameAs(session) != true) {
        _visibleIds = null;
        _activities = const [];
        lastSuccess = _settings.lmsLastSuccess(
          ownerId: session.ownerId,
          schoolId: session.schoolId,
          lmsUserId: session.lmsUserId,
        );
      }
      _state = LmsSyncState.fallback;
      _displaySession = session;
      _lastSession = session;
      errorCode = 'restoration_failed';
    }
    _notify();
  }

  Future<LmsSyncResult?> refresh({bool force = false}) {
    if (_disposed) return Future.value();
    final session = _readSession();
    final running = _inFlight;
    if (running != null) {
      if (_activeEpoch == _epoch && _activeSession?.sameAs(session) == true) {
        return running;
      }
      // A new principal waits for the old GET to finish, then receives its own read.
      return running.then((_) => refresh(force: force));
    }
    if (session == null ||
        session.lmsUserId.isEmpty ||
        !_ownerMatches(session)) {
      _state = LmsSyncState.needsLogin;
      _displaySession = null;
      _notify();
      return Future.value();
    }
    if (session.schoolId != 'smu' ||
        session.baseUrl.origin != 'https://ecampus.smu.ac.kr') {
      _state = LmsSyncState.unsupported;
      _displaySession = null;
      _notify();
      return Future.value();
    }
    if (_lastSession?.sameAs(session) != true) {
      _visibleIds = null;
      _activities = const [];
      _failures = 0;
      retryAfter = null;
      lastSuccess = _settings.lmsLastSuccess(
        ownerId: session.ownerId,
        schoolId: session.schoolId,
        lmsUserId: session.lmsUserId,
      );
      lastResult = null;
    }
    _lastSession = session;
    if (!force && retryAfter != null && _now().isBefore(retryAfter!)) {
      return Future.value();
    }
    if (!force &&
        _state == LmsSyncState.ready &&
        _displaySession?.sameAs(session) == true &&
        lastSuccess != null &&
        _now().difference(lastSuccess!) < refreshInterval) {
      return Future.value(lastResult);
    }
    final completer = Completer<LmsSyncResult?>();
    final epoch = _epoch;
    _inFlight = completer.future;
    _activeSession = session;
    _activeEpoch = epoch;
    _state = LmsSyncState.loading;
    errorCode = null;
    _notify();
    unawaited(() async {
      try {
        final result = await _run(session, epoch);
        _inFlight = null;
        completer.complete(result);
      } on Object catch (error, stack) {
        _inFlight = null;
        completer.completeError(error, stack);
      }
    }());
    return completer.future;
  }

  Future<LmsHtmlPage> _read(Uri url, LmsSyncSession session, int epoch) async {
    _check(session, epoch);
    final previous = _lastResponseAt;
    if (previous != null) {
      final remaining = requestSpacing - _now().difference(previous);
      if (remaining > Duration.zero) await _wait(remaining);
    }
    _check(session, epoch);
    try {
      final page = await _fetchHtml(url);
      _check(session, epoch);
      if (page.url.origin != session.baseUrl.origin) {
        throw const CoursemosParseException('unexpected_response_origin');
      }
      return page;
    } finally {
      _lastResponseAt = _now();
    }
  }

  Future<LmsSyncResult?> _run(LmsSyncSession session, int epoch) async {
    try {
      final dashboard = await _read(
        session.baseUrl.resolve('/'),
        session,
        epoch,
      );
      final courses = _parser.courses(dashboard);
      final fetched = <CoursemosActivity>[];
      for (final course in courses) {
        for (final type in const ['assignment', 'quiz']) {
          final module = type == 'assignment' ? 'assign' : 'quiz';
          final page = await _read(
            session.baseUrl.resolve('/mod/$module/index.php?id=${course.id}'),
            session,
            epoch,
          );
          fetched.addAll(
            _parser.activities(page, course: course, type: type).activities,
          );
        }
      }
      _check(session, epoch);
      final result = await _apply(session, epoch, courses.length, fetched);
      _check(session, epoch);
      final checkedAt = _now().toUtc();
      await _settings.saveLmsLastSuccess(
        checkedAt,
        ownerId: session.ownerId,
        schoolId: session.schoolId,
        lmsUserId: session.lmsUserId,
        validateSession: () => _check(session, epoch),
      );
      _check(session, epoch);
      _activities = List.unmodifiable(fetched);
      _displaySession = session;
      _state = LmsSyncState.ready;
      _failures = 0;
      retryAfter = null;
      lastSuccess = checkedAt;
      lastResult = result;
      return result;
    } on _Cancelled {
      if (!_disposed && epoch == _epoch) {
        _state = LmsSyncState.needsLogin;
        _displaySession = null;
      }
      return null;
    } on Object catch (error) {
      if (!_current(session, epoch)) {
        if (!_disposed && epoch == _epoch) {
          _state = LmsSyncState.needsLogin;
          _displaySession = null;
        }
        return null;
      }
      final authentication =
          _isAuthenticationError(error) ||
          (error is CoursemosParseException && error.authenticationRequired);
      _state = authentication ? LmsSyncState.needsLogin : LmsSyncState.fallback;
      _displaySession = authentication ? null : session;
      errorCode = authentication
          ? 'authentication_required'
          : error is CoursemosParseException
          ? error.code
          : 'refresh_failed';
      _failures++;
      retryAfter = _now().add(
        Duration(
          seconds: math.min(300, 15 * (1 << math.min(5, _failures - 1))),
        ),
      );
      return null;
    } finally {
      if (!_disposed && epoch == _epoch) _notify();
    }
  }

  EventCategory? _configuredCategory() {
    final settings = _settings.load();
    final id = settings.academicProfile?.lmsCategoryId;
    if (id == null) return null;
    return settings.categories
            .where((c) => c.id == id && !c.locked)
            .firstOrNull ??
        settings.categories
            .where((c) => c.id == EventCategory.basic.id)
            .firstOrNull ??
        EventCategory.basic;
  }

  /// Reclassify cached linked events without requiring a school network request.
  Future<void> applyConfiguredCategory() async {
    final owner = normalizeLmsOwner(
      _settings.dailyAccount()?.googleAccount?.email ?? '',
    );
    final school = _settings.load().academicProfile?.timetableUniversity;
    if (owner.isEmpty || school == null || _configuredCategory() == null) {
      return;
    }
    bool valid() =>
        !_disposed &&
        normalizeLmsOwner(
              _settings.dailyAccount()?.googleAccount?.email ?? '',
            ) ==
            owner &&
        _settings.load().academicProfile?.timetableUniversity == school;
    final events = await _repository.allEventsForSync();
    if (!valid()) return;
    await _commands.importBatch(
      events.where(
        (e) =>
            !e.isDeleted &&
            e.lms?.ownerId == owner &&
            e.lms?.schoolId == school,
      ),
      isCurrent: valid,
      lmsCategory: _configuredCategory,
      preserveLmsSource: true,
      prepare: (event) async {
        final latest = await _repository.findById(event.id);
        final category = _configuredCategory();
        if (!valid() ||
            latest == null ||
            latest.isDeleted ||
            category == null ||
            latest.lms?.ownerId != owner ||
            latest.lms?.schoolId != school) {
          return null;
        }
        if (latest.category.id == category.id &&
            latest.category.label == category.label &&
            latest.colorValue == category.colorValue) {
          return null;
        }
        return latest.copyWith(
          category: category,
          colorValue: category.colorValue,
        );
      },
    );
    if (!valid()) return;
    final destination = _configuredCategory();
    final currentEvents = await _repository.allEventsForSync();
    if (!valid() || destination == null) return;
    if (currentEvents.any(
      (e) =>
          !e.isDeleted &&
          e.lms?.ownerId == owner &&
          e.lms?.schoolId == school &&
          (e.category.id != destination.id ||
              e.colorValue != destination.colorValue),
    )) {
      throw StateError('LMS category update incomplete');
    }
  }

  Future<LmsSyncResult> _apply(
    LmsSyncSession session,
    int epoch,
    int courseCount,
    List<CoursemosActivity> activities,
  ) async {
    final previous = await _repository.allEventsForSync();
    _check(session, epoch);
    final deviceId = await _settings.deviceId();
    _check(session, epoch);
    final category = _configuredCategory() ?? EventCategory.basic;
    final candidates = <CalendarEvent>[];
    final now = _now();
    for (final activity in activities) {
      final due = activity.dueAt;
      if (due == null) continue;
      final metadata = LmsEventMetadata(
        schoolId: session.schoolId,
        ownerId: session.ownerId,
        lmsUserId: session.lmsUserId,
        courseId: activity.course.id,
        courseTitle: activity.course.title,
        activityType: activity.type,
        activityId: activity.id,
        sourceUrl: activity.url.toString(),
        dueAt: due,
        submissionStatus: activity.submissionStatus,
      );
      candidates.add(
        CalendarEvent(
          id: eventId(metadata),
          title: '[${activity.course.title}] ${activity.title}',
          startAt: due.toLocal(),
          endAt: due.toLocal(),
          allDay: false,
          category: category,
          colorValue: category.colorValue,
          url: metadata.sourceUrl,
          lms: metadata,
          createdAt: now,
          updatedAt: now,
          deviceId: deviceId,
        ),
      );
    }
    final unchanged = <String>{};
    final added = <String>{};
    final saved = await _commands.importBatch(
      candidates,
      lmsCategory: _configuredCategory,
      isCurrent: () => _current(session, epoch),
      prepare: (incoming) async {
        _check(session, epoch);
        final local = await _repository.findById(incoming.id);
        _check(session, epoch);
        if (local == null) {
          added.add(incoming.id);
          return incoming;
        }
        final destination = _configuredCategory();
        final categoryMatches =
            destination == null ||
            (local.category.id == destination.id &&
                local.category.label == destination.label &&
                local.colorValue == destination.colorValue);
        if (!local.isDeleted &&
            _sameSource(local, incoming) &&
            categoryMatches) {
          unchanged.add(incoming.id);
          return null;
        }
        return local.copyWith(
          category: destination,
          colorValue: destination?.colorValue,
          title: incoming.title,
          startAt: incoming.startAt,
          endAt: incoming.endAt,
          allDay: false,
          url: incoming.url,
          lms: incoming.lms,
          recurrence: const RecurrenceRule(),
          clearDeletedAt: true,
        );
      },
    );
    _check(session, epoch);
    if (saved.length + unchanged.length != candidates.length) {
      throw StateError('LMS event write incomplete');
    }
    final desiredIds = candidates.map((event) => event.id).toSet();
    var deleted = 0;
    for (final event in previous) {
      if (!event.isDeleted &&
          _managed(event, session) &&
          !desiredIds.contains(event.id)) {
        _check(session, epoch);
        await _commands.delete(
          event.id,
          isCurrent: () => _current(session, epoch),
        );
        _check(session, epoch);
        deleted++;
      }
    }
    _visibleIds = desiredIds;
    return LmsSyncResult(
      courses: courseCount,
      activities: activities.length,
      unscheduled: activities
          .where((activity) => activity.dueAt == null)
          .length,
      added: saved.intersection(added).length,
      updated: saved.difference(added).length,
      deleted: deleted,
      unchanged: unchanged.length,
    );
  }

  static bool _sameSource(CalendarEvent local, CalendarEvent incoming) =>
      local.title == incoming.title &&
      local.startAt.isAtSameMomentAs(incoming.startAt) &&
      local.endAt.isAtSameMomentAs(incoming.endAt) &&
      !local.allDay &&
      !local.isRecurring &&
      local.url == incoming.url &&
      local.lms == incoming.lms;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    super.dispose();
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}
