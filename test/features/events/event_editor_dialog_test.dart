import 'package:daily/core/alarms/alarm_service.dart';
import 'package:daily/core/lms/lms_models.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/event_draft.dart';
import 'package:daily/features/events/presentation/event_editor_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'LMS point deadline editor saves personal fields without changing school source',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final due = DateTime(2026, 9, 26, 0, 0, 0, 123);
      final metadata = LmsEventMetadata(
        schoolId: 'smu',
        ownerId: 'student@example.com',
        lmsUserId: '42',
        courseId: '123',
        courseTitle: '자료구조',
        activityType: 'assignment',
        activityId: '456',
        sourceUrl: 'https://ecampus.smu.ac.kr/mod/assign/view.php?id=456',
        dueAt: due,
        submissionStatus: '미제출',
      );
      final event = _eventWithEndBeforeStart().copyWith(
        id: 'lms:deadline',
        title: '[자료구조] 과제',
        startAt: due,
        endAt: due,
        url: metadata.sourceUrl,
        lms: metadata,
        memo: '기존 메모',
        reminderMinutesBeforeList: const [60],
      );
      const category = EventCategory(
        id: 'personal',
        label: '개인 분류',
        colorValue: 0xff336699,
      );
      EventDraft? saved;
      await tester.pumpWidget(
        _DialogHost(
          builder: (_) => EventEditorDialog(
            initialDate: due,
            event: event,
            categories: const [EventCategory.basic, category],
            alarmService: _AuthorizedAlarmService(),
          ),
          onSaved: (draft) => saved = draft,
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(find.text(event.title), findsOneWidget);
      for (final label in [
        '시작일',
        '종료일',
        '시작 시간',
        '종료 시간',
        '종일',
        '반복',
        '장소',
        'URL / 링크',
        '날씨',
      ]) {
        expect(find.text(label), findsNothing);
      }
      final textFields = tester.widgetList<TextField>(find.byType(TextField));
      expect(textFields.map((field) => field.decoration?.labelText), ['메모']);
      await tester.tap(find.byType(DropdownButtonFormField<EventCategory>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('개인 분류').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, '없음'));
      await tester.ensureVisible(find.text('일정 알람'));
      await tester.tap(find.text('일정 알람'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('D-day 표시'));
      await tester.tap(find.text('D-day 표시'));
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '개인 계획 메모');
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(saved, isNotNull);
      expect(saved!.title, event.title);
      expect(saved!.startAt, event.startAt);
      expect(saved!.endAt, event.endAt);
      expect(saved!.url, event.url);
      expect(saved!.memo, '개인 계획 메모');
      expect(saved!.category, category);
      expect(saved!.reminderMinutesBeforeList, isEmpty);
      expect(saved!.showDday, isTrue);
      expect(saved!.alarmEnabled, isTrue);
      expect(saved!.recurrence.isRepeating, isFalse);
      expect(find.text('종료 시간은 시작 시간보다 늦어야 합니다.'), findsNothing);
    },
  );
  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.macOS,
  ]) {
    testWidgets(
      '$platform editor opens without keyboard and picker does not restore input',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        await tester.pumpWidget(
          _DialogHost(
            builder: (_) =>
                EventEditorDialog(initialDate: DateTime(2026, 5, 28)),
            onSaved: (_) {},
          ),
        );
        await tester.tap(find.text('열기'));
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isFalse);
        await tester.tap(find.byType(TextField).first);
        await tester.pump();
        expect(tester.testTextInput.isVisible, isTrue);
        await tester.tap(find.byIcon(Icons.calendar_today_outlined).first);
        await tester.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsOneWidget);
        if (find.byType(DatePickerDialog).evaluate().isNotEmpty) {
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
        }
        expect(tester.testTextInput.isVisible, isFalse);
        await tester.tap(find.byType(TextField).first);
        await tester.pump();
        expect(tester.testTextInput.isVisible, isTrue);
        debugDefaultTargetPlatformOverride = null;
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('shows missing title validation inside the event dialog', (
    tester,
  ) async {
    EventDraft? savedDraft;
    await tester.pumpWidget(
      _DialogHost(
        builder: (context) =>
            EventEditorDialog(initialDate: DateTime(2026, 5, 28)),
        onSaved: (draft) => savedDraft = draft,
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('제목을 입력해야 일정을 저장할 수 있습니다.'), findsOneWidget);
    expect(find.text('제목을 입력하세요.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(savedDraft, isNull);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('shows invalid time validation inside the event dialog', (
    tester,
  ) async {
    EventDraft? savedDraft;
    await tester.pumpWidget(
      _DialogHost(
        builder: (context) => EventEditorDialog(
          initialDate: DateTime(2026, 5, 28, 10),
          event: _eventWithEndBeforeStart(),
        ),
        onSaved: (draft) => savedDraft = draft,
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('종료 시간은 시작 시간보다 늦어야 합니다.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(savedDraft, isNull);
  });

  testWidgets('keeps number picker open when recurrence input is invalid', (
    tester,
  ) async {
    await tester.pumpWidget(
      _DialogHost(
        builder: (context) =>
            EventEditorDialog(initialDate: DateTime(2026, 5, 28)),
        onSaved: (_) {},
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('반복 없음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('반복 없음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('매일').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('1일마다'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1일마다'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'abc');
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();

    expect(find.text('반복 간격'), findsWidgets);
    expect(find.text('1 이상의 숫자를 입력하세요.'), findsOneWidget);
  });

  testWidgets('saves multiple selected reminders from the event dialog', (
    tester,
  ) async {
    EventDraft? savedDraft;
    await tester.pumpWidget(
      _DialogHost(
        builder: (context) => EventEditorDialog(
          initialDate: DateTime(2026, 5, 28, 10),
          defaultReminderMinutes: 60,
        ),
        onSaved: (draft) => savedDraft = draft,
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '복수 알림 일정');
    await tester.ensureVisible(find.text('10분 전'));
    await tester.tap(find.text('10분 전'));
    await tester.tap(find.text('30분 전'));
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(savedDraft, isNotNull);
    expect(savedDraft!.reminderMinutesBeforeList, [10, 30, 60]);
  });

  testWidgets('new event starts with every selected default reminder', (
    tester,
  ) async {
    EventDraft? savedDraft;
    await tester.pumpWidget(
      _DialogHost(
        builder: (context) => EventEditorDialog(
          initialDate: DateTime(2026, 5, 28, 10),
          defaultReminderMinutesList: const [10, 30, 60],
        ),
        onSaved: (draft) => savedDraft = draft,
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '기본 복수 알림');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(savedDraft!.reminderMinutesBeforeList, [10, 30, 60]);
  });

  testWidgets('saves AlarmKit selection for a single event', (tester) async {
    EventDraft? savedDraft;
    await tester.pumpWidget(
      _DialogHost(
        builder: (context) => EventEditorDialog(
          initialDate: DateTime.now().add(const Duration(days: 1)),
          alarmService: const _AuthorizedAlarmService(),
        ),
        onSaved: (draft) => savedDraft = draft,
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '알람 일정');
    await tester.ensureVisible(find.text('일정 알람'));
    await tester.tap(find.text('일정 알람'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(savedDraft?.alarmEnabled, isTrue);
  });

  testWidgets('time picker input mode works with the basic text scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      _DialogHost(
        textScaler: const TextScaler.linear(0.8),
        builder: (context) =>
            EventEditorDialog(initialDate: DateTime(2026, 5, 28)),
        onSaved: (_) {},
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('9:00 AM'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Enter time'), findsOneWidget);
  });

  testWidgets('macOS editor exposes the system notification alarm control', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(
        _DialogHost(
          builder: (context) => EventEditorDialog(
            initialDate: DateTime(2026, 5, 28),
            alarmService: const _AuthorizedAlarmService(),
          ),
          onSaved: (_) {},
        ),
      );

      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();

      expect(find.text('일정 알람'), findsOneWidget);
      expect(
        find.text('시작 시각에 소리와 다시 알림이 있는 macOS 시스템 알림을 전달합니다.'),
        findsOneWidget,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

class _AuthorizedAlarmService implements AlarmService {
  const _AuthorizedAlarmService();

  @override
  Future<AlarmAuthorizationState> authorizationState() async =>
      AlarmAuthorizationState.authorized;

  @override
  Future<AlarmAuthorizationState> requestAuthorization() async =>
      AlarmAuthorizationState.authorized;

  @override
  Future<void> cancelAllEventAlarms() async {}

  @override
  Future<void> cancelEventAlarm(String eventId) async {}

  @override
  Future<void> scheduleEventAlarm(CalendarEvent event) async {}
}

class _DialogHost extends StatelessWidget {
  const _DialogHost({
    required this.builder,
    required this.onSaved,
    this.textScaler,
  });

  final WidgetBuilder builder;
  final ValueChanged<EventDraft> onSaved;
  final TextScaler? textScaler;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: textScaler == null
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                final draft = await showDialog<EventDraft>(
                  context: context,
                  builder: builder,
                );
                if (draft != null) {
                  onSaved(draft);
                }
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
  }
}

CalendarEvent _eventWithEndBeforeStart() {
  final start = DateTime(2026, 5, 28, 10);
  return CalendarEvent(
    id: 'event-1',
    title: '회의',
    startAt: start,
    endAt: DateTime(2026, 5, 28, 9),
    allDay: false,
    category: EventCategory.basic,
    colorValue: EventCategory.basic.colorValue,
    createdAt: start,
    updatedAt: start,
  );
}
