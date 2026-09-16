import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'calendar_event.dart';

String normalizePlace(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');

class FrequentPlaces {
  FrequentPlaces(this.preferences);
  final SharedPreferences preferences;
  static const key = 'frequentPlaces.v1';
  Map<String, dynamic> get _data {
    try {
      return jsonDecode(preferences.getString(key) ?? '{}')
          as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  List<String> get pinned => List<String>.from(_data['pinned'] ?? []);
  List<String> get hidden => List<String>.from(_data['hidden'] ?? []);
  bool get automatic => _data['automatic'] != false;

  Future<void> update({
    List<String>? pinned,
    List<String>? hidden,
    bool? automatic,
  }) async {
    final data = _data;
    if (pinned != null) {
      data['pinned'] = pinned
          .map(normalizePlace)
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
    }
    if (hidden != null) data['hidden'] = hidden;
    if (automatic != null) data['automatic'] = automatic;
    if (!await preferences.setString(key, jsonEncode(data))) {
      throw StateError('Could not save places');
    }
  }

  Future<void> clear() async {
    await preferences.remove(key);
  }

  List<String> recommend(Iterable<CalendarEvent> events, {int limit = 8}) {
    final counts = <String, int>{};
    final recent = <String, DateTime>{};
    final seen = <String>{};
    if (automatic) {
      for (final event in events) {
        final place = normalizePlace(event.location ?? '');
        if (event.isDeleted ||
            place.isEmpty ||
            !seen.add(event.id) ||
            hidden.contains(place)) {
          continue;
        }
        counts.update(place, (value) => value + 1, ifAbsent: () => 1);
        if (recent[place] == null || event.updatedAt.isAfter(recent[place]!)) {
          recent[place] = event.updatedAt;
        }
      }
    }
    final ranked = counts.keys.toList()
      ..sort((a, b) {
        final count = counts[b]!.compareTo(counts[a]!);
        if (count != 0) return count;
        final date = recent[b]!.compareTo(recent[a]!);
        return date == 0 ? a.compareTo(b) : date;
      });
    return {...pinned, ...ranked}.take(limit).toList();
  }
}
