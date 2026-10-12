import 'university_support_policy.dart';

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
    this.lmsUserId,
    this.lmsIntegrationEnabled,
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

  /// Non-secret LMS identity and connection preference, synced with the owner.
  /// Cookies and authentication material remain exclusively in secure storage.
  final String? lmsUserId;
  final bool? lmsIntegrationEnabled;

  AcademicProfile withLmsConnection({String? userId, required bool enabled}) =>
      AcademicProfile(
        universityId: universityId,
        universityName: universityName,
        schoolKind: schoolKind,
        campus: campus,
        campusId: campusId,
        lmsCategoryId: lmsCategoryId,
        lmsUserId: userId ?? lmsUserId,
        lmsIntegrationEnabled: enabled,
      );

  AcademicProfile withLmsCategory(String categoryId) => AcademicProfile(
    universityId: universityId,
    universityName: universityName,
    schoolKind: schoolKind,
    campus: campus,
    campusId: campusId,
    lmsCategoryId: categoryId,
    lmsUserId: lmsUserId,
    lmsIntegrationEnabled: lmsIntegrationEnabled,
  );

  String get selectedCampusId => campusId ?? universityId;

  /// Stable provider identity; integrated campuses share one academic profile.
  String? get timetableUniversity => switch (universityId) {
    'institution:academyinfo:0000164' ||
    'academyinfo:0000164' ||
    'academyinfo:0000166' => 'inje',
    'institution:academyinfo:0000212' ||
    'academyinfo:0000212' ||
    'academyinfo:0002949' => 'hongik',
    'institution:academyinfo:0000240' || 'academyinfo:0000240' => 'wsu',
    'institution:academyinfo:0000129' || 'academyinfo:0000129' => 'sunmoon',
    'institution:academyinfo:0000168' ||
    'academyinfo:0000168' ||
    'academyinfo:0000167' => 'iccu',
    'institution:academyinfo:0000163' || 'academyinfo:0000163' => 'ewha',
    'institution:academyinfo:0000161' ||
    'academyinfo:0000161' ||
    'academyinfo:0000162' ||
    'academyinfo:0002911' => 'eulji',
    'institution:academyinfo:0000201' || 'academyinfo:0000201' => 'hansei',
    'institution:academyinfo:0000207' || 'academyinfo:0000207' => 'hyupsung',
    'institution:academyinfo:0000131' || 'academyinfo:0000131' => 'sungkyul',
    'institution:academyinfo:0000119' || 'academyinfo:0000119' => 'sangji',
    'institution:academyinfo:0000216' || 'academyinfo:0000216' => 'nambu',
    'institution:academyinfo:0000051' || 'academyinfo:0000051' => 'kangnam',
    'institution:academyinfo:0000113' || 'academyinfo:0000113' => 'pcu',
    'institution:academyinfo:0000261' || 'academyinfo:0000261' => 'cje',
    'institution:academyinfo:0000052' || 'academyinfo:0000052' => 'konkuk',
    'institution:academyinfo:0000250' || 'academyinfo:0000250' => 'unist',
    'institution:academyinfo:0000211' || 'academyinfo:0000211' => 'hoseo',
    'institution:academyinfo:0000172' || 'academyinfo:0000172' => 'chosun',
    'institution:academyinfo:0000140' || 'academyinfo:0000140' => 'suwon',
    'institution:academyinfo:0000203' ||
    'academyinfo:0000203' ||
    'academyinfo:0000204' => 'hanyang',
    'institution:academyinfo:0000141' || 'academyinfo:0000141' => 'sookmyung',
    'institution:academyinfo:0000034' || 'academyinfo:0000034' => 'ut',
    'institution:academyinfo:0000245' || 'academyinfo:0000245' => 'nsu',
    'institution:academyinfo:0000254' || 'academyinfo:0000254' => 'bnue',
    'institution:academyinfo:0000374' || 'academyinfo:0000374' => 'kaist',
    'institution:academyinfo:0000253' || 'academyinfo:0000253' => 'dnue',
    'institution:academyinfo:0000100' || 'academyinfo:0000100' => 'dongguk',
    'institution:academyinfo:0000033' || 'academyinfo:0000033' => 'kmou',
    'institution:academyinfo:0000151' || 'academyinfo:0000151' => 'yu',

    'institution:academyinfo:0000069' ||
    'academyinfo:0000069' ||
    'academyinfo:0000070' => 'korea',
    'institution:academyinfo:0000258' || 'academyinfo:0000258' => 'jnue',
    'institution:academyinfo:0000256' ||
    'academyinfo:0000256' ||
    'academyinfo:0000257' => 'ginue',
    'institution:academyinfo:0000251' || 'academyinfo:0000251' => 'gjue',
    'institution:academyinfo:0000252' || 'academyinfo:0000252' => 'gnue',
    'institution:academyinfo:0000136' || 'academyinfo:0000136' => 'sungshin',

    'institution:academyinfo:0000012' || 'academyinfo:0000012' => 'mmu',
    'institution:academyinfo:0000194' || 'academyinfo:0000194' => 'kau',
    'institution:academyinfo:0000025' || 'academyinfo:0000025' => 'jbnu',

    'institution:academyinfo:0000109' ||
    'academyinfo:0000109' ||
    'academyinfo:0000111' => 'mju',
    'institution:academyinfo:0000121' || 'academyinfo:0000121' => 'sku',
    'institution:academyinfo:0000116' || 'academyinfo:0000116' => 'syu',
    'institution:academyinfo:0000105' || 'academyinfo:0000105' => 'donga',
    'institution:academyinfo:0000149' ||
    'academyinfo:0000149' ||
    'academyinfo:0000150' => 'yonsei',

    'institution:academyinfo:0000158' || 'academyinfo:0000158' => 'ulsan',
    'institution:academyinfo:0000020' || 'academyinfo:0000020' => 'scnu',
    'institution:academyinfo:0000010' || 'academyinfo:0000010' => 'kumoh',
    'institution:academyinfo:0002660' || 'academyinfo:0002660' => 'inu',
    'institution:academyinfo:0000027' || 'academyinfo:0000027' => 'jeju',
    'institution:academyinfo:0000013' || 'academyinfo:0000013' => 'pknu',
    'institution:academyinfo:0000039' || 'academyinfo:0000039' => 'hanbat',
    'institution:academyinfo:0000189' || 'academyinfo:0000189' => 'koreatech',
    'institution:academyinfo:0000030' || 'academyinfo:0000030' => 'cbnu',
    'institution:academyinfo:0000084' || 'academyinfo:0000084' => 'daegu',
    'institution:academyinfo:0000008' || 'academyinfo:0000008' => 'kongju',
    'institution:academyinfo:0000028' || 'academyinfo:0000028' => 'changwon',
    'institution:academyinfo:0000021' || 'academyinfo:0000021' => 'gknu',
    'institution:academyinfo:0000143' || 'academyinfo:0000143' => 'ssu',
    'institution:academyinfo:0000126' || 'academyinfo:0000126' => 'swu',
    'institution:academyinfo:0000007' || 'academyinfo:0000007' => 'gnu',
    'institution:academyinfo:0000247' || 'academyinfo:0000247' => 'tuk',
    'institution:academyinfo:0000031' || 'academyinfo:0000031' => 'knue',
    'institution:academyinfo:0000009' || 'academyinfo:0000009' => 'kunsan',
    'institution:academyinfo:0000037' || 'academyinfo:0000037' => 'hknu',
    'institution:academyinfo:0000066' || 'academyinfo:0000066' => 'khu',
    'institution:academyinfo:0000056' || 'academyinfo:0000056' => 'kyonggi',
    'institution:academyinfo:0000188' || 'academyinfo:0000188' => 'postech',
    'institution:academyinfo:0000381' || 'academyinfo:0000381' => 'gist',
    'institution:academyinfo:0000178' || 'academyinfo:0000178' => 'baekseok',
    'institution:academyinfo:0000382' || 'academyinfo:0000382' => 'dgist',
    'institution:academyinfo:0000063' || 'academyinfo:0000063' => 'gachon',
    'institution:academyinfo:0000046' ||
    'academyinfo:0000046' ||
    'academyinfo:0000048' ||
    'academyinfo:0000049' => 'catholic',
    'institution:academyinfo:0000120' || 'academyinfo:0000120' => 'sogang',
    'institution:academyinfo:0000142' || 'academyinfo:0000142' => 'sch',
    'institution:academyinfo:0000029' || 'academyinfo:0000029' => 'cnu',
    'institution:academyinfo:0000133' || 'academyinfo:0000133' => 'skku',
    'institution:academyinfo:0000074' || 'academyinfo:0000074' => 'kwangwoon',
    'institution:academyinfo:0000011' ||
    'academyinfo:0000011' ||
    'academyinfo:0003312' => 'mokpo',
    'institution:academyinfo:0000192' || 'academyinfo:0000192' => 'hufs',
    'institution:academyinfo:0000200' || 'academyinfo:0000200' => 'hansung',
    'institution:academyinfo:0000036' || 'academyinfo:0000036' => 'seoultech',
    'institution:academyinfo:0000040' || 'academyinfo:0000040' => 'uos',
    'institution:academyinfo:0000003' ||
    'academyinfo:0000003' ||
    'academyinfo:0000004' ||
    'academyinfo:0003363' ||
    'academyinfo:0003364' => 'kangwon',
    'institution:academyinfo:0000005' || 'academyinfo:0000005' => 'knu',
    'institution:academyinfo:0000078' || 'academyinfo:0000078' => 'kookmin',
    'institution:academyinfo:0000068' || 'academyinfo:0000068' => 'kmu',
    'institution:academyinfo:0000156' || 'academyinfo:0000156' => 'yongin',
    'institution:academyinfo:0000138' || 'academyinfo:0000138' => 'sejong',
    'institution:academyinfo:0000014' || 'academyinfo:0000014' => 'pnu',
    'institution:academyinfo:0000169' || 'academyinfo:0000169' => 'inha',
    'institution:academyinfo:0000175' ||
    'academyinfo:0000175' ||
    'academyinfo:0000174' => 'cau',
    'institution:academyinfo:0000019' || 'academyinfo:0000019' => 'snu',
    'institution:academyinfo:0000146' || 'academyinfo:0000146' => 'ajou',
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
      'inje' => const ['academyinfo:0000164', 'academyinfo:0000166'],
      'hongik' => const ['academyinfo:0000212', 'academyinfo:0002949'],
      'wsu' => const ['academyinfo:0000240'],
      'sunmoon' => const ['academyinfo:0000129'],
      'iccu' => const ['academyinfo:0000168', 'academyinfo:0000167'],
      'ewha' => const ['academyinfo:0000163'],
      'eulji' => const [
        'academyinfo:0000161',
        'academyinfo:0000162',
        'academyinfo:0002911',
      ],
      'hansei' => const ['academyinfo:0000201'],
      'hyupsung' => const ['academyinfo:0000207'],
      'sungkyul' => const ['academyinfo:0000131'],
      'sangji' => const ['academyinfo:0000119'],
      'nambu' => const ['academyinfo:0000216'],
      'kangnam' => const ['academyinfo:0000051'],
      'pcu' => const ['academyinfo:0000113'],
      'cje' => const ['academyinfo:0000261'],
      'konkuk' => const ['academyinfo:0000052'],
      'unist' => const ['academyinfo:0000250'],
      'hoseo' => const ['academyinfo:0000211'],
      'chosun' => const ['academyinfo:0000172'],
      'suwon' => const ['academyinfo:0000140'],
      'hanyang' => const ['academyinfo:0000203', 'academyinfo:0000204'],
      'sookmyung' => const ['academyinfo:0000141'],
      'ut' => const ['academyinfo:0000034'],
      'nsu' => const ['academyinfo:0000245'],
      'bnue' => const ['academyinfo:0000254'],
      'kaist' => const ['academyinfo:0000374'],
      'dnue' => const ['academyinfo:0000253'],
      'dongguk' => const ['academyinfo:0000100'],
      'kmou' => const ['academyinfo:0000033'],
      'yu' => const ['academyinfo:0000151'],

      'korea' => const ['academyinfo:0000069', 'academyinfo:0000070'],
      'jnue' => const ['academyinfo:0000258'],
      'ginue' => const ['academyinfo:0000256', 'academyinfo:0000257'],
      'gjue' => const ['academyinfo:0000251'],
      'gnue' => const ['academyinfo:0000252'],
      'sungshin' => const ['academyinfo:0000136'],

      'mmu' => const ['academyinfo:0000012'],
      'kau' => const ['academyinfo:0000194'],
      'jbnu' => const ['academyinfo:0000025'],

      'mju' => const ['academyinfo:0000109', 'academyinfo:0000111'],
      'sku' => const ['academyinfo:0000121'],
      'syu' => const ['academyinfo:0000116'],
      'donga' => const ['academyinfo:0000105'],
      'yonsei' => const ['academyinfo:0000149', 'academyinfo:0000150'],

      'ulsan' => const ['academyinfo:0000158'],
      'scnu' => const ['academyinfo:0000020'],
      'kumoh' => const ['academyinfo:0000010'],
      'inu' => const ['academyinfo:0002660'],
      'jeju' => const ['academyinfo:0000027'],
      'pknu' => const ['academyinfo:0000013'],
      'hanbat' => const ['academyinfo:0000039'],
      'koreatech' => const ['academyinfo:0000189'],
      'cbnu' => const ['academyinfo:0000030'],
      'daegu' => const ['academyinfo:0000084'],
      'kongju' => const ['academyinfo:0000008'],
      'changwon' => const ['academyinfo:0000028'],
      'gknu' => const ['academyinfo:0000021'],
      'ssu' => const ['academyinfo:0000143'],
      'swu' => const ['academyinfo:0000126'],
      'gnu' => const ['academyinfo:0000007'],
      'tuk' => const ['academyinfo:0000247'],
      'knue' => const ['academyinfo:0000031'],
      'kunsan' => const ['academyinfo:0000009'],
      'hknu' => const ['academyinfo:0000037'],
      'khu' => const ['academyinfo:0000066'],
      'kyonggi' => const ['academyinfo:0000056'],
      'postech' => const ['academyinfo:0000188'],
      'gist' => const ['academyinfo:0000381'],
      'baekseok' => const ['academyinfo:0000178'],
      'dgist' => const ['academyinfo:0000382'],
      'gachon' => const ['academyinfo:0000063'],
      'catholic' => const [
        'academyinfo:0000046',
        'academyinfo:0000048',
        'academyinfo:0000049',
      ],
      'sogang' => const ['academyinfo:0000120'],
      'sch' => const ['academyinfo:0000142'],
      'cnu' => const ['academyinfo:0000029'],
      'skku' => const ['academyinfo:0000133'],
      'kwangwoon' => const ['academyinfo:0000074'],
      'mokpo' => const ['academyinfo:0000011', 'academyinfo:0003312'],
      'hufs' => const ['academyinfo:0000192'],
      'hansung' => const ['academyinfo:0000200'],
      'seoultech' => const ['academyinfo:0000036'],
      'uos' => const ['academyinfo:0000040'],
      'kangwon' => const [
        'academyinfo:0000003',
        'academyinfo:0000004',
        'academyinfo:0003363',
        'academyinfo:0003364',
      ],
      'knu' => const ['academyinfo:0000005'],
      'kookmin' => const ['academyinfo:0000078'],
      'kmu' => const ['academyinfo:0000068'],
      'yongin' => const ['academyinfo:0000156'],
      'sejong' => const ['academyinfo:0000138'],
      'cau' => const ['academyinfo:0000175', 'academyinfo:0000174'],
      'snu' => const ['academyinfo:0000019'],
      'ajou' => const ['academyinfo:0000146'],
      'inha' => const ['academyinfo:0000169'],
      'pnu' => const ['academyinfo:0000014'],
      'smu' => const ['academyinfo:0000117', 'academyinfo:0002959'],
      'dku' => const ['academyinfo:0000082', 'academyinfo:0002726'],
      'jnu' => const ['academyinfo:0000023', 'academyinfo:0000024'],
      _ => const <String>[],
    };
    if (campusId != null && !allowed.contains(campusId)) return null;
    return switch ((timetableUniversity, selectedCampusId)) {
      ('inje', 'academyinfo:0000166') => null,
      ('inje', _) => 'gimhae',
      ('hongik', 'academyinfo:0002949') => 'sejong',
      ('hongik', _) => 'seoul',
      ('wsu', _) => 'unknown',
      ('sunmoon', _) => 'unknown',
      ('iccu', 'academyinfo:0000168') => null,
      ('iccu', _) => 'songdo',
      ('ewha', _) => 'unknown',
      ('eulji', 'academyinfo:0000161') => null,
      ('eulji', 'academyinfo:0002911') => 'uijeongbu',
      ('eulji', _) => 'seongnam',
      ('hansei', _) => 'main',
      ('hyupsung', _) => 'main',
      ('sungkyul', _) => 'main',
      ('sangji', _) => 'main',
      ('nambu', _) => 'main',
      ('kangnam', _) => 'main',
      ('pcu', _) => 'main',
      ('cje', _) => 'unknown',
      ('konkuk', _) => 'unknown',
      ('unist', _) => 'unknown',
      ('hoseo' || 'chosun' || 'suwon', _) => 'unknown',
      ('hanyang', 'academyinfo:0000204') => 'erica',
      ('hanyang', _) => 'seoul',
      ('sookmyung', _) => 'first',
      ('ut', _) => 'unknown',
      ('nsu', _) => 'unknown',
      ('bnue', _) => 'unknown',
      ('kaist', _) => 'main',
      ('dnue', _) => 'unknown',
      ('dongguk', _) => 'seoul',
      ('kmou' || 'yu', _) => 'unknown',

      ('korea', _) => 'sejong',
      ('jnue' || 'gjue' || 'gnue', _) => 'unknown',
      ('ginue', 'academyinfo:0000257') => 'gyeonggi',
      ('ginue', _) => 'incheon',
      ('sungshin', _) => 'sujeong',

      ('mmu', _) => 'unknown',
      ('kau', _) => 'main',
      ('jbnu', _) => 'unknown',

      ('mju', 'academyinfo:0000111') => 'natural',
      ('mju', _) => 'humanities',
      ('sku', _) => 'unknown',
      ('syu', _) => 'main',
      ('donga', _) => 'seunghak',
      ('yonsei', 'academyinfo:0000150') => 'mirae',
      ('yonsei', _) => 'sinchon',

      ('ulsan', _) => 'main',
      ('scnu', _) => 'unknown',
      ('kumoh', _) => 'yangho',
      ('inu', _) => 'unknown',
      ('jeju', _) => 'unknown',
      ('pknu', _) => 'unknown',
      ('hanbat', _) => 'daejeon',
      ('koreatech', _) => 'unknown',
      ('cbnu', _) => 'main',
      ('daegu', _) => 'main',
      ('kongju', _) => 'cheonan',
      ('changwon', _) => 'unknown',
      ('gknu', _) => 'unknown',
      ('ssu', _) => 'main',
      ('swu', _) => 'main',
      ('gnu', _) => 'gajwa',
      ('tuk', _) => 'first',
      ('knue', _) => 'main',
      ('kunsan', _) => 'unknown',
      ('hknu', _) => 'anseong',
      ('khu', _) => 'seoul',
      ('kyonggi', _) => 'suwon',
      ('postech', _) => 'main',
      ('gist', _) => 'main',
      ('baekseok', _) => 'unknown',
      ('dgist', _) => 'unknown',
      ('gachon', _) => 'global',
      ('catholic', _) => 'songsim',
      ('sogang', _) => 'unknown',
      ('sch', _) => 'unknown',
      ('cnu', _) => 'unknown',
      ('skku', _) => 'humanities',
      ('kwangwoon', _) => 'unknown',
      ('mokpo', 'academyinfo:0003312') => 'damyang',
      ('mokpo', _) => 'dorim',
      ('hufs', _) => 'seoul',
      ('hansung', _) => 'main',
      ('seoultech', _) => 'main',
      ('uos', _) => 'main',
      ('kangwon', 'academyinfo:0000004') => 'samcheok',
      ('kangwon', 'academyinfo:0003363') => 'gangneung',
      ('kangwon', 'academyinfo:0003364') => 'wonju',
      ('kangwon', _) => 'chuncheon',
      ('knu', _) => 'daegu',
      ('kookmin', _) => 'main',
      ('kmu', _) => 'seongseo',
      ('yongin', _) => 'main',
      ('pnu', _) => 'busan',
      ('cau', 'academyinfo:0000174') => 'davinci',
      ('cau', _) => 'seoul',
      ('snu', _) || ('ajou', _) || ('inha', _) || ('sejong', _) => 'main',
      ('smu', 'academyinfo:0002959') => 'cheonan',
      ('smu', _) => 'seoul',
      ('dku', 'academyinfo:0002726') => 'cheonan',
      ('dku', _) => 'jukjeon',
      ('jnu', 'academyinfo:0000024') => 'yeosu',
      ('jnu', _) => 'gwangju',
      _ => null,
    };
  }

  String? get academicSourceId => switch (universityId) {
    'institution:academyinfo:0000161' ||
    'academyinfo:0000161' ||
    'academyinfo:0000162' ||
    'academyinfo:0002911' =>
      campusId == null ||
              const [
                'academyinfo:0000161',
                'academyinfo:0000162',
                'academyinfo:0002911',
              ].contains(campusId)
          ? 'eulji'
          : null,
    'institution:academyinfo:0000168' ||
    'academyinfo:0000168' ||
    'academyinfo:0000167' =>
      campusId == null ||
              const [
                'academyinfo:0000168',
                'academyinfo:0000167',
              ].contains(campusId)
          ? 'iccu'
          : null,
    'institution:academyinfo:0000164' ||
    'academyinfo:0000164' ||
    'academyinfo:0000166' =>
      campusId == null ||
              const [
                'academyinfo:0000164',
                'academyinfo:0000166',
              ].contains(campusId)
          ? 'inje'
          : null,
    'institution:academyinfo:0000212' ||
    'academyinfo:0000212' ||
    'academyinfo:0002949' =>
      campusId == null ||
              const [
                'academyinfo:0000212',
                'academyinfo:0002949',
              ].contains(campusId)
          ? 'hongik'
          : null,
    'institution:academyinfo:0000240' || 'academyinfo:0000240' =>
      campusId == null || const ['academyinfo:0000240'].contains(campusId)
          ? 'wsu'
          : null,
    'institution:academyinfo:0000163' || 'academyinfo:0000163' =>
      campusId == null || const ['academyinfo:0000163'].contains(campusId)
          ? 'ewha'
          : null,
    'institution:academyinfo:0003139' || 'academyinfo:0003139' =>
      campusId == null || const ['academyinfo:0003139'].contains(campusId)
          ? 'kentech'
          : null,
    'institution:academyinfo:0000201' || 'academyinfo:0000201' =>
      campusId == null || const ['academyinfo:0000201'].contains(campusId)
          ? 'hansei'
          : null,
    'institution:academyinfo:0000207' || 'academyinfo:0000207' =>
      campusId == null || const ['academyinfo:0000207'].contains(campusId)
          ? 'hyupsung'
          : null,
    'institution:academyinfo:0000131' || 'academyinfo:0000131' =>
      campusId == null || const ['academyinfo:0000131'].contains(campusId)
          ? 'sungkyul'
          : null,
    'institution:academyinfo:0000129' || 'academyinfo:0000129' =>
      campusId == null || const ['academyinfo:0000129'].contains(campusId)
          ? 'sunmoon'
          : null,
    'institution:academyinfo:0000119' || 'academyinfo:0000119' =>
      campusId == null || const ['academyinfo:0000119'].contains(campusId)
          ? 'sangji'
          : null,
    'institution:academyinfo:0000216' || 'academyinfo:0000216' =>
      campusId == null || const ['academyinfo:0000216'].contains(campusId)
          ? 'nambu'
          : null,
    'institution:academyinfo:0000051' || 'academyinfo:0000051' =>
      campusId == null || const ['academyinfo:0000051'].contains(campusId)
          ? 'kangnam'
          : null,
    'institution:academyinfo:0000054' ||
    'academyinfo:0000054' ||
    'academyinfo:0000055' =>
      campusId == null ||
              const [
                'academyinfo:0000054',
                'academyinfo:0000055',
              ].contains(campusId)
          ? 'konyang'
          : null,
    'institution:academyinfo:0000095' || 'academyinfo:0000095' =>
      campusId == null || const ['academyinfo:0000095'].contains(campusId)
          ? 'dju'
          : null,
    'institution:academyinfo:0000113' || 'academyinfo:0000113' =>
      campusId == null || const ['academyinfo:0000113'].contains(campusId)
          ? 'pcu'
          : null,
    'institution:academyinfo:0000033' || 'academyinfo:0000033' =>
      campusId == null || campusId == 'academyinfo:0000033' ? 'kmou' : null,
    'institution:academyinfo:0000211' || 'academyinfo:0000211' =>
      campusId == null || campusId == 'academyinfo:0000211' ? 'hoseo' : null,
    'institution:academyinfo:0000105' || 'academyinfo:0000105' =>
      campusId == null || campusId == 'academyinfo:0000105' ? 'donga' : null,
    'institution:academyinfo:0000036' || 'academyinfo:0000036' =>
      campusId == null || campusId == 'academyinfo:0000036'
          ? 'seoultech'
          : null,
    'academyinfo:0000053' => 'konkuk-glocal',
    'institution:academyinfo:0000052' || 'academyinfo:0000052' =>
      campusId == 'academyinfo:0000053'
          ? 'konkuk-glocal'
          : campusId == null || campusId == 'academyinfo:0000052'
          ? 'konkuk'
          : null,
    'institution:academyinfo:0000258' || 'academyinfo:0000258' =>
      campusId == null || campusId == 'academyinfo:0000258' ? 'jnue' : null,
    'institution:academyinfo:0000382' || 'academyinfo:0000382' =>
      campusId == null || campusId == 'academyinfo:0000382' ? 'dgist' : null,
    'institution:academyinfo:0000013' || 'academyinfo:0000013' =>
      campusId == null || campusId == 'academyinfo:0000013' ? 'pknu' : null,
    'institution:academyinfo:0000172' || 'academyinfo:0000172' =>
      campusId == null || campusId == 'academyinfo:0000172' ? 'chosun' : null,
    'institution:academyinfo:0000252' || 'academyinfo:0000252' =>
      campusId == null || campusId == 'academyinfo:0000252' ? 'gnue' : null,
    'institution:academyinfo:0000247' || 'academyinfo:0000247' =>
      campusId == null || campusId == 'academyinfo:0000247' ? 'tuk' : null,
    'institution:academyinfo:0000203' ||
    'academyinfo:0000203' ||
    'academyinfo:0000204' =>
      selectedCampusId == 'academyinfo:0000204'
          ? 'hanyang-erica'
          : campusId == null || campusId == 'academyinfo:0000203'
          ? 'hanyang'
          : null,
    'institution:academyinfo:0000069' ||
    'academyinfo:0000069' ||
    'academyinfo:0000070' =>
      campusId == null ||
              {'academyinfo:0000069', 'academyinfo:0000070'}.contains(campusId)
          ? 'korea'
          : null,
    'institution:academyinfo:0000149' ||
    'academyinfo:0000149' ||
    'academyinfo:0000150' =>
      campusId == null ||
              {'academyinfo:0000149', 'academyinfo:0000150'}.contains(campusId)
          ? 'yonsei'
          : null,
    'institution:academyinfo:0000063' || 'academyinfo:0000063' =>
      campusId == null || campusId == 'academyinfo:0000063' ? 'gachon' : null,
    'institution:academyinfo:0000121' || 'academyinfo:0000121' =>
      campusId == null || campusId == 'academyinfo:0000121' ? 'sku' : null,
    'institution:academyinfo:0000056' || 'academyinfo:0000056' =>
      campusId == null ||
              {'academyinfo:0000056', 'academyinfo:0000058'}.contains(campusId)
          ? 'kyonggi'
          : null,
    'institution:academyinfo:0000260' || 'academyinfo:0000260' =>
      campusId == null || campusId == 'academyinfo:0000260' ? 'cue' : null,
    'institution:academyinfo:0000010' || 'academyinfo:0000010' =>
      campusId == null || campusId == 'academyinfo:0000010' ? 'kumoh' : null,
    'institution:academyinfo:0000066' || 'academyinfo:0000066' =>
      campusId == null || campusId == 'academyinfo:0000066' ? 'khu' : null,
    'institution:academyinfo:0000021' || 'academyinfo:0000021' =>
      campusId == null || campusId == 'academyinfo:0000021' ? 'gknu' : null,
    'institution:academyinfo:0000255' || 'academyinfo:0000255' =>
      campusId == null || campusId == 'academyinfo:0000255' ? 'snue' : null,
    'institution:academyinfo:0000136' || 'academyinfo:0000136' =>
      campusId == null || campusId == 'academyinfo:0000136' ? 'sungshin' : null,
    'institution:academyinfo:0000151' || 'academyinfo:0000151' =>
      campusId == null || campusId == 'academyinfo:0000151' ? 'yu' : null,
    'institution:academyinfo:0000012' || 'academyinfo:0000012' =>
      campusId == null || campusId == 'academyinfo:0000012' ? 'mmu' : null,
    'institution:academyinfo:0000029' || 'academyinfo:0000029' =>
      campusId == null || campusId == 'academyinfo:0000029' ? 'cnu' : null,
    'institution:academyinfo:0000253' || 'academyinfo:0000253' =>
      campusId == null || campusId == 'academyinfo:0000253' ? 'dnue' : null,
    'institution:academyinfo:0000192' || 'academyinfo:0000192' =>
      campusId == null || campusId == 'academyinfo:0000192' ? 'hufs' : null,
    'institution:academyinfo:0000014' || 'academyinfo:0000014' =>
      campusId == null || campusId == 'academyinfo:0000014' ? 'pnu' : null,
    'institution:academyinfo:0000189' || 'academyinfo:0000189' =>
      campusId == null || campusId == 'academyinfo:0000189'
          ? 'koreatech'
          : null,
    'institution:academyinfo:0000030' || 'academyinfo:0000030' =>
      campusId == null || campusId == 'academyinfo:0000030' ? 'cbnu' : null,
    'institution:academyinfo:0000194' || 'academyinfo:0000194' =>
      campusId == null || campusId == 'academyinfo:0000194' ? 'kau' : null,
    'institution:academyinfo:0000126' || 'academyinfo:0000126' =>
      campusId == null || campusId == 'academyinfo:0000126' ? 'swu' : null,
    'institution:academyinfo:0000200' || 'academyinfo:0000200' =>
      campusId == null || campusId == 'academyinfo:0000200' ? 'hansung' : null,
    'institution:academyinfo:0000140' || 'academyinfo:0000140' =>
      campusId == null || campusId == 'academyinfo:0000140' ? 'suwon' : null,
    'institution:academyinfo:0000120' || 'academyinfo:0000120' =>
      campusId == null || campusId == 'academyinfo:0000120' ? 'sogang' : null,
    'institution:academyinfo:0000109' ||
    'academyinfo:0000109' ||
    'academyinfo:0000111' =>
      campusId == null ||
              const [
                'academyinfo:0000109',
                'academyinfo:0000111',
              ].contains(campusId)
          ? 'mju'
          : null,
    'institution:academyinfo:0000251' || 'academyinfo:0000251' =>
      campusId == null || campusId == 'academyinfo:0000251' ? 'gjue' : null,
    'institution:academyinfo:0000262' || 'academyinfo:0000262' =>
      campusId == null || campusId == 'academyinfo:0000262' ? 'cnue' : null,
    'institution:academyinfo:0000256' ||
    'academyinfo:0000256' ||
    'academyinfo:0000257' =>
      campusId == null ||
              const [
                'academyinfo:0000256',
                'academyinfo:0000257',
              ].contains(campusId)
          ? 'ginue'
          : null,
    'institution:academyinfo:0000040' || 'academyinfo:0000040' =>
      campusId == null || campusId == 'academyinfo:0000040' ? 'uos' : null,
    'institution:academyinfo:0000178' || 'academyinfo:0000178' =>
      campusId == null || campusId == 'academyinfo:0000178' ? 'bu' : null,
    'institution:academyinfo:0000261' || 'academyinfo:0000261' =>
      campusId == null || campusId == 'academyinfo:0000261' ? 'cje' : null,
    'institution:academyinfo:0000245' || 'academyinfo:0000245' =>
      campusId == null || campusId == 'academyinfo:0000245' ? 'nsu' : null,
    'institution:academyinfo:0000074' || 'academyinfo:0000074' =>
      campusId == null || campusId == 'academyinfo:0000074'
          ? 'kwangwoon'
          : null,
    'institution:academyinfo:0000169' || 'academyinfo:0000169' =>
      campusId == null || campusId == 'academyinfo:0000169' ? 'inha' : null,
    'institution:academyinfo:0002660' || 'academyinfo:0002660' =>
      campusId == null || campusId == 'academyinfo:0002660' ? 'inu' : null,
    'institution:academyinfo:0000031' || 'academyinfo:0000031' =>
      campusId == null || campusId == 'academyinfo:0000031' ? 'knue' : null,
    'institution:academyinfo:0000009' || 'academyinfo:0000009' =>
      campusId == null || campusId == 'academyinfo:0000009' ? 'kunsan' : null,
    'institution:academyinfo:0000011' || 'academyinfo:0000011' =>
      campusId == null ||
              {'academyinfo:0000011', 'academyinfo:0003312'}.contains(campusId)
          ? 'mokpo'
          : null,
    'institution:academyinfo:0000008' || 'academyinfo:0000008' =>
      campusId == null || campusId == 'academyinfo:0000008' ? 'kongju' : null,
    'institution:academyinfo:0000039' || 'academyinfo:0000039' =>
      campusId == null || campusId == 'academyinfo:0000039' ? 'hanbat' : null,
    'institution:academyinfo:0000037' || 'academyinfo:0000037' =>
      campusId == null || campusId == 'academyinfo:0000037' ? 'hknu' : null,
    'institution:academyinfo:0000020' || 'academyinfo:0000020' =>
      campusId == null || campusId == 'academyinfo:0000020' ? 'sunchon' : null,
    'institution:academyinfo:0000025' || 'academyinfo:0000025' =>
      campusId == null || campusId == 'academyinfo:0000025' ? 'jbnu' : null,
    'academyinfo:0003297' => 'changwon-geochang',
    'academyinfo:0003298' => 'changwon-namhae',
    'institution:academyinfo:0000028' ||
    'academyinfo:0000028' => switch (campusId) {
      null || 'academyinfo:0000028' => 'changwon',
      'academyinfo:0003297' => 'changwon-geochang',
      'academyinfo:0003298' => 'changwon-namhae',
      _ => null,
    },
    'institution:academyinfo:0000100' ||
    'academyinfo:0000100' ||
    'academyinfo:0000101' => switch (selectedCampusId) {
      'academyinfo:0000101' => 'dongguk-wise',
      'academyinfo:0000100' ||
      'institution:academyinfo:0000100' => 'dongguk-seoul',
      _ => null,
    },
    'institution:academyinfo:0000007' || 'academyinfo:0000007' =>
      campusId == null || campusId == 'academyinfo:0000007' ? 'gnu' : null,
    'institution:academyinfo:0000068' || 'academyinfo:0000068' =>
      campusId == null || campusId == 'academyinfo:0000068' ? 'kmu' : null,
    'institution:academyinfo:0000143' || 'academyinfo:0000143' =>
      campusId == null || campusId == 'academyinfo:0000143' ? 'ssu' : null,
    'institution:academyinfo:0000116' || 'academyinfo:0000116' =>
      campusId == null || campusId == 'academyinfo:0000116' ? 'syu' : null,
    'institution:academyinfo:0000027' || 'academyinfo:0000027' =>
      campusId == null || campusId == 'academyinfo:0000027' ? 'jeju' : null,
    'institution:academyinfo:0000156' || 'academyinfo:0000156' =>
      campusId == null || campusId == 'academyinfo:0000156' ? 'yongin' : null,
    'institution:academyinfo:0000175' ||
    'academyinfo:0000175' ||
    'academyinfo:0000174' =>
      campusId == null ||
              const [
                'academyinfo:0000175',
                'academyinfo:0000174',
              ].contains(campusId)
          ? 'cau'
          : null,
    'institution:academyinfo:0000374' || 'academyinfo:0000374' =>
      campusId == null || campusId == 'academyinfo:0000374' ? 'kaist' : null,
    'institution:academyinfo:0000003' ||
    'academyinfo:0000003' ||
    'academyinfo:0000004' ||
    'academyinfo:0003363' ||
    'academyinfo:0003364' =>
      campusId == null ||
              const [
                'academyinfo:0000003',
                'academyinfo:0000004',
                'academyinfo:0003363',
                'academyinfo:0003364',
              ].contains(campusId)
          ? 'kangwon'
          : null,
    'institution:academyinfo:0000250' || 'academyinfo:0000250' =>
      campusId == null || campusId == 'academyinfo:0000250' ? 'unist' : null,
    'institution:academyinfo:0000078' || 'academyinfo:0000078' =>
      campusId == null || campusId == 'academyinfo:0000078' ? 'kookmin' : null,
    'institution:academyinfo:0000034' || 'academyinfo:0000034' =>
      campusId == null || campusId == 'academyinfo:0000034' ? 'ut' : null,
    'institution:academyinfo:0000254' || 'academyinfo:0000254' =>
      campusId == null || campusId == 'academyinfo:0000254' ? 'bnue' : null,
    'institution:academyinfo:0000107' || 'academyinfo:0000107' =>
      campusId == null || campusId == 'academyinfo:0000107' ? 'deu' : null,
    'institution:academyinfo:0000158' || 'academyinfo:0000158' =>
      campusId == null || campusId == 'academyinfo:0000158' ? 'ulsan' : null,
    'institution:academyinfo:0000084' || 'academyinfo:0000084' =>
      campusId == null || campusId == 'academyinfo:0000084' ? 'daegu' : null,
    'institution:academyinfo:0000005' || 'academyinfo:0000005' =>
      campusId == null || campusId == 'academyinfo:0000005' ? 'knu' : null,
    'institution:academyinfo:0000046' ||
    'academyinfo:0000046' ||
    'academyinfo:0000048' ||
    'academyinfo:0000049' =>
      campusId == null ||
              const [
                'academyinfo:0000046',
                'academyinfo:0000048',
                'academyinfo:0000049',
              ].contains(campusId)
          ? 'catholic'
          : null,
    'institution:academyinfo:0000133' || 'academyinfo:0000133' =>
      campusId == null || campusId == 'academyinfo:0000133' ? 'skku' : null,
    'institution:academyinfo:0000141' || 'academyinfo:0000141' =>
      campusId == null || campusId == 'academyinfo:0000141'
          ? 'sookmyung'
          : null,
    'institution:academyinfo:0000146' || 'academyinfo:0000146' =>
      campusId == null || campusId == 'academyinfo:0000146' ? 'ajou' : null,
    'institution:academyinfo:0000142' || 'academyinfo:0000142' =>
      campusId == null || campusId == 'academyinfo:0000142' ? 'sch' : null,
    'institution:academyinfo:0000381' || 'academyinfo:0000381' =>
      campusId == null || campusId == 'academyinfo:0000381' ? 'gist' : null,
    'institution:academyinfo:0000188' || 'academyinfo:0000188' =>
      campusId == null || campusId == 'academyinfo:0000188' ? 'postech' : null,
    'institution:academyinfo:0000138' || 'academyinfo:0000138' =>
      campusId == null || campusId == 'academyinfo:0000138' ? 'sejong' : null,
    'institution:academyinfo:0000019' || 'academyinfo:0000019' =>
      campusId == null || campusId == 'academyinfo:0000019' ? 'snu' : null,
    _ => timetableCampus == null ? null : timetableUniversity,
  };
  bool get timetableSupported =>
      timetableCampus != null &&
      UniversitySupportPolicy.timetableAvailable(timetableUniversity);
  bool get supported => academicSourceId != null || timetableSupported;
  String get displayName => universityName;

  Map<String, Object?> toJson() => {
    'universityId': universityId,
    'universityName': universityName,
    'schoolKind': schoolKind,
    'campus': campus,
    if (campusId != null) 'campusId': campusId,
    if (lmsCategoryId != null) 'lmsCategoryId': lmsCategoryId,
    if (lmsUserId != null) 'lmsUserId': lmsUserId,
    if (lmsIntegrationEnabled != null)
      'lmsIntegrationEnabled': lmsIntegrationEnabled,
  };

  factory AcademicProfile.fromJson(Map<String, Object?> json) {
    final id = json['universityId'];
    final name = json['universityName'];
    final kind = json['schoolKind'];
    final campus = json['campus'];
    final campusId = json['campusId'];
    final lmsCategoryId = json['lmsCategoryId'];
    final lmsUserId = json['lmsUserId'];
    final lmsIntegrationEnabled = json['lmsIntegrationEnabled'];
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        (kind != 'fourYear' &&
            kind != 'juniorCollege' &&
            kind != 'cyberUniversity') ||
        (campus != null && campus is! String) ||
        (lmsUserId != null &&
            (lmsUserId is! String || lmsUserId.trim().isEmpty)) ||
        (lmsIntegrationEnabled != null && lmsIntegrationEnabled is! bool) ||
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
      lmsUserId: lmsUserId as String?,
      lmsIntegrationEnabled: lmsIntegrationEnabled as bool?,
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
      lmsCategoryId == other.lmsCategoryId &&
      lmsUserId == other.lmsUserId &&
      lmsIntegrationEnabled == other.lmsIntegrationEnabled;
  @override
  int get hashCode => Object.hash(
    universityId,
    universityName,
    schoolKind,
    campus,
    campusId,
    lmsCategoryId,
    lmsUserId,
    lmsIntegrationEnabled,
  );
}
