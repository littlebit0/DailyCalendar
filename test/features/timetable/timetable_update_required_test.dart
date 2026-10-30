import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/features/settings/presentation/academic_profile_page.dart';
import 'package:daily/features/timetable/data/timetable_store.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/presentation/timetable_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _notice = '업데이트가 필요합니다';

TimetableClass _course() => TimetableClass(
  id: 'course',
  title: '자료구조',
  academicYear: 2026,
  semester: '2',
  meetings: const [
    ClassMeeting(id: 'meeting', weekday: 1, startMinute: 780, endMinute: 840),
  ],
);

void main() {
  late SettingsRepository settings;
  late TimetableStore store;
  late BuildContext host;
  late ValueNotifier<String?> required;

  Future<void> pump(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
    );
    store = settings.timetableStore;
    await store.save(_course());
    required = ValueNotifier<String?>(null);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          requiredUpdateVersionProvider.overrideWithValue(
            required as ValueListenable<String?>,
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
          home: Builder(
            builder: (context) {
              host = context;
              return const Scaffold();
            },
          ),
        ),
      ),
    );
  }

  ClassOccurrence occurrence() {
    final course = store.activeClasses.single;
    return ClassOccurrence(
      course,
      course.meetings.single,
      DateTime(2026, 9, 7),
      course.defaultMode,
    );
  }

  testWidgets('an open occurrence dialog cannot reach the editor', (
    tester,
  ) async {
    await pump(tester);
    showClassOccurrence(host, store, occurrence());
    await tester.pumpAndSettle();
    required.value = '4.1.0';
    await tester.tap(find.text('수업 수정'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('class-editor-popup')), findsNothing);
    expect(find.text(_notice), findsOneWidget);
  });

  testWidgets('an open occurrence dialog cannot reach the mode change', (
    tester,
  ) async {
    await pump(tester);
    showClassOccurrence(host, store, occurrence());
    await tester.pumpAndSettle();
    required.value = '4.1.0';
    await tester.tap(find.text('이번 수업 방식'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.text(_notice), findsOneWidget);
  });

  testWidgets('an open mode dialog does not save the override', (tester) async {
    await pump(tester);
    showClassOccurrence(host, store, occurrence());
    await tester.pumpAndSettle();
    await tester.tap(find.text('이번 수업 방식'));
    await tester.pumpAndSettle();
    required.value = '4.1.0';
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(store.activeClasses.single.overrides, isEmpty);
    expect(find.text(_notice), findsOneWidget);
  });

  testWidgets('an open class editor saves only while up to date', (
    tester,
  ) async {
    await pump(tester);
    showClassEditor(host, store, course: store.activeClasses.single);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('class-title')), '바뀐 과목');
    required.value = '4.1.0';
    final save = find.byKey(const ValueKey('class-save'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(store.activeClasses.single.title, '자료구조');
    expect(find.text(_notice), findsOneWidget);

    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    required.value = null;
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(store.activeClasses.single.title, '바뀐 과목');
  });

  testWidgets('an open academic profile page is replaced', (tester) async {
    await pump(tester);
    Navigator.of(host).push(
      MaterialPageRoute<void>(builder: (_) => const AcademicProfilePage()),
    );
    await tester.pumpAndSettle();
    expect(find.text(_notice), findsNothing);
    required.value = '4.1.0';
    await tester.pumpAndSettle();
    expect(find.text(_notice), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });
}
