import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'academic_source.dart';

class AcademicSubscription {
  AcademicSubscription({
    required this.universityId,
    required this.year,
    this.enabled = true,
    this.followCurrentYear = false,
    Set<String>? excluded,
    List<AcademicEvent>? excludedEvents,
    Map<String, AcademicEvent>? baselines,
    Set<String>? managedIds,
    Set<String>? pendingRemovals,
    this.lastAttempt,
    this.lastSuccess,
    this.failed = false,
    this.owner,
  }) : excluded = excluded ?? {},
       excludedEvents = excludedEvents ?? [],
       baselines = baselines ?? {},
       managedIds = managedIds ?? {},
       pendingRemovals = pendingRemovals ?? {};

  final String universityId;
  int year;
  bool enabled;
  bool followCurrentYear;

  /// Source IDs the user left out. Entries without a matching
  /// [excludedEvents] snapshot come from versions that stored IDs only.
  Set<String> excluded;

  /// What each excluded event was, so the exclusion follows the same event
  /// when occurrence-numbered source IDs shift.
  List<AcademicEvent> excludedEvents;
  final Map<String, AcademicEvent> baselines;
  final Set<String> managedIds;

  /// Imported events whose removal started but did not finish, including its
  /// reminder, alarm and sync follow-ups. Retried on the next removal.
  final Set<String> pendingRemovals;
  DateTime? lastAttempt;
  DateTime? lastSuccess;
  bool failed;

  /// Normalized Google account that imported it; null before accounts were
  /// recorded or when no account was linked.
  String? owner;

  Map<String, dynamic> toJson() => {
    'universityId': universityId,
    'year': year,
    'enabled': enabled,
    'followCurrentYear': followCurrentYear,
    'excluded': excluded.toList(),
    if (excludedEvents.isNotEmpty)
      'excludedEvents': [for (final event in excludedEvents) event.toJson()],
    'baselines': baselines.map((id, event) => MapEntry(id, event.toJson())),
    'managedIds': managedIds.toList(),
    if (pendingRemovals.isNotEmpty) 'pendingRemovals': pendingRemovals.toList(),
    'lastAttempt': lastAttempt?.toIso8601String(),
    'lastSuccess': lastSuccess?.toIso8601String(),
    'failed': failed,
    if (owner != null) 'owner': owner,
  };

  factory AcademicSubscription.fromJson(Map<String, dynamic> json) =>
      AcademicSubscription(
        universityId: json['universityId'] as String,
        year: json['year'] as int,
        enabled: json['enabled'] == true,
        followCurrentYear: json['followCurrentYear'] == true,
        excluded: (json['excluded'] as List).cast<String>().toSet(),
        excludedEvents: [
          for (final raw in json['excludedEvents'] as List? ?? const [])
            AcademicEvent.fromJson(raw as Map<String, dynamic>),
        ],
        managedIds: (json['managedIds'] as List? ?? const [])
            .cast<String>()
            .toSet(),
        pendingRemovals: (json['pendingRemovals'] as List? ?? const [])
            .cast<String>()
            .toSet(),
        baselines: (json['baselines'] as Map<String, dynamic>).map(
          (id, raw) =>
              MapEntry(id, AcademicEvent.fromJson(raw as Map<String, dynamic>)),
        ),
        lastAttempt: DateTime.tryParse(json['lastAttempt'] as String? ?? ''),
        lastSuccess: DateTime.tryParse(json['lastSuccess'] as String? ?? ''),
        failed: json['failed'] == true,
        owner: json['owner'] as String?,
      );
}

class AcademicStore extends ChangeNotifier {
  AcademicStore(this._preferences);
  final SharedPreferences _preferences;
  static const key = 'academic.subscriptions.v1';
  int generation = 0;

  Map<String, AcademicSubscription> load() {
    final raw = _preferences.getString(key);
    if (raw == null) return {};
    // Corruption must not silently discard provenance and enable a fresh import.
    return (jsonDecode(raw) as Map<String, dynamic>).map(
      (id, value) => MapEntry(
        id,
        AcademicSubscription.fromJson(value as Map<String, dynamic>),
      ),
    );
  }

  Future<void> save(
    Map<String, AcademicSubscription> subscriptions,
    int expectedGeneration,
  ) async {
    if (generation != expectedGeneration) {
      throw StateError('Academic operation cancelled');
    }
    if (!await _preferences.setString(
      key,
      jsonEncode(
        subscriptions.map((id, value) => MapEntry(id, value.toJson())),
      ),
    )) {
      throw StateError('Academic settings write failed');
    }
  }

  void invalidate() {
    generation++;
    notifyListeners();
  }

  Future<void> clear() async {
    invalidate();
    if (!await _preferences.remove(key)) {
      // A reset must not look complete while subscriptions would reload.
      throw StateError('Academic settings clear failed');
    }
  }
}
