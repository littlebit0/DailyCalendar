import 'academic_source.dart';
import 'bu_academic_source.dart';
import 'catholic_academic_source.dart';
import 'changwon_academic_source.dart';
import 'daegu_academic_source.dart';
import 'deu_academic_source.dart';
import 'dju_academic_source.dart';
import 'dku_academic_source.dart';
import 'donga_academic_source.dart';
import 'dongguk_academic_source.dart';
import 'gachon_academic_source.dart';
import 'geochang_academic_source.dart';
import 'gknu_academic_source.dart';
import 'gnu_academic_source.dart';
import 'hanbat_academic_source.dart';
import 'kangwon_academic_source.dart';
import 'khu_academic_source.dart';
import 'kmu_academic_source.dart';
import 'knu_academic_source.dart';
import 'kongju_academic_source.dart';
import 'konkuk_academic_source.dart';
import 'konyang_academic_source.dart';
import 'kookmin_academic_source.dart';
import 'korea_academic_source.dart';
import 'kunsan_academic_source.dart';
import 'kwangwoon_academic_source.dart';
import 'kyonggi_academic_source.dart';
import 'mju_academic_source.dart';
import 'mokpo_academic_source.dart';
import 'namhae_academic_source.dart';
import 'nsu_academic_source.dart';
import 'pcu_academic_source.dart';
import 'pknu_academic_source.dart';
import 'pnu_academic_source.dart';
import 'smu_academic_source.dart';
import 'sunchon_academic_source.dart';
import 'ut_academic_source.dart';

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
  AcademicSourceRegistration(
    id: 'catholic',
    institutionId: 'academyinfo:0000046',
    campusIds: {
      'academyinfo:0000046',
      'academyinfo:0000048',
      'academyinfo:0000049',
    },
    create: CatholicAcademicSource.new,
  ),
  AcademicSourceRegistration(
    id: 'konyang',
    institutionId: 'academyinfo:0000054',
    campusIds: {'academyinfo:0000054', 'academyinfo:0000055'},
    create: KonyangAcademicSource.new,
  ),
  AcademicSourceRegistration(
    id: 'kangwon',
    institutionId: 'academyinfo:0000003',
    // Every campus shares one calendar that merges both campus boards.
    campusIds: {
      'academyinfo:0000003',
      'academyinfo:0000004',
      'academyinfo:0003363',
      'academyinfo:0003364',
    },
    create: KangwonAcademicSource.new,
  ),
  AcademicSourceRegistration(
    id: 'kongju',
    institutionId: 'academyinfo:0000008',
    campusIds: {'academyinfo:0000008'},
    create: KongjuAcademicSource.new,
  ),
  AcademicSourceRegistration(
    id: 'kwangwoon',
    institutionId: 'academyinfo:0000074',
    campusIds: {'academyinfo:0000074'},
    create: KwangwoonAcademicSource.new,
  ),
  AcademicSourceRegistration(
    id: 'gknu',
    institutionId: 'academyinfo:0000021',
    campusIds: {'academyinfo:0000021'},
    create: GknuAcademicSource.new,
  ),
  AcademicSourceRegistration(
    id: 'kunsan',
    institutionId: 'academyinfo:0000009',
    campusIds: {'academyinfo:0000009'},
    create: KunsanAcademicSource.new,
  ),
  AcademicSourceRegistration(
    id: 'korea',
    institutionId: 'academyinfo:0000069',
    campusIds: {'academyinfo:0000069', 'academyinfo:0000070'},
    create: KoreaAcademicSource.new,
  ),
  AcademicSourceRegistration(
    id: 'mokpo',
    institutionId: 'academyinfo:0000011',
    campusIds: {'academyinfo:0000011', 'academyinfo:0003312'},
    create: MokpoAcademicSource.new,
  ),
  AcademicSourceRegistration(
    id: 'pknu',
    institutionId: 'academyinfo:0000013',
    campusIds: {'academyinfo:0000013'},
    create: PknuAcademicSource.new,
  ),
  AcademicSourceRegistration(
    id: 'kmu',
    institutionId: 'academyinfo:0000068',
    campusIds: {'academyinfo:0000068'},
    create: KmuAcademicSource.new,
  ),
  AcademicSourceRegistration(
    id: 'sunchon',
    institutionId: 'academyinfo:0000020',
    campusIds: {'academyinfo:0000020'},
    create: SunchonAcademicSource.new,
  ),
  AcademicSourceRegistration(
    id: 'ut',
    institutionId: 'academyinfo:0000034',
    campusIds: {'academyinfo:0000034'},
    create: UtAcademicSource.new,
  ),
  AcademicSourceRegistration(
    id: 'hanbat',
    institutionId: 'academyinfo:0000039',
    campusIds: {'academyinfo:0000039'},
    create: HanbatAcademicSource.new,
  ),
  AcademicSourceRegistration(
    id: 'kookmin',
    institutionId: 'academyinfo:0000078',
    campusIds: {'academyinfo:0000078'},
    create: KookminAcademicSource.new,
  ),
  AcademicSourceRegistration(
    id: 'dku',
    institutionId: 'academyinfo:0000082',
    campusIds: {'academyinfo:0000082', 'academyinfo:0002726'},
    create: DankookAcademicSource.new,
  ),
  AcademicSourceRegistration(
    id: 'daegu',
    institutionId: 'academyinfo:0000084',
    campusIds: {'academyinfo:0000084'},
    create: DaeguAcademicSource.new,
  ),
  AcademicSourceRegistration(
    id: 'dju',
    institutionId: 'academyinfo:0000095',
    campusIds: {'academyinfo:0000095'},
    create: DjuAcademicSource.new,
  ),
  AcademicSourceRegistration(
    id: 'changwon',
    institutionId: 'academyinfo:0000028',
    campusIds: {'academyinfo:0000028'},
    create: ChangwonAcademicSource.new,
  ),
  AcademicSourceRegistration(
    id: 'changwon-geochang',
    institutionId: 'academyinfo:0000028',
    campusIds: {'academyinfo:0003297'},
    create: GeochangAcademicSource.new,
    primary: false,
  ),
  AcademicSourceRegistration(
    id: 'changwon-namhae',
    institutionId: 'academyinfo:0000028',
    campusIds: {'academyinfo:0003298'},
    create: NamhaeAcademicSource.new,
    primary: false,
  ),
  AcademicSourceRegistration(
    id: 'nsu',
    institutionId: 'academyinfo:0000245',
    campusIds: {'academyinfo:0000245'},
    create: NsuAcademicSource.new,
  ),
  AcademicSourceRegistration(
    id: 'dongguk-seoul',
    institutionId: 'academyinfo:0000100',
    campusIds: {'academyinfo:0000100'},
    create: DonggukAcademicSource.new,
  ),
  AcademicSourceRegistration(
    id: 'dongguk-wise',
    institutionId: 'academyinfo:0000100',
    campusIds: {'academyinfo:0000101'},
    create: DonggukAcademicSource.wiseCampus,
    primary: false,
  ),
  AcademicSourceRegistration(
    id: 'bu',
    institutionId: 'academyinfo:0000178',
    campusIds: {'academyinfo:0000178'},
    create: BuAcademicSource.new,
  ),
  AcademicSourceRegistration(
    id: 'pcu',
    institutionId: 'academyinfo:0000113',
    campusIds: {'academyinfo:0000113'},
    create: PcuAcademicSource.new,
  ),
  AcademicSourceRegistration(
    id: 'donga',
    institutionId: 'academyinfo:0000105',
    campusIds: {'academyinfo:0000105'},
    create: DongaAcademicSource.new,
  ),
  AcademicSourceRegistration(
    id: 'pnu',
    institutionId: 'academyinfo:0000014',
    campusIds: {'academyinfo:0000014'},
    create: PnuAcademicSource.new,
  ),
  AcademicSourceRegistration(
    id: 'deu',
    institutionId: 'academyinfo:0000107',
    campusIds: {'academyinfo:0000107'},
    create: DeuAcademicSource.new,
  ),
  AcademicSourceRegistration(
    id: 'smu',
    institutionId: 'academyinfo:0000117',
    campusIds: {'academyinfo:0000117', 'academyinfo:0002959'},
    create: SangmyungAcademicSource.new,
  ),
  AcademicSourceRegistration(
    id: 'mju',
    institutionId: 'academyinfo:0000109',
    campusIds: {'academyinfo:0000109', 'academyinfo:0000111'},
    create: MjuAcademicSource.new,
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
