import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Hanyang complete native source and conservative own-term reservation dates survive all modes and full Drive JSON',
    () {
      const root = 'work/university-research/catalog-f/hanyang/';
      Map<String, dynamic> read(String path) =>
          jsonDecode(fixtureFile(path).readAsStringSync())
              as Map<String, dynamic>;
      final native = read(
        'work/university-research/catalog-d/hanyang-cached-educational-scope-20261008.json',
      );
      final originals = {
        for (final r in native['courses'] as List) r['classId']: r,
      };
      final holidays =
          (read(
                    '${root}hanyang-current-policy-education-receipt-20261008.json',
                  )['conservativelyHeldNationalHolidayDates']
                  as List)
              .cast<String>()
              .toSet();
      // 간호학과 공지 첨부 '2026-2 간호학과 시간표(26.09.14최종).pdf' 격자에서 옮긴 값
      // (1교시=09:00, 교시당 60분; 3학년 이론 9/1~10/23 304호, 4학년 이론 11/2~12/24 404호).
      const nursing = <String, (String, String, List<(int, int, int, String)>)>{
        '12079': ('2026-09-01', '2026-10-23', [(1, 660, 780, '304호'), (4, 660, 780, '304호')]),
        '12065': ('2026-09-01', '2026-10-23', [(1, 900, 1020, '304호'), (5, 600, 720, '304호')]),
        '12066': ('2026-09-01', '2026-10-23', [(2, 660, 780, '304호'), (4, 900, 1020, '304호')]),
        '12068': ('2026-09-01', '2026-10-23', [(2, 840, 900, '304호'), (3, 840, 900, '304호')]),
        '12077': ('2026-09-01', '2026-10-23', [(2, 900, 1020, '304호'), (5, 780, 900, '304호')]),
        '12070': ('2026-09-01', '2026-10-23', [(3, 900, 1020, '304호'), (5, 900, 1020, '304호')]),
        '10306': ('2026-11-02', '2026-12-24', [(1, 540, 660, '404호'), (3, 900, 1020, '404호')]),
        '10308': ('2026-11-02', '2026-12-24', [(1, 900, 1020, '404호'), (4, 600, 720, '404호')]),
      };
      const recensusRooms = {
        'hanyang/seoul/2026-2/10351': '서울 재성토목관 103강의실,서울 재성토목관 103강의실',
        'hanyang/erica/2026-2/24136': 'ERICA 컨퍼런스홀 201 강의실,ERICA 컨퍼런스홀 101 강의실',
      };
      for (final campus in ['seoul', 'erica']) {
        final raw =
            jsonDecode(
                  File(
                    'assets/timetable/hanyang-$campus-2026-2.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        final rawRows = {
          for (final r in raw['courses'] as List) r['sourceId']: r,
        };
        final dataset = UniversityDataset.fromJson(raw);
        final count = campus == 'seoul' ? 2805 : 2156;
        final eligibleCount = campus == 'seoul' ? 2447 : 1971;
        final datedCount = campus == 'seoul' ? 58407 : 46711;
        expect(dataset.courses, hasLength(count));
        expect(
          dataset.courses.map((c) => c.sourceId).toSet(),
          hasLength(count),
        );
        expect(raw['termStartDate'], '2026-09-01');
        expect(raw['termEndDate'], '2026-12-21');
        expect(
          dataset.courses.fold<int>(0, (n, c) => n + c.meetings.length),
          datedCount,
        );
        final scheduled = dataset.courses
            .where((c) => c.meetings.isNotEmpty)
            .toList();
        expect(scheduled, hasLength(eligibleCount));
        for (final c in dataset.courses) {
          final r = rawRows[c.sourceId]!;
          final meta = r['metadata'] as Map;
          final original = originals[meta['nativeEnrollmentNumber']]!;
          expect(meta['originalEducationalRecord'], original);
          final a = (original['officialAliases'] as List).first as Map;
          expect(c.sourceId, 'hanyang/$campus/2026-2/${original['classId']}');
          expect(c.code, a['haksuNo']);
          expect(c.section, a['bunbanNo']);
          expect(c.title, a['gwamokNm']);
          expect(c.professor, a['gyogangsaNms'] ?? a['daepyoGangsaNm'] ?? '');
          expect(c.credits, a['hakjeom']);
          expect(c.campus, campus);
          expect(c.sourceSchedule, a['suupTimes'] ?? '');
          if (c.sourceId == 'hanyang/seoul/2026-2/11311') {
            expect(c.professor, '윤성현');
            expect(c.sourceClassroom, '서울 제3법학관 103호,서울 제3법학관 103호');
            expect(
              meta['currentOfficialClassroomCorrection']['originalSourceClassroom'],
              a['suupRoomNms'],
            );
          } else if (recensusRooms.containsKey(c.sourceId)) {
            // 2026-10-24 public catalog re-census changed only the rooms.
            final fix = meta['currentOfficialClassroomCorrection'] as Map;
            expect(fix['originalSourceClassroom'], a['suupRoomNms']);
            expect(c.sourceClassroom, recensusRooms[c.sourceId]);
            expect(fix['changedSourceClassroom'], c.sourceClassroom);
          } else {
            expect(c.sourceClassroom, a['suupRoomNms'] ?? '');
          }
          expect(r['departmentClassifications'], {
            for (final alias in original['officialAliases'] as List)
              alias['banSosokNm']: alias['isuGbNm'],
          });
          expect(r['departmentCredits'], {
            for (final alias in original['officialAliases'] as List)
              alias['banSosokNm']: alias['hakjeom'],
          });
          final note = c
              .toTimetable(id: c.sourceId, mode: LectureMode.inPerson)
              .note;
          expect(RegExp(r'공개 (?:정규 )?주간 예약 계획').hasMatch(note), true);
          expect(
            note,
            anyOf(
              contains('개별 출석·중간/기말시험·보강·휴강·운영 전환 날짜는 미확인'),
              contains('실제 출석·시험·휴강·보강 날짜 확정이 아닙니다'),
            ),
          );
          for (final restriction in original['restrictions'] as List) {
            expect(note, contains(jsonEncode(restriction)));
          }
          if (c.meetings.isEmpty) {
            expect((meta['reservationProjection'] as Map)['eligible'], false);
            expect(r['period'], isNull);
            continue;
          }
          expect((meta['reservationProjection'] as Map)['eligible'], true);
          expect(
            (meta['reservationProjection'] as Map)['heldReasons'],
            isEmpty,
          );
          // 원문에 시각이 없어 학과 공지 시간표로 확정한 집중수업(2026-11-23).
          final alternate = meta['alternatePublishedSchedule'] as Map?;
          if (alternate != null) {
            final spec = nursing[c.sourceId.split('/').last]!;
            expect(c.period?.start, DateTime.parse(spec.$1));
            expect(c.period?.end, DateTime.parse(spec.$2));
            final want = <String>[];
            for (
              var d = DateTime.parse(spec.$1);
              !d.isAfter(DateTime.parse(spec.$2));
              d = DateTime(d.year, d.month, d.day + 1)
            ) {
              final date = d.toIso8601String().substring(0, 10);
              if (holidays.contains(date)) continue;
              for (final slot in spec.$3) {
                if (slot.$1 == d.weekday) {
                  want.add('$date/${slot.$1}/${slot.$2}/${slot.$3}/${slot.$4}');
                }
              }
            }
            expect(
              c.meetings
                  .map(
                    (m) =>
                        '${m.date}/${m.weekday}/${m.originalStartMinute}/${m.originalEndMinute}/${m.classroom}',
                  )
                  .toList(),
              want,
              reason: c.sourceId,
            );
            continue;
          }
          // Independently derive exact clocks and campus rooms from native fields.
          final pattern = RegExp(
            r'([월화수목금토일])\((\d{2}):(\d{2})-(\d{2}):(\d{2})\)',
          );
          final matches = pattern.allMatches(a['suupTimes'] as String).toList();
          final parts = (a['suupTimes'] as String)
              .split(',')
              .map((s) => s.trim())
              .toList();
          var cells = c.sourceClassroom
                  .split(',')
                  .map((s) => s.trim())
                  .toList();
          // 강의실 칸 수가 시간 칸 수와 다르면 실제 강의실 이름만 모아 모든 구간에 적는다.
          if (cells.length != parts.length) {
            final real = cells
                .where((s) => s.isNotEmpty && !s.startsWith('비지정('))
                .toSet()
                .join(', ');
            cells = List.filled(parts.length, real);
          }
          final rooms = [
            for (var i = 0; i < parts.length; i++)
              if (parts[i] != '시간미지정강좌') cells[i],
          ];
          expect(rooms, hasLength(matches.length));
          expect(
            (a['suupTimes'] as String)
                .replaceAll(pattern, '')
                .replaceAll('시간미지정강좌', '')
                .replaceAll(',', '')
                .trim(),
            isEmpty,
          );
          final expected = <Map<String, dynamic>>[];
          for (
            var d = DateTime(2026, 9, 1);
            !d.isAfter(DateTime(2026, 12, 21));
            d = DateTime(d.year, d.month, d.day + 1)
          ) {
            final date = d.toIso8601String().substring(0, 10);
            if (holidays.contains(date)) continue;
            for (var i = 0; i < matches.length; i++) {
              final m = matches[i];
              final weekday = '월화수목금토일'.indexOf(m[1]!) + 1;
              // 2026-11-23 사용자 결정: 원격·캠퍼스 표기 없는 강의실도 원문 시각으로 확정한다.
              // 캠퍼스 이름이 붙은 강의실은 그 강좌 캠퍼스여야 한다.
              expect(a['campusNm'], campus == 'seoul' ? '서울' : 'ERICA');
              expect(
                rooms[i].startsWith(campus == 'seoul' ? 'ERICA ' : '서울 '),
                false,
              );
              if (d.weekday == weekday) {
                expected.add({
                  'date': date,
                  'weekday': weekday,
                  'startMinute': int.parse(m[2]!) * 60 + int.parse(m[3]!),
                  'endMinute': int.parse(m[4]!) * 60 + int.parse(m[5]!),
                  'classroom': rooms[i].startsWith('비지정(') ? '' : rooms[i],
                });
              }
            }
          }
          expect(c.meetings, hasLength(expected.length));
          for (var i = 0; i < expected.length; i++) {
            final m = c.meetings[i], e = expected[i];
            expect(m.date, e['date']);
            expect(m.weekday, e['weekday']);
            expect(m.originalStartMinute, e['startMinute']);
            expect(m.originalEndMinute, e['endMinute']);
            expect(m.classroom, e['classroom']);
          }
        }
        final nativeWeekend = {
          for (final c in scheduled)
            if (RegExp(r'[토일]\(').hasMatch(
              originals[c.sourceId
                      .split('/')
                      .last]!['officialAliases'][0]['suupTimes']
                  as String,
            ))
              c.sourceId,
        };
        expect(
          scheduled
              .where((c) => c.meetings.any((m) => m.weekday > 5))
              .map((c) => c.sourceId)
              .toSet(),
          nativeWeekend,
        );
        for (final mode in [
          LectureMode.inPerson,
          LectureMode.liveOnline,
          LectureMode.video,
        ]) {
          final classes = scheduled
              .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
              .toList();
          final doc = TimetableSyncDocument.legacy(
            courses: classes,
            termNames: {},
            activeYear: 2026,
            activeSemester: '2',
          );
          final restored = TimetableSyncDocument.fromJson(
            jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
          ).materializeClasses();
          expect(restored, hasLength(eligibleCount));
          final lookup = {for (final c in classes) c.sourceId: c};
          for (final c in restored) {
            expect(c.isValid, true);
            expect(c.defaultMode, mode);
            expect(
              c.toJson()..remove('id'),
              lookup[c.sourceId]!.toJson()..remove('id'),
            );
            expect(c.meetings.every((m) => m.date != null), true);
            expect(c.meetings.any((m) => m.date == '2026-12-22'), false);
          }
        }
      }
    },
  );
}
