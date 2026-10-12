/// An opening unit or official department query association published by the
/// school. A college ancestor does not imply it directly runs the course.
class CourseOrganization {
  const CourseOrganization({
    required this.college,
    required this.department,
    required this.sourceLabel,
    this.group,
    this.affiliationUnconfirmed = false,
  });

  factory CourseOrganization.fromJson(Map<String, dynamic> json) {
    final college = json['college'] as String?;
    final department = json['department'] as String?;
    final sourceLabel = json['sourceLabel'] as String? ?? '';
    if ((college == null && department == null) ||
        college?.trim().isEmpty == true ||
        department?.trim().isEmpty == true ||
        (json['group'] as String?)?.trim().isEmpty == true) {
      throw const FormatException('Invalid published opening organization');
    }
    return CourseOrganization(
      college: college,
      department: department,
      sourceLabel: sourceLabel,
      group: json['group'] as String?,
      affiliationUnconfirmed:
          json['affiliationStatus'] == 'unresolvedNameGroup',
    );
  }

  final String? college;
  final String? department;

  /// Original classification key, independent of the display/organization name.
  final String sourceLabel;

  /// Official university-direct parent, or an explicitly named program family.
  /// This display group is not a college or evidence of direct course ownership.
  final String? group;
  final bool affiliationUnconfirmed;
  String? get displayGroup => college ?? group;
  bool get isCollegeHosted => college != null && department == null;
  String get key => '${college ?? ''}\u0000${department ?? ''}';
  String get label => department ?? college!;
}
