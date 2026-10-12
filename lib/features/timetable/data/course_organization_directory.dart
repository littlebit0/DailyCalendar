import '../domain/course_organization.dart';

/// The user includes both published opening departments and official curriculum
/// query associations. College-only filtering still requires a direct opening
/// unit; a college query/ancestor cannot make its child courses college-hosted.
class CourseOrganizationDirectory {
  CourseOrganizationDirectory.fromJson(Map<String, dynamic> json)
    : university = json['university'] as String,
      _mappings = List<Map<String, dynamic>>.from(
        (json['mappings'] as List).map(
          (row) => Map<String, dynamic>.from(row as Map),
        ),
      ),
      _owners = Map<String, List<Map<String, dynamic>>>.fromEntries([
        for (final row in json['courseOwners'] as List)
          MapEntry((row as Map)['sourceId'] as String, [
            for (final unit in row['units'] as List)
              Map<String, dynamic>.from(unit as Map),
          ]),
      ]) {
    if (json['schemaVersion'] != 1 || university.trim().isEmpty) {
      throw const FormatException('Invalid course organization directory');
    }
    if (_owners.length != (json['courseOwners'] as List).length ||
        _owners.values.any(
          (units) =>
              units.isEmpty ||
              units
                      .map((unit) => CourseOrganization.fromJson(unit).key)
                      .toSet()
                      .length !=
                  units.length,
        )) {
      throw const FormatException('Conflicting course opening units');
    }
    for (final unit in [
      ..._mappings,
      ..._owners.values.expand((units) => units),
    ]) {
      CourseOrganization.fromJson(unit);
      if (unit.containsKey('officialGroups')) {
        final groups = unit['officialGroups'];
        if (groups is! List ||
            unit['department'] == null ||
            groups.isEmpty ||
            groups.any((g) => g is! String || g.trim().isEmpty) ||
            groups.toSet().length != groups.length) {
          throw const FormatException('Invalid official program groups');
        }
      }
      final source = Uri.tryParse(unit['sourceUrl'] as String? ?? '');
      if (source == null ||
          !['https', 'http'].contains(source.scheme) ||
          source.host.isEmpty ||
          (unit['evidence'] as String? ?? '').trim().isEmpty) {
        throw const FormatException('Missing organization source evidence');
      }
    }
    for (final mapping in _mappings) {
      (_byLabel[mapping['sourceLabel'] as String] ??= []).add(mapping);
    }
  }

  final String university;
  final List<Map<String, dynamic>> _mappings;
  final Map<String, List<Map<String, dynamic>>> _owners;
  final _byLabel = <String, List<Map<String, dynamic>>>{};

  bool _isSelectableUnit(Map<String, dynamic> unit) =>
      unit['department'] != null ||
      (unit['isOfferingUnit'] == true && unit['collegeOnlyEligible'] != false);

  Map<String, dynamic> apply(Map<String, dynamic> course) {
    final explicit = _owners[course['sourceId']];
    final units = <Map<String, dynamic>>[
      for (final unit in explicit ?? <Map<String, dynamic>>[])
        if (_isSelectableUnit(unit))
          for (final label in {
            unit['sourceLabel'] as String? ?? '',
            ...List<String>.from(unit['sourceLabels'] as List? ?? const []),
          })
            {...unit, 'sourceLabel': label},
      for (final label in course['departments'] as List)
        for (final mapping in _byLabel[label] ?? <Map<String, dynamic>>[])
          if (_isSelectableUnit(mapping) &&
              (mapping['campus'] == '*' ||
                  mapping['campus'] == course['campus']))
            mapping,
    ];
    final unique = <String, Map<String, dynamic>>{};
    for (final unit in units) {
      final groups = List<String>.from(
        unit['officialGroups'] as List? ?? const [],
      );
      // A university can publish the same degree under its regular college
      // and an additional official system. Preserve the degree affiliation;
      // extra display routes do not create another course or college owner.
      final routes = <Map<String, dynamic>>[
        if (groups.isEmpty || unit['college'] != null || unit['group'] != null)
          unit,
        for (final group in groups) {...unit, 'college': null, 'group': group},
      ];
      for (final expanded in routes) {
        final organization = CourseOrganization.fromJson(expanded);
        unique['${organization.key}\u0000${organization.displayGroup}\u0000${unit['sourceLabel']}'] =
            expanded;
      }
    }
    return {...course, 'offeringOrganizations': unique.values.toList()};
  }
}
