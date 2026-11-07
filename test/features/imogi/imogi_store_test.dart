import 'package:daily/features/imogi/data/imogi_store.dart';
import 'package:daily/features/imogi/domain/imogi_item.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ImogiStore> _store({String device = 'device-a', DateTime? at}) async {
  final preferences = await SharedPreferences.getInstance();
  var tick = 0;
  return ImogiStore(
    preferences,
    deviceId: device,
    now: () => (at ?? DateTime.utc(2026, 11, 5)).add(Duration(seconds: tick++)),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('badge label hides zero and caps at 99+', () {
    expect(imogiBadgeLabel(0), isNull);
    expect(imogiBadgeLabel(1), '1');
    expect(imogiBadgeLabel(99), '99');
    expect(imogiBadgeLabel(100), '99+');
  });

  test('open count follows add, complete, restore and delete', () async {
    final store = await _store();
    final a = await store.add('  택배 반품하기 ');
    final b = await store.add('전화하기');
    expect(a.title, '택배 반품하기');
    expect(store.openCount, 2);
    await store.setCompleted(a.id, true);
    expect(store.openCount, 1);
    expect(store.completedItems.single.id, a.id);
    await store.setCompleted(a.id, false);
    expect(store.openCount, 2);
    await store.remove(b.id);
    expect(store.openCount, 1);
    expect(store.hasPendingSync, isTrue);
    // The tombstone is kept for sync instead of forgetting the deletion.
    expect(store.syncDocument().items[b.id]!.value, isNull);
    await expectLater(store.setImportant(b.id, true), throwsStateError);
    await expectLater(store.add('   '), throwsArgumentError);
  });

  test('important open items sort first, completed items last', () async {
    final store = await _store();
    final older = await store.add('older');
    final newer = await store.add('newer');
    final done = await store.add('done');
    await store.setCompleted(done.id, true);
    expect(store.items.map((i) => i.id), [newer.id, older.id, done.id]);
    await store.setImportant(older.id, true);
    expect(store.items.map((i) => i.id), [older.id, newer.id, done.id]);
  });

  test('edit keeps an optional note and survives reload', () async {
    final store = await _store();
    final item = await store.add('질문');
    await store.edit(item.id, title: '교수님께 질문', note: ' 과제 범위 ');
    final reloaded = await _store();
    expect(reloaded.loadError, isNull);
    expect(reloaded.items.single.title, '교수님께 질문');
    expect(reloaded.items.single.note, '과제 범위');
    expect(reloaded.hasPendingSync, isTrue);
    await reloaded.edit(item.id, title: '교수님께 질문', note: '  ');
    expect(reloaded.items.single.note, isNull);
  });

  test(
    'merge keeps local items missing remotely and newest change wins',
    () async {
      final local = await _store();
      final kept = await local.add('local only');
      final shared = await local.add('shared');
      final remote = ImogiSyncDocument({
        shared.id: TimetableSyncValue(null, DateTime.utc(2027), 'device-b'),
      });
      await local.mergeSyncDocument(remote);
      expect(local.items.map((i) => i.id), [kept.id]);
      expect(local.hasPendingSync, isTrue);

      // An older remote edit does not resurrect the newer local deletion.
      await local.mergeSyncDocument(
        ImogiSyncDocument({
          shared.id: TimetableSyncValue(
            shared.toJson(),
            DateTime.utc(2026),
            'device-b',
          ),
        }),
      );
      expect(local.items.map((i) => i.id), [kept.id]);
    },
  );

  test('a conversion keeps one reserved event ID until it completes', () async {
    final store = await _store();
    final item = await store.add('전화하기');
    final first = await store.reserveConversion(item.id);
    // A retry after a failed completion reuses the persisted ID.
    final reloaded = await _store();
    expect(await reloaded.reserveConversion(item.id), first);
    final replaced = await reloaded.reserveConversion(item.id, discard: first);
    expect(replaced, isNot(first));
    await reloaded.completeConversion(item.id);
    final done = reloaded.items.single;
    expect(done.completed, isTrue);
    expect(done.conversionEventId, isNull);
    // Restoring and converting again reserves a new event.
    await reloaded.setCompleted(item.id, false);
    expect(await reloaded.reserveConversion(item.id), isNot(replaced));
  });

  test('clearLocal empties the cache without cloud tombstones', () async {
    final store = await _store();
    await store.add('x');
    await store.clearLocal();
    expect(store.items, isEmpty);
    expect(store.syncDocument().isEmpty, isTrue);
    expect(store.hasPendingSync, isFalse);
  });

  test('an unreadable cache refuses writes instead of overwriting', () async {
    SharedPreferences.setMockInitialValues({ImogiStore.storageKey: '{bad'});
    final store = await _store();
    expect(store.loadError, isNotNull);
    expect(store.hasPendingSync, isTrue);
    await expectLater(store.add('x'), throwsStateError);
  });
}
