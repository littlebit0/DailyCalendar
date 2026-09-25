import 'dart:convert';
import 'dart:io';

import 'package:daily/app/daily_theme.dart';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/university_directory.dart';
import 'package:daily/core/auth/google_account.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/google_drive_sync_service.dart';
import 'package:daily/features/settings/presentation/academic_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Queue extends Fake implements GoogleDriveSyncService {
  int calls = 0;
  @override
  Future<void> queueSettingsBackup() async {
    calls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late UniversityDirectory directory;
  setUpAll(() {
    directory = UniversityDirectory.fromJson(
      jsonDecode(File('assets/academic/universities.json').readAsStringSync())
          as Map<String, dynamic>,
    );
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<SettingsRepository> repository({bool signedIn = true}) async {
    final repo = SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
    );
    if (signedIn) {
      await repo.saveGoogleAccount(
        const GoogleAccount(email: 'student@example.com'),
      );
    }
    return repo;
  }

  Widget app(
    SettingsRepository repo,
    _Queue queue, {
    double scale = 1,
    Widget? child,
    ValueChanged<bool?>? onResult,
    bool onboarding = false,
  }) => ProviderScope(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(repo),
      googleDriveSyncServiceProvider.overrideWithValue(queue),
      universityDirectoryProvider.overrideWith((ref) async => directory),
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
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body:
            child ??
            Builder(
              builder: (context) => TextButton(
                key: const ValueKey('open-profile'),
                onPressed: () async {
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AcademicProfilePage(onboarding: onboarding),
                    ),
                  );
                  onResult?.call(result);
                },
                child: const Text('Open'),
              ),
            ),
      ),
    ),
  );
  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('open-profile')));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(
      find.byKey(const ValueKey('university-search')),
      query,
    );
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('academic-profile-save'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> chooseCampus(WidgetTester tester, String id) async {
    final selector = find.byKey(const ValueKey('academic-profile-campus'));
    await tester.ensureVisible(selector);
    await tester.pumpAndSettle();
    await tester.tap(selector);
    await tester.pumpAndSettle();
    final campus = find.byKey(ValueKey('university-campus-$id'));
    await tester.ensureVisible(campus);
    await tester.pumpAndSettle();
    await tester.tap(campus);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'integrated university saves once without requiring campus selection',
    (tester) async {
      final repo = await repository();
      final queue = _Queue();
      bool? returned;
      await tester.pumpWidget(
        app(repo, queue, onResult: (value) => returned = value),
      );
      await open(tester);
      expect(find.text('4년제'), findsNothing);
      expect(find.text('2,3년제'), findsNothing);
      expect(find.text('사이버대학'), findsNothing);
      expect(find.byKey(const ValueKey('university-kind')), findsNothing);
      expect(find.byType(SegmentedButton<String>), findsNothing);
      await search(tester, 'ㅅㅁㄷ');
      expect(find.text('상명대학교'), findsOneWidget);
      await tester.tap(
        find.byKey(
          const ValueKey('university-institution:academyinfo:0000117'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('academic-profile-campus')),
        findsNothing,
      );
      expect(find.text('서울 / 천안'), findsWidgets);
      final footer = tester.widget<Container>(
        find.byKey(const ValueKey('academic-profile-selection-footer')),
      );
      expect((footer.decoration! as BoxDecoration).border, isNotNull);
      await save(tester);
      expect(
        repo.load().academicProfile!.universityId,
        'institution:academyinfo:0000117',
      );
      expect(repo.load().academicProfile!.campusId, isNull);
      expect(repo.load().academicProfile!.campus, isNull);
      expect(repo.hasPendingSettingsSync, isTrue);
      expect(queue.calls, 1);
      expect(returned, isTrue);
      expect(find.byType(AcademicProfilePage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('only separate branches retain an official-name campus picker', (
    tester,
  ) async {
    final repo = await repository();
    await tester.pumpWidget(app(repo, _Queue()));
    await open(tester);
    for (final name in [
      '전남대학교',
      '고려대학교',
      '상명대학교',
      '단국대학교',
      '연세대학교',
      '한양대학교',
      '건국대학교',
      '동국대학교',
    ]) {
      await search(tester, name);
      final institution = directory
          .searchInstitutions(name)
          .singleWhere((school) => school.name == name);
      final row = find.byKey(ValueKey('university-${institution.id}'));
      await tester.tap(row);
      await tester.pumpAndSettle();
      final selector = find.byKey(const ValueKey('academic-profile-campus'));
      if (!institution.campusSelectionRequired) {
        expect(selector, findsNothing);
        continue;
      }
      await tester.ensureVisible(selector);
      await tester.pumpAndSettle();
      await tester.tap(selector);
      await tester.pumpAndSettle();
      for (final campus in institution.campuses) {
        final tile = tester.widget<ListTile>(
          find.byKey(ValueKey('university-campus-${campus.id}')),
        );
        expect((tile.title! as Text).data, campus.campus);
        expect((tile.subtitle! as Text).data, campus.region);
      }
      await tester.tap(find.byKey(const ValueKey('university-campus-close')));
      await tester.pumpAndSettle();
    }
    expect(repo.load().academicProfile, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'legacy campus profile remains intact until explicit institution save',
    (tester) async {
      final repo = await repository();
      const legacy = AcademicProfile(
        universityId: 'academyinfo:0002959',
        universityName: '상명대학교',
        schoolKind: 'fourYear',
        campus: '천안캠퍼스',
      );
      await repo.saveAcademicProfile(
        legacy,
        expectedGoogleEmail: 'student@example.com',
      );
      await repo.acknowledgeSettingsSyncDocument(repo.settingsSyncDocument());
      final revision = repo.settingsSyncRevision;
      final queue = _Queue();
      await tester.pumpWidget(app(repo, queue));
      await open(tester);
      expect(find.text('서울 / 천안'), findsWidgets);
      expect(repo.load().academicProfile!.toJson(), legacy.toJson());
      expect(repo.settingsSyncRevision, revision);
      expect(repo.hasPendingSettingsSync, isFalse);
      await save(tester);
      expect(
        repo.load().academicProfile!.universityId,
        'institution:academyinfo:0000117',
      );
      expect(repo.load().academicProfile!.campusId, isNull);
      await open(tester);
      await search(tester, '고려대학교');
      final next = directory
          .searchInstitutions('고려대학교')
          .singleWhere((school) => school.name == '고려대학교');
      await tester.tap(find.byKey(ValueKey('university-${next.id}')));
      await tester.pumpAndSettle();
      await chooseCampus(tester, next.campuses.last.id);
      await save(tester);
      expect(repo.load().academicProfile!.universityId, next.id);
      expect(repo.load().academicProfile!.campusId, 'academyinfo:0000070');
      expect(repo.load().academicProfile!.campus, '세종캠퍼스');
      expect(queue.calls, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'junior cyber military theology and LH schools are absent from the four-year picker',
    (tester) async {
      final repo = await repository();
      final queue = _Queue();
      await tester.pumpWidget(app(repo, queue));
      await open(tester);
      for (final query in [
        '육군사관학교',
        '감리교신학대학교',
        '고려사이버',
        '세계사이버',
        '동양미래',
        '서울예술',
        '토지주택',
        'LH',
      ]) {
        await search(tester, query);
        expect(find.text('검색 결과가 없습니다.'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('academic-profile-save')),
              )
              .onPressed,
          isNull,
        );
      }
      expect(repo.load().academicProfile, isNull);
      expect(repo.hasPendingSettingsSync, isFalse);
      expect(queue.calls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final name in ['육군사관학교', '동양미래대학교', '고려사이버대학교', 'LH토지주택대학교']) {
    testWidgets(
      'excluded legacy $name remains readable without a silent rewrite',
      (tester) async {
        final repo = await repository();
        final institution = directory
            .searchInstitutions(name, includeUnselectable: true)
            .singleWhere((school) => school.name == name);
        final legacy = AcademicProfile(
          universityId: institution.campuses.first.id,
          universityName: name,
          schoolKind: institution.kind.name,
        );
        await repo.saveAcademicProfile(
          legacy,
          expectedGoogleEmail: 'student@example.com',
        );
        await repo.acknowledgeSettingsSyncDocument(repo.settingsSyncDocument());
        final revision = repo.settingsSyncRevision;
        final document = jsonEncode(repo.settingsSyncDocument().toJson());
        final queue = _Queue();
        await tester.pumpWidget(app(repo, queue));
        await open(tester);
        await search(tester, name);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('academic-profile-selection-footer')),
            matching: find.text(name),
          ),
          findsOneWidget,
        );
        expect(find.text('검색 결과가 없습니다.'), findsOneWidget);
        expect(
          find.byKey(ValueKey('university-${institution.id}')),
          findsNothing,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('academic-profile-save')),
              )
              .onPressed,
          isNull,
        );
        expect(repo.load().academicProfile, legacy);
        expect(repo.settingsSyncRevision, revision);
        expect(jsonEncode(repo.settingsSyncDocument().toJson()), document);
        expect(repo.hasPendingSettingsSync, isFalse);
        expect(queue.calls, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'unsupported four-year university remains selectable without enabling SMU',
    (tester) async {
      final repo = await repository();
      final queue = _Queue();
      await tester.pumpWidget(app(repo, queue));
      await open(tester);
      await search(tester, '서울대학교');
      final institution = directory
          .searchInstitutions('서울대학교')
          .singleWhere((school) => school.name == '서울대학교');
      await tester.tap(find.byKey(ValueKey('university-${institution.id}')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('이 대학의 학사일정·시간표 연동은 준비 중입니다.'),
        findsOneWidget,
      );
      await save(tester);
      expect(repo.load().academicProfile!.supported, isFalse);
      expect(repo.load().academicProfile!.schoolKind, 'fourYear');
      expect(queue.calls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        app(
          repo,
          queue,
          child: const AcademicFeatureGate(child: Text('supported-feature')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('supported-feature'), findsNothing);
      expect(find.text('이 대학의 학사일정·시간표 연동은 준비 중입니다.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'canceling onboarding after school selection does not persist a profile',
    (tester) async {
      final repo = await repository();
      final queue = _Queue();
      await tester.pumpWidget(app(repo, queue, onboarding: true));
      await open(tester);
      await search(tester, '상명 천안');
      await tester.tap(
        find.byKey(
          const ValueKey('university-institution:academyinfo:0000117'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('나중에'));
      await tester.pumpAndSettle();
      expect(repo.load().academicProfile, isNull);
      expect(repo.hasPendingSettingsSync, isFalse);
      expect(queue.calls, 0);
      expect(find.byType(AcademicProfilePage), findsNothing);
    },
  );

  testWidgets(
    'signed-out users see account connection without editable university data',
    (tester) async {
      final repo = await repository(signedIn: false);
      final queue = _Queue();
      await tester.pumpWidget(app(repo, queue));
      await open(tester);
      expect(find.text('Google 계정 연결'), findsOneWidget);
      expect(find.byKey(const ValueKey('university-search')), findsNothing);
      expect(find.byKey(const ValueKey('academic-profile-save')), findsNothing);
      expect(repo.load().academicProfile, isNull);
      expect(queue.calls, 0);
    },
  );

  testWidgets(
    'stale account editor keeps selection and reports failure without queuing',
    (tester) async {
      final repo = await repository();
      final queue = _Queue();
      await tester.pumpWidget(app(repo, queue));
      await open(tester);
      await search(tester, '상명 서울');
      await tester.tap(
        find.byKey(
          const ValueKey('university-institution:academyinfo:0000117'),
        ),
      );
      await tester.pumpAndSettle();
      await repo.saveGoogleAccount(
        const GoogleAccount(email: 'changed@example.com'),
      );
      await save(tester);
      expect(
        find.text('학사 정보를 저장하지 못했습니다. 계정 연결을 확인하고 다시 시도해 주세요.'),
        findsOneWidget,
      );
      expect(repo.load().academicProfile, isNull);
      expect(queue.calls, 0);
      expect(find.byType(AcademicProfilePage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'known unsupported and missing profiles remain gated; supported campus opens feature',
    (tester) async {
      final repo = await repository();
      final queue = _Queue();
      await tester.pumpWidget(
        app(
          repo,
          queue,
          child: const AcademicFeatureGate(child: Text('supported-feature')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('학사 정보 설정'), findsOneWidget);
      expect(find.text('supported-feature'), findsNothing);
      await repo.saveAcademicProfile(
        const AcademicProfile(
          universityId: 'academyinfo:0000117',
          universityName: '상명대학교',
          schoolKind: 'fourYear',
        ),
        expectedGoogleEmail: 'student@example.com',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        app(
          repo,
          queue,
          child: const AcademicFeatureGate(child: Text('supported-feature')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('supported-feature'), findsOneWidget);
    },
  );

  testWidgets(
    '320px doubled text keeps selection and save reachable through keyboard resize',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final repo = await repository();
      final queue = _Queue();
      await tester.pumpWidget(app(repo, queue, scale: 2));
      await open(tester);
      expect(tester.takeException(), isNull);
      await search(tester, 'ㅅㅁㄷ');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final row = find.byKey(
        const ValueKey('university-institution:academyinfo:0000117'),
      );
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('academic-profile-campus')),
        findsNothing,
      );
      await save(tester);
      expect(
        repo.load().academicProfile!.universityId,
        'institution:academyinfo:0000117',
      );
      expect(repo.load().academicProfile!.campusId, isNull);
      expect(queue.calls, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
