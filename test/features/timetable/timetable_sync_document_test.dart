import 'dart:async';
import 'dart:convert';

import 'package:daily/features/timetable/data/timetable_store.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// The plugin's in-memory platform implementation lets persistence failures be
// tested without production-only failure hooks on TimetableStore.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

TimetableClass _course(
  String id, {
  String title = '자료구조',
  String? sourceId,
  int year = 2026,
  String semester = '2',
}) => TimetableClass(
  id: id,
  title: title,
  academicYear: year,
  semester: semester,
  sourceId: sourceId,
  sourceType: sourceId == null ? 'manual' : 'universityDataset',
  meetings: const [
    ClassMeeting(id: 'mon', weekday: 1, startMinute: 540, endMinute: 600),
  ],
);

final _time = DateTime.utc(2026, 9, 25, 12);

Future<(SharedPreferences, TimetableStore)> _store(String device) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return (prefs, TimetableStore(prefs, now: () => _time, deviceId: device));
}

TimetableSyncDocument _one(
  TimetableClass course, {
  DateTime? time,
  String device = 'a',
}) => TimetableSyncDocument.records(
  courses: {
    timetableCourseSyncKey(course): TimetableSyncValue(
      {
        ...course.toJson(),
        if (course.sourceId != null) 'id': timetableCourseSyncKey(course),
      },
      time ?? _time,
      device,
    ),
  },
);

class _ControlledPreferences extends InMemorySharedPreferencesStore {
  _ControlledPreferences() : super.empty();
  bool failNext = false;
  bool failNextRemove = false;
  Completer<void>? started;
  Completer<void>? resume;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (failNext) {
      failNext = false;
      return false;
    }
    final pause = resume;
    if (pause != null) {
      resume = null;
      started?.complete();
      await pause.future;
    }
    return super.setValue(valueType, key, value);
  }

  @override
  Future<bool> remove(String key) async {
    if (failNextRemove) {
      failNextRemove = false;
      return false;
    }
    return super.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'fresh cache has no document or upload; old content has stable legacy revisions',
    () async {
      final (_, empty) = await _store('fresh');
      expect(empty.syncDocument().isEmpty, isTrue);
      expect(empty.hasPendingSync, isFalse);
      final raw = jsonEncode({
        'version': 1,
        'activeYear': 2026,
        'activeSemester': '2',
        'classes': [_course('legacy').toJson()],
        'termNames': {
          '2026': {'2': '기존 이름'},
        },
      });
      SharedPreferences.setMockInitialValues({TimetableStore.storageKey: raw});
      final prefs = await SharedPreferences.getInstance();
      final legacy = TimetableStore(
        prefs,
        now: () => _time,
        deviceId: 'new-device',
      );
      expect(legacy.hasPendingSync, isTrue);
      expect(legacy.activeName, '기존 이름');
      expect(legacy.localRevisionNotifier.value, 0);
      expect(prefs.getString(TimetableStore.storageKey), raw);
      final doc = legacy.syncDocument();
      expect(doc.courses.values.single.changedAt, isNull);
      expect(doc.termNames.values.single.changedAt, isNull);
      expect(doc.activeTerm!.changedAt, isNull);
      expect(doc.sameAs(TimetableStore(prefs).syncDocument()), isTrue);
      await legacy.acknowledgeSyncDocument(doc);
      expect(legacy.hasPendingSync, isFalse);
      expect(TimetableStore(prefs).hasPendingSync, isFalse);
      expect(TimetableStore(prefs).classes.single.id, 'legacy');
    },
  );

  test('register ordering uses UTC, deletion, writer, and canonical value', () {
    final a = TimetableSyncValue(
      'a',
      DateTime.parse('2026-09-25T21:00:00+09:00'),
      'a',
    );
    final b = TimetableSyncValue('b', _time, 'b');
    expect(a.compareTo(b), lessThan(0));
    final deleted = TimetableSyncValue(null, _time, 'a');
    expect(deleted.compareTo(b), greaterThan(0));
    final oldDelete = TimetableSyncValue(
      null,
      _time.subtract(const Duration(seconds: 1)),
      'z',
    );
    expect(oldDelete.compareTo(a), lessThan(0));
    final sameWriter = TimetableSyncValue('z', _time, 'a');
    expect(sameWriter.compareTo(a), greaterThan(0));
    expect(
      TimetableSyncValue(
        {'a': 1, 'b': 2},
        _time,
        'x',
      ).compareTo(TimetableSyncValue({'b': 2, 'a': 1}, _time, 'x')),
      0,
    );
    expect(a.toJson()['changedAt'], '2026-09-25T12:00:00.000Z');
  });

  test('document merge is commutative, associative and idempotent', () {
    final a = _one(_course('a'));
    final b = _one(_course('b'), device: 'b');
    final c = _one(
      _course('a', title: '수정된 수업'),
      time: _time.add(const Duration(seconds: 1)),
    );
    expect(a.merge(b).sameAs(b.merge(a)), isTrue);
    expect(a.merge(a).sameAs(a), isTrue);
    expect(a.merge(b).merge(c).sameAs(a.merge(b.merge(c))), isTrue);
    expect(
      a.merge(b).merge(c).materializeClasses().map((c) => c.title),
      contains('수정된 수업'),
    );
    expect(TimetableSyncDocument.fromJson(a.toJson()).sameAs(a), isTrue);
  });

  test(
    'equal timestamp deletion wins on any device and survives stale snapshots',
    () {
      final original = _course('a');
      final alive = _one(original, device: 'z');
      final deleted = TimetableSyncDocument.records(
        courses: {
          timetableCourseSyncKey(original): TimetableSyncValue(
            null,
            _time,
            'a',
          ),
        },
      );
      final merged = alive.merge(deleted);
      expect(merged.sameAs(deleted.merge(alive)), isTrue);
      expect(merged.materializeClasses(), isEmpty);
      expect(merged.merge(alive).materializeClasses(), isEmpty);
      expect(merged.courses, hasLength(1));
    },
  );

  test(
    'offline devices preserve independent courses and converge after later deletion',
    () async {
      final (_, a) = await _store('a');
      await a.selectTerm(2026, '2');
      await a.save(_course('course-a'));
      final (_, b) = await _store('b');
      await b.selectTerm(2026, '2');
      await b.save(_course('course-b'));
      final bOffline = b.syncDocument();
      await a.mergeSyncDocument(bOffline);
      expect(a.classes, hasLength(2));
      expect(a.hasPendingSync, isTrue);
      final uploaded = a.syncDocument();
      await a.acknowledgeSyncDocument(uploaded);
      await b.mergeSyncDocument(uploaded);
      expect(a.syncDocument().sameAs(b.syncDocument()), isTrue);
      expect(a.hasPendingSync, isFalse);
      expect(b.hasPendingSync, isFalse);
      await b.remove('course-a');
      await a.mergeSyncDocument(b.syncDocument());
      expect(a.classes.single.id, 'course-b');
      await a.mergeSyncDocument(uploaded);
      expect(a.classes.single.id, 'course-b');
      expect(a.hasPendingSync, isTrue);
    },
  );

  test(
    'independent section imports merge by source identity without changing local editor IDs',
    () async {
      const source = 'smu/seoul/2026/2/ABC/1';
      final (prefsA, a) = await _store('a');
      await a.save(_course('uuid-a', sourceId: source));
      final (prefsB, b) = await _store('b');
      await b.save(_course('uuid-b', sourceId: source));
      await a.mergeSyncDocument(b.syncDocument());
      await b.mergeSyncDocument(a.syncDocument());
      expect(a.classes.single.id, 'uuid-a');
      expect(b.classes.single.id, 'uuid-b');
      expect(a.syncDocument().sameAs(b.syncDocument()), isTrue);
      expect(TimetableStore(prefsA).classes.single.id, 'uuid-a');
      expect(TimetableStore(prefsB).classes.single.id, 'uuid-b');
      await a.remove('uuid-a');
      await b.mergeSyncDocument(a.syncDocument());
      expect(b.classes, isEmpty);
    },
  );

  test(
    'acknowledgement includes remote content without losing edits after capture',
    () async {
      final (prefs, local) = await _store('local');
      await local.save(_course('local'));
      final upload = local.syncDocument().merge(
        _one(_course('remote'), device: 'remote'),
      );
      await local.save(_course('local', title: '업로드 중 수정'));
      await local.acknowledgeSyncDocument(upload);
      expect(local.classes, hasLength(2));
      expect(
        local.classes.singleWhere((c) => c.id == 'local').title,
        '업로드 중 수정',
      );
      expect(local.hasPendingSync, isTrue);
      expect(TimetableStore(prefs).hasPendingSync, isTrue);
      final latest = local.syncDocument();
      await local.acknowledgeSyncDocument(latest);
      expect(local.hasPendingSync, isFalse);
      expect(TimetableStore(prefs).syncDocument().sameAs(latest), isTrue);
    },
  );

  test(
    'term names sync while selection stays local and reset only deletes active classes',
    () async {
      final (_, local) = await _store('local');
      await local.selectTerm(2026, '2');
      await local.renameActive('가을');
      await local.save(_course('fall'));
      await local.selectTerm(2027, '1');
      await local.renameActive('봄');
      await local.save(_course('spring', year: 2027, semester: '1'));
      final (_, remote) = await _store('remote');
      await remote.mergeSyncDocument(local.syncDocument());
      expect(remote.activeYear, 2026);
      expect(remote.activeSemester, '2');
      expect(remote.activeName, '가을');
      await remote.selectTerm(2027, '1');
      await remote.clearActive();
      expect(remote.classes.single.id, 'fall');
      expect(remote.activeName, '봄');
      await local.mergeSyncDocument(remote.syncDocument());
      expect(local.classes.single.id, 'fall');
      await local.selectTerm(2026, '2');
      expect(local.activeName, '가을');
    },
  );

  test(
    'local revision only signals successful local changes and timestamps never go backwards',
    () async {
      var now = _time;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = TimetableStore(prefs, now: () => now, deviceId: 'a');
      await store.save(_course('a'));
      final first = store.syncDocument().courses.values.single.changedAt!;
      expect(store.localRevisionNotifier.value, 1);
      await store.save(_course('a'));
      expect(store.localRevisionNotifier.value, 1);
      now = _time.subtract(const Duration(days: 1));
      await store.save(_course('a', title: '변경'));
      expect(
        store.syncDocument().courses.values.single.changedAt!.isAfter(first),
        isTrue,
      );
      expect(store.localRevisionNotifier.value, 2);
      await store.mergeSyncDocument(_one(_course('b'), device: 'b'));
      await store.acknowledgeSyncDocument(store.syncDocument());
      expect(store.localRevisionNotifier.value, 2);
      await store.clearLocal();
      expect(store.localRevisionNotifier.value, 2);
      expect(store.syncDocument().isEmpty, isTrue);
      expect(store.hasPendingSync, isFalse);
      expect(prefs.containsKey(TimetableStore.storageKey), isFalse);
    },
  );

  test(
    'explicit term edits retain their dialog target after remote term changes',
    () async {
      final (_, local) = await _store('local');
      await local.selectTerm(2026, '2');
      await local.save(_course('fall'));
      await local.save(_course('spring', year: 2027, semester: '1'));
      await local.renameActive('가을');
      final (_, remote) = await _store('remote');
      await remote.mergeSyncDocument(local.syncDocument());
      await remote.selectTerm(2027, '1');
      await remote.renameActive('봄');
      await Future.wait([
        local.mergeSyncDocument(remote.syncDocument()),
        local.renameTerm(2026, '2', '가을 수정'),
        local.clearTerm(2026, '2'),
      ]);
      expect(local.activeYear, 2026);
      expect(local.activeName, '가을 수정');
      expect(local.classes.single.id, 'spring');
      await local.selectTerm(2026, '2');
      expect(local.activeName, '가을 수정');
      expect(local.activeClasses, isEmpty);
    },
  );

  test(
    'writer identity persists without using an upload-generated revision',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = TimetableStore(prefs, now: () => _time);
      await first.save(_course('a'));
      final writer = first.syncDocument().courses.values.single.deviceId;
      expect(writer, isNotEmpty);
      final restored = TimetableStore(prefs, now: () => _time);
      await restored.save(_course('b'));
      expect(
        restored.syncDocument().courses.values.map((c) => c.deviceId).toSet(),
        {writer},
      );
    },
  );

  test(
    'queued session invalidation prevents stale merges and local writes',
    () async {
      final (prefs, store) = await _store('local');
      await store.save(_course('existing'));
      final before = prefs.getString(TimetableStore.storageKey);
      final staleMerge = store.mergeSyncDocument(_one(_course('remote')));
      final staleSave = store.save(_course('stale-local'));
      final mergeError = expectLater(staleMerge, throwsStateError);
      final saveError = expectLater(staleSave, throwsStateError);
      store.invalidate();
      await Future.wait([mergeError, saveError]);
      expect(prefs.getString(TimetableStore.storageKey), before);
      expect(store.classes.single.id, 'existing');
      await store.clearLocal();
      expect(store.classes, isEmpty);
    },
  );

  test(
    'external session validation runs within the queued merge and ack',
    () async {
      final (prefs, store) = await _store('local');
      await store.save(_course('local'));
      final before = prefs.getString(TimetableStore.storageKey);
      void stale() => throw StateError('account changed');
      await expectLater(
        store.mergeSyncDocument(
          _one(_course('remote')),
          validateSession: stale,
        ),
        throwsStateError,
      );
      await expectLater(
        store.acknowledgeSyncDocument(
          store.syncDocument(),
          validateSession: stale,
        ),
        throwsStateError,
      );
      expect(store.classes.single.id, 'local');
      expect(prefs.getString(TimetableStore.storageKey), before);
      expect(store.hasPendingSync, isTrue);
    },
  );

  test(
    'failed writes keep persisted data, metadata, and notifications unchanged',
    () async {
      SharedPreferences.setMockInitialValues({});
      final backend = _ControlledPreferences();
      SharedPreferencesStorePlatform.instance = backend;
      final prefs = await SharedPreferences.getInstance();
      final store = TimetableStore(prefs, now: () => _time, deviceId: 'local');
      await store.save(_course('existing'));
      await store.acknowledgeSyncDocument(store.syncDocument());
      final before = prefs.getString(TimetableStore.storageKey);
      var notifications = 0;
      store.addListener(() => notifications++);
      backend.failNext = true;
      await expectLater(store.save(_course('failed')), throwsStateError);
      expect(store.classes.single.id, 'existing');
      expect(store.hasPendingSync, isFalse);
      expect(store.localRevisionNotifier.value, 1);
      expect(notifications, 0);
      expect(prefs.getString(TimetableStore.storageKey), before);
      await prefs.reload();
      expect(prefs.getString(TimetableStore.storageKey), before);
    },
  );

  test(
    'session change during native persistence rolls back old-account data',
    () async {
      SharedPreferences.setMockInitialValues({});
      final backend = _ControlledPreferences();
      SharedPreferencesStorePlatform.instance = backend;
      final prefs = await SharedPreferences.getInstance();
      final store = TimetableStore(prefs, now: () => _time, deviceId: 'local');
      await store.save(_course('existing'));
      final before = prefs.getString(TimetableStore.storageKey);
      backend.started = Completer<void>();
      final resume = Completer<void>();
      backend.resume = resume;
      final write = store.mergeSyncDocument(_one(_course('remote')));
      final error = expectLater(write, throwsStateError);
      await backend.started!.future;
      store.invalidate();
      resume.complete();
      await error;
      expect(store.classes.single.id, 'existing');
      expect(prefs.getString(TimetableStore.storageKey), before);
      await prefs.reload();
      expect(prefs.getString(TimetableStore.storageKey), before);
      await store.clearLocal();
      expect(prefs.containsKey(TimetableStore.storageKey), isFalse);
    },
  );

  test('failed local clear restores cache and persisted outbox', () async {
    SharedPreferences.setMockInitialValues({});
    final backend = _ControlledPreferences();
    SharedPreferencesStorePlatform.instance = backend;
    final prefs = await SharedPreferences.getInstance();
    final store = TimetableStore(prefs, now: () => _time, deviceId: 'local');
    await store.save(_course('pending'));
    final before = prefs.getString(TimetableStore.storageKey);
    var notifications = 0;
    store.addListener(() => notifications++);
    backend.failNextRemove = true;
    await expectLater(store.clearLocal(), throwsStateError);
    expect(store.classes.single.id, 'pending');
    expect(store.hasPendingSync, isTrue);
    expect(notifications, 0);
    expect(prefs.getString(TimetableStore.storageKey), before);
    await prefs.reload();
    expect(TimetableStore(prefs).hasPendingSync, isTrue);
    expect(TimetableStore(prefs).classes.single.id, 'pending');
  });

  test(
    'corrupt sync metadata locks pending data and cannot silently drop classes',
    () async {
      final (prefs, store) = await _store('local');
      await store.save(_course('existing'));
      final json =
          jsonDecode(prefs.getString(TimetableStore.storageKey)!)
              as Map<String, dynamic>;
      (json['sync'] as Map)['document'] = const TimetableSyncDocument()
          .toJson();
      final corrupt = jsonEncode(json);
      await prefs.setString(TimetableStore.storageKey, corrupt);
      final restored = TimetableStore(prefs);
      expect(restored.loadError, isNotNull);
      expect(restored.hasPendingSync, isTrue);
      expect(restored.syncDocument, throwsStateError);
      await expectLater(
        restored.mergeSyncDocument(_one(_course('remote'))),
        throwsStateError,
      );
      expect(prefs.getString(TimetableStore.storageKey), corrupt);
    },
  );

  test(
    'sync documents reject invalid versions, naive times and mismatched identities',
    () {
      final json = _one(_course('a')).toJson();
      expect(
        () => TimetableSyncDocument.fromJson({...json, 'schemaVersion': 9}),
        throwsFormatException,
      );
      expect(
        () => TimetableSyncValue.fromJson({
          'value': null,
          'changedAt': '2026-09-25T12:00:00',
          'deviceId': 'a',
        }),
        throwsFormatException,
      );
      expect(
        () => TimetableSyncDocument.records(
          courses: {
            'manual/not-the-id': TimetableSyncValue(
              _course('a').toJson(),
              _time,
              'a',
            ),
          },
        ),
        throwsFormatException,
      );
      final invalid = TimetableClass.fromJson({
        ..._course('a').toJson(),
        'overrides': {'missing/2026-09-21': 'cancelled'},
      });
      expect(() => _one(invalid), throwsFormatException);
    },
  );
}
