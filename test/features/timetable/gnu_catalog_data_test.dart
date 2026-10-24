import 'dart:convert';
import '../../support/gnu_break_slots.dart';
import '../../support/source_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';

void main() {
  test('GNU integrated profile uses its own campus-filterable catalog', () {
    for (final id in [
      'institution:academyinfo:0000007',
      'academyinfo:0000007',
    ]) {
      final profile = AcademicProfile(
        universityId: id,
        universityName: '경상국립대학교',
        schoolKind: 'fourYear',
      );
      expect(profile.timetableUniversity, 'gnu');
      expect(profile.timetableCampus, 'gajwa');
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '경상국립대학교',
          schoolKind: 'fourYear',
          campusId: 'academyinfo:0000117',
        ).timetableSupported,
        isFalse,
      );
    }
  });
  test(
    'GNU Industry scoped research retains native fields and validates all modes plus whole Drive restoration',
    () {
      final originals =
          (jsonDecode(
                    fixtureFile(
                      'work/university-research/catalogs/gnu-public-course-rows.json',
                    ).readAsStringSync(),
                  )
                  as List)
              .cast<Map<String, dynamic>>();
      final native = {
        for (final r in originals) '${r['code']}-${r['section']}': r,
      };
      final oldIds =
          ((jsonDecode(
                        fixtureFile(
                          'work/university-research/catalog-r/gnu/ordinary-weekly-faq-research-20261008/audit.json',
                        ).readAsStringSync(),
                      )
                      as Map)['preservedOld18']
                  as List)
              .toSet();
      final datasets = <UniversityDataset>[];
      var count = 0, scheduled = 0, meetings = 0;
      final ids = <String>{};
      for (final campus in [
        'gajwa',
        'chilam',
        'tongyeong',
        'changwon',
        'naedong',
        'unknown',
      ]) {
        final raw =
            jsonDecode(
                  fixtureFile(
                    'assets/timetable/gnu-$campus-2026-2.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        final dataset = UniversityDataset.fromJson(raw);
        datasets.add(dataset);
        expect(raw['researchOnly'], isFalse);
        expect(raw['completionClaim'], isFalse);
        final sourceRows = (raw['courses'] as List)
            .cast<Map<String, dynamic>>();
        // 쉬는 시간 포함 슬롯: 교시표 구간은 정각에 시작해 정각(또는 야간 21:30)에 끝나고,
        // 같은 날 같은 강의실의 간격 60분 미만 구간은 한 구간으로 합쳐져 있어야 한다.
        expectNoMergeableGnuSegments(sourceRows);
        for (final row in sourceRows) {
          for (final m in row['schedules'] as List) {
            expect(
              m['endMinute'] % 60 == 0 || m['endMinute'] == 1290,
              isTrue,
              reason: '${row['sourceId']} ${m['date']}',
            );
          }
        }
        for (var i = 0; i < dataset.courses.length; i++) {
          final c = dataset.courses[i];
          final r = sourceRows[i];
          final metadata = r['metadata'] as Map<String, dynamic>;
          count++;
          expect(ids.add(c.sourceId), isTrue);
          expect(c.code, matches(RegExp(r'^\d{8}$')));
          expect(c.section, matches(RegExp(r'^\d{3}$')));
          expect(
            metadata['originalEducationalFields'],
            native[c.codeAndSection],
          );
          expect(
            metadata['clockSecondSemesterApplicabilityConfirmed'],
            c.hasSchedulableMeetings,
          );
          expect(metadata['wholeLatestChangesConfirmed'], isFalse);
          expect(
            metadata['originalEducationalFields'],
            native[c.codeAndSection],
          );
          expect(c.remarks.replaceAll(RegExp(r'\s+'), ''), contains('최신변경'));
          expect(c.remarks, contains(native[c.codeAndSection]!['remarks']));
          if (!c.hasSchedulableMeetings) continue;
          scheduled++;
          meetings += c.meetings.length;
          if (!oldIds.contains(c.sourceId)) continue;
          expect(c.campus, 'gajwa');
          expect(c.departments, contains('산업경영학과'));
          expect(
            c.meetings,
            hasLength(c.sourceSchedule.startsWith('금') ? 14 : 13),
          );
          expect(native[c.codeAndSection]!['closedFirstAnnouncement'], isFalse);
          expect(
            native[c.codeAndSection]!['closedSecondAnnouncement'],
            isFalse,
          );
          for (final m in c.meetings) {
            expect(m.teachingDate!.weekday, m.weekday);
            final row =
                metadata['currentPublishedEducationalRow']
                    as Map<String, dynamic>;
            if (c.sourceSchedule.startsWith('금')) {
              expect(m.originalStartMinute, 1140);
              expect(m.originalEndMinute, 1290);
            } else {
              final schedule = row['schedule'] as String;
              final expected = schedule.startsWith('토0,1,2')
                  ? [540, 660]
                  : schedule.startsWith('토3,4,5')
                  ? [660, 780]
                  : schedule.startsWith('토7,8,9')
                  ? [840, 960]
                  : [960, 1080];
              expect(m.originalStartMinute, expected[0]);
              expect(m.originalEndMinute, expected[1]);
            }
            expect(m.date!.compareTo('2026-09-01'), greaterThanOrEqualTo(0));
            expect(m.date!.compareTo('2026-12-14'), lessThanOrEqualTo(0));
            expect([
              '2026-09-24',
              '2026-09-25',
              '2026-09-26',
              '2026-10-05',
              '2026-10-20',
              '2026-10-03',
              '2026-10-09',
            ], isNot(contains(m.date)));
          }
        }
      }
      expect(count, 4842);
      expect(scheduled, 3005);
      expect(meetings, 53869);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final imported = datasets
            .expand((d) => d.courses)
            .where(
              (c) => c.hasSchedulableMeetings && oldIds.contains(c.sourceId),
            )
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final doc = TimetableSyncDocument.legacy(
          courses: imported,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(restored, hasLength(18));
        final before = {for (final c in imported) c.sourceId: c};
        for (final c in restored) {
          final old = before[c.sourceId]!;
          expect(c.isValid, isTrue);
          expect(c.defaultMode, mode);
          expect(
            c.meetings.map((m) => m.toJson()).toList(),
            old.meetings.map((m) => m.toJson()).toList(),
          );
          expect(c.note, old.note);
          expect(c.note, contains('45분'));
          expect(c.note, contains('실제 시각'));
          expect(
            c.meetings.every(
              (m) =>
                  c.modeOn(m, DateTime.parse(m.date!)) == LectureMode.inPerson,
            ),
            isTrue,
          );
        }
      }
      final friday = datasets
          .expand((d) => d.courses)
          .singleWhere((c) => c.code == '11002297' && c.section == '001');
      expect(friday.meetings.map((m) => m.date), contains('2026-12-09'));
      expect(
        friday.meetings.singleWhere((m) => m.date == '2026-12-09').weekday,
        3,
      );
      final saturday = datasets
          .expand((d) => d.courses)
          .singleWhere((c) => c.code == '11002114' && c.section == '003');
      expect(saturday.meetings.map((m) => m.date), contains('2026-12-12'));
      expect(
        saturday.meetings.every(
          (m) => m.originalStartMinute == 660 && m.originalEndMinute == 780,
        ),
        isTrue,
      );
      for (final pair in [
        ['11026184', '002'],
        ['11002308', '001'],
      ]) {
        expect(
          datasets
              .expand((d) => d.courses)
              .singleWhere((c) => c.code == pair[0] && c.section == pair[1])
              .hasSchedulableMeetings,
          isFalse,
        );
      }
    },
  );
}
