import 'academic_source.dart';
import 'gachon_academic_source.dart';

/// Links a university calendar adapter to the academyinfo campuses it serves.
class AcademicSourceRegistration {
  const AcademicSourceRegistration({
    required this.id,
    required this.institutionId,
    required this.campusIds,
    required this.create,
    this.primary = true,
  });

  /// Stable subscription and category key; never reuse it for another school.
  final String id;

  /// academyinfo ID of the institution's main record, e.g. `academyinfo:0000117`.
  final String institutionId;

  /// academyinfo campus IDs whose calendar this adapter publishes.
  final Set<String> campusIds;

  /// Used when a profile names only the institution and no campus.
  final bool primary;
  final AcademicSource Function() create;
}

/// One entry per supported university calendar, in Korean name order.
const academicSourceRegistrations = <AcademicSourceRegistration>[
  AcademicSourceRegistration(
    id: 'gachon',
    institutionId: 'academyinfo:0000063',
    campusIds: {'academyinfo:0000063'},
    create: GachonAcademicSource.new,
  ),
];

/// The adapter for a saved school, or null when its calendar is unsupported.
String? academicSourceIdFor(
  String universityId,
  String? campusId, {
  List<AcademicSourceRegistration> registrations = academicSourceRegistrations,
}) {
  // Legacy profiles stored a campus ID directly as the university.
  final campus =
      campusId ??
      (universityId.startsWith('academyinfo:') ? universityId : null);
  for (final registration in registrations) {
    final institution = registration.institutionId;
    if (campus == null) {
      if (registration.primary && universityId == 'institution:$institution') {
        return registration.id;
      }
      continue;
    }
    final sameSchool =
        universityId == 'institution:$institution' ||
        universityId == institution ||
        registration.campusIds.contains(universityId);
    if (sameSchool && registration.campusIds.contains(campus)) {
      return registration.id;
    }
  }
  return null;
}
