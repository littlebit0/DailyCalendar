import 'dart:async';
import 'dart:io';

import 'package:daily/core/auth/google_account.dart';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/lms/lms_models.dart';
import 'package:daily/core/lms/lms_sync_service.dart';
import 'package:daily/core/notifications/notification_service.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/sync_service.dart';
import 'package:daily/features/events/application/event_command_service.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/event_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _fixture(String name) =>
    File('test/fixtures/coursemos/$name.html').readAsStringSync();
const _dashboard = '''<main id="region-main"><div class="course_lists">
<a class="course_link" href="/course/view.php?id=8001"><div class="course-title"><h3>수업 8001</h3></div></a>
</div></main>''';

class _Repository implements EventRepository {
  final events = <String, CalendarEvent>{};
  int saves = 0;
  bool failWrites = false;
  @override
  Future<List<CalendarEvent>> allEventsForSync() async =>
      events.values.toList();
  @override
  Future<CalendarEvent?> findById(String id) async => events[id];
  @override
  Future<void> save(CalendarEvent event) async {
    if (failWrites) throw StateError('test write failure');
    saves++;
    events[event.id] = event;
  }

  @override
  Future<void> delete(String id) async {
    events[id] = events[id]!.copyWith(deletedAt: DateTime.utc(2026, 9, 26));
  }

  @override
  Future<List<EventRestoreMutation>> mergeRestoredEventsAtomically(
    Iterable<CalendarEvent> incoming, {
    required RestoredEventResolver resolve,
  }) async {
    if (failWrites) throw StateError('test write failure');
    final changes = <EventRestoreMutation>[];
    for (final remote in incoming) {
      final previous = events[remote.id];
      final current = resolve(previous, remote);
      changes.add(EventRestoreMutation(previous: previous, current: current));
    }
    for (final change in changes) {
      saves++;
      events[change.current.id] = change.current;
    }
    return changes;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Notifications implements NotificationService {
  @override
  Future<void> scheduleMorningBriefing({
    required int hour,
    required int minute,
  }) async {}
  @override
  Future<void> scheduleEventReminder(
    CalendarEvent event, {
    bool allowImmediate = false,
  }) async {}
  @override
  Future<void> cancelEventReminder(
    String eventId, {
    List<int> reminderMinutesBeforeList = const [],
  }) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sync implements SyncService {
  final upserts = <CalendarEvent>[];
  final deletes = <String>[];
  @override
  Future<void> queueEventUpsert(CalendarEvent event) async =>
      upserts.add(event);
  @override
  Future<void> queueEventDelete(String id) async => deletes.add(id);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthRequired implements Exception {}

class _Harness {
  late SettingsRepository settings;
  final repository = _Repository();
  final sync = _Sync();
  late LmsSyncService service;
  late EventCommandService commands;
  LmsSyncSession? session = LmsSyncSession(
    schoolId: 'smu',
    ownerId: 'student@example.com',
    lmsUserId: '70001',
    baseUrl: Uri.parse('https://ecampus.smu.ac.kr'),
    generation: 0,
  );
  var now = DateTime.utc(2026, 9, 26);
  final waits = <Duration>[];
  final requests = <Uri>[];
  final requestTimes = <DateTime>[];
  final pages = <String, String>{
    '/': _dashboard,
    '/mod/assign/index.php': _fixture('assignment-single'),
    '/mod/quiz/index.php': _fixture('quizzes'),
  };
  Future<LmsHtmlPage> Function(Uri)? intercept;
  int active = 0;
  int maxActive = 0;

  Future<void> init() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    settings = SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
    );
    await settings.saveGoogleAccount(
      const GoogleAccount(email: 'student@example.com'),
    );
    commands = EventCommandService(
      repository: repository,
      settingsRepository: settings,
      notificationService: _Notifications(),
      syncService: sync,
    );
    service = LmsSyncService(
      settings: settings,
      repository: repository,
      commands: commands,
      fetchHtml: (url) async {
        requests.add(url);
        requestTimes.add(now);
        active++;
        if (active > maxActive) maxActive = active;
        try {
          if (intercept != null) return await intercept!(url);
          return LmsHtmlPage(url: url, html: pages[url.path]!);
        } finally {
          active--;
        }
      },
      readSession: () => session,
      isAuthenticationError: (error) => error is _AuthRequired,
      now: () => now,
      wait: (duration) async {
        waits.add(duration);
        now = now.add(duration);
      },
    );
  }

  CalendarEvent cached({
    String owner = 'student@example.com',
    String principal = '70001',
    String type = 'assignment',
  }) {
    final metadata = LmsEventMetadata(
      schoolId: 'smu',
      ownerId: owner,
      lmsUserId: principal,
      courseId: '8001',
      courseTitle: '수업 8001',
      activityType: type,
      activityId: '9001',
      sourceUrl: 'https://ecampus.smu.ac.kr/mod/assign/view.php?id=9001',
      dueAt: DateTime.utc(2026, 9, 7, 14, 59),
      submissionStatus: '미제출',
    );
    return CalendarEvent(
      id: LmsSyncService.eventId(metadata),
      title: '[수업 8001] 과제 1',
      startAt: metadata.dueAt!.toLocal(),
      endAt: metadata.dueAt!.toLocal(),
      allDay: false,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      lms: metadata,
      url: metadata.sourceUrl,
      createdAt: now,
      updatedAt: now,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Harness h;
  setUp(() async {
    h = _Harness();
    await h.init();
  });
  tearDown(() => h.service.dispose());

  test(
    'configured category imports, reclassifies and syncs only this owner while preserving personal fields',
    () async {
      const category = EventCategory(
        id: 'study',
        label: '학업',
        colorValue: 0xff228844,
      );
      await h.settings.save(
        h.settings.load().copyWith(categories: [EventCategory.basic, category]),
      );
      const profile = AcademicProfile(
        universityId: 'institution:academyinfo:0000117',
        universityName: '상명대학교',
        schoolKind: 'fourYear',
        lmsCategoryId: 'study',
      );
      await h.settings.saveAcademicProfile(
        profile,
        expectedGoogleEmail: 'student@example.com',
      );
      expect(AcademicProfile.fromJson(profile.toJson()), profile);
      await h.service.refresh();
      expect(
        h.repository.events.values.every(
          (e) =>
              e.category.id == 'study' && e.colorValue == category.colorValue,
        ),
        isTrue,
      );
      final first = h.repository.events.values.first;
      h.repository.events[first.id] = first.copyWith(
        memo: '개인 메모',
        completed: true,
      );
      final foreign = h.cached(owner: 'other@example.com');
      h.repository.events[foreign.id] = foreign;
      await h.settings.saveAcademicProfile(
        profile.withLmsCategory('basic'),
        expectedGoogleEmail: 'student@example.com',
      );
      await h.service.applyConfiguredCategory();
      final updated = h.repository.events[first.id]!;
      expect(updated.category.id, 'basic');
      expect(updated.memo, '개인 메모');
      expect(updated.completed, isTrue);
      expect(updated.lms, first.lms);
      expect(h.repository.events[foreign.id], same(foreign));
      expect(h.sync.upserts.last.category.id, 'basic');
      await h.service.refresh(force: true);
      expect(h.repository.events[first.id]!.category.id, 'basic');
      expect(h.repository.events[first.id]!.memo, '개인 메모');
    },
  );

  test(
    'complete indexes import distinct assignment/quiz IDs using only spaced safe GETs',
    () async {
      final result = await h.service.refresh();
      expect(h.service.state, LmsSyncState.ready);
      expect(result!.added, 3);
      expect(result.activities, 3);
      expect(h.repository.events.keys.toSet(), hasLength(3));
      expect(h.sync.upserts, hasLength(3));
      expect(h.maxActive, 1);
      expect(h.requests.map((url) => url.path), [
        '/',
        '/mod/assign/index.php',
        '/mod/quiz/index.php',
      ]);
      expect(
        h.requests.skip(1).every((url) => url.queryParameters['id'] == '8001'),
        isTrue,
      );
      for (var index = 1; index < h.requestTimes.length; index++) {
        expect(
          h.requestTimes[index].difference(h.requestTimes[index - 1]),
          greaterThanOrEqualTo(const Duration(milliseconds: 400)),
        );
      }
      for (final event in h.repository.events.values) {
        expect(event.id.startsWith('lms:'), isTrue);
        expect(event.startAt.isAtSameMomentAs(event.lms!.dueAt!), isTrue);
        expect(event.endAt, event.startAt);
        expect(h.service.isEventVisible(event), isTrue);
      }
    },
  );

  test(
    'initial/loading hides LMS, network failure exposes only matching owner and principal',
    () async {
      final cached = h.cached();
      h.repository.events[cached.id] = cached;
      expect(h.service.isEventVisible(cached), isFalse);
      final response = Completer<LmsHtmlPage>();
      h.intercept = (_) => response.future;
      final refresh = h.service.refresh();
      expect(h.service.state, LmsSyncState.loading);
      expect(h.service.isEventVisible(cached), isFalse);
      response.completeError(StateError('test offline'));
      expect(await refresh, isNull);
      expect(h.service.state, LmsSyncState.fallback);
      expect(h.service.isEventVisible(cached), isTrue);
      expect(
        h.service.isEventVisible(h.cached(owner: 'other@example.com')),
        isFalse,
      );
      expect(h.service.isEventVisible(h.cached(principal: '70002')), isFalse);
      expect(h.repository.events[cached.id], same(cached));
      expect(h.sync.upserts, isEmpty);
      expect(h.sync.deletes, isEmpty);
    },
  );

  test(
    'concurrent lifecycle and manual refreshes share one network sequence',
    () async {
      final response = Completer<LmsHtmlPage>();
      h.intercept = (url) => url.path == '/'
          ? response.future
          : Future.value(LmsHtmlPage(url: url, html: h.pages[url.path]!));
      final first = h.service.refresh();
      final second = h.service.refresh(force: true);
      expect(identical(first, second), isTrue);
      response.complete(
        LmsHtmlPage(
          url: Uri.parse('https://ecampus.smu.ac.kr/'),
          html: _dashboard,
        ),
      );
      await Future.wait([first, second]);
      expect(h.requests, hasLength(3));
      expect(h.maxActive, 1);
      expect(h.sync.upserts, hasLength(3));
    },
  );

  test(
    'unchanged source reads do not rewrite fetched timestamps or upload events',
    () async {
      await h.service.refresh();
      final originals = Map.of(h.repository.events);
      final writes = h.repository.saves;
      h.now = h.now.add(const Duration(minutes: 6));
      final result = await h.service.refresh();
      expect(result!.unchanged, 3);
      expect(result.added, 0);
      expect(result.updated, 0);
      expect(h.repository.saves, writes);
      expect(h.sync.upserts, hasLength(3));
      for (final entry in originals.entries) {
        expect(h.repository.events[entry.key], same(entry.value));
      }
    },
  );

  test(
    'source title deadline and submission refresh preserves personal edits',
    () async {
      await h.service.refresh();
      final event = h.repository.events.values.singleWhere(
        (event) => event.lms!.activityType == 'assignment',
      );
      final category = EventCategory(
        id: 'personal',
        label: '개인',
        colorValue: 0xff123456,
      );
      h.repository.events[event.id] = event.copyWith(
        memo: '내 메모',
        category: category,
        colorValue: category.colorValue,
        reminderMinutesBeforeList: [15, 60],
        completed: true,
        showDday: true,
      );
      h.pages['/mod/assign/index.php'] = h.pages['/mod/assign/index.php']!
          .replaceFirst('과제 1', '변경된 과제')
          .replaceFirst('2026-09-07 23:59', '2026-09-08 09:00')
          .replaceFirst('미제출', '제출 완료');
      final result = await h.service.refresh(force: true);
      final updated = h.repository.events[event.id]!;
      expect(result!.updated, 1);
      expect(updated.title, '[수업 8001] 변경된 과제');
      expect(updated.lms!.dueAt, DateTime.utc(2026, 9, 8));
      expect(updated.lms!.submissionStatus, '제출 완료');
      expect(updated.memo, '내 메모');
      expect(updated.category, category);
      expect(updated.colorValue, category.colorValue);
      expect(updated.reminderMinutesBeforeList, [15, 60]);
      expect(updated.completed, isTrue);
      expect(updated.showDday, isTrue);
    },
  );

  test(
    'partial read failure makes no writes or deletions and keeps last good values',
    () async {
      await h.service.refresh();
      final originals = Map.of(h.repository.events);
      final writes = h.repository.saves;
      h.intercept = (url) async {
        if (url.path == '/mod/quiz/index.php') throw StateError('test offline');
        return LmsHtmlPage(
          url: url,
          html: h.pages[url.path]!.replaceAll('과제 1', '읽었지만 적용하면 안 됨'),
        );
      };
      expect(await h.service.refresh(force: true), isNull);
      expect(h.service.state, LmsSyncState.fallback);
      expect(h.repository.saves, writes);
      expect(h.sync.deletes, isEmpty);
      for (final entry in originals.entries) {
        expect(h.repository.events[entry.key], same(entry.value));
      }
    },
  );

  test(
    'complete empty indexes prune only this principal managed activities',
    () async {
      await h.service.refresh();
      final unrelated = h.cached(owner: 'other@example.com');
      final lecture = h.cached(type: 'lecture');
      final personal = h.cached().copyWith(id: 'personal', clearLms: true);
      for (final event in [unrelated, lecture, personal]) {
        h.repository.events[event.id] = event;
      }
      h.pages['/mod/assign/index.php'] = _fixture('assignments-empty');
      h.pages['/mod/quiz/index.php'] = _fixture('quizzes-empty');
      final result = await h.service.refresh(force: true);
      expect(result!.deleted, 3);
      expect(result.activities, 0);
      expect(h.sync.deletes, hasLength(3));
      for (final event in [unrelated, lecture, personal]) {
        expect(h.repository.events[event.id], same(event));
      }
    },
  );

  test(
    'unknown empty structure preserves previous records instead of pruning',
    () async {
      await h.service.refresh();
      final previous = Map.of(h.repository.events);
      h.pages['/mod/assign/index.php'] =
          '<main id="region-main">새로운 과제 화면</main>';
      expect(await h.service.refresh(force: true), isNull);
      expect(h.service.errorCode, 'activity_table_missing');
      expect(h.service.state, LmsSyncState.fallback);
      expect(h.sync.deletes, isEmpty);
      expect(h.repository.events, previous);
    },
  );

  test(
    'automatic failures back off while manual retry preserves request spacing',
    () async {
      h.intercept = (_) => Future.error(StateError('test offline'));
      await h.service.refresh();
      expect(
        h.service.retryAfter!.difference(h.now),
        const Duration(seconds: 15),
      );
      await h.service.refresh();
      expect(h.requests, hasLength(1));
      await h.service.refresh(force: true);
      expect(h.requests, hasLength(2));
      expect(
        h.requestTimes[1].difference(h.requestTimes[0]),
        greaterThanOrEqualTo(const Duration(milliseconds: 400)),
      );
      expect(
        h.service.retryAfter!.difference(h.now),
        const Duration(seconds: 30),
      );
      await h.service.refresh();
      expect(h.requests, hasLength(2));
      h.now = h.service.retryAfter!;
      await h.service.refresh();
      expect(h.requests, hasLength(3));
      expect(
        h.service.retryAfter!.difference(h.now),
        const Duration(seconds: 60),
      );
    },
  );

  test(
    'successful lifecycle refresh is throttled while explicit refresh remains available',
    () async {
      await h.service.refresh();
      await h.service.refresh();
      expect(h.requests, hasLength(3));
      await h.service.refresh(force: true);
      expect(h.requests, hasLength(6));
    },
  );

  test(
    'logout while a read is pending discards the response without any queued mutation',
    () async {
      final response = Completer<LmsHtmlPage>();
      h.intercept = (_) => response.future;
      final refresh = h.service.refresh();
      h.session = null;
      h.service.invalidateSession();
      response.complete(
        LmsHtmlPage(
          url: Uri.parse('https://ecampus.smu.ac.kr/'),
          html: _dashboard,
        ),
      );
      expect(await refresh, isNull);
      expect(h.service.state, LmsSyncState.needsLogin);
      expect(h.repository.events, isEmpty);
      expect(h.sync.upserts, isEmpty);
      expect(h.sync.deletes, isEmpty);
    },
  );

  test(
    'Google owner changes cannot read or apply the old LMS connection',
    () async {
      final response = Completer<LmsHtmlPage>();
      h.intercept = (_) => response.future;
      final refresh = h.service.refresh();
      await h.settings.saveGoogleAccount(
        const GoogleAccount(email: 'other@example.com'),
      );
      response.complete(
        LmsHtmlPage(
          url: Uri.parse('https://ecampus.smu.ac.kr/'),
          html: _dashboard,
        ),
      );
      expect(await refresh, isNull);
      expect(h.repository.events, isEmpty);
      expect(h.sync.upserts, isEmpty);
      expect(h.service.isEventVisible(h.cached()), isFalse);
      await h.service.refresh(force: true);
      expect(h.service.state, LmsSyncState.needsLogin);
      expect(h.requests, hasLength(1));
    },
  );

  test(
    'a new session waits for the old GET and imports only its own principal',
    () async {
      final oldResponse = Completer<LmsHtmlPage>();
      var first = true;
      h.intercept = (url) {
        if (first) {
          first = false;
          return oldResponse.future;
        }
        return Future.value(LmsHtmlPage(url: url, html: h.pages[url.path]!));
      };
      final oldRefresh = h.service.refresh();
      h.session = LmsSyncSession(
        schoolId: 'smu',
        ownerId: 'student@example.com',
        lmsUserId: '70002',
        baseUrl: Uri.parse('https://ecampus.smu.ac.kr'),
        generation: 1,
      );
      h.service.invalidateSession();
      final newRefresh = h.service.refresh(force: true);
      expect(h.requests, hasLength(1));
      oldResponse.complete(
        LmsHtmlPage(
          url: Uri.parse('https://ecampus.smu.ac.kr/'),
          html: _dashboard,
        ),
      );
      expect(await oldRefresh, isNull);
      expect((await newRefresh)!.added, 3);
      expect(h.maxActive, 1);
      expect(
        h.repository.events.values.every(
          (event) => event.lms!.lmsUserId == '70002',
        ),
        isTrue,
      );
      expect(
        h.sync.upserts.every((event) => event.lms!.lmsUserId == '70002'),
        isTrue,
      );
    },
  );

  test(
    'an activity restored by the LMS reuses its identity and clears its source tombstone',
    () async {
      await h.service.refresh();
      final ids = h.repository.events.keys.toSet();
      h.pages['/mod/assign/index.php'] = _fixture('assignments-empty');
      h.pages['/mod/quiz/index.php'] = _fixture('quizzes-empty');
      await h.service.refresh(force: true);
      expect(
        h.repository.events.values.every((event) => event.isDeleted),
        isTrue,
      );
      h.pages['/mod/assign/index.php'] = _fixture('assignment-single');
      h.pages['/mod/quiz/index.php'] = _fixture('quizzes');
      final result = await h.service.refresh(force: true);
      expect(result!.updated, 3);
      expect(h.repository.events.keys.toSet(), ids);
      expect(
        h.repository.events.values.every((event) => !event.isDeleted),
        isTrue,
      );
    },
  );

  test(
    'explicit authentication failure hides cache while network restoration may use it',
    () async {
      final cached = h.cached();
      h.service.markRestoreFailed();
      expect(h.service.state, LmsSyncState.fallback);
      expect(h.service.isEventVisible(cached), isTrue);
      h.service.invalidateSession();
      expect(h.service.isEventVisible(cached), isFalse);
      h.intercept = (_) => Future.error(_AuthRequired());
      await h.service.refresh();
      expect(h.service.state, LmsSyncState.needsLogin);
      expect(h.service.isEventVisible(cached), isFalse);
      h.service.markRestoreFailed(authenticationRequired: true);
      expect(h.service.isEventVisible(cached), isFalse);
    },
  );

  test('unverified university support never calls the SMU source', () async {
    h.session = LmsSyncSession(
      schoolId: 'jnu',
      ownerId: 'student@example.com',
      lmsUserId: '70001',
      baseUrl: Uri.parse('https://example.jnu.ac.kr'),
      generation: 0,
    );
    expect(await h.service.refresh(), isNull);
    expect(h.service.state, LmsSyncState.unsupported);
    expect(h.requests, isEmpty);
  });

  test('failed local imports never proceed to pruning old records', () async {
    await h.service.refresh();
    h.repository.failWrites = true;
    h.pages['/mod/assign/index.php'] = h.pages['/mod/assign/index.php']!
        .replaceFirst('과제 1', '수정된 과제');
    h.pages['/mod/quiz/index.php'] = _fixture('quizzes-empty');
    expect(await h.service.refresh(force: true), isNull);
    expect(h.service.state, LmsSyncState.fallback);
    expect(h.sync.deletes, isEmpty);
    expect(
      h.repository.events.values.every((event) => !event.isDeleted),
      isTrue,
    );
  });

  test(
    'explicitly absent deadline stays unplaced without inventing any schedule',
    () async {
      h.pages['/mod/assign/index.php'] = h.pages['/mod/assign/index.php']!
          .replaceFirst('2026-09-07 23:59', '—');
      h.pages['/mod/quiz/index.php'] = _fixture('quizzes-empty');
      final result = await h.service.refresh();
      expect(result!.activities, 1);
      expect(result.unscheduled, 1);
      expect(result.added, 0);
      expect(h.service.activities.single.dueAt, isNull);
      expect(h.repository.events, isEmpty);
    },
  );

  test(
    'last successful check survives restart without skipping the first network read',
    () async {
      await h.service.refresh();
      final checked = h.service.lastSuccess;
      expect(checked, isNotNull);
      expect(
        h.settings.lmsLastSuccess(
          ownerId: ' STUDENT@example.com ',
          schoolId: 'smu',
          lmsUserId: '70001',
        ),
        checked,
      );
      var reads = 0;
      final restarted = LmsSyncService(
        settings: h.settings,
        repository: h.repository,
        commands: h.commands,
        fetchHtml: (_) async {
          reads++;
          throw StateError('test offline');
        },
        readSession: () => h.session,
        now: () => h.now,
      );
      addTearDown(restarted.dispose);
      expect(restarted.lastSuccess, isNull);
      restarted.markRestoreFailed();
      expect(restarted.lastSuccess, checked);
      expect(
        restarted.isEventVisible(h.repository.events.values.first),
        isTrue,
      );
      await restarted.refresh();
      expect(reads, 1);
      expect(restarted.state, LmsSyncState.fallback);
      expect(restarted.lastSuccess, checked);
    },
  );

  test(
    'local success time is scoped to Google owner school and LMS principal',
    () async {
      await h.service.refresh();
      expect(
        h.settings.lmsLastSuccess(
          ownerId: 'student@example.com',
          schoolId: 'smu',
          lmsUserId: '70002',
        ),
        isNull,
      );
      expect(
        h.settings.lmsLastSuccess(
          ownerId: 'student@example.com',
          schoolId: 'jnu',
          lmsUserId: '70001',
        ),
        isNull,
      );
      expect(
        h.settings.lmsLastSuccess(
          ownerId: 'other@example.com',
          schoolId: 'smu',
          lmsUserId: '70001',
        ),
        isNull,
      );
      await expectLater(
        h.settings.saveLmsLastSuccess(
          h.now,
          ownerId: 'other@example.com',
          schoolId: 'smu',
          lmsUserId: '70001',
        ),
        throwsStateError,
      );
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs
          .getKeys()
          .where((key) => key.startsWith('daily.lms.lastSuccess.v1.'))
          .toList();
      expect(keys, hasLength(1));
      expect(keys.single.contains('student'), isFalse);
    },
  );

  test(
    'session invalidation during success-time persistence rolls back the value',
    () async {
      await h.service.refresh();
      final checked = h.service.lastSuccess;
      var checks = 0;
      await expectLater(
        h.settings.saveLmsLastSuccess(
          h.now.add(const Duration(days: 1)),
          ownerId: 'student@example.com',
          schoolId: 'smu',
          lmsUserId: '70001',
          validateSession: () {
            if (++checks == 2) throw StateError('test stale session');
          },
        ),
        throwsStateError,
      );
      expect(
        h.settings.lmsLastSuccess(
          ownerId: 'student@example.com',
          schoolId: 'smu',
          lmsUserId: '70001',
        ),
        checked,
      );
    },
  );
}
