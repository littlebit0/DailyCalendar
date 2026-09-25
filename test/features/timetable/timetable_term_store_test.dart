import 'dart:convert';

import 'package:daily/features/timetable/data/timetable_store.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/timetable_term.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

final _now = DateTime.utc(2026, 9, 25, 12);
final _fall = TimetablePeriod(
  start: DateTime(2026, 9, 1),
  end: DateTime(2026, 12, 21),
);
final _spring = TimetablePeriod(
  start: DateTime(2026, 3, 3),
  end: DateTime(2026, 6, 22),
);
final _termKey = timetableTermSyncKey(2026, '2');

TimetableClass _course(String id, {int year = 2026, String semester = '2'}) =>
    TimetableClass(
      id: id,
      title: '자료구조',
      academicYear: year,
      semester: semester,
      meetings: const [
        ClassMeeting(id: 'mon', weekday: 1, startMinute: 540, endMinute: 600),
      ],
    );

Future<(SharedPreferences, TimetableStore)> _store(String device) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  return (
    preferences,
    TimetableStore(preferences, deviceId: device, now: () => _now),
  );
}

class _FailPreferences extends InMemorySharedPreferencesStore {
  _FailPreferences() : super.empty();
  bool failNext = false;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (failNext) {
      failNext = false;
      return false;
    }
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('period dates are inclusive calendar days and round-trip date-only', () {
    final range = TimetablePeriod(
      start: DateTime.utc(2026, 9, 1, 23, 59),
      end: DateTime(2026, 12, 21, 1),
    );
    expect(range, _fall);
    expect(range.contains(DateTime(2026, 8, 31, 23, 59)), isFalse);
    expect(range.contains(DateTime.utc(2026, 9, 1)), isTrue);
    expect(range.contains(DateTime(2026, 12, 21, 23, 59)), isTrue);
    expect(range.contains(DateTime(2026, 12, 22)), isFalse);
    expect(range.toJson(), {
      'startDate': '2026-09-01',
      'endDate': '2026-12-21',
    });
    expect(TimetablePeriod.fromJson(range.toJson()), range);
  });

  test(
    'period decoder rejects impossible, reversed, timed and naive shapes',
    () {
      for (final value in [
        {'startDate': '2026-02-29', 'endDate': '2026-03-01'},
        {'startDate': '2026-09-31', 'endDate': '2026-12-21'},
        {'startDate': '2026-9-01', 'endDate': '2026-12-21'},
        {'startDate': '2026-09-01T00:00:00Z', 'endDate': '2026-12-21'},
        {'startDate': '2026-12-21', 'endDate': '2026-09-01'},
        {'startDate': '1899-12-31', 'endDate': '2026-12-21'},
        {'startDate': null, 'endDate': '2026-12-21'},
      ]) {
        expect(() => TimetablePeriod.fromJson(value), throwsFormatException);
      }
      expect(
        () => TimetablePeriod(
          start: DateTime(2026, 9, 2),
          end: DateTime(2026, 9, 1),
        ),
        throwsArgumentError,
      );
      expect(
        TimetablePeriod.fromJson({
          'startDate': '2024-02-29',
          'endDate': '2024-02-29',
        }).contains(DateTime(2024, 2, 29)),
        isTrue,
      );
    },
  );

  test(
    'saved terms union course/name/range, sort newest and preserve empty creation',
    () async {
      final (preferences, store) = await _store('a');
      await store.save(_course('legacy'));
      await store.renameTerm(2025, '2', '이전 가을');
      await store.createTerm(2026, '여름', period: _spring, name: '여름 수업');
      await store.createTerm(2026, '겨울', period: _fall);
      await store.createTerm(2027, '1', period: _spring);
      expect(store.terms.map((term) => (term.year, term.semester)).toList(), [
        (2027, '1'),
        (2026, '겨울'),
        (2026, '2'),
        (2026, '여름'),
        (2025, '2'),
      ]);
      expect(
        store.terms
            .singleWhere((term) => term.semester == '2' && term.year == 2026)
            .courseCount,
        1,
      );
      expect(
        store.terms
            .singleWhere((term) => term.semester == '2' && term.year == 2026)
            .period,
        isNull,
      );
      expect(store.activeYear, 2027);
      expect(store.activeSemester, '1');
      expect(store.activePeriod, _spring);
      final restored = TimetableStore(preferences);
      expect(restored.terms, hasLength(5));
      expect(restored.activeYear, 2027);
      expect(restored.activeClasses, isEmpty);
      expect(restored.hasPendingSync, isTrue);
    },
  );

  test(
    'duplicate creation and invalid names leave original range and selection intact',
    () async {
      final (preferences, store) = await _store('a');
      await store.createTerm(2026, '2', period: _fall, name: '가을');
      await store.selectTerm(2026, '1');
      final before = preferences.getString(TimetableStore.storageKey);
      await expectLater(
        store.createTerm(2026, '2', period: _spring, name: '바꾸면 안 됨'),
        throwsStateError,
      );
      expect(
        () => store.createTerm(2027, '1', period: _spring, name: ' '),
        throwsArgumentError,
      );
      expect(preferences.getString(TimetableStore.storageKey), before);
      expect(store.activeSemester, '1');
      expect(store.periodFor(2026, '2'), _fall);
    },
  );

  test(
    'queued duplicate creation checks the latest committed term list',
    () async {
      final (_, store) = await _store('a');
      final first = store.createTerm(2026, '2', period: _fall, name: '처음');
      final duplicate = store.createTerm(
        2026,
        '2',
        period: _spring,
        name: '두 번째',
      );
      final rejected = expectLater(duplicate, throwsStateError);
      await first;
      await rejected;
      expect(store.terms, hasLength(1));
      expect(store.activeName, '처음');
      expect(store.activePeriod, _fall);
    },
  );

  test('course reset retains name, range and saved empty term', () async {
    final (preferences, store) = await _store('a');
    await store.createTerm(2026, '2', period: _fall, name: '가을');
    await store.save(_course('a'));
    await store.clearActive();
    final restored = TimetableStore(preferences);
    expect(restored.terms.single.courseCount, 0);
    expect(restored.terms.single.name, '가을');
    expect(restored.terms.single.period, _fall);
  });

  test(
    'selection persists locally without cloud content, pending or revision changes',
    () async {
      final (preferences, store) = await _store('a');
      final empty = store.syncDocument();
      await store.selectTerm(2026, '2');
      expect(store.hasPendingSync, isFalse);
      expect(store.localRevisionNotifier.value, 0);
      expect(store.syncDocument().sameAs(empty), isTrue);
      expect(store.terms, isEmpty);
      await store.selectTerm(2027, '1');
      final restored = TimetableStore(
        preferences,
        now: () => DateTime(2028, 8),
      );
      expect(restored.activeYear, 2027);
      expect(restored.activeSemester, '1');
      expect(restored.hasPendingSync, isFalse);
      expect(restored.syncDocument().activeTerm, isNull);
    },
  );

  test(
    'legacy active register round-trips without moving local selection or rejecting cache',
    () async {
      final (preferences, store) = await _store('a');
      await store.selectTerm(2026, '2');
      final remote = TimetableSyncDocument.records(
        activeTerm: TimetableSyncValue(
          {'academicYear': 2027, 'semester': '1'},
          _now,
          'older-client',
        ),
      );
      await store.mergeSyncDocument(remote);
      expect(store.activeYear, 2026);
      expect(store.activeSemester, '2');
      expect(
        store.syncDocument().activeTerm!.toJson(),
        remote.activeTerm!.toJson(),
      );
      await store.selectTerm(2025, '2');
      final restored = TimetableStore(preferences);
      expect(restored.loadError, isNull);
      expect(restored.activeYear, 2025);
      expect(restored.syncDocument().sameAs(remote), isTrue);
      expect(restored.hasPendingSync, isFalse);
    },
  );

  test('upload acknowledgement preserves a newer local selection', () async {
    final (preferences, store) = await _store('a');
    await store.createTerm(2026, '2', period: _fall);
    final upload = store.syncDocument();
    final revision = store.localRevisionNotifier.value;
    await store.selectTerm(2027, '1');
    expect(store.hasPendingSync, isTrue);
    await store.acknowledgeSyncDocument(upload);
    expect(store.activeYear, 2027);
    expect(store.activeSemester, '1');
    expect(store.localRevisionNotifier.value, revision);
    expect(store.hasPendingSync, isFalse);
    expect(TimetableStore(preferences).activeYear, 2027);
  });

  test(
    'old schema 1 document without termPeriods still decodes unchanged content',
    () async {
      final (_, store) = await _store('a');
      await store.save(_course('a'));
      final json = store.syncDocument().toJson()..remove('termPeriods');
      final decoded = TimetableSyncDocument.fromJson(json);
      expect(decoded.termPeriods, isEmpty);
      expect(decoded.materializeClasses().single.id, 'a');
      expect(decoded.toJson()['schemaVersion'], 1);
    },
  );

  test(
    'names and periods merge independently and newer period edit wins',
    () async {
      final (_, a) = await _store('a');
      await a.createTerm(2026, '2', period: _fall, name: '가을');
      final (_, b) = await _store('b');
      await b.mergeSyncDocument(a.syncDocument());
      await a.renameTerm(2026, '2', '새 이름');
      await b.setTermPeriod(2026, '2', _spring);
      final merged = a.syncDocument().merge(b.syncDocument());
      expect(merged.sameAs(b.syncDocument().merge(a.syncDocument())), isTrue);
      expect(merged.materializeNames()[2026]!['2'], '새 이름');
      expect(merged.materializePeriods()[2026]!['2'], _spring);
      final reloaded = TimetableSyncDocument.fromJson(
        jsonDecode(jsonEncode(merged.toJson())) as Map<String, dynamic>,
      );
      expect(reloaded.sameAs(merged), isTrue);
    },
  );

  test(
    'known period defaults seed only existing terms as untimed migration values',
    () async {
      final (preferences, store) = await _store('a');
      await store.seedTermPeriods({_termKey: _fall});
      expect(store.terms, isEmpty);
      expect(store.hasPendingSync, isFalse);
      await store.save(_course('a'));
      expect(store.activePeriod, _fall);
      expect(store.syncDocument().termPeriods[_termKey]!.changedAt, isNull);
      expect(TimetableStore(preferences).activePeriod, _fall);
      final revision = store.localRevisionNotifier.value;
      final before = preferences.getString(TimetableStore.storageKey);
      await store.seedTermPeriods({_termKey: _fall});
      expect(preferences.getString(TimetableStore.storageKey), before);
      expect(store.localRevisionNotifier.value, revision);
    },
  );

  test(
    'later remote courses inherit configured defaults while unknown terms remain unset',
    () async {
      final (_, local) = await _store('local');
      await local.seedTermPeriods({_termKey: _fall});
      final (_, remote) = await _store('remote');
      await remote.save(_course('known'));
      await remote.save(_course('unknown', year: 2027));
      await local.mergeSyncDocument(remote.syncDocument());
      expect(local.periodFor(2026, '2'), _fall);
      expect(local.periodFor(2027, '2'), isNull);
      expect(local.hasPendingSync, isTrue);
      expect(local.syncDocument().termPeriods[_termKey]!.changedAt, isNull);
    },
  );

  test(
    'migration never overwrites explicit period edits or tombstones',
    () async {
      final (_, store) = await _store('a');
      await store.save(_course('a'));
      await store.setTermPeriod(2026, '2', _spring);
      await store.seedTermPeriods({_termKey: _fall});
      expect(store.activePeriod, _spring);
      final deletion = TimetableSyncDocument.records(
        termPeriods: {
          _termKey: TimetableSyncValue(
            null,
            _now.add(const Duration(days: 1)),
            'b',
          ),
        },
      );
      await store.mergeSyncDocument(deletion);
      await store.seedTermPeriods({_termKey: _fall});
      expect(store.activePeriod, isNull);
      expect(store.syncDocument().termPeriods[_termKey]!.value, isNull);
      expect(store.terms.single.courseCount, 1);
    },
  );

  test(
    'remote timed edit outranks a freshly migrated untimed official period',
    () async {
      final (_, local) = await _store('a');
      await local.save(_course('a'));
      await local.seedTermPeriods({_termKey: _fall});
      final remote = TimetableSyncDocument.records(
        termPeriods: {
          _termKey: TimetableSyncValue(
            _spring.toJson(),
            _now.subtract(const Duration(days: 20)),
            'b',
          ),
        },
      );
      await local.mergeSyncDocument(remote);
      expect(local.activePeriod, _spring);
    },
  );

  test(
    'invalid synced period fails closed before merge and preserves local data',
    () async {
      final (preferences, store) = await _store('a');
      await store.createTerm(2026, '2', period: _fall);
      final before = preferences.getString(TimetableStore.storageKey);
      final json = store.syncDocument().toJson();
      json['termPeriods'] = {
        _termKey: {
          'value': {'startDate': '2026-02-30', 'endDate': '2026-12-21'},
          'changedAt': null,
          'deviceId': '',
        },
      };
      expect(() => TimetableSyncDocument.fromJson(json), throwsFormatException);
      expect(preferences.getString(TimetableStore.storageKey), before);
    },
  );

  test(
    'failed new term write keeps selection, cache, cloud document and notifications',
    () async {
      final platform = _FailPreferences();
      SharedPreferencesStorePlatform.instance = platform;
      SharedPreferences.resetStatic();
      final preferences = await SharedPreferences.getInstance();
      final store = TimetableStore(preferences, now: () => _now, deviceId: 'a');
      await store.createTerm(2026, '2', period: _fall);
      await store.acknowledgeSyncDocument(store.syncDocument());
      final before = preferences.getString(TimetableStore.storageKey);
      final doc = store.syncDocument();
      final revision = store.localRevisionNotifier.value;
      var notifications = 0;
      store.addListener(() => notifications++);
      platform.failNext = true;
      await expectLater(
        store.createTerm(2027, '1', period: _spring),
        throwsStateError,
      );
      expect(preferences.getString(TimetableStore.storageKey), before);
      expect(store.terms, hasLength(1));
      expect(store.activeYear, 2026);
      expect(store.syncDocument().sameAs(doc), isTrue);
      expect(store.hasPendingSync, isFalse);
      expect(store.localRevisionNotifier.value, revision);
      expect(notifications, 0);
    },
  );

  test(
    'failed baseline migration is not retried by device-local selection',
    () async {
      final platform = _FailPreferences();
      SharedPreferencesStorePlatform.instance = platform;
      SharedPreferences.resetStatic();
      final preferences = await SharedPreferences.getInstance();
      final store = TimetableStore(preferences, now: () => _now, deviceId: 'a');
      await store.save(_course('a'));
      await store.acknowledgeSyncDocument(store.syncDocument());
      final revision = store.localRevisionNotifier.value;
      platform.failNext = true;
      await expectLater(
        store.seedTermPeriods({_termKey: _fall}),
        throwsStateError,
      );
      expect(store.activePeriod, isNull);
      expect(store.hasPendingSync, isFalse);
      await store.selectTerm(2027, '1');
      expect(store.periodFor(2026, '2'), isNull);
      expect(store.hasPendingSync, isFalse);
      expect(store.localRevisionNotifier.value, revision);
      await store.seedTermPeriods({_termKey: _fall});
      expect(store.periodFor(2026, '2'), _fall);
      expect(store.hasPendingSync, isTrue);
    },
  );

  test(
    'cache period mismatch or impossible date fails closed without data loss',
    () async {
      final (preferences, store) = await _store('a');
      await store.createTerm(2026, '2', period: _fall);
      final original =
          jsonDecode(preferences.getString(TimetableStore.storageKey)!)
              as Map<String, dynamic>;
      for (final range in [
        _spring.toJson(),
        {'startDate': '2026-02-30', 'endDate': '2026-12-21'},
      ]) {
        final corrupted = jsonEncode({
          ...original,
          'termPeriods': {
            '2026': {'2': range},
          },
        });
        SharedPreferences.setMockInitialValues({
          TimetableStore.storageKey: corrupted,
        });
        final badPreferences = await SharedPreferences.getInstance();
        final bad = TimetableStore(badPreferences);
        expect(bad.loadError, isNotNull);
        expect(bad.hasPendingSync, isTrue);
        await expectLater(
          bad.setTermPeriod(2026, '2', _fall),
          throwsStateError,
        );
        await expectLater(bad.selectTerm(2027, '1'), throwsStateError);
        expect(badPreferences.getString(TimetableStore.storageKey), corrupted);
      }
    },
  );
}
