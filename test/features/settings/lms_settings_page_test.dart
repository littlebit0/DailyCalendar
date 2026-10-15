import 'dart:io';
import 'package:flutter/services.dart';
import 'package:daily/app/daily_theme.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/auth/google_account.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/lms/lms_controller.dart';
import 'package:daily/core/lms/lms_credentials_store.dart';
import 'package:daily/core/lms/lms_sync_service.dart';
import 'package:daily/core/lms/lms_web_session.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/features/events/application/event_command_service.dart';
import 'package:daily/features/events/domain/event_repository.dart';
import 'package:daily/features/settings/presentation/lms_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repository extends Fake implements EventRepository {}

class _Commands extends Fake implements EventCommandService {}

class _NoSession extends LmsWebSession {
  _NoSession(String owner, String school)
    : super(ownerId: owner, schoolId: school);
  int checks = 0;
  LmsLocalCredentials? submittedCredentials;
  @override
  Future<bool> loginAutomatically(
    LmsLocalCredentials credentials, {
    String? expectedPrincipal,
  }) async {
    submittedCredentials = credentials;
    return false;
  }

  @override
  Future<bool> hasStoredSession() async {
    checks++;
    return false;
  }

  @override
  Future<void> close() async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets(
    'Mac password focus requests English input and restores on blur and dialog close',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel('daily/password_input');
      final modes = <bool>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        expect(call.method, 'setEnglishInput');
        modes.add(call.arguments as bool);
        return true;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final settings = SettingsRepository(
        preferences: await SharedPreferences.getInstance(),
      );
      await settings.saveGoogleAccount(
        const GoogleAccount(email: 'student@example.com'),
      );
      await settings.saveAcademicProfile(
        const AcademicProfile(
          universityId: 'institution:academyinfo:0000117',
          universityName: '상명대학교',
          schoolKind: 'fourYear',
        ),
        expectedGoogleEmail: 'student@example.com',
      );
      final controller = LmsController(
        settings: settings,
        repository: _Repository(),
        commands: _Commands(),
        createSession: (owner, school) => _NoSession(owner, school),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settings),
            lmsControllerProvider.overrideWith((ref) => controller),
          ],
          child: MaterialApp(home: const LmsSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();
      final configure = find.byKey(const ValueKey('lms-local-login-configure'));
      await tester.ensureVisible(configure);
      await tester.tap(configure);
      await tester.pumpAndSettle();
      final password = find.byKey(const ValueKey('lms-local-password'));
      final username = find.byKey(const ValueKey('lms-local-username'));
      await tester.ensureVisible(password);
      await tester.showKeyboard(password);
      await tester.pumpAndSettle();
      expect(modes.last, isTrue);
      const fixture = " Ab9!@#'-_ ";
      await tester.enterText(password, fixture);
      expect(tester.widget<TextField>(password).controller!.text, fixture);
      await tester.ensureVisible(username);
      await tester.showKeyboard(username);
      await tester.pumpAndSettle();
      expect(modes.last, isFalse);
      await tester.showKeyboard(password);
      await tester.pumpAndSettle();
      expect(modes.last, isTrue);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(modes.last, isFalse);
      expect(
        await LmsCredentialsStore().read('student@example.com', 'smu'),
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('LMS grouped design $brightness displays saved device username', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(720, 1500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final settings = SettingsRepository(
        preferences: await SharedPreferences.getInstance(),
      );
      await settings.saveGoogleAccount(
        const GoogleAccount(email: 'student@example.com'),
      );
      await settings.saveAcademicProfile(
        const AcademicProfile(
          universityId: 'institution:academyinfo:0000117',
          universityName: '상명대학교',
          schoolKind: 'fourYear',
        ),
        expectedGoogleEmail: 'student@example.com',
      );
      await LmsCredentialsStore().save(
        'student@example.com',
        'smu',
        const LmsLocalCredentials('fixture-student', 'synthetic', paused: true),
      );
      final controller = LmsController(
        settings: settings,
        repository: _Repository(),
        commands: _Commands(),
        createSession: (owner, school) => _NoSession(owner, school),
      );
      final captureDesign = Platform.environment['DAILY_LMS_UI_AUDIT'] == '1';
      if (captureDesign && Platform.isMacOS) {
        await tester.runAsync(() async {
          await (FontLoader('Apple SD Gothic Neo')..addFont(
                File(
                  '/System/Library/Fonts/AppleSDGothicNeo.ttc',
                ).readAsBytes().then(ByteData.sublistView),
              ))
              .load();
          await (FontLoader('MaterialIcons')..addFont(
                File(
                  '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
                ).readAsBytes().then(ByteData.sublistView),
              ))
              .load();
        });
      }
      final capture = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settings),
            lmsControllerProvider.overrideWith((ref) => controller),
          ],
          child: MaterialApp(
            theme:
                (brightness == Brightness.dark
                        ? DailyTheme.dark()
                        : DailyTheme.light())
                    .copyWith(
                      textTheme:
                          (brightness == Brightness.dark
                                  ? DailyTheme.dark()
                                  : DailyTheme.light())
                              .textTheme
                              .apply(
                                fontFamily: Platform.isMacOS
                                    ? 'Apple SD Gothic Neo'
                                    : null,
                              ),
                    ),
            home: RepaintBoundary(key: capture, child: const LmsSettingsPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('fixture-student'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('lms-local-login-remove')),
        findsOneWidget,
      );
      expect(find.text('synthetic'), findsNothing);
      expect(tester.takeException(), isNull);
      if (captureDesign) {
        final boundary =
            capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          final captureDirectory = await Directory.systemTemp.createTemp(
            'daily-ui-audit-',
          );
          await File(
            '${captureDirectory.path}/settings-${brightness.name}.png',
          ).writeAsBytes(png!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

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
          expect(
            find.byKey(const ValueKey('lms-local-login-remove')),
            findsNothing,
          );
          expect(controller.localLoginUsername, isNull);
          final configure = find.byKey(
            const ValueKey('lms-local-login-configure'),
          );
          await tester.scrollUntilVisible(configure, 180);
          await tester.pumpAndSettle();
          await tester.tap(configure);
          await tester.pumpAndSettle();
          expect(find.textContaining('자동 로그인은 해당 기기에만 적용됩니다.'), findsWidgets);
          expect(find.textContaining('로그아웃될 수 있습니다.'), findsWidgets);
          expect(
            tester
                .widget<TextField>(
                  find.byKey(const ValueKey('lms-local-password')),
                )
                .obscureText,
            isTrue,
          );
          expect(
            tester
                .widget<FilledButton>(
                  find.byKey(const ValueKey('lms-local-save')),
                )
                .onPressed,
            isNull,
          );
          // Exercise incremental Mac input through the real dialog, secure
          // store and controller; never use an actual user's password here.
          final passwordField = find.byKey(
            const ValueKey('lms-local-password'),
          );
          await tester.enterText(
            find.byKey(const ValueKey('lms-local-username')),
            ' fixture-user ',
          );
          await tester.ensureVisible(passwordField);
          await tester.showKeyboard(passwordField);
          const fixturePassword = " Ab9!@#\\\"'-_끝 ";
          final originalController = tester
              .widget<TextField>(passwordField)
              .controller;
          for (var i = 1; i <= fixturePassword.length; i++) {
            tester.testTextInput.updateEditingValue(
              TextEditingValue(
                text: fixturePassword.substring(0, i),
                selection: TextSelection.collapsed(offset: i),
              ),
            );
            await tester.pump();
            expect(
              tester.widget<TextField>(passwordField).controller,
              same(originalController),
            );
            expect(originalController!.text, fixturePassword.substring(0, i));
          }
          expect(
            tester.widget<TextField>(passwordField).enableInlinePrediction,
            isFalse,
          );
          await tester.ensureVisible(
            find.byKey(const ValueKey('lms-local-consent')),
          );
          await tester.tap(find.byKey(const ValueKey('lms-local-consent')));
          await tester.pump();
          await tester.ensureVisible(
            find.byKey(const ValueKey('lms-local-save')),
          );
          await tester.tap(find.byKey(const ValueKey('lms-local-save')));
          await tester.pumpAndSettle();
          final stored = await LmsCredentialsStore().read(
            'student@example.com',
            'smu',
          );
          expect(stored!.username, 'fixture-user');
          expect(stored.password, fixturePassword);
          expect(
            sessions.single.submittedCredentials!.password,
            fixturePassword,
          );
          final username = find.byKey(
            const ValueKey('lms-local-login-username'),
          );
          await tester.ensureVisible(username);
          await tester.pumpAndSettle();
          expect(tester.widget<Text>(username).data, 'fixture-user');
          final reason = find.byKey(const ValueKey('lms-login-failure-reason'));
          await tester.ensureVisible(reason);
          await tester.pumpAndSettle();
          expect(
            tester.widget<Text>(reason).data,
            LmsLoginFailure.authenticationUnconfirmed.message,
          );
          expect(find.textContaining(fixturePassword), findsNothing);

          final remove = find.byKey(const ValueKey('lms-local-login-remove'));
          await Scrollable.ensureVisible(
            tester.element(remove),
            alignment: 0.5,
          );
          await tester.pumpAndSettle();
          await tester.tap(remove);
          await tester.pumpAndSettle();
          expect(remove, findsNothing);
          expect(controller.localLoginUsername, isNull);
          expect(
            await LmsCredentialsStore().read('student@example.com', 'smu'),
            isNull,
          );
          expect(tester.takeException(), isNull);
          final connect = find.byKey(const ValueKey('lms-connect'));
          await tester.scrollUntilVisible(connect, 180);
          expect(tester.widget<FilledButton>(connect).onPressed, isNotNull);
          expect(sessions.single.checks, greaterThanOrEqualTo(1));
          // A partial learning snapshot remains explicit even after a later
          // connection failure; it must not silently look like full coverage.
          controller.sync.lastResult = const LmsSyncResult(
            courses: 3,
            activities: 8,
            unscheduled: 0,
            added: 5,
            updated: 0,
            deleted: 0,
            unchanged: 3,
            learningActivities: 5,
            unresolvedLearningActivities: 4,
            failedLearningCourses: 2,
          );
          controller.sync.markRestoreFailed();
          await tester.pumpAndSettle();
          final notice = find.byKey(
            const ValueKey('lms-learning-coverage-notice'),
          );
          await tester.scrollUntilVisible(notice, -180);
          expect(
            find.text('학습 정보가 충분하지 않은 항목 4개는 추가하지 않았습니다.'),
            findsOneWidget,
          );
          expect(
            find.text('강좌 2개의 학습 정보를 확인하지 못했습니다. 기존 학습 일정은 유지됩니다.'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          // A subsequently complete report removes the previous warning.
          controller.sync.lastResult = const LmsSyncResult(
            courses: 3,
            activities: 12,
            unscheduled: 0,
            added: 4,
            updated: 0,
            deleted: 0,
            unchanged: 8,
            learningActivities: 9,
          );
          controller.sync.markRestoreFailed();
          await tester.pumpAndSettle();
          expect(notice, findsNothing);
        } else {
          expect(find.byKey(const ValueKey('lms-connect')), findsNothing);
          expect(sessions, isEmpty);
          expect(find.text('해당 대학의 LMS 연결은 아직 지원하지 않습니다.'), findsOneWidget);
          expect(find.textContaining('현재 상명대학교 LMS'), findsNothing);
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
