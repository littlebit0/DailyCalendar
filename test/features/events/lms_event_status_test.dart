import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/lms/lms_controller.dart';
import 'package:daily/core/lms/lms_models.dart';
import 'package:daily/core/lms/lms_sync_service.dart';
import 'package:daily/core/lms/lms_web_session.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/features/events/application/event_command_service.dart';
import 'package:daily/features/events/domain/event_repository.dart';
import 'package:daily/features/events/presentation/lms_event_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repository extends Fake implements EventRepository {}

class _Commands extends Fake implements EventCommandService {}

class _NoSession extends LmsWebSession {
  _NoSession(String owner, String school)
    : super(ownerId: owner, schoolId: school);
}

LmsEventMetadata _lecture() => LmsEventMetadata(
  schoolId: 'smu',
  ownerId: 'student@example.com',
  lmsUserId: '70001',
  courseId: '1',
  courseTitle: '강좌',
  activityType: 'lecture',
  activityId: '10',
  sourceUrl: 'https://example.com/mod/vod/view.php?id=10',
  dueAt: DateTime.utc(2026, 10, 20),
  learnedSeconds: 317,
  requiredLearningSeconds: 3000,
);

const _note = '일부 학습 정보를 이번에 확인하지 못해 위 학습 정보는 이전에 확인한 값일 수 있습니다.';

void main() {
  setUpAll(initializeDateFormatting);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<LmsController> pump(
    WidgetTester tester,
    LmsEventMetadata metadata,
    LmsSyncResult? result,
  ) async {
    final settings = SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
    );
    final controller = LmsController(
      settings: settings,
      repository: _Repository(),
      commands: _Commands(),
      createSession: (owner, school) => _NoSession(owner, school),
    );
    controller.sync.lastResult = result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          lmsControllerProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(
          home: Scaffold(body: LmsEventStatus(metadata: metadata)),
        ),
      ),
    );
    return controller;
  }

  const partial = LmsSyncResult(
    courses: 2,
    activities: 5,
    unscheduled: 0,
    added: 0,
    updated: 1,
    deleted: 0,
    unchanged: 4,
    failedLearningCourses: 1,
  );
  const complete = LmsSyncResult(
    courses: 2,
    activities: 5,
    unscheduled: 0,
    added: 0,
    updated: 1,
    deleted: 0,
    unchanged: 4,
  );

  testWidgets('a lecture shows that its learning values may be earlier ones', (
    tester,
  ) async {
    await pump(tester, _lecture(), partial);
    expect(find.text(_note), findsOneWidget);
  });

  Future<void> stamp(
    WidgetTester tester,
    LmsController controller,
    LmsEventMetadata metadata,
    DateTime confirmed,
    DateTime syncSuccess,
  ) async {
    final settings = SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
    );
    await settings.saveLmsLearningCheckedAt(
      {LmsSyncService.eventId(metadata): confirmed},
      ownerId: metadata.ownerId,
      schoolId: metadata.schoolId,
      lmsUserId: metadata.lmsUserId,
    );
    controller.sync.lastSuccess = syncSuccess;
  }

  testWidgets(
    'this lecture older than the latest sync is flagged even after a restart',
    (tester) async {
      final lecture = _lecture();
      final controller = await pump(tester, lecture, null); // no lastResult
      await stamp(
        tester,
        controller,
        lecture,
        DateTime.utc(2026, 10, 1, 12),
        DateTime.utc(2026, 10, 5, 12),
      );
      controller.sync.notifyListeners();
      await tester.pump();
      expect(find.text(_note), findsOneWidget);
      // The shown time is this lecture's, not the whole sync's.
      expect(find.textContaining('2026. 10. 1.'), findsOneWidget);
      expect(find.textContaining('2026. 10. 5.'), findsNothing);
    },
  );

  testWidgets(
    'a lecture confirmed in the latest sync is not flagged when another course failed',
    (tester) async {
      final lecture = _lecture();
      final controller = await pump(tester, lecture, partial);
      await stamp(
        tester,
        controller,
        lecture,
        DateTime.utc(2026, 10, 5, 12),
        DateTime.utc(2026, 10, 5, 12),
      );
      controller.sync.notifyListeners();
      await tester.pump();
      expect(find.text(_note), findsNothing);
      expect(find.textContaining('2026. 10. 5.'), findsOneWidget);
    },
  );

  testWidgets('a fully read sync shows no extra note', (tester) async {
    await pump(tester, _lecture(), complete);
    expect(find.text(_note), findsNothing);
  });

  testWidgets('assignments and quizzes never get the learning note', (
    tester,
  ) async {
    final assignment = LmsEventMetadata(
      schoolId: 'smu',
      ownerId: 'student@example.com',
      lmsUserId: '70001',
      courseId: '1',
      courseTitle: '강좌',
      activityType: 'assignment',
      activityId: '11',
      sourceUrl: 'https://example.com/mod/assign/view.php?id=11',
      dueAt: DateTime.utc(2026, 10, 20),
    );
    await pump(tester, assignment, partial);
    expect(find.text(_note), findsNothing);
  });
}
