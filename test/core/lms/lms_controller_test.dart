import 'dart:async';
import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/analytics/privacy_analytics_service.dart';
import 'package:daily/core/analytics/product_analytics.dart';
import 'package:daily/core/auth/google_account.dart';
import 'package:daily/core/lms/lms_controller.dart';
import 'package:daily/core/lms/lms_credentials_store.dart';
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

class _RecordingAnalytics extends NoopProductAnalytics {
  final records = <AnalyticsRecord>[];
  @override
  Future<void> record(AnalyticsRecord record) async => records.add(record);
}

class _UnreadableCredentials extends LmsCredentialsStore {
  @override
  Future<LmsLocalCredentials?> read(String owner, String school) async {
    throw StateError('fixture Keychain failure with secret-token-123');
  }
}

class _DeferredCredentials extends LmsCredentialsStore {
  final reads = <Completer<LmsLocalCredentials?>>[];
  @override
  Future<LmsLocalCredentials?> read(String owner, String school) {
    final result = Completer<LmsLocalCredentials?>();
    reads.add(result);
    return result.future;
  }
}

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
    CalendarEvent? Function(CalendarEvent? latest, CalendarEvent incoming)?
    resolveLatest,
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
  String selectedUser = '70001';
  bool loginVisible = false;
  bool retainedIdentity = false;
  bool recoverySucceeds = false;
  int recoveries = 0;
  int confirmedRefreshes = 0;
  int preparations = 0, storedReads = 0, reads = 0, closes = 0, disconnects = 0;
  Completer<void>? prepareWait;
  Completer<void>? disconnectWait;
  Completer<void>? recoveryWait;
  Object? prepareError;
  Object? closeError;
  Future<LmsHtmlPage> Function(Uri)? answer;
  @override
  String? get principalId => authenticated ? selectedUser : null;
  @override
  String? get storedPrincipalId => stored || retainedIdentity ? '70001' : null;
  int automaticLogins = 0;
  bool automaticSucceeds = true;
  Completer<void>? automaticWait;
  Object? automaticError;
  @override
  Future<bool> loginAutomatically(
    LmsLocalCredentials credentials, {
    String? expectedPrincipal,
  }) async {
    automaticLogins++;
    if (automaticWait != null) await automaticWait!.future;
    if (automaticError != null) throw automaticError!;
    authenticated = automaticSucceeds;
    return automaticSucceeds;
  }

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
  Future<bool> recoverAuthentication() async {
    recoveries++;
    if (recoveryWait != null) await recoveryWait!.future;
    authenticated = recoverySucceeds;
    stored = recoverySucceeds;
    return recoverySucceeds;
  }

  @override
  void acknowledgeSuccessfulRefresh() {
    confirmedRefreshes++;
    super.acknowledgeSuccessfulRefresh();
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

  test(
    'local username loads independently, switches owners and deletes without changing cloud settings',
    () async {
      final store = LmsCredentialsStore();
      await store.save(
        'student@example.com',
        'smu',
        const LmsLocalCredentials('local-student', 'synthetic', paused: true),
      );
      final before = settings.load().academicProfile;
      await controller.loadLocalLoginInfo();
      expect(controller.localLoginUsername, 'local-student');
      expect(controller.automaticLoginPaused, isTrue);
      expect(sessions, isEmpty);
      expect(settings.load().academicProfile, before);
      await account('other@example.com');
      expect(controller.localLoginUsername, isNull);
      controller.settingsChanged();
      await controller.loadLocalLoginInfo();
      expect(controller.localLoginUsername, isNull);
      await account('student@example.com');
      await controller.loadLocalLoginInfo();
      expect(controller.localLoginUsername, 'local-student');
      await controller.removeAutomaticLogin();
      expect(controller.localLoginUsername, isNull);
      expect(await store.read('student@example.com', 'smu'), isNull);
    },
  );

  test(
    'late credential reads never show another owner and read failures are explicit',
    () async {
      final store = _DeferredCredentials();
      final local = LmsController(
        settings: settings,
        repository: repository,
        commands: commands,
        credentialsStore: store,
      );
      addTearDown(local.dispose);
      final first = local.loadLocalLoginInfo();
      expect(local.localLoginLoading, isTrue);
      await account('other@example.com');
      final second = local.loadLocalLoginInfo();
      store.reads[1].complete(
        const LmsLocalCredentials('other-local-user', 'synthetic'),
      );
      await second;
      store.reads[0].complete(
        const LmsLocalCredentials('old-local-user', 'synthetic'),
      );
      await first;
      expect(local.localLoginUsername, 'other-local-user');
      final failure = local.loadLocalLoginInfo();
      store.reads[2].completeError(StateError('fixture Keychain failure'));
      await failure;
      expect(local.localLoginReadFailed, isTrue);
      expect(local.localLoginLoading, isFalse);
      expect(local.localLoginUsername, 'other-local-user');
      expect(sessions, isEmpty);
    },
  );

  test(
    'local automatic login refreshes schedules once and never changes cloud credential settings',
    () async {
      configure = (s) => s.stored = false;
      await controller.saveAutomaticLogin('test-user', 'fixture-password');
      expect(sessions.single.automaticLogins, 1);
      expect(controller.sync.state, LmsSyncState.ready);
      await controller.refresh(force: true);
      expect(sessions.single.automaticLogins, 1);
      final local = await LmsCredentialsStore().read(
        'student@example.com',
        'smu',
      );
      expect(local, isNotNull);
      expect(
        settings.load().academicProfile!.toJson().toString(),
        isNot(contains('fixture-password')),
      );
    },
  );

  test(
    'automatic login first-read rejection uses bounded recovery without resubmitting credentials',
    () async {
      configure = (session) {
        session.stored = false;
        session.recoverySucceeds = true;
        session.answer = (_) async {
          session.answer = null;
          session.authenticated = false;
          throw const LmsWebSessionException(
            LmsWebSessionError.authenticationRequired,
          );
        };
      };
      await controller.saveAutomaticLogin('test-user', 'fixture-password');
      expect(sessions.single.automaticLogins, 1);
      expect(sessions.single.recoveries, 1);
      expect(sessions.single.confirmedRefreshes, 1);
      expect(controller.sync.state, LmsSyncState.ready);
      expect(controller.connected, isTrue);
      expect(controller.automaticLoginPaused, isFalse);
    },
  );

  test(
    'automatic login failed first-read recovery preserves cache and does not pause valid credentials',
    () async {
      final cached = _cached('student@example.com');
      repository.events[cached.id] = cached;
      configure = (session) {
        session.stored = false;
        session.answer = (_) async {
          session.authenticated = false;
          throw const LmsWebSessionException(
            LmsWebSessionError.authenticationRequired,
          );
        };
      };
      await controller.saveAutomaticLogin('test-user', 'fixture-password');
      expect(sessions.single.automaticLogins, 1);
      expect(sessions.single.recoveries, 1);
      expect(sessions.single.reads, 1);
      expect(controller.sync.state, LmsSyncState.needsLogin);
      expect(controller.automaticLoginPaused, isFalse);
      expect(repository.events[cached.id], same(cached));
      expect(
        (await LmsCredentialsStore().read(
          'student@example.com',
          'smu',
        ))!.paused,
        isFalse,
      );
    },
  );

  test(
    'owner switch during automatic first-read recovery prevents the retry import',
    () async {
      final wait = Completer<void>();
      configure = (session) {
        session.stored = false;
        session.recoverySucceeds = true;
        session.recoveryWait = wait;
        session.answer = (_) async {
          session.answer = null;
          session.authenticated = false;
          throw const LmsWebSessionException(
            LmsWebSessionError.authenticationRequired,
          );
        };
      };
      final attempt = controller.saveAutomaticLogin(
        'test-user',
        'fixture-password',
      );
      while (sessions.isEmpty || sessions.single.recoveries == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      await settings.saveGoogleAccount(
        const GoogleAccount(email: 'other@example.com'),
      );
      controller.settingsChanged();
      wait.complete();
      await attempt;
      expect(sessions.single.automaticLogins, 1);
      expect(sessions.single.reads, 1);
      expect(repository.events, isEmpty);
    },
  );

  test(
    'rejected automatic credentials pause across process restarts until explicit replacement',
    () async {
      configure = (s) {
        s.stored = false;
        s.automaticSucceeds = false;
      };
      await controller.saveAutomaticLogin('test-user', 'fixture-password');
      expect(controller.automaticLoginPaused, isTrue);
      expect(
        controller.lastLoginFailure,
        LmsLoginFailure.authenticationUnconfirmed,
      );
      await controller.refresh(force: true);
      expect(sessions.single.automaticLogins, 1);
      expect(
        (await LmsCredentialsStore().read(
          'student@example.com',
          'smu',
        ))!.paused,
        isTrue,
      );
      await controller.removeAutomaticLogin();
      expect(controller.lastLoginFailure, isNull);
      expect(
        await LmsCredentialsStore().read('student@example.com', 'smu'),
        isNull,
      );
    },
  );

  test(
    'owner switch during automatic login cannot import or share credentials',
    () async {
      final wait = Completer<void>();
      configure = (s) {
        s.stored = false;
        s.automaticWait = wait;
      };
      final attempt = controller.saveAutomaticLogin(
        'test-user',
        'fixture-password',
      );
      while (sessions.isEmpty || sessions.single.automaticLogins == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      await account('other@example.com');
      controller.settingsChanged();
      wait.complete();
      await attempt;
      expect(repository.events, isEmpty);
      expect(
        await LmsCredentialsStore().read('other@example.com', 'smu'),
        isNull,
      );
      expect(settings.load().academicProfile!.lmsUserId, isNull);
    },
  );

  test(
    'explicit local credential save reconnects a disabled integration only after authentication',
    () async {
      await settings.saveAcademicProfile(
        _profile.withLmsConnection(enabled: false),
        expectedGoogleEmail: 'student@example.com',
      );
      configure = (s) => s.stored = false;
      await controller.saveAutomaticLogin('test-user', 'fixture-password');
      expect(sessions.single.automaticLogins, 1);
      expect(settings.load().academicProfile!.lmsIntegrationEnabled, isTrue);
      expect(controller.sync.state, LmsSyncState.ready);
    },
  );

  test(
    'network failure during automatic login preserves credentials without repeated submission',
    () async {
      configure = (s) {
        s.stored = false;
        s.automaticError = const LmsWebSessionException(
          LmsWebSessionError.network,
        );
      };
      await controller.saveAutomaticLogin('test-user', 'fixture-password');
      await controller.refresh(force: true);
      expect(sessions.single.automaticLogins, 1);
      expect(controller.lastLoginFailure, LmsLoginFailure.network);
      expect(
        (await LmsCredentialsStore().read(
          'student@example.com',
          'smu',
        ))!.paused,
        isFalse,
      );
    },
  );

  test('network restore failure never submits stored credentials', () async {
    configure = (s) => s.prepareError = const LmsWebSessionException(
      LmsWebSessionError.network,
    );
    await LmsCredentialsStore().save(
      'student@example.com',
      'smu',
      const LmsLocalCredentials('test-user', 'fixture-password'),
    );
    await controller.refresh(force: true);
    expect(sessions.single.automaticLogins, 0);
    expect(controller.sync.state, LmsSyncState.fallback);
  });

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
      expect(controller.isEventVisible(_cached('student@example.com')), isTrue);
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
    'network restoration keeps known same-owner data visible while restoring',
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
      expect(controller.isEventVisible(_cached('student@example.com')), isTrue);
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

  test('retrying a failed restoration keeps fallback events visible', () async {
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
    expect(visibleDuringRetry, isTrue);
    expect(controller.restoring, isFalse);
    expect(controller.isEventVisible(cached), isTrue);
  });

  test(
    'expired authentication keeps known cached events and requires login',
    () async {
      configure = (session) =>
          session.prepareError = const LmsWebSessionException(
            LmsWebSessionError.authenticationRequired,
          );
      await controller.refresh();
      expect(controller.sync.state, LmsSyncState.needsLogin);
      expect(controller.connected, isFalse);
      expect(controller.isEventVisible(_cached('student@example.com')), isTrue);
      expect(sessions.single.reads, 0);
    },
  );

  test(
    'cookie expiry across restart retains identity but performs no school GET',
    () async {
      configure = (session) {
        session.stored = false;
        session.retainedIdentity = true;
      };
      final cached = _cached('student@example.com');
      repository.events[cached.id] = cached;
      await controller.refresh();
      expect(controller.needsLogin, isTrue);
      expect(controller.connected, isFalse);
      expect(controller.isEventVisible(cached), isTrue);
      expect(sessions.single.preparations, 0);
      expect(sessions.single.reads, 0);
      expect(sessions.single.recoveries, 0);
      expect(repository.events[cached.id], same(cached));
    },
  );

  test(
    'one rejected read restores saved authentication then completes one fresh pass',
    () async {
      configure = (session) {
        session.recoverySucceeds = true;
        session.answer = (_) async {
          session.answer = null;
          session.authenticated = false;
          throw const LmsWebSessionException(
            LmsWebSessionError.authenticationRequired,
          );
        };
      };
      await controller.refresh();
      expect(sessions.single.recoveries, 1);
      expect(sessions.single.preparations, 1);
      expect(controller.sync.state, LmsSyncState.ready);
      expect(sessions.single.confirmedRefreshes, 1);
      expect(controller.connected, isTrue);
      expect(settings.load().academicProfile?.lmsUserId, '70001');
      expect(settings.load().academicProfile?.lmsIntegrationEnabled, isTrue);
    },
  );

  test(
    'failed authentication recovery stops reads and retains the enabled connection',
    () async {
      configure = (session) {
        session.answer = (_) async {
          session.authenticated = false;
          session.retainedIdentity = true;
          throw const LmsWebSessionException(
            LmsWebSessionError.authenticationRequired,
          );
        };
      };
      await controller.refresh();
      expect(sessions.single.recoveries, 1);
      expect(sessions.single.reads, 1);
      expect(controller.needsLogin, isTrue);
      expect(sessions.single.confirmedRefreshes, 0);
      expect(controller.connected, isFalse);
      expect(settings.load().academicProfile?.lmsIntegrationEnabled, isTrue);
      expect(controller.isEventVisible(_cached('student@example.com')), isTrue);
      await controller.refresh(force: true);
      expect(sessions.single.reads, 1);
      expect(sessions.single.recoveries, 1);
    },
  );

  test(
    'owner switch during authentication recovery cannot issue retry reads',
    () async {
      final pending = Completer<void>();
      configure = (session) {
        session.recoverySucceeds = true;
        session.recoveryWait = pending;
        session.answer = (_) async {
          session.authenticated = false;
          throw const LmsWebSessionException(
            LmsWebSessionError.authenticationRequired,
          );
        };
      };
      final first = controller.refresh();
      while (sessions.isEmpty || sessions.single.recoveries == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      await account('other@example.com');
      controller.settingsChanged();
      pending.complete();
      await first;
      expect(sessions.single.reads, 1);
      expect(
        controller.isEventVisible(_cached('student@example.com')),
        isFalse,
      );
      expect(settings.load().academicProfile?.lmsUserId, isNull);
      expect(commands.imports, 0);
    },
  );

  test(
    'explicit disconnect persists disabled state and only manual login reconnects',
    () async {
      await controller.refresh();
      final cached = _cached('student@example.com');
      repository.events[cached.id] = cached;
      await controller.disconnect();
      expect(settings.load().academicProfile?.lmsIntegrationEnabled, isFalse);
      expect(settings.load().academicProfile?.lmsUserId, '70001');
      await controller.refresh(force: true);
      expect(sessions.last.reads, 0);
      expect(sessions.last.preparations, 0);
      expect(controller.connected, isFalse);
      expect(repository.events[cached.id], same(cached));
      final login = await controller.prepareLogin() as _Session;
      expect(login.preparations, 0);
      expect(settings.load().academicProfile?.lmsIntegrationEnabled, isFalse);
      login.authenticated = true;
      await controller.loginCompleted(login);
      expect(settings.load().academicProfile?.lmsIntegrationEnabled, isTrue);
      expect(controller.connected, isTrue);
    },
  );

  test(
    'Drive-selected principal blocks an already authenticated previous school account',
    () async {
      await controller.refresh();
      final previousReads = sessions.single.reads;
      await settings.saveAcademicProfile(
        settings.load().academicProfile!.withLmsConnection(
          userId: '70002',
          enabled: true,
        ),
        expectedGoogleEmail: 'student@example.com',
      );
      controller.settingsChanged();
      expect(controller.connected, isFalse);
      await controller.refresh(force: true);
      expect(sessions.single.reads, previousReads);
      expect(sessions.single.closes, 1);
      expect(controller.needsLogin, isTrue);
      expect(settings.load().academicProfile?.lmsUserId, '70002');
      await controller.refresh(force: true);
      expect(sessions.single.preparations, 1);
      expect(sessions.single.reads, previousReads);
      await controller.disconnect();
      expect(settings.load().academicProfile?.lmsUserId, '70002');
    },
  );

  test(
    'stored school principal mismatch requires explicit login before new reads',
    () async {
      await settings.saveAcademicProfile(
        _profile.withLmsConnection(userId: '70002', enabled: true),
        expectedGoogleEmail: 'student@example.com',
      );
      await controller.refresh();
      expect(controller.connected, isFalse);
      expect(controller.needsLogin, isTrue);
      expect(sessions.single.preparations, 0);
      expect(sessions.single.reads, 0);
      expect(settings.load().academicProfile?.lmsUserId, '70002');
      final login = await controller.prepareLogin() as _Session;
      login.selectedUser = '70002';
      login.authenticated = true;
      await controller.loginCompleted(login);
      expect(controller.connected, isTrue);
      expect(controller.sync.state, LmsSyncState.ready);
      expect(settings.load().academicProfile?.lmsUserId, '70002');
    },
  );

  test(
    'forced refreshes during restoration upgrade one upcoming complete pass',
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
      expect(sessions.single.reads, 4);
      expect(controller.sync.state, LmsSyncState.ready);
      expect(controller.connected, isTrue);
      expect(controller.restoring, isFalse);
    },
  );

  test(
    'forced refresh after collection starts retains a fresh trailing pass',
    () async {
      final pending = Completer<LmsHtmlPage>();
      configure = (session) {
        session.answer = (url) async {
          if (session.reads == 1) return pending.future;
          return LmsHtmlPage(
            url: url,
            html: url.path == '/'
                ? _dashboard
                : File(
                    'test/fixtures/coursemos/${url.path.contains('/assign/') ? 'assignments-empty' : 'quizzes-empty'}.html',
                  ).readAsStringSync(),
          );
        };
      };
      final first = controller.refresh();
      while (sessions.isEmpty || sessions.single.reads == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final trailing = controller.refresh(force: true);
      pending.complete(
        LmsHtmlPage(
          url: Uri.parse('https://ecampus.smu.ac.kr/'),
          html: _dashboard,
        ),
      );
      await Future.wait([first, trailing]);
      expect(sessions.single.reads, 8);
      expect(controller.sync.state, LmsSyncState.ready);
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
      while (session.disconnects == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(session.disconnects, 1);
      expect(controller.connected, isFalse);
      expect(controller.isEventVisible(_cached('student@example.com')), isTrue);
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

  group('LMS login analytics (#259)', () {
    late _RecordingAnalytics analytics;
    LmsController create({LmsCredentialsStore? store}) {
      analytics = _RecordingAnalytics();
      final local = LmsController(
        settings: settings,
        repository: repository,
        commands: commands,
        analytics: analytics,
        credentialsStore: store,
        createSession: (owner, school) {
          final session = _Session(owner, school);
          configure?.call(session);
          sessions.add(session);
          return session;
        },
      );
      addTearDown(local.dispose);
      return local;
    }

    Map<String, Object> only() {
      expect(analytics.records, hasLength(1));
      expect(analytics.records.single.name, AnalyticsEventName.lmsLogin);
      final attributes = analytics.records.single.attributes;
      expect(
        isSafeAnalyticsEvent({
          'eventId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          'name': 'lms_login',
          'occurredAt': '2026-10-19T00:00:00Z',
          'attributes': attributes,
        }),
        isTrue,
      );
      return attributes;
    }

    test('successful stored-account login is one automatic success', () async {
      configure = (session) => session.stored = false;
      await create().saveAutomaticLogin('test-user', 'fixture-password');
      expect(only(), {
        'method': 'automatic',
        'stage': 'session',
        'result': 'succeeded',
      });
    });

    test('a rejected login reports the safe cause at the authentication stage', () async {
      configure = (session) {
        session.stored = false;
        session.automaticSucceeds = false;
      };
      await create().saveAutomaticLogin('test-user', 'fixture-password');
      expect(only(), {
        'method': 'automatic',
        'stage': 'authentication',
        'result': 'failed',
        'cause': 'authenticationUnconfirmed',
      });
    });

    test('exception text and credentials never reach the record', () async {
      configure = (session) {
        session.stored = false;
        session.automaticError = StateError(
          'password=fixture-password token=secret-token-123 https://school.example/?ticket=abc',
        );
      };
      await create()
          .saveAutomaticLogin('test-user', 'fixture-password')
          .catchError((Object _) {});
      final json = analytics.records.single.attributes.toString();
      for (final secret in [
        'fixture-password',
        'test-user',
        'secret-token-123',
        'school.example',
        'ticket',
        'student@example.com',
      ]) {
        expect(json, isNot(contains(secret)));
      }
      expect(only()['result'], 'failed');
      expect(analyticsLmsCauseValues, contains(only()['cause']));
    });

    test('an unreadable credential store is a credentials-stage failure', () async {
      configure = (session) => session.stored = false;
      final local = create(store: _UnreadableCredentials());
      await local.refresh(force: true);
      expect(only(), {
        'method': 'automatic',
        'stage': 'credentials',
        'result': 'failed',
        'cause': 'secureStorage',
      });
    });

    test('paused automatic login is a skip, reported once, not a failure', () async {
      await LmsCredentialsStore().save(
        'student@example.com',
        'smu',
        const LmsLocalCredentials('test-user', 'fixture-password', paused: true),
      );
      configure = (session) => session.stored = false;
      final local = create();
      await local.refresh(force: true);
      await local.refresh(force: true);
      expect(sessions.single.automaticLogins, 0);
      expect(only(), {
        'method': 'automatic',
        'stage': 'credentials',
        'result': 'skipped',
        'skipReason': 'paused',
      });
    });

    test('an account change during the school answer is canceled, not failed', () async {
      final wait = Completer<void>();
      configure = (session) {
        session.stored = false;
        session.automaticWait = wait;
      };
      final local = create();
      final attempt = local.saveAutomaticLogin('test-user', 'fixture-password');
      while (sessions.isEmpty || sessions.single.automaticLogins == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      await settings.saveGoogleAccount(
        const GoogleAccount(email: 'other@example.com'),
      );
      local.settingsChanged();
      wait.complete();
      await attempt;
      expect(only()['result'], 'canceled');
    });

    test('every LmsLoginFailure has a matching analytics cause code', () {
      expect(
        LmsLoginFailure.values.map((value) => value.name).toSet(),
        analyticsLmsCauseValues,
      );
    });
  });
}
