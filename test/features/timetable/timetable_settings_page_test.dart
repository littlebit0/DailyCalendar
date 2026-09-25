import 'package:daily/app/daily_theme.dart';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/theme/daily_ui.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/timetable_term.dart';
import 'package:daily/features/timetable/presentation/timetable_page.dart';
import 'package:daily/features/timetable/presentation/timetable_settings_page.dart';
import 'package:daily/features/timetable/presentation/weekly_timetable_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _profile = AcademicProfile(
  universityId: 'academyinfo:0000117',
  universityName: '상명대학교',
  schoolKind: 'fourYear',
  campus: '서울캠퍼스',
);

TimetableClass _course(String id, int year) => TimetableClass(
  id: id,
  title: id,
  academicYear: year,
  semester: '2',
  meetings: const [
    ClassMeeting(id: 'meeting', weekday: 1, startMinute: 540, endMinute: 600),
  ],
);

Future<SettingsRepository> _settings() async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsRepository(
    preferences: await SharedPreferences.getInstance(),
  );
  await settings.timetableStore.selectTerm(2026, '2');
  return settings;
}

Widget _app(
  SettingsRepository settings, {
  Widget home = const TimetableSettingsPage(),
  AcademicProfile? profile = _profile,
  double textScale = 1,
}) => ProviderScope(
  overrides: [
    settingsRepositoryProvider.overrideWithValue(settings),
    timetableStoreProvider.overrideWithValue(settings.timetableStore),
    appSettingsProvider.overrideWith(
      (_) => settings.load().copyWith(academicProfile: profile),
    ),
  ],
  child: MaterialApp(
    locale: const Locale('ko'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: DailyTheme.dark(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: home,
  ),
);

void main() {
  testWidgets(
    'management opens a separate page while weekly view survives back',
    (tester) async {
      final settings = await _settings();
      await settings.timetableStore.save(_course('current', 2026));
      await tester.pumpWidget(
        _app(
          settings,
          home: const Scaffold(
            body: TimetablePage(),
            bottomNavigationBar: SizedBox(
              height: 50,
              child: Text('main-navigation'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsNothing);
      await tester.tap(find.byKey(const ValueKey('timetable-week-toggle')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<WeeklyTimetableGrid>(find.byType(WeeklyTimetableGrid))
            .showDates,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('timetable-menu')));
      await tester.pumpAndSettle();
      expect(find.byType(TimetableSettingsPage), findsOneWidget);
      expect(find.text('main-navigation'), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('main-navigation'), findsOneWidget);
      expect(
        tester
            .widget<WeeklyTimetableGrid>(find.byType(WeeklyTimetableGrid))
            .showDates,
        isTrue,
      );
      expect(settings.timetableStore.classes, hasLength(1));
    },
  );

  testWidgets(
    'term management shares selection and resets only the selected term',
    (tester) async {
      final settings = await _settings();
      final store = settings.timetableStore;
      await store.save(_course('previous', 2025));
      await store.save(_course('current', 2026));
      final period = TimetablePeriod(
        start: DateTime(2025, 9, 1),
        end: DateTime(2025, 12, 20),
      );
      await store.setTermPeriod(2025, '2', period);
      await tester.pumpWidget(_app(settings));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('timetable-settings-term')));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('timetable-term-2025-2')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('timetable-term-2025-2')));
      await tester.pumpAndSettle();
      expect(store.activeYear, 2025);
      expect(store.activeSemester, '2');
      await tester.tap(find.byKey(const ValueKey('timetable-settings-name')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('timetable-name-input')),
        '지난 학기',
      );
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(store.activeName, '지난 학기');
      expect(store.hasPendingSync, isTrue);
      await tester.tap(find.byKey(const ValueKey('timetable-settings-period')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('timetable-term-period')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('timetable-term-cancel')));
      await tester.pumpAndSettle();
      expect(store.activePeriod, period);
      final reset = find.byKey(const ValueKey('timetable-settings-reset'));
      await tester.ensureVisible(reset);
      await tester.pumpAndSettle();
      await tester.tap(reset);
      await tester.pumpAndSettle();
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(store.classes, hasLength(2));
      await tester.tap(reset);
      await tester.pumpAndSettle();
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();
      expect(store.classes.single.id, 'current');
      expect(store.activeName, '지난 학기');
      expect(store.activePeriod, period);
      expect(tester.widget<DailySettingsRow>(reset).enabled, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  for (final profile in [
    null,
    const AcademicProfile(
      universityId: 'unsupported-school',
      universityName: '다른 대학',
      schoolKind: 'fourYear',
    ),
  ]) {
    testWidgets(
      'settings keeps academic gate and data for ${profile?.universityId ?? 'missing'} profile',
      (tester) async {
        final settings = await _settings();
        await settings.timetableStore.save(_course('preserved', 2026));
        await tester.pumpWidget(_app(settings, profile: profile));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('academic-profile-open')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('timetable-settings-reset')),
          findsNothing,
        );
        expect(settings.timetableStore.classes.single.id, 'preserved');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'management remains scrollable on a short screen with large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 320);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final settings = await _settings();
      await settings.timetableStore.save(_course('current', 2026));
      await tester.pumpWidget(_app(settings, textScale: 2));
      await tester.pumpAndSettle();
      final reset = find.byKey(const ValueKey('timetable-settings-reset'));
      await tester.scrollUntilVisible(
        reset,
        160,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('timetable-settings-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      expect(reset.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
