import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/sync/settings_sync_document.dart';
import '../../../core/sync/sync_version.dart';
import '../domain/event_template.dart';

/// Local cache and outbox for the event template Drive document.
///
/// Templates belong to the signed-in Google account: each account (and the
/// signed-out state) keeps its own bucket, so switching accounts never shows,
/// uploads or merges another account's templates. Inside a bucket every
/// template is one last-writer-wins register (`template/<id>`, null = deleted)
/// plus one register for the list order.
class EventTemplateStore extends ChangeNotifier {
  EventTemplateStore(
    this._preferences, {
    required String? Function() readOwner,
    required Future<String> Function() deviceId,
    DateTime Function()? now,
  }) : _readOwner = readOwner,
       _deviceId = deviceId,
       _now = now ?? DateTime.now;

  static const storageKey = 'eventTemplates.v1';
  static const orderKey = 'order';
  static const _templatePrefix = 'template/';

  final SharedPreferences _preferences;
  final String? Function() _readOwner;
  final Future<String> Function() _deviceId;
  final DateTime Function() _now;
  final localRevisionNotifier = ValueNotifier<int>(0);
  Future<void> _tail = Future.value();

  String get _owner => _readOwner()?.trim().toLowerCase() ?? '';

  /// Throws when stored data is unreadable, so writes never overwrite it.
  Map<String, Object?> _readAll() {
    final raw = _preferences.getString(storageKey);
    if (raw == null) return {'version': 1, 'owners': <String, Object?>{}};
    final json = Map<String, Object?>.from(jsonDecode(raw) as Map);
    if (json['version'] != 1 || json['owners'] is! Map) {
      throw const FormatException('Unsupported event template data');
    }
    json['owners'] = Map<String, Object?>.from(json['owners'] as Map);
    return json;
  }

  ({SettingsSyncDocument document, bool pending}) _bucket(
    Map<String, Object?> all,
    String owner,
  ) {
    final bucket = (all['owners'] as Map)[owner];
    if (bucket is! Map) {
      return (document: const SettingsSyncDocument(), pending: false);
    }
    return (
      document: SettingsSyncDocument.fromJson(
        Map<String, Object?>.from(bucket['document'] as Map),
      ),
      pending: bucket['pending'] == true,
    );
  }

  SettingsSyncDocument syncDocument() => _bucket(_readAll(), _owner).document;

  bool get hasPendingSync {
    try {
      return _bucket(_readAll(), _owner).pending;
    } on Object {
      return false;
    }
  }

  /// Ordered templates of the current account; empty when data is unreadable.
  List<EventTemplate> get templates {
    try {
      return materialize(syncDocument());
    } on Object {
      return const [];
    }
  }

  static List<EventTemplate> materialize(SettingsSyncDocument document) {
    final order = (document.fields[orderKey]?.value as List? ?? const [])
        .whereType<String>()
        .toList();
    final items = <EventTemplate>[];
    for (final entry in document.fields.entries) {
      if (!entry.key.startsWith(_templatePrefix)) continue;
      final template = EventTemplate.tryFromJson(entry.value.value);
      if (template != null &&
          template.id ==
              Uri.decodeComponent(
                entry.key.substring(_templatePrefix.length),
              )) {
        items.add(template);
      }
    }
    items.sort((a, b) {
      final ai = order.indexOf(a.id), bi = order.indexOf(b.id);
      if (ai >= 0 && bi >= 0) return ai.compareTo(bi);
      if (ai >= 0) return -1;
      if (bi >= 0) return 1;
      final name = a.name.compareTo(b.name);
      return name != 0 ? name : a.id.compareTo(b.id);
    });
    return items;
  }

  static String templateKey(String id) =>
      '$_templatePrefix${Uri.encodeComponent(id)}';

  Future<void> save(EventTemplate template) {
    if (!template.isValid) {
      throw ArgumentError.value(template.id, 'template', 'Invalid template');
    }
    return _change((current) {
      final ids = [for (final t in materialize(current)) t.id];
      return {
        templateKey(template.id): template.toJson(),
        if (!ids.contains(template.id)) orderKey: [...ids, template.id],
      };
    });
  }

  Future<void> delete(String id) => _change((current) {
    final ids = [for (final t in materialize(current)) t.id];
    return {
      templateKey(id): null,
      if (ids.contains(id)) orderKey: [...ids]..remove(id),
    };
  });

  Future<void> reorder(List<String> ids) => _change((_) => {orderKey: ids});

  Future<void> _change(
    Map<String, Object?> Function(SettingsSyncDocument current) registers,
  ) => _enqueue(() async {
    final all = _readAll();
    final owner = _owner;
    final bucket = _bucket(all, owner);
    final updates = registers(bucket.document);
    final device = await _deviceId();
    var changedAt = _now().toUtc();
    final latest = bucket.document.fields.values
        .map((value) => value.changedAt)
        .whereType<DateTime>()
        .fold<DateTime?>(
          null,
          (max, value) => max == null || value.isAfter(max) ? value : max,
        );
    if (latest != null && !changedAt.isAfter(latest)) {
      changedAt = latest.add(const Duration(microseconds: 1));
    }
    var document = bucket.document;
    var changed = false;
    for (final entry in updates.entries) {
      final previous = document.fields[entry.key];
      if (previous != null &&
          canonicalSyncJson(previous.value) == canonicalSyncJson(entry.value)) {
        continue;
      }
      document = document.withField(
        entry.key,
        SettingsSyncValue(entry.value, changedAt, device),
      );
      changed = true;
    }
    if (!changed) return;
    if (owner != _owner) throw StateError('Event template account changed');
    await _write(all, owner, document, pending: true);
    localRevisionNotifier.value++;
  });

  Future<void> mergeSyncDocument(
    SettingsSyncDocument remote, {
    VoidCallback? validateSession,
  }) => _mergeAndPersist(remote, validateSession);

  Future<void> acknowledgeSyncDocument(
    SettingsSyncDocument uploaded, {
    VoidCallback? validateSession,
  }) => _mergeAndPersist(uploaded, validateSession);

  Future<void> _mergeAndPersist(
    SettingsSyncDocument remote,
    VoidCallback? validateSession,
  ) => _enqueue(() async {
    validateSession?.call();
    final all = _readAll();
    final owner = _owner;
    final bucket = _bucket(all, owner);
    final merged = bucket.document.merge(remote);
    final pending = !merged.sameAs(remote);
    if (merged.sameAs(bucket.document) && pending == bucket.pending) return;
    await _write(all, owner, merged, pending: pending);
  });

  Future<void> _write(
    Map<String, Object?> all,
    String owner,
    SettingsSyncDocument document, {
    required bool pending,
  }) async {
    (all['owners'] as Map<String, Object?>)[owner] = {
      'document': document.toJson(),
      'pending': pending,
    };
    if (!await _preferences.setString(storageKey, canonicalSyncJson(all))) {
      throw StateError('Event templates could not be saved');
    }
    notifyListeners();
  }

  /// Clears this device's cache only; it never emits cloud deletions.
  Future<void> clearLocal() => _enqueue(() async {
    await _preferences.remove(storageKey);
    notifyListeners();
  });

  Future<void> _enqueue(Future<void> Function() action) {
    final operation = _tail.then((_) => action());
    _tail = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  @override
  void dispose() {
    localRevisionNotifier.dispose();
    super.dispose();
  }
}
