import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/features/events/domain/recurrence_rule.dart';
import 'package:daily/features/events/presentation/event_editor_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Checks sentences after their arguments are filled in, which the
/// key-coverage test cannot see.
void main() {
  const en = AppLocalizations(Locale('en'));
  const ja = AppLocalizations(Locale('ja'));
  const zh = AppLocalizations(
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  );

  test('empty import list names the calendar once', () {
    for (final l10n in [en, ja, zh]) {
      for (final provider in ['Apple 캘린더', 'Samsung 캘린더', 'Google 캘린더']) {
        final label = l10n.text(provider);
        final sentence = l10n.text(
          '가져올 수 있는 {provider}가 없습니다.',
          args: {'provider': label},
        );
        expect(sentence, contains(label));
        if (l10n.languageCode == 'en') {
          expect(sentence, isNot(contains('Calendar calendars')));
          continue;
        }
        final calendarWord = l10n.languageCode == 'ja'
            ? 'カレンダー'
            : RegExp('行事曆|日曆');
        expect(
          calendarWord.allMatches(sentence),
          hasLength(1),
          reason: sentence,
        );
      }
    }
  });

  test('reminder body says the event starts after the offset', () {
    String body(AppLocalizations l10n) => l10n.text(
      '일정 시작 {time}입니다.',
      args: {
        'time': l10n.text('{count}분 전', args: {'count': 10}),
      },
    );
    expect(body(en), 'It is 10 minutes before the event starts.');
    expect(body(zh), isNot(contains('將於')));
    expect(body(zh), contains('10 分鐘前'));
    expect(body(ja), '予定開始の10分前です。');
  });

  test('repeat interval question uses a unit word, not the day view name', () {
    String question(AppLocalizations l10n, RecurrenceFrequency frequency) =>
        l10n.text(
          '몇 {unit}마다 반복할까요?',
          args: {'unit': frequencyUnitLabel(l10n, frequency)},
        );
    expect(
      question(en, RecurrenceFrequency.daily),
      'Repeat every how many days?',
    );
    expect(
      question(en, RecurrenceFrequency.weekly),
      'Repeat every how many weeks?',
    );
    expect(question(ja, RecurrenceFrequency.monthly), '何か月ごとに繰り返しますか？');
    expect(question(zh, RecurrenceFrequency.daily), '每幾天重複一次？');
    expect(
      question(const AppLocalizations(Locale('ko')), RecurrenceFrequency.daily),
      '몇 일마다 반복할까요?',
    );
    for (final l10n in [en, ja, zh]) {
      for (final frequency in RecurrenceFrequency.values) {
        final unit = frequencyUnitLabel(l10n, frequency);
        expect(unit, isNot(contains('반복 간격')), reason: '$frequency');
      }
    }
  });

  test('terms stay consistent within each language', () {
    expect(ja.text('시그널 처리 중...'), startsWith('Signal'));
    expect(ja.text('학과 · 전공'), contains('学科'));
    expect(zh.text('학과 · 전공'), contains('主修'));
    expect(zh.text('종일 일정 표시'), contains('全天'));
    expect(zh.text('종일 일정 숨기기'), contains('全天'));
    expect(
      zh.text('대학교를 선택하세요. 학사 정보는 Google Drive로 동기화됩니다.'),
      contains(zh.text('학사 정보')),
    );
  });
}
