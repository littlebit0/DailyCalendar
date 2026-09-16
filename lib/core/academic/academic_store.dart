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
    Map<String, AcademicEvent>? baselines,
    Set<String>? managedIds,
    this.lastAttempt,
    this.lastSuccess,
    this.failed = false,
  }) : excluded = excluded ?? {},
       baselines = baselines ?? {},
       managedIds = managedIds ?? {};

  final String universityId;
  int year;
  bool enabled;
  bool followCurrentYear;
  Set<String> excluded;
  final Map<String, AcademicEvent> baselines;
  final Set<String> managedIds;
  DateTime? lastAttempt;
  DateTime? lastSuccess;
  bool failed;

  Map<String, dynamic> toJson() => {
    'universityId': universityId,
    'year': year,
    'enabled': enabled,
    'followCurrentYear': followCurrentYear,
    'excluded': excluded.toList(),
    'baselines': baselines.map((id, event) => MapEntry(id, event.toJson())),
    'managedIds': managedIds.toList(),
    'lastAttempt': lastAttempt?.toIso8601String(),
    'lastSuccess': lastSuccess?.toIso8601String(),
    'failed': failed,
  };

  factory AcademicSubscription.fromJson(Map<String, dynamic> json) =>
      AcademicSubscription(
        universityId: json['universityId'] as String,
        year: json['year'] as int,
        enabled: json['enabled'] == true,
        followCurrentYear: json['followCurrentYear'] == true,
        excluded: (json['excluded'] as List).cast<String>().toSet(),
        managedIds: (json['managedIds'] as List? ?? const [])
            .cast<String>()
            .toSet(),
        baselines: (json['baselines'] as Map<String, dynamic>).map(
          (id, raw) =>
              MapEntry(id, AcademicEvent.fromJson(raw as Map<String, dynamic>)),
        ),
        lastAttempt: DateTime.tryParse(json['lastAttempt'] as String? ?? ''),
        lastSuccess: DateTime.tryParse(json['lastSuccess'] as String? ?? ''),
        failed: json['failed'] == true,
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
    await _preferences.remove(key);
  }
}
