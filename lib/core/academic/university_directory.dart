import 'dart:convert';

import 'package:flutter/services.dart';

/// Retained source groups; the picker currently offers four-year schools only.
enum UniversityKind { fourYear, juniorCollege, cyberUniversity }

class University {
  const University({
    required this.id,
    required this.name,
    required this.kind,
    this.campus,
    this.region,
    this.sourceSchoolId,
    this.sourceKind,
    String? institutionId,
    String? institutionName,
    this.aliases = const [],
    this.campusOrder = 0,
    this.selectable = true,
    this.campusSelectionRequired = false,
    this.campusNames = const [],
  }) : _institutionId = institutionId,
       _institutionName = institutionName;

  final String id;
  final String name;
  final UniversityKind kind;
  final String? campus;
  final String? region;
  final String? sourceSchoolId;
  final String? sourceKind;
  final String? _institutionId;
  final String? _institutionName;
  final List<String> aliases;
  final int campusOrder;
  final bool selectable;
  final bool campusSelectionRequired;
  final List<String> campusNames;

  /// Explicit source-reviewed membership; names are never stripped or merged
  /// at runtime. The fallback keeps legacy fixtures and standalone rows unique.
  String get institutionId => _institutionId ?? 'institution:$id';
  String get institutionName => _institutionName ?? name;

  /// Integration support is assigned to a stable school ID, never a name
  /// substring or an untrusted profile's claim of support.
  String? get integrationId => switch (id) {
    'academyinfo:0000117' => 'smu/seoul',
    'academyinfo:0002959' => 'smu/cheonan',
    _ => null,
  };

  bool get supportsSangmyung => integrationId != null;

  bool get supportsAcademicFeatures => const {
    'institution:academyinfo:0000117',
    'institution:academyinfo:0000082',
    'institution:academyinfo:0000023',
  }.contains(institutionId);

  String get displayName => campus == null || institutionName.contains(campus!)
      ? institutionName
      : '$institutionName $campus';

  bool matchesQuery(String query) {
    final tokens = query.trim().split(RegExp(r'\s+'));
    final fields = [
      name,
      institutionName,
      campus ?? '',
      region ?? '',
      displayName,
      ...aliases,
      ...campusNames,
    ];
    return tokens.every(
      (token) => fields.any((field) => matchesUniversityQuery(field, token)),
    );
  }
}

/// One selectable university, with its sourced campus records retained below it.
class UniversityInstitution {
  UniversityInstitution({
    required this.id,
    required this.name,
    required this.kind,
    required List<University> campuses,
  }) : campuses = List.unmodifiable(campuses);

  final String id;
  final String name;
  final UniversityKind kind;
  final List<University> campuses;

  bool get selectable =>
      kind == UniversityKind.fourYear &&
      campuses.any((campus) => campus.selectable);
  bool get campusSelectionRequired => campuses.first.campusSelectionRequired;
  bool get supportsAcademicFeatures =>
      campuses.any((campus) => campus.supportsAcademicFeatures);

  /// Official campus names only. Generic disclosure labels such as 본교 do not
  /// claim a physical campus name and are not replaced with a region name.
  List<String> get campusNames => [
    ...{
      for (final campus in campuses)
        if (campus.campusNames.isNotEmpty)
          ...campus.campusNames
        else if (campus.campus != null &&
            !RegExp(r'^(본교|분교|제\d캠퍼스)$').hasMatch(campus.campus!))
          campus.campus!,
    },
  ];

  String get campusSummary => campusNames
      .map((name) => name.replaceFirst(RegExp(r'\s*캠퍼스$'), ''))
      .join(' / ');

  bool matchesQuery(String query) =>
      campuses.any((campus) => campus.matchesQuery(query));
}

class UniversityDirectory {
  UniversityDirectory._({
    required List<University> universities,
    required this.checkedAt,
    required this.dataYear,
  }) : universities = List.unmodifiable(universities),
       _byId = Map.unmodifiable({
         for (final school in universities) school.id: school,
       }) {
    final grouped = <String, List<University>>{};
    for (final campus in universities) {
      (grouped[campus.institutionId] ??= []).add(campus);
    }
    institutions = List.unmodifiable(
      grouped.entries.map((entry) {
        entry.value.sort((a, b) {
          final order = a.campusOrder.compareTo(b.campusOrder);
          return order != 0 ? order : a.id.compareTo(b.id);
        });
        final first = entry.value.first;
        if (entry.value.any(
          (campus) =>
              campus.institutionName != first.institutionName ||
              campus.kind != first.kind ||
              campus.campusSelectionRequired != first.campusSelectionRequired,
        )) {
          throw const FormatException('Conflicting university membership');
        }
        return UniversityInstitution(
          id: entry.key,
          name: first.institutionName,
          kind: first.kind,
          campuses: entry.value,
        );
      }).toList()..sort((a, b) {
        final nameOrder = a.name.compareTo(b.name);
        return nameOrder != 0 ? nameOrder : a.id.compareTo(b.id);
      }),
    );
    _institutionsById = Map.unmodifiable({
      for (final institution in institutions) institution.id: institution,
    });
  }

  final List<University> universities;
  final String checkedAt;
  final int dataYear;
  final Map<String, University> _byId;
  late final List<UniversityInstitution> institutions;
  late final Map<String, UniversityInstitution> _institutionsById;

  University? byId(String id) => _byId[id];

  UniversityInstitution? institutionById(String id) => _institutionsById[id];

  UniversityInstitution? institutionForCampus(String campusId) =>
      _institutionsById[_byId[campusId]?.institutionId];

  List<UniversityInstitution> searchInstitutions(
    String query, {
    UniversityKind? kind,
    bool includeUnselectable = false,
  }) => [
    for (final institution in institutions)
      if ((includeUnselectable || institution.selectable) &&
          (kind == null || institution.kind == kind) &&
          institution.matchesQuery(query))
        institution,
  ];

  List<University> search(String query, {UniversityKind? kind}) => [
    for (final school in universities)
      if ((kind == null || school.kind == kind) && school.matchesQuery(query))
        school,
  ];

  static Future<UniversityDirectory> load({AssetBundle? bundle}) async =>
      UniversityDirectory.fromJson(
        jsonDecode(
              await (bundle ?? rootBundle).loadString(
                'assets/academic/universities.json',
              ),
            )
            as Map<String, dynamic>,
      );

  factory UniversityDirectory.fromJson(Map<String, dynamic> json) {
    if ((json['schemaVersion'] != 1 && json['schemaVersion'] != 2) ||
        json['dataYear'] is! int ||
        json['checkedAt'] is! String ||
        json['universities'] is! List) {
      throw const FormatException('Invalid university directory');
    }
    final rows = json['universities'] as List;
    if (json['rowCount'] != rows.length || rows.isEmpty) {
      throw const FormatException('Incomplete university directory');
    }
    final schools = <University>[];
    final ids = <String>{};
    for (final row in rows) {
      if (row is! Map ||
          row['id'] is! String ||
          (row['id'] as String).trim().isEmpty ||
          row['name'] is! String ||
          (row['name'] as String).trim().isEmpty ||
          !UniversityKind.values.any((kind) => kind.name == row['kind'])) {
        throw const FormatException('Invalid university entry');
      }
      for (final field in [
        'campus',
        'region',
        'sourceSchoolId',
        'sourceKind',
        'institutionId',
        'institutionName',
      ]) {
        if (row[field] != null && row[field] is! String) {
          throw const FormatException('Invalid university metadata');
        }
      }
      if (json['schemaVersion'] == 2 &&
          (row['institutionId'] is! String ||
              !(row['institutionId'] as String).startsWith('institution:') ||
              row['institutionName'] is! String ||
              (row['institutionName'] as String).trim().isEmpty)) {
        throw const FormatException('Missing university membership');
      }
      if (row['aliases'] != null &&
          (row['aliases'] is! List ||
              (row['aliases'] as List).any((alias) => alias is! String))) {
        throw const FormatException('Invalid university search aliases');
      }
      for (final field in ['selectable', 'campusSelectionRequired']) {
        if (row[field] != null && row[field] is! bool) {
          throw const FormatException('Invalid university selection metadata');
        }
      }
      if (row['campusNames'] != null &&
          (row['campusNames'] is! List ||
              (row['campusNames'] as List).any(
                (name) => name is! String || name.trim().isEmpty,
              ))) {
        throw const FormatException('Invalid official campus names');
      }
      if (row['campusOrder'] != null &&
          (row['campusOrder'] is! int || (row['campusOrder'] as int) < 0)) {
        throw const FormatException('Invalid university campus order');
      }
      final id = row['id'] as String;
      if (!ids.add(id)) {
        throw const FormatException('Duplicate university ID');
      }
      final school = University(
        id: id,
        name: row['name'] as String,
        kind: UniversityKind.values.byName(row['kind'] as String),
        campus: row['campus'] as String?,
        region: row['region'] as String?,
        sourceSchoolId: row['sourceSchoolId'] as String?,
        sourceKind: row['sourceKind'] as String?,
        institutionId: row['institutionId'] as String?,
        institutionName: row['institutionName'] as String?,
        aliases: List.unmodifiable(
          (row['aliases'] as List? ?? const []).cast<String>(),
        ),
        campusOrder: row['campusOrder'] as int? ?? 0,
        selectable: row['selectable'] as bool? ?? true,
        campusSelectionRequired:
            row['campusSelectionRequired'] as bool? ?? false,
        campusNames: List.unmodifiable(
          (row['campusNames'] as List? ?? const []).cast<String>(),
        ),
      );
      if (row['integrationId'] != null &&
          row['integrationId'] != school.integrationId) {
        throw const FormatException('Invalid university integration');
      }
      schools.add(school);
    }
    schools.sort((a, b) {
      final nameOrder = a.name.compareTo(b.name);
      if (nameOrder != 0) return nameOrder;
      final campusOrder = (a.campus ?? '').compareTo(b.campus ?? '');
      return campusOrder != 0 ? campusOrder : a.id.compareTo(b.id);
    });
    final directory = UniversityDirectory._(
      universities: schools,
      checkedAt: json['checkedAt'] as String,
      dataYear: json['dataYear'] as int,
    );
    if (json['schemaVersion'] == 2 &&
        json['institutionCount'] != directory.institutions.length) {
      throw const FormatException('Incomplete university memberships');
    }
    return directory;
  }
}

const _hangulInitials = [
  'ㄱ',
  'ㄲ',
  'ㄴ',
  'ㄷ',
  'ㄸ',
  'ㄹ',
  'ㅁ',
  'ㅂ',
  'ㅃ',
  'ㅅ',
  'ㅆ',
  'ㅇ',
  'ㅈ',
  'ㅉ',
  'ㅊ',
  'ㅋ',
  'ㅌ',
  'ㅍ',
  'ㅎ',
];

String _initialFor(int rune) {
  if (rune >= 0xac00 && rune <= 0xd7a3) {
    return _hangulInitials[(rune - 0xac00) ~/ 588];
  }
  if (rune >= 0x1100 && rune <= 0x1112) {
    return _hangulInitials[rune - 0x1100];
  }
  return String.fromCharCode(rune);
}

String hangulInitials(String value) => value.runes.map(_initialFor).join();

String _compact(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[\s\-·ㆍ.,()\[\]{}_/]+'), '');

/// Supports full text, initial-only text (ㅅㅁㄷ), and mixed text (ㅅ명대).
/// A Hangul syllable in the query remains exact, so 상 does not match 서.
bool matchesUniversityQuery(String value, String query) {
  final target = _compact(value).runes.toList();
  final needle = _compact(query).runes.toList();
  if (needle.isEmpty) return true;
  for (var offset = 0; offset + needle.length <= target.length; offset++) {
    var matches = true;
    for (var i = 0; i < needle.length; i++) {
      final letter = String.fromCharCode(needle[i]);
      final isInitial =
          _hangulInitials.contains(letter) ||
          (needle[i] >= 0x1100 && needle[i] <= 0x1112);
      if (isInitial
          ? _initialFor(target[offset + i]) != _initialFor(needle[i])
          : target[offset + i] != needle[i]) {
        matches = false;
        break;
      }
    }
    if (matches) return true;
  }
  return false;
}
