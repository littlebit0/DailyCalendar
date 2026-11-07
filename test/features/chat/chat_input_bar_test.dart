import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/features/chat/domain/event_parse_result.dart';
import 'package:daily/features/chat/domain/schedule_parser.dart';
import 'package:daily/features/chat/presentation/chat_input_bar.dart';
import 'package:daily/features/events/domain/event_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedParser implements ScheduleParser {
  _FixedParser(this.draft);

  final EventDraft draft;

  @override
  Future<EventParseResult> parse(
    String input, {
    required DateTime baseDate,
    DateTime? selectedDate,
    required int defaultReminderMinutes,
    List<int>? defaultReminderMinutesList,
  }) async => EventParseResult(draft: draft);
}

void main() {
  // Run under a DST zone (e.g. TZ=America/New_York) to cover clock changes;
  // US DST starts on 8 March 2026, a 23-hour day inside this all-day range.
  testWidgets(
    'all-day confirmation shows the last calendar date of the range',
    (tester) async {
      final draft = EventDraft(
        title: '여행',
        startAt: DateTime(2026, 3, 7),
        endAt: DateTime(2026, 3, 9),
        allDay: true,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingsProvider.overrideWith((_) => AppSettings()),
            scheduleParserProvider.overrideWithValue(_FixedParser(draft)),
          ],
          child: const MaterialApp(
            locale: Locale('en', 'US'),
            localizationsDelegates: [AppLocalizations.delegate],
            home: Scaffold(body: ChatInputBar()),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '내일부터 모레까지 여행');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward));
      // The submit spinner keeps animating while the sheet is open.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('March 7, 2026 - March 8, 2026'),
        findsOneWidget,
      );
    },
  );
}
