import 'dart:async';
import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/auth/google_account.dart';
import 'package:daily/core/lms/lms_controller.dart';
import 'package:daily/core/lms/lms_models.dart';
import 'package:daily/core/lms/lms_sync_service.dart';
import 'package:daily/core/lms/lms_web_session.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/features/events/application/event_command_service.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/event_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _profile = AcademicProfile(
  universityId: 'institution:academyinfo:0000117',
  universityName: '상명대학교',
  schoolKind: 'fourYear',
);
const _dashboard = '''<main id="region-main"><div class="course_lists">
<a class="course_link" href="/course/view.php?id=8001"><div class="course-title"><h3>수업 8001</h3></div></a>
</div></main>''';

class _Repository implements EventRepository {
  final events = <String, CalendarEvent>{};
  @override
  Future<List<CalendarEvent>> allEventsForSync() async =>
      events.values.toList();
  @override
  Future<CalendarEvent?> findById(String id) async => events[id];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Commands implements EventCommandService {
  _Commands(this.repository);
  final _Repository repository;
  int imports = 0;
  @override
  Future<Set<String>> importBatch(
    Iterable<CalendarEvent> events, {
    Future<CalendarEvent?> Function(CalendarEvent event)? prepare,
    bool Function()? isCurrent,
    EventCategory? Function()? lmsCategory,
    bool preserveLmsSource = false,
  }) async {
    final saved = <String>{};
    for (final event in events) {
      final incoming = prepare == null ? event : await prepare(event);
      if (isCurrent != null && !isCurrent()) break;
      if (incoming == null) continue;
      repository.events[incoming.id] = incoming;
      imports++;
      saved.add(incoming.id);
    }
    return saved;
  }

  @override
  Future<void> delete(String eventId, {bool Function()? isCurrent}) async {
    if (isCurrent?.call() == false) return;
    repository.events.remove(eventId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Session extends LmsWebSession {
  _Session(String owner, String school)
    : super(ownerId: owner, schoolId: school);
  bool stored = true;
  bool authenticated = false;
  bool loginVisible = false;
  int preparations = 0, storedReads = 0, reads = 0, closes = 0, disconnects = 0;
  Completer<void>? prepareWait;
  Completer<void>? disconnectWait;
  Object? prepareError;
  Object? closeError;
  Future<LmsHtmlPage> Function(Uri)? answer;
  @override
  String? get principalId => authenticated ? '70001' : null;
  @override
  String? get storedPrincipalId => stored ? '70001' : null;
  @override
  bool get isAuthenticated => authenticated;
  @override
  bool get isLoginVisible => loginVisible;
  @override
  Future<bool> hasStoredSession() async {
    storedReads++;
    return stored;
  }

  @override
  Future<void> prepare() async {
    preparations++;
    if (prepareWait != null) await prepareWait!.future;
    if (prepareError != null) throw prepareError!;
    authenticated = true;
  }

  @override
  Future<LmsHtmlPage> fetchHtml(Uri url) async {
    reads++;
    if (answer != null) return answer!(url);
    return LmsHtmlPage(
      url: url,
      html: url.path == '/'
          ? _dashboard
          : File(
              'test/fixtures/coursemos/${url.path.contains('/assign/') ? 'assignments-empty' : 'quizzes-empty'}.html',
            ).readAsStringSync(),
    );
  }

  @override
  Future<void> disconnect() async {
    disconnects++;
    authenticated = false;
    stored = false;
    if (disconnectWait != null) await disconnectWait!.future;
  }

  @override
  Future<void> close() async {
    closes++;
    authenticated = false;
    if (closeError != null) throw closeError!;
  }

  @override
  Future<void> retire() => close();
}

CalendarEvent _cached(String owner) {
  final metadata = LmsEventMetadata(
    schoolId: 'smu',
    ownerId: owner,
    lmsUserId: '70001',
    courseId: '8001',
    courseTitle: '수업',
    activityType: 'assignment',
    activityId: '9001',
    sourceUrl: 'https://ecampus.smu.ac.kr/mod/assign/view.php?id=9001',
    dueAt: DateTime.utc(2026, 9, 26, 14, 59),
  );
  return CalendarEvent(
    id: LmsSyncService.eventId(metadata),
    title: '과제',
    startAt: metadata.dueAt!,
    endAt: metadata.dueAt!,
    allDay: false,
    category: EventCategory.basic,
    colorValue: EventCategory.basic.colorValue,
    lms: metadata,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SettingsRepository settings;
  late LmsController controller;
  late List<_Session> sessions;
  late _Repository repository;
  late _Commands commands;
  void Function(_Session)? configure;
  Future<void> account(String email) async {
    await settings.saveGoogleAccount(GoogleAccount(email: email));
    await settings.saveAcademicProfile(_profile, expectedGoogleEmail: email);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    settings = SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
    );
    await account('student@example.com');
    sessions = [];
    configure = null;
    repository = _Repository();
    commands = _Commands(repository);
    controller = LmsController(
      settings: settings,
      repository: repository,
      commands: commands,
      createSession: (owner, school) {
        final session = _Session(owner, school);
        configure?.call(session);
        sessions.add(session);
        return session;
      },
    );
  });
  tearDown(() => controller.dispose());

  testWidgets('five-minute refresh timer pauses while backgrounded', (
    tester,
  ) async {
    configure = (session) => session.stored = false;
    controller.setForeground(true);
    await tester.pump(const Duration(minutes: 4, seconds: 59));
    expect(sessions, isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(sessions.single.storedReads, 1);
    controller.setForeground(false);
    await tester.pump(const Duration(minutes: 15));
    expect(sessions.single.storedReads, 1);
    controller.setForeground(true);
    await tester.pump(const Duration(minutes: 4, seconds: 59));
    expect(sessions.single.storedReads, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(sessions.single.storedReads, 2);
    expect(sessions.single.reads, 0);
    controller.setForeground(false);
  });

  test(
    'construction does not access browser and missing stored login performs no GET',
    () async {
      expect(sessions, isEmpty);
      expect(
        controller.isEventVisible(_cached('student@example.com')),
        isFalse,
      );
      configure = (session) => session.stored = false;
      await controller.refresh();
      expect(sessions, hasLength(1));
      expect(sessions.single.preparations, 0);
      expect(sessions.single.reads, 0);
      expect(controller.connected, isFalse);
      expect(controller.restoring, isFalse);
      expect(controller.needsLogin, isTrue);
      final login = await controller.prepareLogin();
      expect(login, same(sessions.single));
      expect(sessions.single.reads, 0);
    },
  );

  test(
    'network restoration failure can show same-owner last data only after restoration ends',
    () async {
      final pending = Completer<void>();
      configure = (session) {
        session.prepareWait = pending;
        session.prepareError = const LmsWebSessionException(
          LmsWebSessionError.network,
        );
      };
      final refresh = controller.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(controller.restoring, isTrue);
      expect(
        controller.isEventVisible(_cached('student@example.com')),
        isFalse,
      );
      pending.complete();
      await refresh;
      expect(controller.sync.state, LmsSyncState.fallback);
      expect(controller.restoring, isFalse);
      expect(controller.connected, isTrue);
      expect(controller.isEventVisible(_cached('student@example.com')), isTrue);
      expect(controller.isEventVisible(_cached('other@example.com')), isFalse);
      expect(sessions.single.reads, 0);
    },
  );

  test(
    'retrying a failed restoration hides fallback events until the retry finishes',
    () async {
      configure = (session) => session.prepareError =
          const LmsWebSessionException(LmsWebSessionError.network);
      await controller.refresh();
      final cached = _cached('student@example.com');
      expect(controller.isEventVisible(cached), isTrue);
      final pending = Completer<void>();
      sessions.single.prepareWait = pending;
      final retry = controller.refresh(force: true);
      await Future<void>.delayed(Duration.zero);
      expect(controller.restoring, isTrue);
      final visibleDuringRetry = controller.isEventVisible(cached);
      pending.complete();
      await retry;
      expect(visibleDuringRetry, isFalse);
      expect(controller.restoring, isFalse);
      expect(controller.isEventVisible(cached), isTrue);
    },
  );

  test(
    'expired authentication hides cached events and requires login',
    () async {
      configure = (session) =>
          session.prepareError = const LmsWebSessionException(
            LmsWebSessionError.authenticationRequired,
          );
      await controller.refresh();
      expect(controller.sync.state, LmsSyncState.needsLogin);
      expect(controller.connected, isFalse);
      expect(
        controller.isEventVisible(_cached('student@example.com')),
        isFalse,
      );
      expect(sessions.single.reads, 0);
    },
  );

  test(
    'forced refresh queued during restoration runs one additional complete pass',
    () async {
      final pending = Completer<void>();
      configure = (session) => session.prepareWait = pending;
      final first = controller.refresh();
      final forceA = controller.refresh(force: true);
      final forceB = controller.refresh(force: true);
      pending.complete();
      await Future.wait([first, forceA, forceB]);
      expect(sessions, hasLength(1));
      expect(sessions.single.preparations, 1);
      expect(sessions.single.reads, 6);
      expect(controller.sync.state, LmsSyncState.ready);
      expect(controller.connected, isTrue);
      expect(controller.restoring, isFalse);
    },
  );

  test(
    'account switch during restore cannot fetch or show the previous account',
    () async {
      final pending = Completer<void>();
      configure = (session) {
        if (session.ownerId == 'student@example.com') {
          session.prepareWait = pending;
        } else {
          session.stored = false;
        }
      };
      final first = controller.refresh();
      await Future<void>.delayed(Duration.zero);
      await account('other@example.com');
      controller.settingsChanged();
      expect(
        controller.isEventVisible(_cached('student@example.com')),
        isFalse,
      );
      final next = controller.refresh();
      pending.complete();
      await Future.wait([first, next]);
      expect(sessions, hasLength(2));
      expect(sessions.first.closes, 1);
      expect(sessions.first.reads, 0);
      expect(sessions.last.ownerId, 'other@example.com');
      expect(controller.session, same(sessions.last));
      expect(controller.connected, isFalse);
      expect(commands.imports, 0);
    },
  );

  test(
    'failed old-session cleanup retries before activating the next owner',
    () async {
      configure = (session) => session.stored = false;
      await controller.refresh();
      final previous = sessions.single;
      previous.closeError = StateError('test cleanup failure');
      await account('other@example.com');
      controller.settingsChanged();
      await controller.refresh();
      expect(sessions, hasLength(1));
      expect(previous.closes, 1);
      expect(previous.reads, 0);
      expect(controller.connected, isFalse);
      expect(
        controller.isEventVisible(_cached('student@example.com')),
        isFalse,
      );

      previous.closeError = null;
      final login = await controller.prepareLogin();
      expect(previous.closes, 2);
      expect(sessions, hasLength(2));
      expect(sessions.last.ownerId, 'other@example.com');
      expect(login, same(sessions.last));
      expect(sessions.last.reads, 0);
    },
  );

  test(
    'disconnect blocks refresh and login while cookie cleanup is pending',
    () async {
      configure = (session) => session.stored = false;
      await controller.refresh();
      final session = sessions.single;
      final pending = Completer<void>();
      session.disconnectWait = pending;
      final disconnect = controller.disconnect();
      final secondDisconnect = controller.disconnect();
      await controller.refresh(force: true);
      expect(await controller.prepareLogin(), isNull);
      expect(session.disconnects, 1);
      expect(controller.connected, isFalse);
      expect(
        controller.isEventVisible(_cached('student@example.com')),
        isFalse,
      );
      expect(sessions, hasLength(1));
      pending.complete();
      await Future.wait([disconnect, secondDisconnect]);
      expect(session.reads, 0);
    },
  );

  test(
    'unsupported profile and stale login callback do not activate a source',
    () async {
      configure = (session) => session.stored = false;
      final previous = await controller.prepareLogin();
      await settings.saveAcademicProfile(
        const AcademicProfile(
          universityId: 'institution:academyinfo:0000023',
          universityName: '전남대학교',
          schoolKind: 'fourYear',
        ),
        expectedGoogleEmail: 'student@example.com',
      );
      controller.settingsChanged();
      (previous as _Session).authenticated = true;
      await controller.loginCompleted(previous);
      await controller.refresh(force: true);
      expect(controller.supported, isFalse);
      expect(controller.connected, isFalse);
      expect(sessions, hasLength(1));
      expect(sessions.single.reads, 0);
      expect(sessions.single.closes, 1);
    },
  );
}
