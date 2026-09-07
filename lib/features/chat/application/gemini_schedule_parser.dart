import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../../../core/settings/settings_repository.dart';
import '../../events/domain/calendar_event.dart';
import '../../events/domain/event_category.dart';
import '../../events/domain/event_draft.dart';
import '../../events/domain/recurrence_rule.dart';
import '../domain/event_parse_result.dart';
import '../domain/schedule_parser.dart';

class GeminiScheduleParser implements ScheduleParser {
  GeminiScheduleParser(
    this._settingsRepository, {
    this.modelName = 'gemini-2.0-flash',
  });

  final SettingsRepository _settingsRepository;
  final String modelName;

  @override
  Future<EventParseResult> parse(
    String input, {
    required DateTime baseDate,
    DateTime? selectedDate,
    required int defaultReminderMinutes,
    List<int>? defaultReminderMinutesList,
  }) async {
    final apiKey = await _settingsRepository.geminiApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return const EventParseResult(question: 'Gemini API 키가 설정되어 있지 않습니다.');
    }

    final model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );
    final response = await model.generateContent([
      Content.text(
        _prompt(
          input: input,
          baseDate: baseDate,
          selectedDate: selectedDate,
          defaultReminderMinutes: defaultReminderMinutes,
          defaultReminderMinutesList: defaultReminderMinutesList,
        ),
      ),
    ]);

    final jsonText = response.text;
    if (jsonText == null || jsonText.trim().isEmpty) {
      return const EventParseResult(question: '일정을 해석하지 못했습니다.');
    }

    final decoded = jsonDecode(_stripFences(jsonText)) as Map<String, Object?>;
    final title = decoded['title'] as String?;
    final startAt = DateTime.tryParse(decoded['startAt'] as String? ?? '');
    final endAt = DateTime.tryParse(decoded['endAt'] as String? ?? '');

    if (title == null || title.trim().isEmpty || startAt == null) {
      return const EventParseResult(question: '제목과 날짜를 다시 알려주세요.');
    }

    final allDay = decoded['allDay'] as bool? ?? false;
    final category = EventCategory.fromName(decoded['category'] as String?);
    final recurrenceFrequency = RecurrenceFrequency.fromName(
      decoded['recurrenceFrequency'] as String?,
    );

    return EventParseResult(
      usedAi: true,
      draft: EventDraft(
        title: title.trim(),
        memo: decoded['memo'] as String?,
        location: decoded['location'] as String?,
        startAt: startAt,
        endAt:
            endAt ??
            startAt.add(
              allDay ? const Duration(days: 1) : const Duration(hours: 1),
            ),
        allDay: allDay,
        category: category,
        colorValue: category.colorValue,
        reminderMinutesBeforeList: _resolvedReminders(
          decoded['reminderMinutesBefore'],
          defaultReminderMinutesList ?? [defaultReminderMinutes],
        ),
        recurrence: RecurrenceRule(frequency: recurrenceFrequency),
      ),
    );
  }

  String _prompt({
    required String input,
    required DateTime baseDate,
    required DateTime? selectedDate,
    required int defaultReminderMinutes,
    required List<int>? defaultReminderMinutesList,
  }) {
    final defaultReminders =
        defaultReminderMinutesList ?? [defaultReminderMinutes];
    return '''
너는 개인 캘린더 앱의 일정 파서다. 사용자의 한국어 문장을 일정 JSON으로 변환한다.
기준 날짜: ${baseDate.toIso8601String()}
선택된 날짜: ${selectedDate?.toIso8601String() ?? '없음'}
기본 알림: ${defaultReminders.map((minutes) => '$minutes분 전').join(', ')}

반드시 JSON 객체만 반환한다.
필드:
title string
memo string|null
location string|null
startAt ISO-8601 string
endAt ISO-8601 string|null
allDay boolean
category one of health, work, appointment, family, personal, travel, deadline, other
reminderMinutesBefore integer|null
recurrenceFrequency one of none, daily, weekly, monthly, yearly

입력: $input
''';
  }

  List<int> _resolvedReminders(Object? parsed, List<int> defaults) {
    if (parsed is int) {
      return <int>[parsed];
    }
    return normalizeReminderMinutes(defaults);
  }

  String _stripFences(String value) {
    return value
        .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\s*```$', multiLine: true), '')
        .trim();
  }
}
