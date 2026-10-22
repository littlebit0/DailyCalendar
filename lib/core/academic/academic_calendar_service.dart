import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter/foundation.dart';
import '../../features/events/application/event_command_service.dart';
import '../../features/events/domain/calendar_event.dart';
import '../../features/events/domain/event_category.dart';
import '../../features/events/domain/event_repository.dart';
import '../settings/settings_repository.dart';
import '../sync/sync_service.dart';
import 'academic_source.dart';
import 'academic_store.dart';

class AcademicPreview {
  const AcademicPreview(
    this.source,
    this.year,
    this.events,
    this.generation, [
    this.account,
  ]);
  final AcademicSource source;
  final int year;
  final List<AcademicEvent> events;
  final int generation;

  /// Google account active when the preview was fetched.
  final String? account;
}

class AcademicResult {
  const AcademicResult({
    this.added = 0,
    this.updated = 0,
    this.preserved = 0,
    this.failed = 0,
  });
  final int added;
  final int updated;
  final int preserved;
  final int failed;
}

class AcademicCalendarService extends ChangeNotifier {
  AcademicCalendarService({
    required this.sources,
    required AcademicStore store,
    required SettingsRepository settings,
    required EventRepository repository,
    required EventCommandService commands,
    required SyncService sync,
    DateTime Function()? now,
  }) : _store = store,
       _settings = settings,
       _repository = repository,
       _commands = commands,
       _sync = sync,
       _now = now ?? DateTime.now {
    _reload();
    _store.addListener(_reset);
  }

  final List<AcademicSource> sources;
  final AcademicStore _store;
  final SettingsRepository _settings;
  final EventRepository _repository;
  final EventCommandService _commands;
  final SyncService _sync;
  final DateTime Function() _now;
  Map<String, AcademicSubscription> _subscriptions = {};
  Map<String, AcademicSubscription> get subscriptions =>
      Map.unmodifiable(_subscriptions);
  bool busy = false;
  bool unavailable = false;
  bool _disposed = false;
  bool _storageError = false;
  AcademicResult? result;

  static String categoryId(String universityId) => 'academic_$universityId';

  Future<void> setCategoryColor(String universityId, int colorValue) => _run((
    generation,
  ) async {
    // The colour applies to every imported row of this subscription.
    _requireManageable(universityId);
    bool current() => _isCurrent(generation);
    final change = await _settings.updateCategory(
      categoryId(universityId),
      (current) => current.copyWith(colorValue: colorValue),
      isCurrent: current,
    );
    if (change == null) throw StateError('Academic category is missing');
    final (previous: category, updated: updated) = change;
    try {
      // An account switch after the setting saved cancels propagation, and
      // the setting is rolled back with it.
      _check(generation);
      await _commands.updateCategoryUsage(
        previous: category,
        updated: updated,
        isCurrent: current,
      );
    } on Object {
      // Event rows stay on the old colour when propagation fails; restore only
      // this colour in the latest list so concurrent category edits survive.
      await _settings.updateCategory(
        category.id,
        (current) => current.copyWith(colorValue: category.colorValue),
      );
      rethrow;
    }
    _check(generation);
    await _sync.queueSettingsBackup();
  });

  void _reload() {
    try {
      _subscriptions = _store.load();
      _storageError = false;
    } on Object {
      _storageError = true;
      unavailable = true;
    }
  }

  void _reset() {
    _subscriptions = {};
    result = null;
    unavailable = false;
    _storageError = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Google account active for the running operation.
  String? _operationAccount;

  /// Owner recorded for imports made while no Google account was linked.
  static const localOwner = '';

  String _ownerKey(String? account) => account ?? localOwner;

  /// Whether the current account may refresh, import into or remove this
  /// subscription. Subscriptions without an owner (saved before owners were
  /// recorded) or made while signed out are adopted by an explicit action.
  bool canManage(String universityId) {
    final owner = _subscriptions[universityId]?.owner;
    return owner == null ||
        owner == localOwner ||
        owner == _ownerKey(_account());
  }

  /// Saves subscriptions; on failure, puts [universityId] back to [before]
  /// (absent when null) so memory never runs ahead of storage.
  Future<void> _saveOrRestore(
    int generation,
    String universityId,
    Map<String, dynamic>? before,
  ) async {
    try {
      await _store.save(_subscriptions, generation);
    } on Object {
      if (before == null) {
        _subscriptions.remove(universityId);
      } else {
        _subscriptions[universityId] = AcademicSubscription.fromJson(before);
      }
      rethrow;
    }
  }

  void _requireManageable(String universityId) {
    if (!canManage(universityId)) {
      throw StateError('Academic subscription belongs to another account');
    }
  }

  String? _account() =>
      _settings.dailyAccount()?.googleAccount?.email.trim().toLowerCase();

  /// A reset (store generation) or account switch cancels remaining work, so a
  /// late write never lands in, or uploads for, a different account.
  bool _isCurrent(int generation) =>
      !_disposed &&
      generation == _store.generation &&
      _account() == _operationAccount;

  void _check(int generation) {
    if (!_isCurrent(generation)) {
      throw StateError('Academic operation cancelled');
    }
  }

  Future<T> _run<T>(Future<T> Function(int generation) action) async {
    if (busy || _storageError) {
      throw StateError('Academic operation unavailable');
    }
    busy = true;
    unavailable = false;
    result = null;
    final generation = _store.generation;
    _operationAccount = _account();
    _notify();
    try {
      return await action(generation);
    } on Object {
      if (_isCurrent(generation)) unavailable = true;
      rethrow;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<AcademicPreview> preview(AcademicSource source, int year) =>
      _run((generation) async {
        final events = await source.fetch(year);
        _check(generation);
        if (events.isEmpty) throw const FormatException('No academic records');
        return AcademicPreview(source, year, events, generation, _account());
      });

  Future<void> importSelection(
    AcademicPreview preview,
    Set<String> selected, {
    int? colorValue,
  }) => _run((generation) async {
    if (preview.generation != generation ||
        preview.account != _operationAccount) {
      throw StateError('Stale academic preview');
    }
    if (selected.isEmpty) {
      throw ArgumentError('No academic events selected');
    }
    final source = preview.source;
    // Never take over another account's exclusions and imported events.
    _requireManageable(source.id);
    final before = _subscriptions[source.id]?.toJson();
    final subscription = _subscriptions.putIfAbsent(
      source.id,
      () => AcademicSubscription(universityId: source.id, year: preview.year),
    );
    subscription
      ..enabled = true
      ..owner = _ownerKey(_operationAccount)
      ..year = preview.year
      ..followCurrentYear = preview.year == _now().year
      ..lastAttempt = _now();
    for (final event in preview.events) {
      if (selected.contains(event.sourceId)) {
        subscription.excluded.remove(event.sourceId);
      } else {
        subscription.excluded.add(event.sourceId);
      }
    }
    await _saveOrRestore(generation, source.id, before);
    try {
      result = await _apply(
        source,
        subscription,
        preview.events,
        generation,
        initialColor: colorValue,
      );
    } on Object {
      _check(generation);
      subscription.failed = true;
      await _store.save(_subscriptions, generation);
      rethrow;
    }
  });

  Future<void> refresh(String universityId) => _run((generation) async {
    final source = sources.firstWhere((source) => source.id == universityId);
    final subscription = _subscriptions[universityId]!;
    _requireManageable(universityId);
    final before = subscription.toJson();
    // An explicit refresh adopts an ownerless or signed-out subscription.
    subscription.owner = _ownerKey(_operationAccount);
    subscription.lastAttempt = _now();
    if (subscription.followCurrentYear) subscription.year = _now().year;
    // Unsaved owner, attempt time or year must not throttle or redirect a
    // later refresh in this session.
    await _saveOrRestore(generation, universityId, before);
    try {
      final events = await source.fetch(subscription.year);
      _check(generation);
      result = await _apply(source, subscription, events, generation);
    } on Object {
      _check(generation);
      subscription.failed = true;
      await _store.save(_subscriptions, generation);
      rethrow;
    }
  });

  /// Lifecycle-triggered, no timer/polling; failed attempts are throttled too.
  Future<void> refreshIfDue() async {
    if (busy || _storageError || _disposed) return;
    for (final source in sources) {
      final subscription = _subscriptions[source.id];
      if (subscription == null || !subscription.enabled) continue;
      // Automatic refresh runs only what this account (or, signed out, this
      // device) imported; ownerless legacy entries wait for an explicit
      // refresh, even while signed out.
      final owner = subscription.owner;
      if (owner == null || owner != _ownerKey(_account())) continue;
      final previous = subscription.lastAttempt;
      final now = _now();
      final yearChanged =
          subscription.followCurrentYear && subscription.year != now.year;
      // Once per local calendar day; a future timestamp (clock or zone
      // correction) must not suppress refreshes.
      if (!yearChanged &&
          previous != null &&
          !previous.isAfter(now) &&
          DateUtils.isSameDay(previous, now)) {
        continue;
      }
      try {
        await refresh(source.id);
      } on Object {
        // Keep the calendar usable; settings retain the failure status.
      }
    }
  }

  Future<AcademicResult> _apply(
    AcademicSource source,
    AcademicSubscription subscription,
    List<AcademicEvent> events,
    int generation, {
    int? initialColor,
  }) async {
    _check(generation);
    if (events.isEmpty) throw const FormatException('No academic records');
    final id = categoryId(source.id);
    var category = _settings
        .load()
        .categories
        .where((c) => c.id == id)
        .firstOrNull;
    if (category == null) {
      category = await _settings.ensureCategory(
        EventCategory(
          id: id,
          label: source.name,
          colorValue: initialColor ?? EventCategory.basic.colorValue,
        ),
      );
      _check(generation);
      await _sync.queueSettingsBackup();
    }
    _check(generation);
    final deviceId = await _settings.deviceId();
    _check(generation);
    final now = _now();
    final external = _localIds(source.id, [
      for (final event in events)
        if (!subscription.excluded.contains(event.sourceId)) event,
    ], subscription.baselines);
    final candidates = [
      for (final entry in external.entries)
        CalendarEvent(
          id: entry.key,
          title: entry.value.title,
          startAt: entry.value.start,
          endAt: entry.value.end,
          allDay: true,
          category: category,
          colorValue: category.colorValue,
          url: entry.value.url,
          createdAt: now,
          updatedAt: now,
          deviceId: deviceId,
        ),
    ];
    final newIds = <String>{};
    subscription.managedIds.addAll(external.keys);
    await _store.save(_subscriptions, generation);
    final unchanged = <String>{};
    var preserved = 0;
    // Sync compaction drops deleted rows and keeps only a deletion record.
    // Neither such a record (checked inside each write transaction below) nor
    // a vanished row imported before may be re-imported, or the user's
    // deletion would return and re-upload.
    final importing = <CalendarEvent>[];
    for (final candidate in candidates) {
      if (subscription.baselines.containsKey(candidate.id) &&
          await _repository.findById(candidate.id) == null) {
        preserved++;
        unchanged.add(candidate.id);
      } else {
        importing.add(candidate);
      }
    }
    _check(generation);
    final recordedDeletions = <String>{};
    final saved = await _commands.importBatch(
      importing,
      isCurrent: () => _isCurrent(generation),
      skippedDeleted: recordedDeletions,
      resolveLatest: (local, incoming) {
        _check(generation);
        if (local == null) {
          newIds.add(incoming.id);
          return incoming;
        }
        final baseline = subscription.baselines[incoming.id];
        final remote = external[incoming.id]!;
        // A deleted or locally edited source stays under the user's control.
        // On another device with no baseline, only an exact match is adopted.
        if (local.isDeleted || !_matches(local, baseline ?? remote)) {
          preserved++;
          unchanged.add(incoming.id);
          return null;
        }
        if (_matches(local, remote)) {
          unchanged.add(incoming.id);
          return null;
        }
        // The previous row for this id still exists in the feed under another
        // id: the feed was reordered or shifted, not edited. Moving this row's
        // personal state onto a different date would swap user data.
        if (baseline != null &&
            external.entries.any(
              (entry) =>
                  entry.key != incoming.id &&
                  _sameSource(entry.value, baseline),
            )) {
          preserved++;
          unchanged.add(incoming.id);
          return null;
        }
        return local.copyWith(
          title: incoming.title,
          startAt: incoming.startAt,
          endAt: incoming.endAt,
          url: incoming.url,
        );
      },
    );
    _check(generation);
    preserved += recordedDeletions.length;
    unchanged.addAll(recordedDeletions);
    for (final id in {...saved, ...unchanged}) {
      subscription.baselines[id] = external[id]!;
    }
    final failed = candidates.length - saved.length - unchanged.length;
    subscription.failed = failed > 0;
    if (failed == 0) subscription.lastSuccess = _now();
    await _store.save(_subscriptions, generation);
    return AcademicResult(
      added: saved.intersection(newIds).length,
      updated: saved.difference(newIds).length,
      preserved: preserved,
      failed: failed,
    );
  }

  /// Maps feed events to local event IDs. Occurrence-numbered source IDs
  /// shift when a same-title event is inserted earlier in the year, so an
  /// event identical to an imported baseline keeps that baseline's row first.
  /// The rest use their own ID (so a date correction still updates its row),
  /// or a start-dated ID when that row already represents another event.
  static Map<String, AcademicEvent> _localIds(
    String universityId,
    List<AcademicEvent> events,
    Map<String, AcademicEvent> baselines,
  ) {
    final result = <String, AcademicEvent>{};
    final unmatched = <AcademicEvent>[];
    for (final event in events) {
      final baseline = baselines.entries
          .where(
            (entry) =>
                !result.containsKey(entry.key) &&
                _sameSource(entry.value, event),
          )
          .firstOrNull;
      if (baseline == null) {
        unmatched.add(event);
      } else {
        result[baseline.key] = event;
      }
    }
    for (final event in unmatched) {
      var id = event.dailyId(universityId);
      for (var attempt = 0; result.containsKey(id); attempt++) {
        id = AcademicEvent(
          sourceId:
              '${event.sourceId}@${event.start.toIso8601String()}#$attempt',
          title: event.title,
          start: event.start,
          end: event.end,
          url: event.url,
        ).dailyId(universityId);
      }
      result[id] = event;
    }
    return result;
  }

  static bool _sameSource(AcademicEvent a, AcademicEvent b) =>
      a.title == b.title && a.start == b.start && a.end == b.end;

  static bool _matches(CalendarEvent local, AcademicEvent baseline) =>
      local.title == baseline.title &&
      local.startAt == baseline.start &&
      local.endAt == baseline.end &&
      local.allDay &&
      !local.isRecurring &&
      local.url == baseline.url;

  Future<void> setEnabled(String universityId, bool enabled) =>
      _run((generation) async {
        _requireManageable(universityId);
        final subscription = _subscriptions[universityId]!;
        final before = subscription.toJson();
        subscription.enabled = enabled;
        // Reconnecting an ownerless or signed-out subscription adopts it, so
        // automatic refresh resumes for this account.
        if (enabled) subscription.owner = _ownerKey(_operationAccount);
        // Memory follows storage so refresh never acts on an unsaved change.
        await _saveOrRestore(generation, universityId, before);
      });

  Future<void> removeImported(String universityId) => _run((generation) async {
    // Another account's imported events stay intact and are not tombstoned.
    _requireManageable(universityId);
    final subscription = _subscriptions[universityId]!;
    final before = subscription.toJson();
    // Provenance IDs, not category/title matching: never remove personal events.
    for (final id in subscription.managedIds) {
      _check(generation);
      final local = await _repository.findById(id);
      if (local != null && !local.isDeleted) {
        subscription.pendingRemovals.add(id);
      }
    }
    _check(generation);
    subscription.enabled = false;
    // Recorded first, so a row tombstoned before a failed reminder, alarm or
    // sync follow-up is deleted again (follow-ups included) on retry.
    await _saveOrRestore(generation, universityId, before);
    try {
      for (final id in subscription.pendingRemovals.toList()) {
        _check(generation);
        await _commands.delete(id, isCurrent: () => _isCurrent(generation));
        _check(generation);
        subscription.pendingRemovals.remove(id);
      }
    } finally {
      if (_isCurrent(generation)) {
        try {
          await _store.save(_subscriptions, generation);
        } on Object {
          // Unsaved progress only repeats completed deletions on retry.
        }
      }
    }
  });

  @override
  void dispose() {
    _disposed = true;
    _store.removeListener(_reset);
    for (final source in sources) {
      source.close();
    }
    super.dispose();
  }
}
