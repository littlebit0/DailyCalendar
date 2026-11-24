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
    'gnue',
    'hansei',
    'hknu',
    'hyupsung',
    'iccu',
    'inje',
    'jnue',
    'kaist',
    'kangnam',
    'kmou',
    'knue',
    'kumoh',
    'kyonggi',
    'mmu',
    'nambu',
    'postech',
    'sangji',
    'sungkyul',
    'syu',
    'unist',
    'wsu',
    'yongin',
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
