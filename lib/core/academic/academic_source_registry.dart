import 'academic_source.dart';
import 'gachon_academic_source.dart';
import 'gnu_academic_source.dart';
import 'khu_academic_source.dart';
import 'knu_academic_source.dart';
import 'konkuk_academic_source.dart';
import 'kyonggi_academic_source.dart';

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
  AcademicSourceRegistration(
    id: 'gnu',
    institutionId: 'academyinfo:0000007',
    campusIds: {'academyinfo:0000007'},
    create: GnuAcademicSource.new,
  ),
  AcademicSourceRegistration(
    id: 'knu',
    institutionId: 'academyinfo:0000005',
    campusIds: {'academyinfo:0000005'},
    create: KnuAcademicSource.new,
  ),
  AcademicSourceRegistration(
    id: 'kyonggi',
    institutionId: 'academyinfo:0000056',
    campusIds: {'academyinfo:0000056', 'academyinfo:0000058'},
    create: KyonggiAcademicSource.new,
  ),
  AcademicSourceRegistration(
    id: 'konkuk',
    institutionId: 'academyinfo:0000052',
    campusIds: {'academyinfo:0000052'},
    create: KonkukAcademicSource.new,
  ),
  AcademicSourceRegistration(
    id: 'konkuk-glocal',
    institutionId: 'academyinfo:0000052',
    campusIds: {'academyinfo:0000053'},
    create: KonkukAcademicSource.glocal,
    primary: false,
  ),
  AcademicSourceRegistration(
    id: 'khu',
    institutionId: 'academyinfo:0000066',
    campusIds: {'academyinfo:0000066'},
    create: KhuAcademicSource.new,
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
