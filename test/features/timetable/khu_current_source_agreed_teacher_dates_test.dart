import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';

const dir =
    'work/university-research/catalog-c/khu-full-operating-context-batches-v8-20261009/outside-shortlist-review-v1/packet038-reviewed30';
dynamic read(String name) {
  final actual = '$dir/$name';
  final data = jsonDecode(fixtureFile(actual).readAsStringSync());
  if (data is Map) {
    for (final c in data['courses'] as List? ?? []) {
      if (c['metadata']?.containsKey('researchOnly') == true) {
        c['metadata']['researchOnly'] = false;
      }
    }
  }
  return data;
}

// Independent source calendar literals, not copied from candidate schedules.
const expectedDates = {
  "khu/2026/2/seoul/GEC0103S05": [
    "2026-09-02",
    "2026-09-09",
    "2026-09-21",
    "2026-09-30",
    "2026-10-28",
    "2026-11-09",
    "2026-11-18",
    "2026-11-30",
    "2026-12-09",
  ],
  "khu/2026/2/seoul/GEC0103S04": [
    "2026-09-02",
    "2026-09-14",
    "2026-09-23",
    "2026-10-07",
    "2026-10-14",
    "2026-10-28",
    "2026-11-04",
    "2026-11-16",
    "2026-11-25",
    "2026-12-07",
  ],
  "khu/2026/2/seoul/GEC0103S24": [
    "2026-09-01",
    "2026-09-08",
    "2026-09-29",
    "2026-10-06",
    "2026-10-13",
  ],
  "khu/2026/2/seoul/GEC0103S25": ["2026-09-01", "2026-10-27"],
  "khu/2026/2/seoul/GEC1102S51": [
    "2026-09-04",
    "2026-09-11",
    "2026-09-18",
    "2026-10-02",
    "2026-10-16",
    "2026-10-30",
    "2026-11-06",
    "2026-11-13",
    "2026-11-20",
    "2026-11-27",
    "2026-12-04",
    "2026-12-11",
  ],
  "khu/2026/2/seoul/GEC1104S48": [
    "2026-09-04",
    "2026-09-11",
    "2026-09-18",
    "2026-10-02",
    "2026-10-16",
    "2026-10-23",
    "2026-11-13",
    "2026-11-20",
    "2026-12-04",
    "2026-12-11",
  ],
  "khu/2026/2/seoul/GEC1104S56": [
    "2026-09-05",
    "2026-09-12",
    "2026-09-19",
    "2026-10-10",
    "2026-10-17",
    "2026-10-24",
    "2026-11-14",
    "2026-11-21",
    "2026-12-05",
    "2026-12-12",
  ],
  "khu/2026/2/seoul/GEC1104S03": [
    "2026-09-07",
    "2026-09-14",
    "2026-09-21",
    "2026-09-28",
    "2026-10-12",
    "2026-10-19",
    "2026-10-26",
    "2026-12-07",
  ],
  "khu/2026/2/seoul/GEC1104S50": [
    "2026-09-07",
    "2026-09-14",
    "2026-09-21",
    "2026-09-28",
    "2026-10-12",
    "2026-10-19",
    "2026-12-07",
  ],
};
const originalSlots = {
  "GEC0103S05": [
    [1, 630, 705, "청207"],
    [3, 630, 705, "청207"],
  ],
  "GEC0103S04": [
    [1, 630, 705, "청207"],
    [3, 630, 705, "청207"],
  ],
  "GEC0103S24": [
    [2, 720, 795, "청309"],
    [4, 720, 795, "청309"],
  ],
  "GEC0103S25": [
    [2, 720, 795, "청309"],
    [4, 720, 795, "청309"],
  ],
  "GEC1102S51": [
    [5, 540, 705, "청203"],
  ],
  "GEC1104S48": [
    [5, 900, 1065, "청503"],
  ],
  "GEC1104S56": [
    [6, 780, 945, "호703"],
  ],
  "GEC1104S03": [
    [1, 720, 885, "청502"],
  ],
  "GEC1104S50": [
    [1, 900, 1065, "청502"],
  ],
};
const rawNativeSlots = {
  "GEC0103S05": [
    [1, 630, 705, "청207"],
    [3, 630, 705, "청207"],
  ],
  "GEC0103S04": [
    [1, 630, 705, "청207"],
    [3, 630, 705, "청207"],
  ],
  "GEC0103S24": [
    [2, 720, 795, "청309"],
    [4, 720, 795, "청309"],
  ],
  "GEC0103S25": [
    [2, 720, 795, "청309"],
    [4, 720, 795, "청309"],
  ],
  "GEC1102S51": [
    [5, 540, 705, "청203"],
  ],
  "GEC1104S48": [
    [5, 900, 1065, "청503"],
  ],
  "GEC1104S56": [
    [6, 780, 945, "호703"],
  ],
  "GEC1104S03": [
    [1, 720, 885, "청502"],
  ],
  "GEC1104S50": [
    [1, 900, 1065, "청502"],
  ],
};
const independentMeetings = {
  "khu/2026/2/seoul/GEC0103S05": [
    ["2026-09-02", 3, 630, 705, "청207"],
    ["2026-09-09", 3, 630, 705, "청207"],
    ["2026-09-21", 1, 630, 705, "청207"],
    ["2026-09-30", 3, 630, 705, "청207"],
    ["2026-10-28", 3, 630, 705, "청207"],
    ["2026-11-09", 1, 630, 705, "청207"],
    ["2026-11-18", 3, 630, 705, "청207"],
    ["2026-11-30", 1, 630, 705, "청207"],
    ["2026-12-09", 3, 630, 705, "청207"],
  ],
  "khu/2026/2/seoul/GEC0103S04": [
    ["2026-09-02", 3, 630, 705, "청207"],
    ["2026-09-14", 1, 630, 705, "청207"],
    ["2026-09-23", 3, 630, 705, "청207"],
    ["2026-10-07", 3, 630, 705, "청207"],
    ["2026-10-14", 3, 630, 705, "청207"],
    ["2026-10-28", 3, 630, 705, "청207"],
    ["2026-11-04", 3, 630, 705, "청207"],
    ["2026-11-16", 1, 630, 705, "청207"],
    ["2026-11-25", 3, 630, 705, "청207"],
    ["2026-12-07", 1, 630, 705, "청207"],
  ],
  "khu/2026/2/seoul/GEC0103S24": [
    ["2026-09-01", 2, 720, 795, "청309"],
    ["2026-09-08", 2, 720, 795, "청309"],
    ["2026-09-29", 2, 720, 795, "청309"],
    ["2026-10-06", 2, 720, 795, "청309"],
    ["2026-10-13", 2, 720, 795, "청309"],
  ],
  "khu/2026/2/seoul/GEC0103S25": [
    ["2026-09-01", 2, 720, 795, "청309"],
    ["2026-10-27", 2, 720, 795, "청309"],
  ],
  "khu/2026/2/seoul/GEC1102S51": [
    ["2026-09-04", 5, 540, 705, "청203"],
    ["2026-09-11", 5, 540, 705, "청203"],
    ["2026-09-18", 5, 540, 705, "청203"],
    ["2026-10-02", 5, 540, 705, "청203"],
    ["2026-10-16", 5, 540, 705, "청203"],
    ["2026-10-30", 5, 540, 705, "청203"],
    ["2026-11-06", 5, 540, 705, "청203"],
    ["2026-11-13", 5, 540, 705, "청203"],
    ["2026-11-20", 5, 540, 705, "청203"],
    ["2026-11-27", 5, 540, 705, "청203"],
    ["2026-12-04", 5, 540, 705, "청203"],
    ["2026-12-11", 5, 540, 705, "청203"],
  ],
  "khu/2026/2/seoul/GEC1104S48": [
    ["2026-09-04", 5, 900, 1065, "청503"],
    ["2026-09-11", 5, 900, 1065, "청503"],
    ["2026-09-18", 5, 900, 1065, "청503"],
    ["2026-10-02", 5, 900, 1065, "청503"],
    ["2026-10-16", 5, 900, 1065, "청503"],
    ["2026-10-23", 5, 900, 1065, "청503"],
    ["2026-11-13", 5, 900, 1065, "청503"],
    ["2026-11-20", 5, 900, 1065, "청503"],
    ["2026-12-04", 5, 900, 1065, "청503"],
    ["2026-12-11", 5, 900, 1065, "청503"],
  ],
  "khu/2026/2/seoul/GEC1104S56": [
    ["2026-09-05", 6, 780, 945, "호703"],
    ["2026-09-12", 6, 780, 945, "호703"],
    ["2026-09-19", 6, 780, 945, "호703"],
    ["2026-10-10", 6, 780, 945, "호703"],
    ["2026-10-17", 6, 780, 945, "호703"],
    ["2026-10-24", 6, 780, 945, "호703"],
    ["2026-11-14", 6, 780, 945, "호703"],
    ["2026-11-21", 6, 780, 945, "호703"],
    ["2026-12-05", 6, 780, 945, "호703"],
    ["2026-12-12", 6, 780, 945, "호703"],
  ],
  "khu/2026/2/seoul/GEC1104S03": [
    ["2026-09-07", 1, 720, 885, "청502"],
    ["2026-09-14", 1, 720, 885, "청502"],
    ["2026-09-21", 1, 720, 885, "청502"],
    ["2026-09-28", 1, 720, 885, "청502"],
    ["2026-10-12", 1, 720, 885, "청502"],
    ["2026-10-19", 1, 720, 885, "청502"],
    ["2026-10-26", 1, 720, 885, "청502"],
    ["2026-12-07", 1, 720, 885, "청502"],
  ],
  "khu/2026/2/seoul/GEC1104S50": [
    ["2026-09-07", 1, 900, 1065, "청502"],
    ["2026-09-14", 1, 900, 1065, "청502"],
    ["2026-09-21", 1, 900, 1065, "청502"],
    ["2026-09-28", 1, 900, 1065, "청502"],
    ["2026-10-12", 1, 900, 1065, "청502"],
    ["2026-10-19", 1, 900, 1065, "청502"],
    ["2026-12-07", 1, 900, 1065, "청502"],
  ],
};
void main() {
  test(
    'KHU packet038 fifteen exact own physical groups preserve whole4666 and full3modeDrive',
    () {
      final old = <String, dynamic>{};
      final raw = <String, dynamic>{};
      final courses = <UniversityCourse>[];
      for (final campus in ['seoul', 'global']) {
        final previous = read('packet038-prior-$campus-whole.json');
        final current = read(
          'khu-$campus-2026-2.packet038-physical-groups-prepared.json',
        );
        for (final c in previous['courses']) {
          old[c['sourceId']] = c;
        }
        for (final c in current['courses']) {
          raw[c['sourceId']] = c;
        }
        courses.addAll(UniversityDataset.fromJson(current).courses);
      }
      expect(old, hasLength(4666));
      expect(raw.keys.toSet(), old.keys.toSet());
      expect(
        read('packet038-review-decisions.json')['decisions'],
        hasLength(30),
      );
      final proof = read('packet038-independent-proof.json');
      expect(proof['proofs'], hasLength(9));
      for (final p in proof['proofs']) {
        expect(
          p['previousResearchDepartmentRemarks'],
          old[p['sourceId']]['departmentRemarks'],
        );
      }
      for (final code in [
        'GEC0103S18',
        'GEC1102S16',
        'GEC1102S53',
        'GEC1102S54',
        'GEC1104S19',
        'GEC1104S59',
        'GEC1104S23',
        'GEC1104S30',
      ]) {
        final sid = 'khu/2026/2/seoul/$code';
        expect(raw[sid], old[sid]);
        expect(raw[sid]['schedules'], isEmpty);
      }
      for (final pair in [
        ['GEC0103S05', '2026-10-19'],
        ['GEC0103S05', '2026-10-21'],
        ['GEC0103S05', '2026-10-26'],
        ['GEC0103S25', '2026-09-08'],
        ['GEC0103S25', '2026-09-10'],
        ['GEC1104S03', '2026-10-12'],
        ['GEC1104S48', '2026-11-06'],
        ['GEC1104S56', '2026-11-07'],
        ['GEC1104S50', '2026-10-26'],
      ]) {
        if (pair[0] == 'GEC1104S03') {
          expect(
            (raw['khu/2026/2/seoul/${pair[0]}']['schedules'] as List).any(
              (m) => m['date'] == pair[1],
            ),
            true,
          );
          continue;
        }
        expect(
          (raw['khu/2026/2/seoul/${pair[0]}']['schedules'] as List).any(
            (m) => m['date'] == pair[1],
          ),
          false,
        );
      }
      var originalCourses = 0;
      var originalDates = 0;
      var added = 0;
      for (final c in courses) {
        final previous = old[c.sourceId] as Map;
        if (!expectedDates.containsKey(c.sourceId)) {
          expect(raw[c.sourceId], previous, reason: c.sourceId);
          if ((previous['schedules'] as List).isNotEmpty) {
            originalCourses++;
            originalDates += (previous['schedules'] as List).length;
          }
          continue;
        }
        expect(previous['schedules'], isEmpty);
        for (final entry in previous.entries) {
          if (!{
            'schedules',
            'scheduleStatus',
            'departmentRemarks',
            'semanticOperatingReview',
          }.contains(entry.key)) {
            expect(
              raw[c.sourceId][entry.key],
              entry.value,
              reason: '${c.sourceId}/${entry.key}',
            );
          }
        }
        for (final entry in (previous['departmentRemarks'] as Map).entries) {
          final original = entry.value as String;
          final schoolRemaining = original
              .replaceAll(
                '강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.\n',
                '',
              )
              .replaceAll(
                '강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.',
                '',
              )
              .replaceAll(
                '현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.',
                '',
              );
          expect(
            raw[c.sourceId]['departmentRemarks'][entry.key],
            '$schoolRemaining\n현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.',
          );
        }
        expect(c.campus, previous['campus']);
        expect(
          c.meetings.map((m) => m.date).toSet(),
          expectedDates[c.sourceId]!.toSet(),
        );
        expect(c.meetings.length, independentMeetings[c.sourceId]!.length);
        final nativeCode =
            (previous['sourceEducationalVariants'] as List).first['lecture_cd']
                as String;
        final pattern = RegExp(
          r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)',
        );
        final parsedNative = pattern
            .allMatches(previous['sourceSchedule'] as String)
            .map(
              (m) => <Object>[
                '월화수목금토일'.indexOf(m[1]!) + 1,
                int.parse(m[2]!) * 60 + int.parse(m[3]!),
                int.parse(m[4]!) * 60 + int.parse(m[5]!),
                m[6]!.trim(),
              ],
            )
            .toList();
        expect(parsedNative, rawNativeSlots[nativeCode]);
        if (nativeCode == 'MEDIC100900') {
          expect(parsedNative, hasLength(8));
          expect(parsedNative[2], parsedNative[0]);
          expect(parsedNative[3], parsedNative[1]);
          expect(parsedNative[5], parsedNative[1]);
          expect(parsedNative[6], parsedNative[4]);
          expect(parsedNative[7], parsedNative[0]);
        }
        if (nativeCode == 'KMS121500' || nativeCode == 'KMS121501') {
          expect(c.meetings.every((m) => m.weekday == 4), true);
        }
        final slots = originalSlots[nativeCode]!;
        for (final m in c.meetings) {
          final hh = slots.singleWhere(
            (h) =>
                h[0] == m.weekday &&
                h[1] == m.originalStartMinute &&
                h[2] == m.originalEndMinute,
          );
          expect(m.originalStartMinute, hh[1]);
          expect(m.originalEndMinute, hh[2]);
          final source = independentMeetings[c.sourceId]!.singleWhere(
            (v) =>
                v[0] == m.date &&
                v[1] == m.weekday &&
                v[2] == m.originalStartMinute &&
                v[3] == m.originalEndMinute,
          );
          expect(m.classroom, source[4]);
          expect(m.teachingDate!.weekday, m.weekday);
        }
        expect(
          (raw[c.sourceId]['schedules'] as List).every(
            (m) => m['deliveryMode'] == null,
          ),
          true,
        );
        added += c.meetings.length;
      }
      expect(originalCourses, 2937);
      expect(originalDates, 54960);
      expect(added, 73);
      expect(courses.where((c) => c.meetings.isNotEmpty), hasLength(2946));
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
        expect(restored, hasLength(2946));
        for (final c in restored) {
          expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
        }
      }
    },
  );
}
