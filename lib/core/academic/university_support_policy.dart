/// Temporary source-integration suspension. Stored classes, events and school
/// identities are retained; resumption requires completing the recorded source
/// work and verification, not simply changing this policy.
class UniversitySupportPolicy {
  static const suspendedTimetableUniversities = <String>{
    'bnue',
    'cje',
    'dgist',
    'dnue',
    'ginue',
    'gist',
    'gjue',
    'gnue',
    'hansei',
    'hknu',
    'hyupsung',
    'iccu',
    'jnue',
    'kaist',
    'kangnam',
    'kmou',
    'knue',
    'kumoh',
    'mmu',
    'nambu',
    'postech',
    'sangji',
    'sungkyul',
    'syu',
    'unist',
    'wsu',
    'yongin',
    'snue',
    'cue',
    'cnue',
    'kentech',
  };

  static bool timetableAvailable(String? university) =>
      university != null &&
      !suspendedTimetableUniversities.contains(university);
}
