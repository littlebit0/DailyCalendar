import 'dart:async';
import 'dart:convert';

import 'package:daily/core/academic/academic_calendar_service.dart';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/academic_source.dart';
import 'package:daily/core/academic/academic_store.dart';
import 'package:daily/core/auth/google_account.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/theme/daily_ui.dart';
import 'package:daily/features/settings/presentation/academic_calendar_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _smu = AcademicProfile(
  universityId: 'institution:academyinfo:0000117',
  universityName: '상명대학교',
  schoolKind: 'fourYear',
);
const _jnu = AcademicProfile(
  universityId: 'institution:academyinfo:0000023',
  universityName: '전남대학교',
  schoolKind: 'fourYear',
);

class _Source implements AcademicSource {
  _Source(this.id, this.name);
  @override
  final String id;
  @override
  final String name;
  @override
  Uri get website => Uri.parse('https://example.invalid/$id');
  Completer<List<AcademicEvent>>? pending;
  List<AcademicEvent> get events => [
    AcademicEvent(
      sourceId: '$id-event',
      title: '$name 일정',
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 9, 2),
      url: website.toString(),
    ),
  ];
  @override
  Future<List<AcademicEvent>> fetch(int year) async =>
      pending == null ? events : pending!.future;
  @override
  void close() {}
}

/// Keeps source completion and import calls observable at the UI boundary.
class _CalendarService extends ChangeNotifier
    implements AcademicCalendarService {
  _CalendarService(this.sources);
  @override
  final List<AcademicSource> sources;
  final importedSources = <String>[];
  @override
  bool busy = false;
  @override
  bool unavailable = false;
  @override
  AcademicResult? result;
  @override
  Map<String, AcademicSubscription> get subscriptions => {};
  @override
  Future<AcademicPreview> preview(AcademicSource source, int year) async {
    busy = true;
    notifyListeners();
    try {
      return AcademicPreview(source, year, await source.fetch(year), 0);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  Future<void> importSelection(
    AcademicPreview preview,
    Set<String> selected, {
    int? colorValue,
  }) async {
    importedSources.add(preview.source.id);
  }

  void notifyForTest() => notifyListeners();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late SettingsRepository settings;
  late ProviderContainer container;
  late _Source smu;
  late _Source jnu;
  late _CalendarService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'academicProfile.v1': jsonEncode(_smu.toJson()),
      'academicProfile.owner.v1': 'first@example.com',
      'dailyAccount': jsonEncode({
        'id': 'daily-account',
        'googleAccount': {'email': 'first@example.com'},
      }),
    });
    settings = SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
    );
    smu = _Source('smu', '상명대학교');
    jnu = _Source('jnu', '전남대학교');
    service = _CalendarService([smu, jnu]);
    container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settings),
        academicCalendarServiceProvider.overrideWithValue(service),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    service.dispose();
  });

  Future<void> mount(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('ko'),
          supportedLocales: [Locale('ko')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: AcademicCalendarPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> changeProfile(
    WidgetTester tester,
    AcademicProfile profile,
  ) async {
    await tester.runAsync(() async {
      final previous = settings.load();
      await settings.save(
        previous.copyWith(academicProfile: profile),
        changedFrom: previous,
      );
    });
    container.read(appSettingsProvider.notifier).state = settings.load();
  }

  testWidgets(
    'restored school change discards old preview and its captured import action',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byKey(const ValueKey('academic-preview')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('academic-event-smu-event')),
        findsOneWidget,
      );
      final oldImport = tester
          .widget<DailyPrimaryButton>(
            find.byKey(const ValueKey('academic-import')),
          )
          .onPressed!;
      await changeProfile(tester, _jnu);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('academic-event-smu-event')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('academic-import')), findsNothing);
      oldImport();
      await tester.pumpAndSettle();
      expect(service.importedSources, isEmpty);
      await tester.tap(find.byKey(const ValueKey('academic-preview')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('academic-event-jnu-event')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('academic-import')));
      await tester.pumpAndSettle();
      expect(service.importedSources, ['jnu']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late preview is discarded even if profile switches away and back during fetch',
    (tester) async {
      smu.pending = Completer<List<AcademicEvent>>();
      await mount(tester);
      await tester.tap(find.byKey(const ValueKey('academic-preview')));
      await tester.pump();
      await changeProfile(tester, _jnu);
      await tester.pump();
      await changeProfile(tester, _smu);
      await tester.pump();
      smu.pending!.complete(smu.events);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('academic-event-smu-event')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('academic-import')), findsNothing);
      expect(service.importedSources, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final duringFetch in [false, true]) {
    testWidgets(
      'account switch ${duringFetch ? 'during fetch' : 'after preview'} prevents importing previous account preview',
      (tester) async {
        if (duringFetch) smu.pending = Completer<List<AcademicEvent>>();
        await mount(tester);
        await tester.tap(find.byKey(const ValueKey('academic-preview')));
        if (duringFetch) {
          await tester.pump();
        } else {
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('academic-import')), findsOneWidget);
        }
        await tester.runAsync(
          () => settings.saveGoogleAccount(
            const GoogleAccount(email: 'second@example.com'),
          ),
        );
        // Both accounts may attend the same school; source equality is insufficient.
        await changeProfile(tester, _smu);
        if (duringFetch) smu.pending!.complete(smu.events);
        service.notifyForTest();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('academic-event-smu-event')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('academic-import')), findsNothing);
        expect(service.importedSources, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('new session for the same account rejects a late preview', (
    tester,
  ) async {
    smu.pending = Completer<List<AcademicEvent>>();
    await mount(tester);
    await tester.tap(find.byKey(const ValueKey('academic-preview')));
    await tester.pump();
    // Logout/session reset increments this even if the same account returns.
    settings.academicStore.invalidate();
    smu.pending!.complete(smu.events);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('academic-event-smu-event')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('academic-import')), findsNothing);
    expect(service.importedSources, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
