// Historical frozen-source packet regression. Latest packaged sources are
// checked by packaged_asset_source_integrity_test and resumed_batch_changed_courses_test.
import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';

const dir =
    'work/university-research/catalog-c/khu-full-operating-context-batches-v8-20261009/outside-shortlist-review-v1/packet042-reviewed30';
dynamic read(String name) {
  final actual = '$dir/$name';
  final data = jsonDecode(File(actual).readAsStringSync());
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
  "khu/2026/2/seoul/GEE11007S00": [
    "2026-09-01",
    "2026-09-08",
    "2026-09-15",
    "2026-09-22",
    "2026-09-29",
    "2026-12-01",
    "2026-12-08",
  ],
  "khu/2026/2/seoul/GEE11027S00": [
    "2026-09-01",
    "2026-09-03",
    "2026-09-08",
    "2026-09-10",
    "2026-09-15",
    "2026-09-17",
    "2026-09-22",
    "2026-09-29",
    "2026-10-01",
    "2026-10-06",
    "2026-10-08",
    "2026-10-13",
    "2026-10-15",
    "2026-10-27",
    "2026-10-29",
    "2026-11-03",
    "2026-11-05",
    "2026-11-10",
    "2026-11-12",
    "2026-11-17",
    "2026-11-19",
    "2026-11-24",
    "2026-11-26",
    "2026-12-01",
    "2026-12-03",
    "2026-12-08",
    "2026-12-10",
  ],
  "khu/2026/2/seoul/GEE11019S00": [
    "2026-09-02",
    "2026-09-09",
    "2026-09-16",
    "2026-09-23",
    "2026-09-30",
    "2026-10-07",
    "2026-10-14",
    "2026-10-28",
    "2026-11-04",
    "2026-11-11",
    "2026-11-18",
    "2026-11-25",
    "2026-12-02",
    "2026-12-09",
  ],
  "khu/2026/2/seoul/GEE11038S00": [
    "2026-09-02",
    "2026-09-09",
    "2026-09-16",
    "2026-09-23",
    "2026-09-30",
    "2026-10-07",
    "2026-10-28",
    "2026-11-11",
    "2026-11-18",
    "2026-11-25",
    "2026-12-09",
  ],
  "khu/2026/2/seoul/GEE11039S00": ["2026-12-04"],
  "khu/2026/2/seoul/ETC0515S00": [
    "2026-09-02",
    "2026-09-09",
    "2026-09-16",
    "2026-09-23",
    "2026-09-30",
    "2026-10-07",
    "2026-10-14",
    "2026-10-28",
    "2026-11-04",
    "2026-11-11",
    "2026-11-18",
    "2026-11-25",
    "2026-12-02",
    "2026-12-09",
  ],
  "khu/2026/2/seoul/ETC1514S00": [
    "2026-09-03",
    "2026-09-10",
    "2026-09-17",
    "2026-10-01",
    "2026-10-08",
    "2026-10-15",
    "2026-10-29",
    "2026-11-05",
    "2026-11-12",
    "2026-11-19",
    "2026-11-26",
    "2026-12-03",
  ],
  "khu/2026/2/seoul/EDU2107S00": [
    "2026-09-02",
    "2026-09-09",
    "2026-09-16",
    "2026-09-23",
    "2026-09-30",
    "2026-10-07",
    "2026-10-14",
    "2026-10-28",
    "2026-11-04",
    "2026-11-11",
    "2026-11-18",
    "2026-11-25",
    "2026-12-02",
  ],
  "khu/2026/2/seoul/EDU3103S00": [
    "2026-09-01",
    "2026-09-08",
    "2026-09-15",
    "2026-09-22",
    "2026-09-29",
    "2026-10-06",
    "2026-10-13",
    "2026-10-20",
    "2026-10-27",
    "2026-11-03",
    "2026-11-10",
    "2026-11-17",
    "2026-11-24",
    "2026-12-01",
  ],
};
const originalSlots = {
  "GEE11007S00": [
    [2, 900, 1065, "네104"],
  ],
  "GEE11027S00": [
    [2, 720, 795, "청407"],
    [4, 720, 795, "청407"],
  ],
  "GEE11019S00": [
    [3, 720, 885, "네B201"],
  ],
  "GEE11038S00": [
    [3, 900, 1065, "네B201"],
  ],
  "GEE11039S00": [
    [5, 540, 705, "네105"],
  ],
  "ETC0515S00": [
    [3, 720, 830, "네105"],
  ],
  "ETC1514S00": [
    [4, 960, 1070, "청715"],
  ],
  "EDU2107S00": [
    [3, 960, 1070, "청303"],
  ],
  "EDU3103S00": [
    [2, 600, 710, "청303"],
  ],
};
const rawNativeSlots = {
  "GEE11007S00": [
    [2, 900, 1065, "네104"],
  ],
  "GEE11027S00": [
    [2, 720, 795, "청407"],
    [4, 720, 795, "청407"],
  ],
  "GEE11019S00": [
    [3, 720, 885, "네B201"],
  ],
  "GEE11038S00": [
    [3, 900, 1065, "네B201"],
  ],
  "GEE11039S00": [
    [5, 540, 705, "네105"],
  ],
  "ETC0515S00": [
    [3, 720, 830, "네105"],
  ],
  "ETC1514S00": [
    [4, 960, 1070, "청715"],
  ],
  "EDU2107S00": [
    [3, 960, 1070, "청303"],
  ],
  "EDU3103S00": [
    [2, 600, 710, "청303"],
  ],
};
const independentMeetings = {
  "khu/2026/2/seoul/GEE11007S00": [
    ["2026-09-01", 2, 900, 1065, "네104"],
    ["2026-09-08", 2, 900, 1065, "네104"],
    ["2026-09-15", 2, 900, 1065, "네104"],
    ["2026-09-22", 2, 900, 1065, "네104"],
    ["2026-09-29", 2, 900, 1065, "네104"],
    ["2026-12-01", 2, 900, 1065, "네104"],
    ["2026-12-08", 2, 900, 1065, "네104"],
  ],
  "khu/2026/2/seoul/GEE11027S00": [
    ["2026-09-01", 2, 720, 795, "청407"],
    ["2026-09-03", 4, 720, 795, "청407"],
    ["2026-09-08", 2, 720, 795, "청407"],
    ["2026-09-10", 4, 720, 795, "청407"],
    ["2026-09-15", 2, 720, 795, "청407"],
    ["2026-09-17", 4, 720, 795, "청407"],
    ["2026-09-22", 2, 720, 795, "청407"],
    ["2026-09-29", 2, 720, 795, "청407"],
    ["2026-10-01", 4, 720, 795, "청407"],
    ["2026-10-06", 2, 720, 795, "청407"],
    ["2026-10-08", 4, 720, 795, "청407"],
    ["2026-10-13", 2, 720, 795, "청407"],
    ["2026-10-15", 4, 720, 795, "청407"],
    ["2026-10-27", 2, 720, 795, "청407"],
    ["2026-10-29", 4, 720, 795, "청407"],
    ["2026-11-03", 2, 720, 795, "청407"],
    ["2026-11-05", 4, 720, 795, "청407"],
    ["2026-11-10", 2, 720, 795, "청407"],
    ["2026-11-12", 4, 720, 795, "청407"],
    ["2026-11-17", 2, 720, 795, "청407"],
    ["2026-11-19", 4, 720, 795, "청407"],
    ["2026-11-24", 2, 720, 795, "청407"],
    ["2026-11-26", 4, 720, 795, "청407"],
    ["2026-12-01", 2, 720, 795, "청407"],
    ["2026-12-03", 4, 720, 795, "청407"],
    ["2026-12-08", 2, 720, 795, "청407"],
    ["2026-12-10", 4, 720, 795, "청407"],
  ],
  "khu/2026/2/seoul/GEE11019S00": [
    ["2026-09-02", 3, 720, 885, "네B201"],
    ["2026-09-09", 3, 720, 885, "네B201"],
    ["2026-09-16", 3, 720, 885, "네B201"],
    ["2026-09-23", 3, 720, 885, "네B201"],
    ["2026-09-30", 3, 720, 885, "네B201"],
    ["2026-10-07", 3, 720, 885, "네B201"],
    ["2026-10-14", 3, 720, 885, "네B201"],
    ["2026-10-28", 3, 720, 885, "네B201"],
    ["2026-11-04", 3, 720, 885, "네B201"],
    ["2026-11-11", 3, 720, 885, "네B201"],
    ["2026-11-18", 3, 720, 885, "네B201"],
    ["2026-11-25", 3, 720, 885, "네B201"],
    ["2026-12-02", 3, 720, 885, "네B201"],
    ["2026-12-09", 3, 720, 885, "네B201"],
  ],
  "khu/2026/2/seoul/GEE11038S00": [
    ["2026-09-02", 3, 900, 1065, "네B201"],
    ["2026-09-09", 3, 900, 1065, "네B201"],
    ["2026-09-16", 3, 900, 1065, "네B201"],
    ["2026-09-23", 3, 900, 1065, "네B201"],
    ["2026-09-30", 3, 900, 1065, "네B201"],
    ["2026-10-07", 3, 900, 1065, "네B201"],
    ["2026-10-28", 3, 900, 1065, "네B201"],
    ["2026-11-11", 3, 900, 1065, "네B201"],
    ["2026-11-18", 3, 900, 1065, "네B201"],
    ["2026-11-25", 3, 900, 1065, "네B201"],
    ["2026-12-09", 3, 900, 1065, "네B201"],
  ],
  "khu/2026/2/seoul/GEE11039S00": [
    ["2026-12-04", 5, 540, 705, "네105"],
  ],
  "khu/2026/2/seoul/ETC0515S00": [
    ["2026-09-02", 3, 720, 830, "네105"],
    ["2026-09-09", 3, 720, 830, "네105"],
    ["2026-09-16", 3, 720, 830, "네105"],
    ["2026-09-23", 3, 720, 830, "네105"],
    ["2026-09-30", 3, 720, 830, "네105"],
    ["2026-10-07", 3, 720, 830, "네105"],
    ["2026-10-14", 3, 720, 830, "네105"],
    ["2026-10-28", 3, 720, 830, "네105"],
    ["2026-11-04", 3, 720, 830, "네105"],
    ["2026-11-11", 3, 720, 830, "네105"],
    ["2026-11-18", 3, 720, 830, "네105"],
    ["2026-11-25", 3, 720, 830, "네105"],
    ["2026-12-02", 3, 720, 830, "네105"],
    ["2026-12-09", 3, 720, 830, "네105"],
  ],
  "khu/2026/2/seoul/ETC1514S00": [
    ["2026-09-03", 4, 960, 1070, "청715"],
    ["2026-09-10", 4, 960, 1070, "청715"],
    ["2026-09-17", 4, 960, 1070, "청715"],
    ["2026-10-01", 4, 960, 1070, "청715"],
    ["2026-10-08", 4, 960, 1070, "청715"],
    ["2026-10-15", 4, 960, 1070, "청715"],
    ["2026-10-29", 4, 960, 1070, "청715"],
    ["2026-11-05", 4, 960, 1070, "청715"],
    ["2026-11-12", 4, 960, 1070, "청715"],
    ["2026-11-19", 4, 960, 1070, "청715"],
    ["2026-11-26", 4, 960, 1070, "청715"],
    ["2026-12-03", 4, 960, 1070, "청715"],
  ],
  "khu/2026/2/seoul/EDU2107S00": [
    ["2026-09-02", 3, 960, 1070, "청303"],
    ["2026-09-09", 3, 960, 1070, "청303"],
    ["2026-09-16", 3, 960, 1070, "청303"],
    ["2026-09-23", 3, 960, 1070, "청303"],
    ["2026-09-30", 3, 960, 1070, "청303"],
    ["2026-10-07", 3, 960, 1070, "청303"],
    ["2026-10-14", 3, 960, 1070, "청303"],
    ["2026-10-28", 3, 960, 1070, "청303"],
    ["2026-11-04", 3, 960, 1070, "청303"],
    ["2026-11-11", 3, 960, 1070, "청303"],
    ["2026-11-18", 3, 960, 1070, "청303"],
    ["2026-11-25", 3, 960, 1070, "청303"],
    ["2026-12-02", 3, 960, 1070, "청303"],
  ],
  "khu/2026/2/seoul/EDU3103S00": [
    ["2026-09-01", 2, 600, 710, "청303"],
    ["2026-09-08", 2, 600, 710, "청303"],
    ["2026-09-15", 2, 600, 710, "청303"],
    ["2026-09-22", 2, 600, 710, "청303"],
    ["2026-09-29", 2, 600, 710, "청303"],
    ["2026-10-06", 2, 600, 710, "청303"],
    ["2026-10-13", 2, 600, 710, "청303"],
    ["2026-10-20", 2, 600, 710, "청303"],
    ["2026-10-27", 2, 600, 710, "청303"],
    ["2026-11-03", 2, 600, 710, "청303"],
    ["2026-11-10", 2, 600, 710, "청303"],
    ["2026-11-17", 2, 600, 710, "청303"],
    ["2026-11-24", 2, 600, 710, "청303"],
    ["2026-12-01", 2, 600, 710, "청303"],
  ],
};
void main() {
  test(
    'KHU packet042 nineteen exact own physical groups preserve whole4666 and full3modeDrive',
    () {
      final old = <String, dynamic>{};
      final raw = <String, dynamic>{};
      final courses = <UniversityCourse>[];
      for (final campus in ['seoul', 'global']) {
        final previous = read('packet042-prior-$campus-whole.json');
        final current = read(
          'khu-$campus-2026-2.packet042-physical-groups-prepared.json',
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
        read('packet042-review-decisions.json')['decisions'],
        hasLength(30),
      );
      final proof = read('packet042-independent-proof.json');
      expect(proof['proofs'], hasLength(9));
      for (final p in proof['proofs']) {
        expect(
          p['previousResearchDepartmentRemarks'],
          old[p['sourceId']]['departmentRemarks'],
        );
      }
      for (final code in [
        'GEE11016S00',
        'GEE1345S00',
        'GEE1988S00',
        'GEE1986S00',
        'GEE1953S00',
        'GEE1987S00',
        'EDU3106S00',
        'EDU3104S00',
        'EDU2114S01',
        'EDU2109S00',
        'EDU4101S00',
        'OPEN100100',
        'OPEN100400',
      ]) {
        final sid = 'khu/2026/2/seoul/$code';
        expect(raw[sid], old[sid]);
        expect(raw[sid]['schedules'], isEmpty);
      }
      for (final pair in [
        ['GEE11007S00', '2026-10-06'],
        ['GEE11007S00', '2026-10-13'],
        ['GEE11007S00', '2026-10-27'],
        ['GEE11038S00', '2026-10-14'],
        ['GEE11038S00', '2026-11-04'],
        ['GEE11038S00', '2026-12-02'],
        ['GEE11039S00', '2026-10-30'],
        ['GEE11039S00', '2026-11-06'],
        ['GEE11039S00', '2026-12-11'],
        ['EDU3103S00', '2026-12-08'],
        ['EDU3103S00', '2026-12-15'],
      ]) {
        expect(
          (raw['khu/2026/2/seoul/${pair[0]}']['schedules'] as List).any(
            (m) => m['date'] == pair[1],
          ),
          false,
        );
      }
      expect(
        (raw['khu/2026/2/seoul/EDU3103S00']['schedules'] as List).any(
          (m) => m['date'] == '2026-10-20',
        ),
        true,
      );
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
      expect(originalCourses, 2999);
      expect(originalDates, 55890);
      expect(added, 113);
      expect(courses.where((c) => c.meetings.isNotEmpty), hasLength(3008));
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
        expect(restored, hasLength(3008));
        for (final c in restored) {
          expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
        }
      }
    },
  );
}
