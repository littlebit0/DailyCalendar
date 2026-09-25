/// User-selected school, stored in the linked account's Drive settings.
/// Names are retained so profiles remain readable across directory updates.
class AcademicProfile {
  const AcademicProfile({
    required this.universityId,
    required this.universityName,
    required this.schoolKind,
    this.campus,
    this.campusId,
    this.lmsCategoryId,
  });

  final String universityId;
  final String universityName;
  final String schoolKind;
  final String? campus;

  /// New profiles distinguish the institution from its individual campus.
  /// Legacy profiles retain a campus-row ID in universityId until the user edits.
  final String? campusId;

  /// Destination for LMS imports, scoped to this account and school.
  final String? lmsCategoryId;

  AcademicProfile withLmsCategory(String categoryId) => AcademicProfile(
    universityId: universityId,
    universityName: universityName,
    schoolKind: schoolKind,
    campus: campus,
    campusId: campusId,
    lmsCategoryId: categoryId,
  );

  String get selectedCampusId => campusId ?? universityId;

  /// Stable provider identity; integrated campuses share one academic profile.
  String? get timetableUniversity => switch (universityId) {
    'institution:academyinfo:0000117' ||
    'academyinfo:0000117' ||
    'academyinfo:0002959' => 'smu',
    'institution:academyinfo:0000082' ||
    'academyinfo:0000082' ||
    'academyinfo:0002726' => 'dku',
    'institution:academyinfo:0000023' ||
    'academyinfo:0000023' ||
    'academyinfo:0000024' => 'jnu',
    _ => null,
  };

  String? get timetableCampus {
    final allowed = switch (timetableUniversity) {
      'smu' => const ['academyinfo:0000117', 'academyinfo:0002959'],
      'dku' => const ['academyinfo:0000082', 'academyinfo:0002726'],
      'jnu' => const ['academyinfo:0000023', 'academyinfo:0000024'],
      _ => const <String>[],
    };
    if (campusId != null && !allowed.contains(campusId)) return null;
    return switch ((timetableUniversity, selectedCampusId)) {
      ('smu', 'academyinfo:0002959') => 'cheonan',
      ('smu', _) => 'seoul',
      ('dku', 'academyinfo:0002726') => 'cheonan',
      ('dku', _) => 'jukjeon',
      ('jnu', 'academyinfo:0000024') => 'yeosu',
      ('jnu', _) => 'gwangju',
      _ => null,
    };
  }

  String? get academicSourceId =>
      timetableCampus == null ? null : timetableUniversity;
  bool get supported => academicSourceId != null;
  String get displayName => universityName;

  Map<String, Object?> toJson() => {
    'universityId': universityId,
    'universityName': universityName,
    'schoolKind': schoolKind,
    'campus': campus,
    if (campusId != null) 'campusId': campusId,
    if (lmsCategoryId != null) 'lmsCategoryId': lmsCategoryId,
  };

  factory AcademicProfile.fromJson(Map<String, Object?> json) {
    final id = json['universityId'];
    final name = json['universityName'];
    final kind = json['schoolKind'];
    final campus = json['campus'];
    final campusId = json['campusId'];
    final lmsCategoryId = json['lmsCategoryId'];
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        (kind != 'fourYear' &&
            kind != 'juniorCollege' &&
            kind != 'cyberUniversity') ||
        (campus != null && campus is! String) ||
        (lmsCategoryId != null &&
            (lmsCategoryId is! String || lmsCategoryId.isEmpty)) ||
        (campusId != null &&
            (campusId is! String || campusId.trim().isEmpty))) {
      throw const FormatException('Invalid academic profile');
    }
    return AcademicProfile(
      universityId: id,
      universityName: name,
      schoolKind: kind as String,
      campus: campus as String?,
      campusId: campusId as String?,
      lmsCategoryId: lmsCategoryId as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AcademicProfile &&
      universityId == other.universityId &&
      universityName == other.universityName &&
      schoolKind == other.schoolKind &&
      campus == other.campus &&
      campusId == other.campusId &&
      lmsCategoryId == other.lmsCategoryId;
  @override
  int get hashCode => Object.hash(
    universityId,
    universityName,
    schoolKind,
    campus,
    campusId,
    lmsCategoryId,
  );
}
