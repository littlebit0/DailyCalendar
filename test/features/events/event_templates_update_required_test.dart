import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/event_template.dart';
import 'package:daily/features/events/presentation/event_template_actions.dart';
import 'package:daily/features/events/presentation/event_templates_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _notice = '업데이트가 필요합니다';

EventTemplate _template() => EventTemplate(
  id: 't',
  name: '운동',
  title: '운동',
  startMinutes: 19 * 60,
  endMinutes: 20 * 60,
  categoryId: EventCategory.basic.id,
  alarmEnabled: true,
  alarmMinutesBeforeList: const [0, 30],
  showOvernightOnFollowingDays: false,
);

void main() {
  late SettingsRepository settings;
  late ValueNotifier<String?> required;
  late WidgetRef hostRef;

  Future<void> pump(WidgetTester tester, {String? requiredVersion}) async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
    );
    await settings.eventTemplates.save(_template());
    required = ValueNotifier<String?>(requiredVersion);
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
          home: Consumer(
            builder: (context, ref, _) {
              hostRef = ref;
              return const EventTemplatesPage();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester, String item) async {
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item));
    await tester.pumpAndSettle();
  }

  testWidgets('no required update: renaming keeps every value', (tester) async {
    await pump(tester);
    await openMenu(tester, '이름 변경');
    await tester.enterText(find.byType(TextField), '수영');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    final stored = settings.eventTemplates.templates.single;
    expect(stored.name, '수영');
    expect(stored.alarmMinutesBeforeList, [0, 30]);
    expect(stored.showOvernightOnFollowingDays, isFalse);
  });

  testWidgets('a required update blocks rename, edit, delete and favorite', (
    tester,
  ) async {
    await pump(tester, requiredVersion: '9.9.9');
    final before = settings.eventTemplates.syncDocument();
    for (final item in ['이름 변경', '내용 수정', '삭제']) {
      await openMenu(tester, item);
      expect(find.text(_notice), findsOneWidget, reason: item);
      expect(find.byType(TextField), findsNothing, reason: item);
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byIcon(Icons.star_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text(_notice), findsOneWidget);
    expect(settings.eventTemplates.syncDocument().sameAs(before), isTrue);
  });

  testWidgets('an update found while the name dialog is open stops the save', (
    tester,
  ) async {
    await pump(tester);
    await openMenu(tester, '이름 변경');
    await tester.enterText(find.byType(TextField), '수영');
    required.value = '9.9.9';
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text(_notice), findsOneWidget);
    expect(settings.eventTemplates.templates.single.name, '운동');
  });

  testWidgets('a required update blocks saving a draft as a template', (
    tester,
  ) async {
    await pump(tester, requiredVersion: '9.9.9');
    final context = tester.element(find.byType(EventTemplatesPage));
    final draft = _template().draftOn(
      DateTime(2026, 11, 10),
      EventCategory.basic,
    );
    final saving = saveDraftAsTemplate(context, hostRef, draft);
    await tester.pumpAndSettle();
    await saving;
    expect(find.text(_notice), findsOneWidget);
    expect(find.text('템플릿 이름'), findsNothing);
    expect(settings.eventTemplates.templates, hasLength(1));
  });
}
