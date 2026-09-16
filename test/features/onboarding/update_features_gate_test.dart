import 'package:daily/core/academic/academic_calendar_service.dart';
import 'package:daily/core/academic/academic_source.dart';
import 'package:daily/core/academic/academic_store.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/features/onboarding/feature_announcements.dart';
import 'package:daily/features/onboarding/presentation/update_features_gate.dart';
import 'package:daily/features/settings/presentation/academic_calendar_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'skip persists, preserves settings, and does not repeat after remount',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboardingCompleted': true,
        'showLunarDates': true,
      });
      final prefs = await SharedPreferences.getInstance();
      PackageInfo.setMockInitialValues(
        appName: 'Daily',
        packageName: 'daily',
        version: '3.4.0',
        buildNumber: '340',
        buildSignature: '',
      );
      final store = SettingsRepository(preferences: prefs);
      Widget app() => ProviderScope(
        overrides: [settingsRepositoryProvider.overrideWithValue(store)],
        child: const MaterialApp(
          home: UpdateFeaturesGate(child: Text('calendar')),
        ),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('새로운 기능'), findsOneWidget);
      await tester.tap(find.text('나중에'));
      await tester.pumpAndSettle();
      expect(find.text('대학교 학사일정'), findsOneWidget);
      await tester.tap(find.text('나중에'));
      await tester.pumpAndSettle();
      expect(find.text('calendar'), findsOneWidget);
      expect(prefs.getBool('showLunarDates'), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('새로운 기능'), findsNothing);
      expect(find.text('calendar'), findsOneWidget);
    },
  );

  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.macOS,
  ]) {
    testWidgets(
      '$platform sees only academic intro after the same-version update',
      (tester) async {
        final settings = await _existingUser();
        Widget app() => ProviderScope(
          overrides: [settingsRepositoryProvider.overrideWithValue(settings)],
          child: const MaterialApp(
            home: UpdateFeaturesGate(child: Text('calendar')),
          ),
        );
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(find.text('대학교 학사일정'), findsOneWidget);
        expect(find.text('날씨 예보'), findsNothing);
        expect(find.text('잠금화면 월간 캘린더'), findsNothing);
        expect(settings.academicStore.load(), isEmpty);

        // Merely displaying it is not an acknowledgement.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(find.text('대학교 학사일정'), findsOneWidget);
        await tester.tap(find.text('나중에'));
        await tester.pumpAndSettle();
        expect(find.text('calendar'), findsOneWidget);
        expect(settings.academicStore.load(), isEmpty);
        expect(settings.load().showLunarDates, isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(find.text('calendar'), findsOneWidget);
        expect(find.text('새로운 기능'), findsNothing);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }

  testWidgets(
    'academic settings button opens the existing page without importing',
    (tester) async {
      final settings = await _existingUser();
      final service = _AcademicService();
      addTearDown(service.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settings),
            academicCalendarServiceProvider.overrideWithValue(service),
          ],
          child: const MaterialApp(
            home: UpdateFeaturesGate(child: Text('calendar')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('설정 보기'));
      await tester.pumpAndSettle();
      expect(find.byType(AcademicCalendarPage), findsOneWidget);
      expect(find.byKey(const ValueKey('academic-school')), findsOneWidget);
      expect(
        settings.announcements.pending('3.4.0', TargetPlatform.android),
        hasLength(1),
      );
      final context = tester.element(find.byType(AcademicCalendarPage));
      Navigator.of(context).pop();
      await tester.pumpAndSettle();
      expect(find.text('calendar'), findsOneWidget);
      expect(settings.academicStore.load(), isEmpty);
      expect(
        settings.announcements.pending('3.4.0', TargetPlatform.android),
        isEmpty,
      );
    },
  );

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      'academic introduction is localized and fits large text: $locale',
      (tester) async {
        final settings = await _existingUser();
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [settingsRepositoryProvider.overrideWithValue(settings)],
            child: MaterialApp(
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!,
              ),
              home: const UpdateFeaturesGate(child: Text('calendar')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final strings = AppLocalizations(locale);
        expect(find.text(strings.text('대학교 학사일정')), findsOneWidget);
        if (locale.languageCode != 'ko') {
          expect(find.text('대학교 학사일정'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<SettingsRepository> _existingUser() async {
  SharedPreferences.setMockInitialValues({
    'onboardingCompleted': true,
    'showLunarDates': true,
    FeatureAnnouncementStore.key: [
      'lockscreen-calendar-v1',
      'weather-forecast-v1',
    ],
  });
  PackageInfo.setMockInitialValues(
    appName: 'Daily',
    packageName: 'daily',
    version: '3.4.0',
    buildNumber: '340',
    buildSignature: '',
  );
  return SettingsRepository(preferences: await SharedPreferences.getInstance());
}

class _AcademicService extends ChangeNotifier
    implements AcademicCalendarService {
  @override
  final sources = <AcademicSource>[SangmyungAcademicSource()];
  @override
  Map<String, AcademicSubscription> get subscriptions => const {};
  @override
  bool busy = false;
  @override
  bool unavailable = false;
  @override
  AcademicResult? result;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected academic mutation: ${invocation.memberName}',
  );
  @override
  void dispose() {
    for (final source in sources) {
      source.close();
    }
    super.dispose();
  }
}
