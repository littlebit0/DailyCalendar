/// Temporary source-integration suspension. Stored classes, events and school
/// identities are retained; resumption requires completing the recorded source
/// work and verification, not simply changing this policy.
class UniversitySupportPolicy {
  static const suspendedTimetableUniversities = <String>{
    'bnue',
    'cje',
    'dgist',
    'dnue',
    'dongguk',
    'eulji',
    'ginue',
    'gist',
    'gjue',
    'gnu',
    'gnue',
    'hansei',
    'hknu',
    'hyupsung',
    'iccu',
    'inje',
    'inu',
    'jbnu',
    'jeju',
    'jnu',
    'jnue',
    'kaist',
    'kangnam',
    'khu',
    'kmou',
    'knu',
    'knue',
    'korea',
    'kumoh',
    'kyonggi',
    'mmu',
    'nambu',
    'postech',
    'sangji',
    'sungkyul',
    'syu',
    'ulsan',
    'unist',
    'wsu',
    'yongin',
    'yonsei',
    'yu',
    'snue',
    'cue',
    'cnue',
    'kentech',
    'konyang',
  };

  static bool timetableAvailable(String? university) =>
      university != null &&
      !suspendedTimetableUniversities.contains(university);
}
