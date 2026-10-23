import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    '904 practice-only source semantics identify903 ordinary candidates, whole previous2552 preserved',
    () {
      const root =
          'work/university-research/catalog-c/hanyang-ordinary-source-semantic-v2-20261009/';
      final proofs =
          jsonDecode(
                fixtureFile(
                  '${root}independent-native-course-semantic-review.json',
                ).readAsStringSync(),
              )
              as List;
      expect(proofs, hasLength(904));
      expect(
        proofs.where(
          (r) => r['decision'] == 'ordinaryPublishedWeeklyReservation',
        ),
        hasLength(903),
      );
      final pending = proofs.singleWhere(
        (r) => r['decision'] != 'ordinaryPublishedWeeklyReservation',
      );
      expect(pending['sourceId'], 'hanyang/erica/2026-2/24314');
      expect(pending['nativeViewtype'], '온오프동시');
      final audit = jsonDecode(
        fixtureFile('${root}candidate-audit.json').readAsStringSync(),
      );
      expect(
        (audit['campuses'] as List).fold<int>(
          0,
          (n, c) => n + (c['metadata'] as int),
        ),
        4961,
      );
      expect(
        (audit['campuses'] as List).fold<int>(
          0,
          (n, c) => n + (c['scheduled'] as int),
        ),
        3455,
      );
      expect(
        (audit['campuses'] as List).fold<int>(
          0,
          (n, c) => n + (c['meetings'] as int),
        ),
        83940,
      );
    },
  );

  test(
    'Hanyang complete native source and conservative own-term reservation dates survive all modes and full Drive JSON',
    () {
      const root =
          'work/university-research/catalog-c/hanyang-ordinary-source-semantic-v2-20261009/';
      Map<String, dynamic> read(String path) {
        final data =
            jsonDecode(fixtureFile(path).readAsStringSync())
                as Map<String, dynamic>;
        for (final row in data['courses'] ?? []) {
          if (row['metadata']?.containsKey('researchOnly') == true) {
            row['metadata']['researchOnly'] = false;
          }
        }
        return data;
      }

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
      for (final campus in ['seoul', 'erica']) {
        final raw = read(
          '${root}hanyang-$campus-2026-2.ordinary-source-semantic-candidate-v2.json',
        );
        final rawRows = {
          for (final r in raw['courses'] as List) r['sourceId']: r,
        };
        final previous =
            read('${root}baseline-$campus-frozen-v1.json')['courses'] as List;
        final priorById = {for (final r in previous) r['sourceId']: r};
        final dataset = UniversityDataset.fromJson(raw);
        final count = campus == 'seoul' ? 2805 : 2156;
        final eligibleCount = campus == 'seoul' ? 1997 : 1458;
        final datedCount = campus == 'seoul' ? 47526 : 36414;
        expect(dataset.courses, hasLength(count));
        expect(
          dataset.courses.map((c) => c.sourceId).toSet(),
          hasLength(count),
        );
        expect(raw['termStartDate'], '2026-09-01');
        expect(raw['termEndDate'], '2026-12-21');
        // Each campus's own current calendar fixture independently agrees.
        final calendar = read('${root}own-$campus-2026-calendar-frozen.json');
        final calendarRows = (jsonDecode(calendar['data'] as String) as List)
            .expand((m) => m['events'] as List)
            .toList();
        expect(
          calendarRows.any(
            (r) =>
                r['subject'] == '2026학년도 2학기 개강' &&
                (r['startDateTime'] as String).startsWith('2026-09-01'),
          ),
          true,
        );
        expect(
          calendarRows.any(
            (r) =>
                r['subject'] == '2026학년도 2학기 종강' &&
                (r['startDateTime'] as String).startsWith('2026-12-21'),
          ),
          true,
        );
        expect(
          calendarRows.any(
            (r) =>
                r['subject'] == '보강가능일' &&
                (r['startDateTime'] as String).startsWith('2026-12-22'),
          ),
          true,
        );
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
          expect(c.sourceClassroom, a['suupRoomNms'] ?? '');
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
          final before = priorById[c.sourceId]!;
          final changed = before['schedules'].isEmpty && c.meetings.isNotEmpty;
          if (!changed) {
            expect(r, before);
          } else {
            for (final e in (before as Map).entries) {
              if ([
                'schedules',
                'scheduleStatus',
                'remarks',
                'departmentRemarks',
                'period',
                'metadata',
              ].contains(e.key)) {
                continue;
              }
              expect(r[e.key], e.value);
            }
            expect(note, contains('실습 시수 값만으로 정규 공개 강의시각 전체를 보류했던 기준을 교정'));
            expect(a['suupOprNm'], '일반');
            expect(a['suupUnitCnt'], 16);
            expect(original['operatingGaps'], isEmpty);
            expect(a['suupViewtypeNm'], anyOf(isNull, '대면'));
          }
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
          expect(c.departments.any((d) => d == '의학과' || d == '의예과'), false);
          // Independently derive exact clocks and campus rooms from native fields.
          final pattern = RegExp(
            r'([월화수목금토일])\((\d{2}):(\d{2})-(\d{2}):(\d{2})\)',
          );
          final matches = pattern.allMatches(a['suupTimes'] as String).toList();
          final rooms = (a['suupRoomNms'] as String)
              .split(',')
              .map((s) => s.trim())
              .toList();
          expect(rooms, hasLength(matches.length));
          expect(
            (a['suupTimes'] as String)
                .replaceAll(pattern, '')
                .replaceAll(',', '')
                .trim(),
            isEmpty,
          );
          final expected = <Map<String, dynamic>>[];
          for (
            var d = DateTime(2026, 9, 1);
            !d.isAfter(DateTime(2026, 12, 21));
            d = d.add(const Duration(days: 1))
          ) {
            final date = d.toIso8601String().substring(0, 10);
            if (holidays.contains(date)) continue;
            for (var i = 0; i < matches.length; i++) {
              final m = matches[i];
              final weekday = '월화수목금토일'.indexOf(m[1]!) + 1;
              expect(
                rooms[i],
                startsWith(campus == 'seoul' ? '서울 ' : 'ERICA '),
              );
              if (d.weekday == weekday) {
                expected.add({
                  'date': date,
                  'weekday': weekday,
                  'startMinute': int.parse(m[2]!) * 60 + int.parse(m[3]!),
                  'endMinute': int.parse(m[4]!) * 60 + int.parse(m[5]!),
                  'classroom': rooms[i],
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
        expect(
          scheduled.where((c) => c.meetings.any((m) => m.weekday > 5)),
          hasLength(campus == 'seoul' ? 5 : 44),
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
