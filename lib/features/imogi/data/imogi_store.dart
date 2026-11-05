import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/sync/sync_version.dart';
import '../../timetable/data/timetable_sync_document.dart';
import '../domain/imogi_item.dart';

/// The separate `daily-sync-v2-imogi.json` Drive document: one LWW register
/// per item, where a null value is a deletion tombstone.
class ImogiSyncDocument {
  ImogiSyncDocument([Map<String, TimetableSyncValue> items = const {}])
    : items = Map.unmodifiable(items) {
    for (final entry in items.entries) {
      if (entry.key.isEmpty) throw const FormatException('Invalid imogi key');
      final value = entry.value.value;
      if (value == null) continue;
      final item = ImogiItem.fromJson(Map<String, dynamic>.from(value as Map));
      if (item.id != entry.key) {
        throw const FormatException('Imogi key does not match its item');
      }
    }
  }

  static const schemaVersion = 1;
  final Map<String, TimetableSyncValue> items;

  bool get isEmpty => items.isEmpty;

  factory ImogiSyncDocument.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported imogi sync version');
    }
    return ImogiSyncDocument(
      Map<String, dynamic>.from(json['items'] as Map).map(
        (key, value) => MapEntry(
          key,
          TimetableSyncValue.fromJson(Map<String, dynamic>.from(value as Map)),
        ),
      ),
    );
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'items': items.map((key, value) => MapEntry(key, value.toJson())),
  };

  bool sameAs(ImogiSyncDocument other) =>
      canonicalSyncJson(toJson()) == canonicalSyncJson(other.toJson());

  ImogiSyncDocument merge(ImogiSyncDocument other) => ImogiSyncDocument({
    for (final key in {...items.keys, ...other.items.keys})
      key: switch ((items[key], other.items[key])) {
        (final a?, final b?) => a.compareTo(b) >= 0 ? a : b,
        (final a?, null) => a,
        (null, final b?) => b,
        (null, null) => throw StateError('unreachable'),
      },
  });

  DateTime? get latestChangedAt {
    DateTime? latest;
    for (final record in items.values) {
      final date = record.changedAt;
      if (date != null && (latest == null || date.isAfter(latest))) {
        latest = date;
      }
    }
    return latest;
  }

  List<ImogiItem> materialize() => [
    for (final record in items.values)
      if (record.value != null)
        ImogiItem.fromJson(Map<String, dynamic>.from(record.value as Map)),
  ]..sort(compareImogiItems);
}

/// Offline cache and outbox for the imogi Drive document.
class ImogiStore extends ChangeNotifier {
  ImogiStore(this._preferences, {DateTime Function()? now, String? deviceId})
    : _now = now ?? DateTime.now,
      _injectedDeviceId = deviceId {
    _load();
  }

  static const storageKey = 'daily.imogi.v1';
  final SharedPreferences _preferences;
  final DateTime Function() _now;
  final String? _injectedDeviceId;
  String? _deviceId;
  ImogiSyncDocument _document = ImogiSyncDocument();
  List<ImogiItem> _items = const [];
  bool _pendingSync = false;
  int _generation = 0;
  Future<void> _tail = Future.value();
  Object? loadError;

  /// Bumped only by local edits, so the sync service can queue an upload.
  final localRevisionNotifier = ValueNotifier<int>(0);

  List<ImogiItem> get items => _items;
  List<ImogiItem> get openItems => _items.where((i) => !i.completed).toList();
  List<ImogiItem> get completedItems =>
      _items.where((i) => i.completed).toList();

  /// Computed from the stored items, so it can never drift from the list.
  int get openCount => _items.where((i) => !i.completed).length;

  bool get hasPendingSync => loadError != null || _pendingSync;

  ImogiSyncDocument syncDocument() {
    _requireReadable();
    return _document;
  }

  void _load() {
    try {
      final raw = _preferences.getString(storageKey);
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['version'] != 1) {
        throw const FormatException('Unsupported imogi cache version');
      }
      _document = ImogiSyncDocument.fromJson(
        Map<String, dynamic>.from(json['document'] as Map),
      );
      _items = _document.materialize();
      _pendingSync = json['pending'] as bool;
      _deviceId = json['deviceId'] as String?;
    } catch (error) {
      loadError = error;
    }
  }

  Future<ImogiItem> add(String title) async {
    final now = _now();
    final item = ImogiItem(
      id: const Uuid().v4(),
      title: title.trim(),
      createdAt: now.toUtc(),
    );
    if (!item.isValid) throw ArgumentError('Invalid imogi title');
    await _write(item.id, (_) => item);
    return item;
  }

  Future<void> edit(String id, {required String title, String? note}) {
    final trimmedNote = note?.trim();
    return _write(id, (current) {
      final next = current!.copyWith(
        title: title.trim(),
        note: trimmedNote,
        clearNote: trimmedNote == null || trimmedNote.isEmpty,
      );
      if (!next.isValid) throw ArgumentError('Invalid imogi item');
      return next;
    });
  }

  Future<void> setImportant(String id, bool important) =>
      _write(id, (current) => current!.copyWith(important: important));

  Future<void> setCompleted(String id, bool completed) => _write(
    id,
    (current) => completed
        ? current!.copyWith(completedAt: _now().toUtc())
        : current!.copyWith(clearCompletedAt: true),
  );

  Future<void> remove(String id) => _write(id, (_) => null);

  Future<void> _write(String id, ImogiItem? Function(ImogiItem?) update) =>
      _enqueue((validate) async {
        _requireReadable();
        final current = _items.where((i) => i.id == id).firstOrNull;
        final exists = _document.items.containsKey(id);
        if (exists && current == null) {
          throw StateError('This imogi item was deleted');
        }
        final next = update(current);
        if (current == null && next == null) return;
        if (current != null &&
            next != null &&
            canonicalSyncJson(current.toJson()) ==
                canonicalSyncJson(next.toJson())) {
          return;
        }
        final device = _writerId();
        final document = ImogiSyncDocument({
          ..._document.items,
          id: TimetableSyncValue(next?.toJson(), _nextTimestamp(), device),
        });
        validate();
        await _persist(document, pending: true, device: device);
        localRevisionNotifier.value++;
      });

  Future<void> mergeSyncDocument(
    ImogiSyncDocument remote, {
    VoidCallback? validateSession,
  }) => _mergeAndPersist(remote, validateSession);

  Future<void> acknowledgeSyncDocument(
    ImogiSyncDocument uploaded, {
    VoidCallback? validateSession,
  }) => _mergeAndPersist(uploaded, validateSession);

  Future<void> _mergeAndPersist(
    ImogiSyncDocument remote,
    VoidCallback? validateSession,
  ) => _enqueue((validate) async {
    _requireReadable();
    final merged = _document.merge(remote);
    validate();
    await _persist(
      merged,
      pending: !merged.sameAs(remote),
      device: _writerId(),
    );
  }, validateSession: validateSession);

  Future<void> _persist(
    ImogiSyncDocument document, {
    required bool pending,
    required String device,
  }) async {
    final saved = await _preferences.setString(
      storageKey,
      jsonEncode({
        'version': 1,
        'document': document.toJson(),
        'pending': pending,
        'deviceId': device,
      }),
    );
    if (!saved) throw StateError('Imogi save failed');
    _document = document;
    _items = document.materialize();
    _pendingSync = pending;
    _deviceId = device;
    notifyListeners();
  }

  String _writerId() {
    final writer =
        _injectedDeviceId ?? _deviceId ?? _preferences.getString('deviceId');
    if (writer != null && writer.isNotEmpty) return writer;
    return _deviceId = const Uuid().v4();
  }

  DateTime _nextTimestamp() {
    final now = _now().toUtc();
    final latest = _document.latestChangedAt;
    return latest != null && !now.isAfter(latest)
        ? latest.add(const Duration(microseconds: 1))
        : now;
  }

  void _requireReadable() {
    if (loadError != null) {
      throw StateError('Existing imogi items could not be read');
    }
  }

  Future<void> _enqueue(
    Future<void> Function(VoidCallback validate) action, {
    VoidCallback? validateSession,
  }) {
    final generation = _generation;
    void validate() {
      if (generation != _generation) throw StateError('Imogi session changed');
      validateSession?.call();
    }

    final operation = _tail.then((_) async {
      validate();
      await action(validate);
    });
    _tail = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  /// Cancels queued work that belongs to the previous account session.
  void invalidate() => _generation++;

  /// Clears only this device's cache; it never writes cloud tombstones.
  Future<void> clearLocal() {
    invalidate();
    return _enqueue((_) async {
      if (!await _preferences.remove(storageKey)) {
        throw StateError('Could not clear imogi cache');
      }
      _document = ImogiSyncDocument();
      _items = const [];
      _pendingSync = false;
      _deviceId = null;
      loadError = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    invalidate();
    localRevisionNotifier.dispose();
    super.dispose();
  }
}
