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
  const AcademicPreview(this.source, this.year, this.events, this.generation);
  final AcademicSource source;
  final int year;
  final List<AcademicEvent> events;
  final int generation;
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
    final before = _settings.load();
    final category = before.categories
        .where((c) => c.id == categoryId(universityId))
        .firstOrNull;
    if (category == null) throw StateError('Academic category is missing');
    final updated = category.copyWith(colorValue: colorValue);
    await _settings.save(
      before.copyWith(
        categories: [
          for (final c in before.categories) c.id == category.id ? updated : c,
        ],
      ),
      changedFrom: before,
    );
    _check(generation);
    await _commands.updateCategoryUsage(previous: category, updated: updated);
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

  void _check(int generation) {
    if (_disposed || generation != _store.generation) {
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
    _notify();
    try {
      return await action(generation);
    } on Object {
      if (generation == _store.generation) unavailable = true;
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
        return AcademicPreview(source, year, events, generation);
      });

  Future<void> importSelection(
    AcademicPreview preview,
    Set<String> selected, {
    int? colorValue,
  }) => _run((generation) async {
    if (preview.generation != generation) {
      throw StateError('Stale academic preview');
    }
    if (selected.isEmpty) {
      throw ArgumentError('No academic events selected');
    }
    final source = preview.source;
    final subscription = _subscriptions.putIfAbsent(
      source.id,
      () => AcademicSubscription(universityId: source.id, year: preview.year),
    );
    subscription
      ..enabled = true
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
    await _store.save(_subscriptions, generation);
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
    await _refresh(source, subscription, generation);
  });

  Future<void> _refresh(
    AcademicSource source,
    AcademicSubscription subscription,
    int generation,
  ) async {
    subscription.lastAttempt = _now();
    if (subscription.followCurrentYear) subscription.year = _now().year;
    await _store.save(_subscriptions, generation);
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
  }

  /// Lifecycle-triggered, no timer/polling; failed attempts are throttled too.
  Future<void> refreshIfDue() async {
    if (busy || _storageError || _disposed) return;
    for (final source in sources) {
      final subscription = _subscriptions[source.id];
      if (subscription == null || !subscription.enabled) continue;
      final previous = subscription.lastAttempt;
      final yearChanged =
          subscription.followCurrentYear && subscription.year != _now().year;
      if (!yearChanged &&
          previous != null &&
          _now().difference(previous) < const Duration(days: 1)) {
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
    final settings = _settings.load();
    final id = categoryId(source.id);
    final category =
        settings.categories.where((c) => c.id == id).firstOrNull ??
        EventCategory(
          id: id,
          label: source.name,
          colorValue: initialColor ?? EventCategory.basic.colorValue,
        );
    if (!settings.categories.any((c) => c.id == id)) {
      await _settings.save(
        settings.copyWith(categories: [...settings.categories, category]),
        changedFrom: settings,
      );
      _check(generation);
      await _sync.queueSettingsBackup();
    }
    _check(generation);
    final deviceId = await _settings.deviceId();
    _check(generation);
    final now = _now();
    final external = {
      for (final event in events)
        if (!subscription.excluded.contains(event.sourceId))
          event.dailyId(source.id): event,
    };
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
    final saved = await _commands.importBatch(
      candidates,
      isCurrent: () => !_disposed && generation == _store.generation,
      prepare: (incoming) async {
        _check(generation);
        final local = await _repository.findById(incoming.id);
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
        return local.copyWith(
          title: incoming.title,
          startAt: incoming.startAt,
          endAt: incoming.endAt,
          url: incoming.url,
        );
      },
    );
    _check(generation);
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

  static bool _matches(CalendarEvent local, AcademicEvent baseline) =>
      local.title == baseline.title &&
      local.startAt == baseline.start &&
      local.endAt == baseline.end &&
      local.allDay &&
      !local.isRecurring &&
      local.url == baseline.url;

  Future<void> setEnabled(String universityId, bool enabled) =>
      _run((generation) async {
        _subscriptions[universityId]!.enabled = enabled;
        await _store.save(_subscriptions, generation);
      });

  Future<void> removeImported(String universityId) => _run((generation) async {
    final subscription = _subscriptions[universityId]!;
    subscription.enabled = false;
    await _store.save(_subscriptions, generation);
    // Provenance IDs, not category/title matching: never remove personal events.
    for (final id in subscription.managedIds) {
      _check(generation);
      final local = await _repository.findById(id);
      _check(generation);
      if (local != null && !local.isDeleted) await _commands.delete(id);
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
