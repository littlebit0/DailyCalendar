import 'dart:convert';
import 'dart:io';

import 'package:daily/app/daily_theme.dart';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/university_directory.dart';
import 'package:daily/core/auth/google_account.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/lms/lms_controller.dart';
import 'package:daily/core/lms/lms_web_session.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:daily/core/sync/google_drive_sync_service.dart';
import 'package:daily/features/events/application/event_command_service.dart';
import 'package:daily/features/events/domain/event_repository.dart';
import 'package:daily/features/settings/presentation/academic_calendar_page.dart';
import 'package:daily/features/settings/presentation/academic_management_page.dart';
import 'package:daily/features/settings/presentation/academic_profile_page.dart';
import 'package:daily/features/settings/presentation/lms_settings_page.dart';
import 'package:daily/features/settings/presentation/settings_page.dart';
import 'package:daily/features/timetable/presentation/timetable_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends GoogleDriveAuthService {
  @override
  Future<GoogleDriveAccount?> restorePreviousSignIn() async => null;
}

class _Drive extends Fake implements GoogleDriveSyncService {
  @override
  final statusNotifier = ValueNotifier(const GoogleDriveSyncStatus());
}

class _Events extends Fake implements EventRepository {}

class _Commands extends Fake implements EventCommandService {}

class _NoSession extends LmsWebSession {
  _NoSession(String owner, String school)
    : super(ownerId: owner, schoolId: school);
  @override
  Future<bool> hasStoredSession() async => false;
  @override
  Future<void> close() async {}
}

void main() {
  late UniversityDirectory directory;
  setUpAll(() {
    directory = UniversityDirectory.fromJson(
      jsonDecode(File('assets/academic/universities.json').readAsStringSync())
          as Map<String, dynamic>,
    );
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Daily',
      packageName: 'daily',
      version: '3.5.2',
      buildNumber: '352',
      buildSignature: '',
    );
  });

  Future<SettingsRepository> pump(
    WidgetTester tester, {
    Widget home = const SettingsPage(),
    String? university,
  }) async {
    final settings = SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
    );
    if (university != null) {
      await settings.saveGoogleAccount(
        const GoogleAccount(email: 'student@example.com'),
      );
      await settings.saveAcademicProfile(
        AcademicProfile(
          universityId: university == 'smu'
              ? 'institution:academyinfo:0000117'
              : 'institution:academyinfo:0000023',
          universityName: university == 'smu' ? '상명대학교' : '전남대학교',
          schoolKind: 'fourYear',
        ),
        expectedGoogleEmail: 'student@example.com',
      );
    }
    final drive = _Drive();
    addTearDown(drive.statusNotifier.dispose);
    final lms = LmsController(
      settings: settings,
      repository: _Events(),
      commands: _Commands(),
      createSession: _NoSession.new,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          googleDriveAuthServiceProvider.overrideWithValue(_Auth()),
          googleDriveSyncServiceProvider.overrideWithValue(drive),
          universityDirectoryProvider.overrideWith((ref) async => directory),
          timetablePeriodPreparationProvider.overrideWith((ref) async {}),
          lmsControllerProvider.overrideWith((ref) => lms),
        ],
        child: MaterialApp(
          theme: DailyTheme.light(),
          locale: const Locale('ko'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return settings;
  }

  Future<void> open(WidgetTester tester, String key) async {
    final tile = find.byKey(ValueKey(key));
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    // pageBack() searches for the English tooltip "Back". These tests run
    // with Korean Material localizations, so verify and tap the actual button.
    final button = find.byType(BackButton);
    expect(button, findsOneWidget);
    final tooltip = MaterialLocalizations.of(
      tester.element(button),
    ).backButtonTooltip;
    expect(
      find.descendant(of: button, matching: find.byTooltip(tooltip)),
      findsOneWidget,
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'academic management is next to account and removes old duplicate entries',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pump(tester);
      final account = find.byKey(const ValueKey('account-settings-navigation'));
      final academic = find.byKey(
        const ValueKey('academic-management-navigation'),
      );
      final notification = find.byKey(
        const ValueKey('notification-settings-navigation'),
      );
      expect(academic, findsOneWidget);
      expect(
        tester.getTopLeft(account).dy,
        lessThan(tester.getTopLeft(academic).dy),
      );
      expect(
        tester.getTopLeft(academic).dy,
        lessThan(tester.getTopLeft(notification).dy),
      );
      await open(tester, 'account-settings-navigation');
      expect(
        find.byKey(const ValueKey('academic-profile-settings')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('academic-lms-connection')),
        findsNothing,
      );
      await back(tester);
      await open(tester, 'appearance-settings-navigation');
      expect(
        find.byKey(const ValueKey('academic-calendar-settings')),
        findsNothing,
      );
      await back(tester);
      await open(tester, 'academic-management-navigation');
      expect(find.byType(AcademicManagementPage), findsOneWidget);
      for (final key in [
        'academic-profile-settings',
        'academic-lms-connection',
        'academic-calendar-settings',
        'timetable-settings-navigation',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'all four destinations open and preserve signed-out/profile gates',
    (tester) async {
      await pump(tester, home: const AcademicManagementPage());
      await open(tester, 'academic-profile-settings');
      expect(find.byType(AcademicProfilePage), findsOneWidget);
      expect(find.text('Google 계정 연결'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('academic-lms-connection')),
        findsNothing,
      );
      await back(tester);
      await open(tester, 'academic-lms-connection');
      expect(find.byType(LmsSettingsPage), findsOneWidget);
      expect(find.text('Google 계정 로그인이 필요합니다.'), findsOneWidget);
      expect(find.byKey(const ValueKey('lms-connect')), findsNothing);
      await back(tester);
      await open(tester, 'academic-calendar-settings');
      expect(find.byType(AcademicCalendarPage), findsOneWidget);
      expect(find.text('학사 정보 설정'), findsOneWidget);
      await back(tester);
      await open(tester, 'timetable-settings-navigation');
      expect(find.byType(TimetableSettingsPage), findsOneWidget);
      expect(find.text('학사 정보 설정'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final university in ['smu', 'jnu']) {
    testWidgets(
      '$university profile form has no LMS button; management preserves LMS support gate',
      (tester) async {
        final settings = await pump(
          tester,
          home: const AcademicManagementPage(),
          university: university,
        );
        final before = settings.load().academicProfile;
        await open(tester, 'academic-profile-settings');
        expect(find.byKey(const ValueKey('university-search')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('academic-lms-connection')),
          findsNothing,
        );
        await back(tester);
        await open(tester, 'academic-lms-connection');
        expect(find.byType(LmsSettingsPage), findsOneWidget);
        expect(
          find.byKey(const ValueKey('lms-connect')),
          university == 'smu' ? findsOneWidget : findsNothing,
        );
        if (university == 'jnu') {
          expect(
            find.text('현재 상명대학교 과제·퀴즈를 지원합니다. 다른 학교는 확인 후 지원합니다.'),
            findsOneWidget,
          );
        }
        expect(settings.load().academicProfile, before);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  test('academic menu labels cover all four supported locales', () {
    final labels = [
      (const Locale('ko'), '학사 관리', '시간표 설정'),
      (const Locale('en'), 'Academic management', 'Timetable settings'),
      (const Locale('ja'), '学事管理', '時間割設定'),
      (
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        '學務管理',
        '課表設定',
      ),
    ];
    for (final (locale, academic, timetable) in labels) {
      final l10n = AppLocalizations(locale);
      expect(l10n.text('학사 관리'), academic);
      expect(l10n.text('시간표 설정'), timetable);
    }
  });
}
