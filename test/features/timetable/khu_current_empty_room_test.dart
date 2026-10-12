import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';

const dir =
    'work/university-research/catalog-c/khu-empty-room-ordinary-followup-v6-20261009';
const oldDir =
    'work/university-research/catalog-c/khu-conditional-date-allocation-followup-v5-20261009';
Map<String, dynamic> read(String path) {
  final actual = path;
  final data =
      jsonDecode(File(actual).readAsStringSync()) as Map<String, dynamic>;
  for (final c in data['courses'] as List? ?? []) {
    if (c['metadata']?.containsKey('researchOnly') == true) {
      c['metadata']['researchOnly'] = false;
    }
  }
  return data;
}

void main() {
  test(
    'KHU v6 73 native empty-room reviews, 41 literal clocks, prior1906 deep, three modes and full Drive',
    () {
      final proof = read('$dir/independent-native-clock-date-proof.json');
      final review = read('$dir/all73-individual-operating-source-review.json');
      expect(review['reviews'], hasLength(73));
      expect(proof['proofs'], hasLength(41));
      for (final entry in (proof['sourceInputsSHA256'] as Map).entries) {
        expect(
          sha256
              .convert(File(entry.key as String).readAsBytesSync())
              .toString(),
          entry.value,
        );
      }
      final previous = <String, dynamic>{};
      final raw = <String, dynamic>{};
      final courses = <UniversityCourse>[];
      for (final campus in ['seoul', 'global']) {
        final old = read(
          '$oldDir/khu-$campus-2026-2.conditional-operating-research-v5-20261009.json',
        );
        final current = read(
          '$dir/khu-$campus-2026-2.empty-room-research-v6-20261009.json',
        );
        for (final c in old['courses']) {
          previous[c['sourceId']] = c;
        }
        for (final c in current['courses']) {
          raw[c['sourceId']] = c;
        }
        courses.addAll(UniversityDataset.fromJson(current).courses);
      }
      expect(raw, hasLength(4666));
      expect(raw.keys.toSet(), previous.keys.toSet());
      final additions = {for (final p in proof['proofs']) p['sourceId']: p};
      var oldCount = 0;
      var oldDates = 0;
      var addedDates = 0;
      final slot = RegExp(
        r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(([^()]*)\)',
      );
      final range = RegExp(r'^(\d+)/(\d+)\s*~\s*(\d+)/(\d+)$');
      final exception = RegExp(
        r'시험|고사|중간평가|기말평가|종합평가|최종평가|보강|추석|휴강|휴일|midterm|final\s*(exam|test)',
        caseSensitive: false,
      );
      const holidays = {
        '2026-09-24',
        '2026-09-25',
        '2026-09-26',
        '2026-10-03',
        '2026-10-05',
        '2026-10-09',
      };
      for (final c in courses) {
        final old = previous[c.sourceId] as Map;
        if (!additions.containsKey(c.sourceId)) {
          expect(raw[c.sourceId], old, reason: c.sourceId);
          if ((old['schedules'] as List).isNotEmpty) {
            oldCount++;
            oldDates += (old['schedules'] as List).length;
          }
          continue;
        }
        expect(old['schedules'], isEmpty);
        for (final e in old.entries) {
          if (!{
            'schedules',
            'scheduleStatus',
            'departmentRemarks',
            'semanticOperatingReview',
          }.contains(e.key)) {
            expect(
              raw[c.sourceId][e.key],
              e.value,
              reason: '${c.sourceId}/${e.key}',
            );
          }
        }
        for (final e in (old['departmentRemarks'] as Map).entries) {
          expect(
            (raw[c.sourceId]['departmentRemarks'][e.key] as String).startsWith(
              (e.value as String).replaceAll(
                '강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.',
                '',
              ),
            ),
            true,
          );
        }
        final item = (review['reviews'] as List).singleWhere(
          (r) => r['sourceId'] == c.sourceId,
        );
        expect(item['selected'], true);
        final excluded = <List<DateTime>>[
          [DateTime(2026, 10, 20), DateTime(2026, 10, 26)],
          [DateTime(2026, 12, 15), DateTime(2026, 12, 21)],
        ];
        for (final source in item['currentOwnPlanProofs']) {
          final plan = read(source['file']);
          expect(plan, source['wholeOriginalEducationalPlan']);
          expect(plan['header'], ['2026학년도 2학기 강의계획서']);
          expect(
            plan['lectureCode'],
            old['sourceEducationalVariants'][0]['lecture_cd'],
          );
          expect(
            plan['queriedProfessorName'],
            isIn(
              (old['sourceEducationalVariants'] as List).map(
                (v) => v['teach_na'],
              ),
            ),
          );
          for (final section in plan['educationalSections']) {
            if (section['section'] != '주별강의내용') {
              continue;
            }
            for (final row in section['rows']) {
              if (row.length < 3 || !RegExp(r'^\d+주$').hasMatch(row[0])) {
                continue;
              }
              final match = range.firstMatch(row[1])!;
              final a = DateTime(
                2026,
                int.parse(match[1]!),
                int.parse(match[2]!),
              );
              final b = DateTime(
                2026,
                int.parse(match[3]!),
                int.parse(match[4]!),
              );
              final text = row.skip(2).join(' ').trim();
              if (exception.hasMatch(text) ||
                  (text.isEmpty && row[0] == '16주')) {
                excluded.add([a, b]);
              }
            }
          }
        }
        if (c.code == 'GEE1638') {
          excluded.add([DateTime(2026, 10, 20), DateTime(2026, 12, 21)]);
        }
        final expected = <String>{};
        for (final m in slot.allMatches(c.sourceSchedule)) {
          final wd = '월화수목금토일'.indexOf(m[1]!) + 1;
          final start = int.parse(m[2]!) * 60 + int.parse(m[3]!);
          final end = int.parse(m[4]!) * 60 + int.parse(m[5]!);
          final room = m[6]!.trim();
          var date = DateTime(2026, 9, 1);
          while (date.weekday != wd) {
            date = date.add(const Duration(days: 1));
          }
          while (!date.isAfter(DateTime(2026, 12, 21))) {
            final key = date.toIso8601String().substring(0, 10);
            if (!holidays.contains(key) &&
                !excluded.any(
                  (r) => !date.isBefore(r[0]) && !date.isAfter(r[1]),
                )) {
              expected.add('$key/$wd/$start/$end/$room');
            }
            date = date.add(const Duration(days: 7));
          }
        }
        expect(
          c.meetings
              .map(
                (m) =>
                    '${m.date}/${m.weekday}/${m.originalStartMinute}/${m.originalEndMinute}/${m.classroom}',
              )
              .toSet(),
          expected,
          reason: c.sourceId,
        );
        expect(c.meetings.length, expected.length);
        expect(
          raw[c.sourceId]['schedules'],
          additions[c.sourceId]['literalDatedMeetings'],
        );
        expect(
          (raw[c.sourceId]['schedules'] as List).every(
            (m) => m['deliveryMode'] == null,
          ),
          true,
        );
        addedDates += c.meetings.length;
      }
      expect(oldCount, 1906);
      expect(oldDates, 35970);
      expect(addedDates, 578);
      expect(courses.where((c) => c.meetings.isNotEmpty), hasLength(1947));
      expect(courses.fold<int>(0, (n, c) => n + c.meetings.length), 36548);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final values = <String, TimetableSyncValue>{};
        for (final c in courses.where((c) => c.meetings.isNotEmpty)) {
          final saved = c.toTimetable(id: c.sourceId, mode: mode);
          expect(saved.isValid, true);
          for (var i = 0; i < saved.meetings.length; i++) {
            final m = saved.meetings[i];
            final published = raw[c.sourceId]['schedules'][i]['deliveryMode'];
            final expected = published == 'inPerson'
                ? LectureMode.inPerson
                : published == 'liveOnline'
                ? LectureMode.liveOnline
                : mode;
            expect(saved.modeOn(m, m.teachingDate!), expected);
            expect(saved.period!.contains(m.teachingDate!), true);
          }
          final key = timetableCourseSyncKey(saved);
          expect(values.containsKey(key), false);
          values[key] = TimetableSyncValue(
            {...saved.toJson(), 'id': key},
            DateTime.utc(2026, 10, 9),
            'research',
          );
        }
        final document = TimetableSyncDocument.records(
          courses: values,
          schemaVersion: 2,
        );
        final encoded =
            jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>;
        final restored = TimetableSyncDocument.fromJson(
          encoded,
        ).materializeClasses();
        expect(restored, hasLength(1947));
        for (final c in restored) {
          expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
        }
        File(
          '$dir/full-timetable-sync-${mode.name}.json',
        ).writeAsStringSync('${jsonEncode(encoded)}\n');
      }
    },
  );
}
