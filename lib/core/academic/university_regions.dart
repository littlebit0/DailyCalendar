import 'dart:convert';

import 'package:flutter/services.dart';

class UniversityRegion {
  UniversityRegion(Map<String, dynamic> json)
    : id = json['id'] as String,
      name = json['name'] as String,
      anchor = _point(json['anchor'] as List),
      institutionIds = Set.unmodifiable(
        (json['institutionIds'] as List).cast<String>(),
      ),
      rings = _rings(json['rings'] as List);

  final String id;
  final String name;
  final Offset anchor;
  final Set<String> institutionIds;
  final List<List<Offset>> rings;
}

Offset _point(List point) =>
    Offset((point[0] as num).toDouble(), (point[1] as num).toDouble());
List<List<Offset>> _rings(List rings) => List.unmodifiable([
  for (final ring in rings)
    List<Offset>.unmodifiable([
      for (final point in ring as List) _point(point as List),
    ]),
]);

/// Offline sourced campus membership, separate from persisted academic identity.
class UniversityRegions {
  UniversityRegions.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Invalid region directory');
    }
    regions = List.unmodifiable([
      for (final row in json['regions'] as List)
        UniversityRegion(Map<String, dynamic>.from(row as Map)),
    ]);
    final northCities = Set<String>.from(
      (json['classificationPolicy'] as Map?)?['gyeonggiNorthCities'] as List? ??
          const [],
    );
    campusRegionIds = Map.unmodifiable({
      for (final entry in (json['campusLocations'] as Map? ?? const {}).entries)
        entry.key as String: Set<String>.unmodifiable([
          for (final location in entry.value as List)
            _locationRegionId(location as Map, northCities),
        ]),
    });
    institutionCaptions = Map.unmodifiable(
      Map<String, String>.from(json['institutionCaptions'] as Map? ?? {}),
    );
    logoUnavailableInstitutionIds = Set.unmodifiable(
      (json['logoUnavailableInstitutionIds'] as List? ?? const [])
          .cast<String>(),
    );
    logoForegroundColors = Map.unmodifiable(
      Map<String, int>.from(json['logoForegroundColors'] as Map? ?? {}),
    );
    outlines = _rings(json['outlines'] as List);
    islands = Map.unmodifiable({
      for (final entry in (json['islands'] as Map).entries)
        entry.key as String: _rings(entry.value as List),
    });
  }

  late final Map<String, Set<String>> campusRegionIds;

  bool includesCampus(String campusId, String regionId) =>
      campusRegionIds[campusId]?.contains(regionId) ?? false;

  static String _locationRegionId(Map location, Set<String> northCities) {
    final province = location['province'] as String;
    final city = location['city'] as String;
    if (province == '경기') {
      return northCities.contains(city) ? '경기북부' : '경기남부';
    }
    if (province == '충남' && (city == '천안시' || city == '아산시')) {
      return '천안아산';
    }
    return province;
  }

  late final Map<String, int> logoForegroundColors;
  late final Set<String> logoUnavailableInstitutionIds;
  late final Map<String, String> institutionCaptions;
  String? captionFor(String institutionId) =>
      institutionCaptions[institutionId];

  late final List<UniversityRegion> regions;
  late final List<List<Offset>> outlines;
  late final Map<String, List<List<Offset>>> islands;

  UniversityRegion? byId(String? id) {
    for (final region in regions) {
      if (region.id == id) return region;
    }
    return null;
  }

  bool includes(String institutionId, String? regionId) =>
      regionId == null ||
      (byId(regionId)?.institutionIds.contains(institutionId) ?? false);

  List<String> namesFor(String institutionId) => [
    for (final region in regions)
      if (region.institutionIds.contains(institutionId)) region.name,
  ];

  static Future<UniversityRegions> load({AssetBundle? bundle}) async =>
      UniversityRegions.fromJson(
        jsonDecode(
              await (bundle ?? rootBundle).loadString(
                'assets/academic/university_regions.json',
              ),
            )
            as Map<String, dynamic>,
      );
}
