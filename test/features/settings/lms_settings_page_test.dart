import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/auth/google_account.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/lms/lms_controller.dart';
import 'package:daily/core/lms/lms_web_session.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/features/events/application/event_command_service.dart';
import 'package:daily/features/events/domain/event_repository.dart';
import 'package:daily/features/settings/presentation/lms_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repository extends Fake implements EventRepository {}

class _Commands extends Fake implements EventCommandService {}

class _NoSession extends LmsWebSession {
  _NoSession(String owner, String school)
    : super(ownerId: owner, schoolId: school);
  int checks = 0;
  @override
  Future<bool> hasStoredSession() async {
    checks++;
    return false;
  }

  @override
  Future<void> close() async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final school in ['smu', 'jnu']) {
    testWidgets(
      '$school LMS settings supports narrow large-text layout without opening login',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final settings = SettingsRepository(
          preferences: await SharedPreferences.getInstance(),
        );
        await settings.saveGoogleAccount(
          const GoogleAccount(email: 'student@example.com'),
        );
        await settings.saveAcademicProfile(
          AcademicProfile(
            universityId: school == 'smu'
                ? 'institution:academyinfo:0000117'
                : 'institution:academyinfo:0000023',
            universityName: school == 'smu' ? '상명대학교' : '전남대학교',
            schoolKind: 'fourYear',
          ),
          expectedGoogleEmail: 'student@example.com',
        );
        final sessions = <_NoSession>[];
        final controller = LmsController(
          settings: settings,
          repository: _Repository(),
          commands: _Commands(),
          createSession: (owner, school) {
            final value = _NoSession(owner, school);
            sessions.add(value);
            return value;
          },
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsRepositoryProvider.overrideWithValue(settings),
              lmsControllerProvider.overrideWith((ref) => controller),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(2)),
                child: child!,
              ),
              home: const LmsSettingsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (school == 'smu') {
          final connect = find.byKey(const ValueKey('lms-connect'));
          await tester.scrollUntilVisible(connect, 180);
          expect(tester.widget<FilledButton>(connect).onPressed, isNotNull);
          expect(sessions.single.checks, 1);
        } else {
          expect(find.byKey(const ValueKey('lms-connect')), findsNothing);
          expect(sessions, isEmpty);
        }
        // Closing the page without connecting changes neither Google nor profile.
        expect(
          settings.dailyAccount()!.googleAccount!.email,
          'student@example.com',
        );
        expect(settings.load().academicProfile!.timetableUniversity, school);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
