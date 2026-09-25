import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:daily/app/daily_theme.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/features/timetable/data/timetable_store.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/timetable_term.dart';
import 'package:daily/features/timetable/presentation/timetable_term_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  TimetablePeriod fall([int year = 2026]) =>
      TimetablePeriod(start: DateTime(year, 9, 1), end: DateTime(year, 12, 21));

  Future<TimetableStore> store() async => TimetableStore(
    await SharedPreferences.getInstance(),
    now: () => DateTime(2026, 9, 25),
    deviceId: 'picker-test',
  );

  Widget app(
    TimetableStore store, {
    TimetablePeriodSuggestion? suggest,
    double scale = 1,
    double keyboard = 0,
    Locale locale = const Locale('ko'),
  }) => MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: DailyTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        viewInsets: EdgeInsets.only(bottom: keyboard),
      ),
      child: child!,
    ),
    home: Scaffold(
      body: Builder(
        builder: (context) => Column(
          children: [
            TextButton(
              key: const ValueKey('open-picker'),
              onPressed: () =>
                  showTimetablePicker(context, store, suggestPeriod: suggest),
              child: const Text('Picker'),
            ),
            TextButton(
              key: const ValueKey('open-period'),
              onPressed: () => showTimetablePeriodEditor(
                context,
                store,
                store.activeYear,
                store.activeSemester,
                suggestPeriod: suggest,
              ),
              child: const Text('Period'),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> open(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  Future<void> create(
    WidgetTester tester, {
    int year = 2026,
    String semester = '2',
  }) async {
    expect(find.byType(TextFormField), findsNothing);
    final term = find.byKey(ValueKey('timetable-term-$year-$semester'));
    await tester.ensureVisible(term);
    await tester.pumpAndSettle();
    await tester.tap(term);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('timetable-term-year')), findsNothing);
    expect(find.byKey(const ValueKey('timetable-term-semester')), findsNothing);
  }

  testWidgets('saved selection is one tap and keeps a legacy semester', (
    tester,
  ) async {
    final data = await store();
    await data.createTerm(2025, '2', name: '지난 가을', period: fall(2025));
    await data.save(
      TimetableClass(
        id: 'legacy',
        title: '옛 수업',
        academicYear: 2026,
        semester: '특별학기',
        meetings: const [
          ClassMeeting(id: 'm', weekday: 1, startMinute: 600, endMinute: 660),
        ],
      ),
    );
    final before = data.syncDocument().toJson();
    final revision = data.localRevisionNotifier.value;
    await tester.pumpWidget(app(data));
    await open(tester, 'open-picker');
    expect(find.text('학기 기간 설정 필요'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('timetable-term-2026-특별학기')))
          .dy,
      greaterThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('timetable-term-2025-2')))
            .dy,
      ),
    );
    await open(tester, 'timetable-term-2026-특별학기');
    expect(data.activeYear, 2026);
    expect(data.activeSemester, '특별학기');
    expect(data.classes.single.title, '옛 수업');
    expect(data.syncDocument().toJson(), before);
    expect(data.localRevisionNotifier.value, revision);
    expect(find.byKey(const ValueKey('timetable-term-list')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'empty picker and cancelled creation do not invent a saved term',
    (tester) async {
      final data = await store();
      await tester.pumpWidget(app(data, suggest: (_, _) async => fall()));
      await open(tester, 'open-picker');
      expect(find.byKey(const ValueKey('timetable-term-list')), findsOneWidget);
      expect(find.byKey(const ValueKey('timetable-create')), findsNothing);
      await create(tester);
      expect(find.textContaining('시작일:'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('timetable-term-name')),
        '저장하지 않을 이름',
      );
      await open(tester, 'timetable-term-cancel');
      expect(data.terms, isEmpty);
      expect(data.classes, isEmpty);
      expect(data.hasPendingSync, isFalse);
      await open(tester, 'timetable-picker-close');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'year and semester list includes seasonal terms and expands without typing',
    (tester) async {
      final data = await store();
      await tester.pumpWidget(app(data));
      await open(tester, 'open-picker');
      expect(find.text('25년도 1학기'), findsOneWidget);
      expect(find.text('25년도 여름계절학기'), findsOneWidget);
      expect(find.text('26년도 2학기'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('timetable-earlier-years')),
      );
      await open(tester, 'timetable-earlier-years');
      expect(
        find.byKey(const ValueKey('timetable-term-2022-1')),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('timetable-later-years')),
      );
      await open(tester, 'timetable-later-years');
      expect(
        find.byKey(const ValueKey('timetable-term-2030-겨울')),
        findsOneWidget,
      );
      expect(data.terms, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('new empty timetable persists only after confirming its period', (
    tester,
  ) async {
    final data = await store();
    await tester.pumpWidget(app(data, suggest: (_, _) async => fall()));
    await open(tester, 'open-picker');
    await create(tester);
    expect(data.terms, isEmpty);
    await tester.enterText(
      find.byKey(const ValueKey('timetable-term-name')),
      '가을 공부',
    );
    await open(tester, 'timetable-term-save');
    expect(data.activeName, '가을 공부');
    expect(data.activePeriod, fall());
    expect(data.terms.single.courseCount, 0);
    expect(data.hasPendingSync, isTrue);
    expect(find.byKey(const ValueKey('timetable-term-form')), findsNothing);
    expect(find.byKey(const ValueKey('timetable-term-list')), findsNothing);
    final restored = await store();
    expect(restored.terms.single.name, '가을 공부');
    expect(restored.terms.single.period, fall());
    expect(tester.takeException(), isNull);
  });

  testWidgets('new term has no year input and requires an actual period', (
    tester,
  ) async {
    final data = await store();
    await tester.pumpWidget(app(data));
    await open(tester, 'open-picker');
    await create(tester);
    await open(tester, 'timetable-term-save');
    expect(
      find.byKey(const ValueKey('timetable-period-error')),
      findsOneWidget,
    );
    expect(data.terms, isEmpty);
    expect(data.hasPendingSync, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('older async suggestions cannot cross into another semester', (
    tester,
  ) async {
    final data = await store();
    final first = Completer<TimetablePeriod?>();
    final second = Completer<TimetablePeriod?>();
    await tester.pumpWidget(
      app(
        data,
        suggest: (year, _) => year == 2026 ? first.future : second.future,
      ),
    );
    await open(tester, 'open-picker');
    await create(tester);
    await open(tester, 'timetable-term-cancel');
    await create(tester, year: 2027);
    second.complete(fall(2027));
    await tester.pumpAndSettle();
    first.complete(fall(2026));
    await tester.pumpAndSettle();
    await open(tester, 'timetable-term-save');
    expect(data.activeYear, 2027);
    expect(data.activePeriod, fall(2027));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'manual range validates order and survives a delayed suggestion',
    (tester) async {
      final data = await store();
      final suggestion = Completer<TimetablePeriod?>();
      await tester.pumpWidget(
        app(
          data,
          locale: const Locale('en'),
          suggest: (_, _) => suggestion.future,
        ),
      );
      await open(tester, 'open-picker');
      await create(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('timetable-term-period')),
      );
      await open(tester, 'timetable-term-period');
      final picker = find.byType(DateRangePickerDialog);
      final material = MaterialLocalizations.of(tester.element(picker));
      await tester.tap(find.byTooltip(material.inputDateModeButtonLabel));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: picker,
        matching: find.byType(TextField),
      );
      await tester.enterText(
        fields.at(0),
        material.formatCompactDate(DateTime(2026, 12, 21)),
      );
      await tester.enterText(
        fields.at(1),
        material.formatCompactDate(DateTime(2026, 9, 1)),
      );
      await tester.tap(
        find.descendant(
          of: picker,
          matching: find.text(material.okButtonLabel),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(material.invalidDateRangeLabel), findsOneWidget);
      expect(data.terms, isEmpty);
      await tester.enterText(
        fields.at(0),
        material.formatCompactDate(DateTime(2026, 9, 8)),
      );
      await tester.enterText(
        fields.at(1),
        material.formatCompactDate(DateTime(2026, 12, 18)),
      );
      await tester.tap(
        find.descendant(
          of: picker,
          matching: find.text(material.okButtonLabel),
        ),
      );
      await tester.pumpAndSettle();
      suggestion.complete(fall());
      await tester.pumpAndSettle();
      await open(tester, 'timetable-term-save');
      expect(
        data.activePeriod,
        TimetablePeriod(
          start: DateTime(2026, 9, 8),
          end: DateTime(2026, 12, 18),
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('saved term in combined list switches without overwriting', (
    tester,
  ) async {
    final data = await store();
    await data.createTerm(2026, '2', name: '보존할 이름', period: fall());
    await data.selectTerm(2026, '1');
    final before = data.syncDocument().toJson();
    await tester.pumpWidget(app(data, suggest: (_, _) async => fall()));
    await open(tester, 'open-picker');
    await create(tester);
    expect(find.byKey(const ValueKey('timetable-term-form')), findsNothing);
    expect(data.activeName, '보존할 이름');
    expect(data.activeSemester, '2');
    expect(data.terms, hasLength(1));
    expect(data.syncDocument().toJson(), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'editing a period preserves the selected timetable and cancellation',
    (tester) async {
      final data = await store();
      final winter = TimetablePeriod(
        start: DateTime(2025, 12, 26),
        end: DateTime(2026, 1, 19),
      );
      await data.createTerm(2025, '겨울', name: '내 겨울', period: winter);
      final before = data.syncDocument().toJson();
      await tester.pumpWidget(app(data, suggest: (_, _) async => fall(2027)));
      await open(tester, 'open-period');
      expect(find.byKey(const ValueKey('timetable-term-year')), findsNothing);
      expect(find.byKey(const ValueKey('timetable-term-name')), findsNothing);
      expect(find.textContaining('2027'), findsNothing);
      expect(
        tester.widget<Text>(find.textContaining('시작일:')).data,
        contains('2025'),
      );
      expect(
        tester.widget<Text>(find.textContaining('종료일:')).data,
        contains('2026'),
      );
      await open(tester, 'timetable-term-cancel');
      expect(data.activePeriod, winter);
      expect(data.activeName, '내 겨울');
      expect(data.syncDocument().toJson(), before);
      await open(tester, 'open-picker');
      expect(find.textContaining(RegExp(r'2025.*2026')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('320px large text and keyboard keep form actions reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = await store();
    await data.createTerm(2026, '2', name: '가을 시간표', period: fall());
    await tester.pumpWidget(
      app(data, suggest: (_, _) async => null, scale: 2, keyboard: 250),
    );
    await open(tester, 'open-picker');
    expect(tester.takeException(), isNull);
    await create(tester, semester: '겨울');
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(
      find.byKey(const ValueKey('timetable-term-name')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('timetable-term-name')),
      '겨울',
    );
    await open(tester, 'timetable-term-cancel');
    expect(data.terms, hasLength(1));
    expect(data.activeName, '가을 시간표');
    expect(tester.takeException(), isNull);
  });

  final auditPath = Platform.environment['DAILY_TIMETABLE_PICKER_AUDIT'];
  if (auditPath != null) {
    testWidgets('picker review screenshots', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
      final data = await store();
      final winter = TimetablePeriod(
        start: DateTime(2025, 12, 26),
        end: DateTime(2026, 1, 19),
      );
      await data.createTerm(2025, '겨울', name: '겨울 수업', period: winter);
      await data.createTerm(
        2026,
        '1',
        name: '봄 수업',
        period: TimetablePeriod(
          start: DateTime(2026, 3, 3),
          end: DateTime(2026, 6, 22),
        ),
      );
      await data.createTerm(2026, '2', name: '가을 수업', period: fall());
      final boundary = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: boundary, child: app(data)));
      Future<void> capture(String name) async {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$auditPath/$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await open(tester, 'open-picker');
      await capture('picker-term-list');
      final winterChoice = find.byKey(const ValueKey('timetable-term-2026-겨울'));
      await tester.ensureVisible(winterChoice);
      await tester.tap(winterChoice);
      await tester.pumpAndSettle();
      await capture('picker-create-form');
      await open(tester, 'timetable-term-cancel');
      await open(tester, 'timetable-picker-close');
      await open(tester, 'open-period');
      await capture('picker-period-editor');
      await open(tester, 'timetable-term-cancel');
      await data.selectTerm(2025, '겨울');
      await open(tester, 'open-period');
      await capture('picker-winter-period-editor');
      expect(tester.takeException(), isNull);
    });
  }
}
