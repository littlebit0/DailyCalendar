import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/file_asset_bundle.dart';

const directory = 'work/university-research/catalog-c/jbnu-current-20261008';
Map<String, dynamic> read(String file) =>
    jsonDecode(fixtureFile('$directory/$file').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Medical rows come from the official JUMP query and replace the dated document',
    () async {
      // 2026-11-23 user decision: the 33 rows of the 2026-08-19 medical
      // document were replaced by the same courses' official JUMP rows.
      final list =
          (jsonDecode(
                    File(
                      'test/fixtures/jbnu_medical_jump_2026_2.json',
                    ).readAsStringSync(),
                  )
                  as Map)['rows']
              as List;
      final official = {
        for (final r in list)
          if ('${r['STDTR_NO']}'.startsWith('UMED'))
            '${r['STDTR_NO']}-${r['DVCLS_NO']}': r,
      };
      expect(official, hasLength(33));
      final datasets = await UniversityCatalog.load(
        bundle: FileAssetBundle(),
        university: 'jbnu',
      );
      final medical = datasets
          .expand((d) => d.courses)
          .where((c) => c.code.startsWith('UMED'))
          .toList();
      expect(medical, hasLength(33));
      expect(
        datasets
            .expand((d) => d.courses)
            .where((c) => c.sourceId.startsWith('jbnu-med-document')),
        isEmpty,
      );
      for (final c in medical) {
        final r = official['${c.code}-${c.section}']!;
        expect(c.campus, 'jeonju');
        expect(c.title, r['SBJCT_NM']);
        expect(c.professor, r['STAFFNM']);
        expect(c.sourceSchedule, r['DOW_HR_CN']);
        expect(c.sourceClassroom, r['DONG_RMNM_CN']);
        expect(c.hasSchedulableMeetings, isTrue, reason: c.sourceId);
        final saved = c.toTimetable(id: c.sourceId, mode: LectureMode.inPerson);
        expect(saved.isValid, isTrue, reason: c.sourceId);
      }
      final neurology = medical.singleWhere((c) => c.code == 'UMED001');
      // 월 0-B (08:30) ... 월 4-A (12:00~12:30) is one Monday block.
      expect(neurology.meetings.first.weekday, DateTime.monday);
      expect(neurology.meetings.first.originalStartMinute, 8 * 60 + 30);
      expect(neurology.meetings.first.originalEndMinute, 12 * 60 + 30);
    },
  );
  test(
    'Current public native 3571 metadata, exact campus prefixes and zero fabricated clocks',
    () {
      final a = read('whole-metadata-audit.json');
      final ids = <String>{};
      var count = 0;
      final names = {
        '전주': 'jeonju',
        '익산': 'iksan',
        '남원': 'namwon',
        '고창': 'gochang',
        '새만금': 'saemangeum',
      };
      for (final file in a['candidates']) {
        expect(
          sha256
              .convert(
                fixtureFile('$directory/${file['file']}').readAsBytesSync(),
              )
              .toString(),
          file['sha256'],
        );
        final r = read(file['file']);
        final model = UniversityDataset.fromJson(r);
        expect(model.courses, hasLength(file['classes']));
        for (final c in r['courses']) {
          count++;
          expect(ids.add(c['sourceId']), true);
          final e = c['publicEducationRow'];
          expect(c['courseCode'], e['STDTR_NO']);
          expect(c['section'], e['DVCLS_NO'].toString());
          expect(c['classification'], e['CMCRS_DIVCDNM']);
          expect(c['credits'], e['ESTBL_PNT']);
          expect(c['sourceClassroom'], e['DONG_RMNM_CN'] ?? '');
          expect(c['sourceSchedule'], e['DOW_HR_CN']);
          expect(c['schedules'], isEmpty);
          final prefixes = RegExp(
            r'(전주|익산|고창|남원|새만금):',
          ).allMatches(e['DONG_RMNM_CN'] ?? '').map((m) => m[1]).toSet();
          expect(
            c['campus'],
            prefixes.length == 1 ? names[prefixes.single] : 'unknown',
          );
          expect(c['referenceKind'], '공개 과목번호');
        }
      }
      expect(count, 3571);
      expect(ids, hasLength(3571));
      expect(a['priorAbsentNow'], hasLength(5));
      final closure = read('closure-educational-reconciliation.json');
      expect(closure['sourceRows'], hasLength(248));
      expect(closure['currentTitleSectionValidationMatches'], isEmpty);
      expect(closure['medicalSameTitleNoticeRows'], isEmpty);
      expect(closure['officialCodeJoinPerformed'], false);
    },
  );
  test(
    'JBNU restored catalog keeps 3571 courses and 2 held clocks',
    () async {
      final datasets = await UniversityCatalog.load(
        bundle: FileAssetBundle(),
        university: 'jbnu',
      );
      expect(
        {for (final d in datasets) d.campus: d.courses.length},
        {
          'unknown': 233,
          'gochang': 11,
          'iksan': 129,
          'jeonju': 3170,
          'namwon': 21,
          'saemangeum': 7,
        },
      );
      final courses = datasets.expand((d) => d.courses).toList();
      expect(courses.map((c) => c.sourceId).toSet(), hasLength(3571));
      expect(courses.where((c) => c.hasSchedulableMeetings), hasLength(3569));
      expect(
        courses.where((c) => c.scheduleStatus == 'unrecognized'),
        hasLength(2),
      );
      expect(courses.where((c) => c.scheduleStatus == 'unscheduled'), isEmpty);
      // Late half-slots past the handbook table continue the same 30-minute
      // unit (2026-11-23 user decision): 월 11-A 19:00 ... 월 13-B ~22:00.
      final late = courses.singleWhere(
        (c) => c.code == 'USOF075' && c.section == '1',
      );
      expect(late.scheduleStatus, 'scheduled');
      expect(late.meetings.single.originalStartMinute, 19 * 60);
      expect(late.meetings.single.originalEndMinute, 22 * 60);
    },
  );

  test(
    'JBNU major labels all reach an official college in the course page',
    () async {
      final datasets = await UniversityCatalog.load(
        bundle: FileAssetBundle(),
        university: 'jbnu',
      );
      final raw = <String>{};
      final orphans = <String>{};
      for (final d in datasets) {
        for (final c in d.courses) {
          for (final l in c.departments) {
            if (c.isMajorForSourceDepartment(l) &&
                !c.offeringOrganizations.any((o) => o.sourceLabel == l)) {
              raw.add('${d.campus} $l');
            }
          }
          for (final o in c.offeringOrganizations) {
            if (o.department != null &&
                o.college == null &&
                o.group == null &&
                c.isMajorForOrganization(o)) {
              orphans.add('${d.campus} ${o.department}');
            }
          }
        }
      }
      expect(raw, isEmpty);
      expect(orphans, isEmpty);
      // UECO economics courses belong to 경상대학 경제학부, not agriculture.
      final economics = datasets
          .expand((d) => d.courses)
          .where((c) => c.code == 'UECO001')
          .expand((c) => c.offeringOrganizations)
          .where((o) => o.sourceLabel == '경제학');
      expect(economics.map((o) => o.college).toSet(), {'경상대학'});
    },
  );
}
