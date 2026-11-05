import 'dart:convert';

import 'package:daily/core/sync/settings_sync_document.dart';
import 'package:daily/features/events/data/event_template_store.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/event_draft.dart';
import 'package:daily/features/events/domain/event_template.dart';
import 'package:daily/features/events/domain/recurrence_rule.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _workout = EventCategory(
  id: 'workout',
  label: '운동',
  colorValue: 0xff10b981,
);

EventTemplate _template({
  String id = 't1',
  String name = '운동',
  bool allDay = false,
  int start = 19 * 60,
  int endOffset = 0,
  int end = 20 * 60,
}) => EventTemplate(
  id: id,
  name: name,
  title: name,
  allDay: allDay,
  startMinutes: start,
  endDayOffset: endOffset,
  endMinutes: end,
  categoryId: _workout.id,
  reminderMinutesBeforeList: const [10],
);

void main() {
  group('EventTemplate dates', () {
    test('a timed template lands on the selected day at its saved time', () {
      final draft = _template().draftOn(DateTime(2026, 10, 30, 8), _workout);
      expect(draft.startAt, DateTime(2026, 10, 30, 19));
      expect(draft.endAt, DateTime(2026, 10, 30, 20));
      expect(draft.category, _workout);
      expect(draft.colorValue, _workout.colorValue);
      expect(draft.reminderMinutesBeforeList, [10]);
      expect(draft.recurrence.frequency, RecurrenceFrequency.none);
    });

    test('a template whose times vanish in a DST gap is not applied', () {
      final gapTemplate = _template(start: 2 * 60 + 30, end: 3 * 60);
      final day = DateTime(2026, 3, 8);
      final draft = gapTemplate.draftOn(day, _workout);
      // Only DST zones (e.g. America/New_York) have the gap; elsewhere the
      // draft stays valid and must be returned.
      if (draft.endAt.isAfter(draft.startAt)) {
        expect(gapTemplate.validDraftOn(day, _workout), isNotNull);
      } else {
        expect(gapTemplate.validDraftOn(day, _workout), isNull);
      }
      expect(_template().validDraftOn(day, _workout), isNotNull);
    });

    test('editing seeds a day on which the saved times exist', () {
      final gapTemplate = _template(start: 2 * 60 + 30, end: 4 * 60);
      final from = DateTime(2026, 3, 8);
      final day = gapTemplate.representableDayFrom(from);
      final draft = gapTemplate.draftOn(day, _workout);
      expect(draft.startAt.hour * 60 + draft.startAt.minute, 2 * 60 + 30);
      expect(draft.endAt.hour, 4);
      // Outside DST zones the requested day is kept.
      if (gapTemplate.draftOn(from, _workout).startAt.hour == 2) {
        expect(day, from);
      } else {
        expect(day, DateTime(2026, 3, 9));
      }
      expect(
        EventTemplate.fromDraft(draft, id: 't1', name: '운동').startMinutes,
        2 * 60 + 30,
      );
    });

    test('an overnight template keeps its end on the following day', () {
      final draft = _template(
        start: 23 * 60,
        endOffset: 1,
        end: 60,
      ).draftOn(DateTime(2026, 12, 31), _workout);
      expect(draft.startAt, DateTime(2026, 12, 31, 23));
      expect(draft.endAt, DateTime(2027, 1, 1, 1));
    });

    test('an all-day multi-day template uses an exclusive end date', () {
      final draft = _template(
        allDay: true,
        endOffset: 2,
      ).draftOn(DateTime(2026, 2, 27, 15), _workout);
      expect(draft.allDay, isTrue);
      expect(draft.startAt, DateTime(2026, 2, 27));
      expect(draft.endAt, DateTime(2026, 3, 2));
    });

    test('saving from a draft keeps only offsets and drops recurrence', () {
      final source = EventDraft(
        title: ' 야간 근무 ',
        memo: '메모',
        location: '본관',
        url: 'https://example.com',
        weather: '흐림',
        startAt: DateTime(2026, 3, 7, 22, 30),
        endAt: DateTime(2026, 3, 8, 6, 15),
        category: _workout,
        reminderMinutesBeforeList: const [30, 0],
        recurrence: const RecurrenceRule(frequency: RecurrenceFrequency.daily),
        showDday: true,
      );
      final template = EventTemplate.fromDraft(source, id: 'x', name: '근무');
      expect(template.title, '야간 근무');
      expect(template.startMinutes, 22 * 60 + 30);
      expect(template.endDayOffset, 1);
      expect(template.endMinutes, 6 * 60 + 15);
      expect(template.reminderMinutesBeforeList, [0, 30]);
      // Applied months later, across a different DST period, it keeps the
      // same wall-clock times.
      final draft = template.draftOn(DateTime(2026, 11, 1), _workout);
      expect(draft.startAt, DateTime(2026, 11, 1, 22, 30));
      expect(draft.endAt, DateTime(2026, 11, 2, 6, 15));
      expect(draft.weather, isNull);
      expect(draft.memo, '메모');
      expect(draft.location, '본관');
      expect(draft.url, 'https://example.com');
      expect(draft.showDday, isTrue);
      expect(draft.recurrence.frequency, RecurrenceFrequency.none);
    });

    test('an all-day draft is stored as its number of extra days', () {
      final template = EventTemplate.fromDraft(
        EventDraft(
          title: '여행',
          startAt: DateTime(2026, 5, 1),
          endAt: DateTime(2026, 5, 4),
          allDay: true,
          category: _workout,
        ),
        id: 'trip',
        name: '여행',
      );
      expect(template.endDayOffset, 2);
      expect(template.startMinutes, 0);
    });

    test('an all-day span ending on a DST change keeps its day count', () {
      final template = EventTemplate.fromDraft(
        EventDraft(
          title: '주말',
          startAt: DateTime(2026, 3, 7),
          endAt: DateTime(2026, 3, 9),
          allDay: true,
          category: _workout,
        ),
        id: 'weekend',
        name: '주말',
      );
      expect(template.endDayOffset, 1);
    });

    test(
      'json round trip keeps every copied field; invalid data is refused',
      () {
        final template = _template().copyWith(favorite: true);
        final restored = EventTemplate.tryFromJson(
          jsonDecode(jsonEncode(template.toJson())),
        )!;
        expect(restored.toJson(), template.toJson());
        expect(EventTemplate.tryFromJson({'id': 'a'}), isNull);
        expect(
          EventTemplate.tryFromJson(
            _template(start: 20 * 60, end: 19 * 60).toJson(),
          ),
          isNull,
        );
      },
    );
  });

  group('EventTemplateStore', () {
    late SharedPreferences preferences;
    String? owner;
    late DateTime now;

    EventTemplateStore store() => EventTemplateStore(
      preferences,
      readOwner: () => owner,
      deviceId: () async => 'device-a',
      now: () => now,
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
      owner = 'Tester@Example.com';
      now = DateTime.utc(2026, 11, 5, 9);
    });

    test(
      'save, reorder and delete persist and mark the bucket pending',
      () async {
        final templates = store();
        await templates.save(_template(id: 'a', name: 'A'));
        await templates.save(_template(id: 'b', name: 'B'));
        expect(templates.templates.map((t) => t.id), ['a', 'b']);
        expect(templates.hasPendingSync, isTrue);

        await templates.reorder(['b', 'a']);
        expect(store().templates.map((t) => t.id), ['b', 'a']);

        await templates.delete('b');
        expect(store().templates.map((t) => t.id), ['a']);
        // The deletion is kept as a register so other devices remove it too.
        final register = templates
            .syncDocument()
            .fields[EventTemplateStore.templateKey('b')]!;
        expect(register.value, isNull);
        expect(register.changedAt, isNotNull);
      },
    );

    test('accounts never see or merge each other\'s templates', () async {
      final templates = store();
      await templates.save(_template(id: 'a'));
      owner = 'other@example.com';
      expect(templates.templates, isEmpty);
      expect(templates.hasPendingSync, isFalse);
      await templates.save(_template(id: 'b'));
      owner = null;
      expect(templates.templates, isEmpty);
      owner = 'tester@example.com';
      expect(templates.templates.map((t) => t.id), ['a']);
    });

    test(
      'remote merge is last-writer-wins and acknowledgement clears pending',
      () async {
        final templates = store();
        await templates.save(_template(id: 'a', name: 'local'));
        final local = templates.syncDocument();
        final remote = const SettingsSyncDocument().withField(
          EventTemplateStore.templateKey('a'),
          SettingsSyncValue(
            _template(id: 'a', name: 'remote').toJson(),
            now.add(const Duration(minutes: 1)),
            'device-b',
          ),
        );
        final merged = local.merge(remote);
        await templates.acknowledgeSyncDocument(merged);
        expect(templates.templates.single.name, 'remote');
        expect(templates.hasPendingSync, isFalse);

        // An older remote write does not undo a newer local delete.
        now = now.add(const Duration(minutes: 5));
        await templates.delete('a');
        await templates.mergeSyncDocument(merged);
        expect(templates.templates, isEmpty);
        expect(templates.hasPendingSync, isTrue);
      },
    );

    test('unreadable stored data is never overwritten', () async {
      await preferences.setString(EventTemplateStore.storageKey, '{broken');
      final templates = store();
      expect(templates.templates, isEmpty);
      await expectLater(templates.save(_template()), throwsFormatException);
      expect(preferences.getString(EventTemplateStore.storageKey), '{broken');
    });

    test(
      'updating a template does not touch drafts already built from it',
      () async {
        final templates = store();
        await templates.save(_template(id: 'a', name: '운동'));
        final draft = templates.templates.single.draftOn(
          DateTime(2026, 10, 30),
          _workout,
        );
        await templates.save(
          _template(id: 'a', name: '수영', start: 6 * 60, end: 7 * 60),
        );
        await templates.delete('a');
        expect(draft.title, '운동');
        expect(draft.startAt, DateTime(2026, 10, 30, 19));
      },
    );
  });
}
