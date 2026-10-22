import 'package:daily/core/academic/academic_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'New public catalog institutions preserve academic identity and campus boundary',
    () {
      for (final id in [
        'institution:academyinfo:0000084',
        'academyinfo:0000084',
      ]) {
        final profile = AcademicProfile(
          universityId: id,
          universityName: '대구대학교',
          schoolKind: 'fourYear',
        );
        expect(profile.timetableUniversity, 'daegu');
        expect(profile.timetableCampus, 'main');
        expect(
          AcademicProfile(
            universityId: id,
            universityName: '대구대학교',
            schoolKind: 'fourYear',
            campusId: 'academyinfo:0000117',
          ).timetableSupported,
          false,
        );
      }
      for (final id in [
        'institution:academyinfo:0000030',
        'academyinfo:0000030',
      ]) {
        final profile = AcademicProfile(
          universityId: id,
          universityName: '충북대학교',
          schoolKind: 'fourYear',
        );
        expect(profile.timetableUniversity, 'cbnu');
        expect(profile.timetableCampus, 'main');
        expect(
          AcademicProfile(
            universityId: id,
            universityName: '충북대학교',
            schoolKind: 'fourYear',
            campusId: 'academyinfo:0000117',
          ).timetableSupported,
          false,
        );
      }
      for (final id in [
        'institution:academyinfo:0000189',
        'academyinfo:0000189',
      ]) {
        final profile = AcademicProfile(
          universityId: id,
          universityName: '한국기술교육대학교',
          schoolKind: 'fourYear',
        );
        expect(profile.timetableUniversity, 'koreatech');
        expect(profile.timetableCampus, 'unknown');
        expect(
          AcademicProfile(
            universityId: id,
            universityName: '한국기술교육대학교',
            schoolKind: 'fourYear',
            campusId: 'academyinfo:0000117',
          ).timetableSupported,
          false,
        );
      }
      for (final id in [
        'institution:academyinfo:0000039',
        'academyinfo:0000039',
      ]) {
        final p = AcademicProfile(
          universityId: id,
          universityName: '국립한밭대학교',
          schoolKind: 'fourYear',
        );
        expect(p.timetableUniversity, 'hanbat');
        expect(p.timetableCampus, 'daejeon');
        expect(
          AcademicProfile(
            universityId: id,
            universityName: '국립한밭대학교',
            schoolKind: 'fourYear',
            campusId: 'academyinfo:0000117',
          ).timetableSupported,
          false,
        );
      }
      for (final id in [
        'institution:academyinfo:0000013',
        'academyinfo:0000013',
      ]) {
        final profile = AcademicProfile(
          universityId: id,
          universityName: '국립부경대학교',
          schoolKind: 'fourYear',
        );
        expect(profile.timetableUniversity, 'pknu');
        expect(profile.timetableCampus, 'unknown');
        expect(
          AcademicProfile(
            universityId: id,
            universityName: '국립부경대학교',
            schoolKind: 'fourYear',
            campusId: 'academyinfo:0000117',
          ).timetableSupported,
          false,
        );
      }
      for (final id in [
        'institution:academyinfo:0000027',
        'academyinfo:0000027',
      ]) {
        final p = AcademicProfile(
          universityId: id,
          universityName: '제주대학교',
          schoolKind: 'fourYear',
        );
        expect(p.timetableUniversity, 'jeju');
        expect(p.timetableCampus, 'unknown');
        expect(
          AcademicProfile(
            universityId: id,
            universityName: '제주대학교',
            schoolKind: 'fourYear',
            campusId: 'academyinfo:0000117',
          ).timetableSupported,
          false,
        );
      }
      for (final id in [
        'institution:academyinfo:0002660',
        'academyinfo:0002660',
      ]) {
        final p = AcademicProfile(
          universityId: id,
          universityName: 'inu',
          schoolKind: 'fourYear',
        );
        expect(p.timetableUniversity, 'inu');
        expect(p.timetableCampus, 'unknown');
        expect(
          AcademicProfile(
            universityId: id,
            universityName: 'inu',
            schoolKind: 'fourYear',
            campusId: 'academyinfo:0000117',
          ).timetableSupported,
          false,
        );
      }
      for (final id in [
        'institution:academyinfo:0000010',
        'academyinfo:0000010',
      ]) {
        final p = AcademicProfile(
          universityId: id,
          universityName: 'kumoh',
          schoolKind: 'fourYear',
        );
        expect(p.timetableUniversity, 'kumoh');
        expect(p.timetableCampus, 'yangho');
        expect(
          AcademicProfile(
            universityId: id,
            universityName: 'kumoh',
            schoolKind: 'fourYear',
            campusId: 'academyinfo:0000117',
          ).timetableSupported,
          false,
        );
      }

      for (final id in [
        'institution:academyinfo:0000020',
        'academyinfo:0000020',
      ]) {
        final p = AcademicProfile(
          universityId: id,
          universityName: '순천대학교',
          schoolKind: 'fourYear',
        );
        expect(p.timetableUniversity, 'scnu');
        expect(p.timetableCampus, 'unknown');
        expect(
          AcademicProfile(
            universityId: id,
            universityName: '순천대학교',
            schoolKind: 'fourYear',
            campusId: 'academyinfo:0000117',
          ).timetableSupported,
          false,
        );
      }

      for (final id in [
        'institution:academyinfo:0000158',
        'academyinfo:0000158',
      ]) {
        final p = AcademicProfile(
          universityId: id,
          universityName: '울산대학교',
          schoolKind: 'fourYear',
        );
        expect(p.timetableUniversity, 'ulsan');
        expect(p.timetableCampus, 'main');
        expect(
          AcademicProfile(
            universityId: id,
            universityName: '울산대학교',
            schoolKind: 'fourYear',
            campusId: 'academyinfo:0000117',
          ).timetableSupported,
          false,
        );
      }
    },
  );
}
