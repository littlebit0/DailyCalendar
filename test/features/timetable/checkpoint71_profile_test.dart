import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/university_support_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Konkuk Seoul and GLOCAL select their own published timetables', () {
    for (final id in [
      'institution:academyinfo:0000052',
      'academyinfo:0000052',
    ]) {
      final glocal = AcademicProfile(
        universityId: id,
        universityName: '건국대학교',
        schoolKind: 'fourYear',
        campusId: 'academyinfo:0000053',
      );
      expect(glocal.timetableCampus, 'glocal');
      final seoul = AcademicProfile(
        universityId: id,
        universityName: '건국대학교',
        schoolKind: 'fourYear',
        campusId: 'academyinfo:0000052',
      );
      expect(seoul.timetableCampus, 'seoul');
      for (final profile in [glocal, seoul]) {
        expect(
          profile.timetableSupported,
          UniversitySupportPolicy.timetableAvailable('konkuk'),
        );
      }
    }
    const legacy = AcademicProfile(
      universityId: 'academyinfo:0000053',
      universityName: '건국대학교 GLOCAL',
      schoolKind: 'fourYear',
    );
    expect(legacy.timetableUniversity, 'konkuk');
    expect(legacy.timetableCampus, 'glocal');
  });
  test(
    'Five current source providers keep own institution and campus guards',
    () {
      const groups = {
        'konkuk': ['0000052', '0000053'],
        'unist': ['0000250'],
        'hoseo': ['0000211'],
        'chosun': ['0000172'],
        'suwon': ['0000140'],
        'hanyang': ['0000203', '0000204'],
        'sookmyung': ['0000141'],
        'ut': ['0000034'],
        'nsu': ['0000245'],
        'bnue': ['0000254'],
        'kaist': ['0000374'],
        'mju': ['0000109', '0000111'],
        'sku': ['0000121'],
        'mmu': ['0000012'],
        'kau': ['0000194'],
        'jbnu': ['0000025'],
        'korea': ['0000069', '0000070'],
        'jnue': ['0000258'],
        'ginue': ['0000256', '0000257'],
        'gjue': ['0000251'],
        'gnue': ['0000252'],
        'sungshin': ['0000136'],
        'dongguk': ['0000100'],
        'kmou': ['0000033'],
        'yu': ['0000151'],
        'dnue': ['0000253'],
        'syu': ['0000116'],
        'donga': ['0000105'],
        'yonsei': ['0000149', '0000150'],
      };
      for (final group in groups.entries) {
        final base = group.value.first;
        for (final raw in group.value) {
          for (final id in [
            'academyinfo:$raw',
            'institution:academyinfo:$base',
          ]) {
            final profile = AcademicProfile(
              universityId: id,
              universityName: group.key,
              schoolKind: 'fourYear',
              campusId: 'academyinfo:$raw',
            );
            expect(profile.timetableUniversity, group.key);
            expect(
              profile.timetableSupported,
              UniversitySupportPolicy.timetableAvailable(
                profile.timetableUniversity,
              ),
            );
            expect(profile.timetableCampus, switch (group.key) {
              'hanyang' => raw == '0000204' ? 'erica' : 'seoul',
              'sookmyung' => 'first',
              'mju' => raw == '0000111' ? 'natural' : 'humanities',
              'konkuk' => raw == '0000053' ? 'glocal' : 'seoul',
              'unist' ||
              'hoseo' ||
              'chosun' ||
              'suwon' ||
              'sku' ||
              'mmu' ||
              'jbnu' ||
              'jnue' ||
              'gjue' ||
              'gnue' => 'unknown',
              'korea' => 'sejong',
              'ginue' => raw == '0000257' ? 'gyeonggi' : 'incheon',
              'sungshin' => 'sujeong',
              'dongguk' => 'seoul',
              'kmou' || 'yu' || 'dnue' => 'unknown',
              'kau' || 'kaist' => 'main',
              'ut' || 'nsu' || 'bnue' => 'unknown',
              'syu' => 'main',
              'donga' => 'seunghak',
              _ => raw == '0000150' ? 'mirae' : 'sinchon',
            });
            final foreign = AcademicProfile(
              universityId: id,
              universityName: group.key,
              schoolKind: 'fourYear',
              campusId: 'academyinfo:0000117',
            );
            expect(foreign.timetableSupported, false);
          }
        }
      }
    },
  );
}
