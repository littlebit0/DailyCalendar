import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';

const dir =
    'work/university-research/catalog-c/khu-full-operating-context-batches-v8-20261009/outside-shortlist-review-v1/packet008-reviewed30';
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
  "khu/2026/2/seoul/MEDIC202300": [
    "2026-09-07",
    "2026-09-14",
    "2026-09-21",
    "2026-09-28",
    "2026-10-12",
    "2026-10-19",
    "2026-11-02",
    "2026-11-09",
    "2026-11-16",
    "2026-11-23",
    "2026-11-30",
    "2026-12-07",
    "2026-12-14",
  ],
  "khu/2026/2/seoul/MEDIC202400": [
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
  "khu/2026/2/seoul/MEDIC100900": [
    "2026-09-02",
    "2026-09-04",
    "2026-09-07",
    "2026-09-09",
    "2026-09-11",
    "2026-09-14",
    "2026-09-16",
    "2026-09-18",
    "2026-09-21",
    "2026-09-23",
    "2026-09-28",
    "2026-09-30",
    "2026-10-02",
    "2026-10-07",
    "2026-10-12",
    "2026-10-14",
    "2026-10-16",
    "2026-10-19",
    "2026-10-28",
    "2026-10-30",
    "2026-11-02",
    "2026-11-04",
    "2026-11-06",
    "2026-11-09",
    "2026-11-11",
    "2026-11-13",
    "2026-11-16",
    "2026-11-18",
    "2026-11-20",
    "2026-11-23",
    "2026-11-25",
    "2026-11-27",
    "2026-11-30",
    "2026-12-02",
    "2026-12-04",
    "2026-12-07",
    "2026-12-09",
    "2026-12-11",
    "2026-12-14",
  ],
  "khu/2026/2/seoul/MEDIC202600": [
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
    "2026-12-10",
  ],
  "khu/2026/2/seoul/MEDIC201800": [
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
    "2026-12-10",
  ],
  "khu/2026/2/seoul/KMS121500": [
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
    "2026-12-10",
  ],
  "khu/2026/2/seoul/KMS121501": [
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
    "2026-12-10",
  ],
  "khu/2026/2/seoul/KMS121700": ["2026-09-04", "2026-12-04", "2026-12-11"],
  "khu/2026/2/seoul/KMS121701": ["2026-09-01", "2026-12-01", "2026-12-08"],
  "khu/2026/2/seoul/KMS122201": [
    "2026-09-03",
    "2026-09-10",
    "2026-09-17",
    "2026-10-01",
    "2026-10-08",
    "2026-10-15",
  ],
  "khu/2026/2/seoul/KMS122200": [
    "2026-09-03",
    "2026-09-10",
    "2026-09-17",
    "2026-10-01",
    "2026-10-08",
    "2026-10-15",
  ],
};
const originalSlots = {
  "MEDIC202300": [
    [1, 540, 650, "6강의실"],
  ],
  "MEDIC202400": [
    [3, 660, 710, "6강의실"],
  ],
  "MEDIC100900": [
    [1, 540, 650, "5강의실"],
    [3, 540, 650, "5강의실"],
    [5, 540, 650, "5강의실"],
  ],
  "MEDIC202600": [
    [4, 540, 650, "6강의실"],
  ],
  "MEDIC201800": [
    [4, 660, 710, "6강의실"],
  ],
  "KMS121500": [
    [4, 540, 615, "스356"],
  ],
  "KMS121501": [
    [4, 630, 720, "스357"],
  ],
  "KMS121700": [
    [5, 840, 1005, "스356"],
  ],
  "KMS121701": [
    [2, 540, 705, "스357"],
  ],
  "KMS122201": [
    [4, 780, 855, "스357"],
  ],
  "KMS122200": [
    [4, 870, 945, "스356"],
  ],
};
const rawNativeSlots = {
  "MEDIC202300": [
    [1, 540, 650, "6강의실"],
  ],
  "MEDIC202400": [
    [3, 660, 710, "6강의실"],
  ],
  "MEDIC100900": [
    [1, 540, 650, "5강의실"],
    [3, 540, 650, "5강의실"],
    [1, 540, 650, "5강의실"],
    [3, 540, 650, "5강의실"],
    [5, 540, 650, "5강의실"],
    [3, 540, 650, "5강의실"],
    [5, 540, 650, "5강의실"],
    [1, 540, 650, "5강의실"],
  ],
  "MEDIC202600": [
    [4, 540, 650, "6강의실"],
  ],
  "MEDIC201800": [
    [4, 660, 710, "6강의실"],
  ],
  "KMS121500": [
    [4, 540, 615, "스356"],
    [1, 840, 915, "스356"],
  ],
  "KMS121501": [
    [4, 630, 720, "스357"],
    [1, 930, 1020, "스357"],
  ],
  "KMS121700": [
    [5, 840, 1005, "스356"],
  ],
  "KMS121701": [
    [2, 540, 705, "스357"],
  ],
  "KMS122201": [
    [4, 780, 855, "스357"],
  ],
  "KMS122200": [
    [4, 870, 945, "스356"],
  ],
};
const independentMeetings = {
  "khu/2026/2/seoul/MEDIC202300": [
    ["2026-09-07", 1, 540, 650, "6강의실"],
    ["2026-09-14", 1, 540, 650, "6강의실"],
    ["2026-09-21", 1, 540, 650, "6강의실"],
    ["2026-09-28", 1, 540, 650, "6강의실"],
    ["2026-10-12", 1, 540, 650, "6강의실"],
    ["2026-10-19", 1, 540, 650, "6강의실"],
    ["2026-11-02", 1, 540, 650, "6강의실"],
    ["2026-11-09", 1, 540, 650, "6강의실"],
    ["2026-11-16", 1, 540, 650, "6강의실"],
    ["2026-11-23", 1, 540, 650, "6강의실"],
    ["2026-11-30", 1, 540, 650, "6강의실"],
    ["2026-12-07", 1, 540, 650, "6강의실"],
    ["2026-12-14", 1, 540, 650, "6강의실"],
  ],
  "khu/2026/2/seoul/MEDIC202400": [
    ["2026-09-09", 3, 660, 710, "6강의실"],
    ["2026-09-16", 3, 660, 710, "6강의실"],
    ["2026-09-23", 3, 660, 710, "6강의실"],
    ["2026-09-30", 3, 660, 710, "6강의실"],
    ["2026-10-07", 3, 660, 710, "6강의실"],
    ["2026-10-14", 3, 660, 710, "6강의실"],
    ["2026-10-28", 3, 660, 710, "6강의실"],
    ["2026-11-04", 3, 660, 710, "6강의실"],
    ["2026-11-11", 3, 660, 710, "6강의실"],
    ["2026-11-18", 3, 660, 710, "6강의실"],
    ["2026-11-25", 3, 660, 710, "6강의실"],
    ["2026-12-02", 3, 660, 710, "6강의실"],
    ["2026-12-09", 3, 660, 710, "6강의실"],
  ],
  "khu/2026/2/seoul/MEDIC100900": [
    ["2026-09-02", 3, 540, 650, "5강의실"],
    ["2026-09-04", 5, 540, 650, "5강의실"],
    ["2026-09-07", 1, 540, 650, "5강의실"],
    ["2026-09-09", 3, 540, 650, "5강의실"],
    ["2026-09-11", 5, 540, 650, "5강의실"],
    ["2026-09-14", 1, 540, 650, "5강의실"],
    ["2026-09-16", 3, 540, 650, "5강의실"],
    ["2026-09-18", 5, 540, 650, "5강의실"],
    ["2026-09-21", 1, 540, 650, "5강의실"],
    ["2026-09-23", 3, 540, 650, "5강의실"],
    ["2026-09-28", 1, 540, 650, "5강의실"],
    ["2026-09-30", 3, 540, 650, "5강의실"],
    ["2026-10-02", 5, 540, 650, "5강의실"],
    ["2026-10-07", 3, 540, 650, "5강의실"],
    ["2026-10-12", 1, 540, 650, "5강의실"],
    ["2026-10-14", 3, 540, 650, "5강의실"],
    ["2026-10-16", 5, 540, 650, "5강의실"],
    ["2026-10-19", 1, 540, 650, "5강의실"],
    ["2026-10-28", 3, 540, 650, "5강의실"],
    ["2026-10-30", 5, 540, 650, "5강의실"],
    ["2026-11-02", 1, 540, 650, "5강의실"],
    ["2026-11-04", 3, 540, 650, "5강의실"],
    ["2026-11-06", 5, 540, 650, "5강의실"],
    ["2026-11-09", 1, 540, 650, "5강의실"],
    ["2026-11-11", 3, 540, 650, "5강의실"],
    ["2026-11-13", 5, 540, 650, "5강의실"],
    ["2026-11-16", 1, 540, 650, "5강의실"],
    ["2026-11-18", 3, 540, 650, "5강의실"],
    ["2026-11-20", 5, 540, 650, "5강의실"],
    ["2026-11-23", 1, 540, 650, "5강의실"],
    ["2026-11-25", 3, 540, 650, "5강의실"],
    ["2026-11-27", 5, 540, 650, "5강의실"],
    ["2026-11-30", 1, 540, 650, "5강의실"],
    ["2026-12-02", 3, 540, 650, "5강의실"],
    ["2026-12-04", 5, 540, 650, "5강의실"],
    ["2026-12-07", 1, 540, 650, "5강의실"],
    ["2026-12-09", 3, 540, 650, "5강의실"],
    ["2026-12-11", 5, 540, 650, "5강의실"],
    ["2026-12-14", 1, 540, 650, "5강의실"],
  ],
  "khu/2026/2/seoul/MEDIC202600": [
    ["2026-09-03", 4, 540, 650, "6강의실"],
    ["2026-09-10", 4, 540, 650, "6강의실"],
    ["2026-09-17", 4, 540, 650, "6강의실"],
    ["2026-10-01", 4, 540, 650, "6강의실"],
    ["2026-10-08", 4, 540, 650, "6강의실"],
    ["2026-10-15", 4, 540, 650, "6강의실"],
    ["2026-10-29", 4, 540, 650, "6강의실"],
    ["2026-11-05", 4, 540, 650, "6강의실"],
    ["2026-11-12", 4, 540, 650, "6강의실"],
    ["2026-11-19", 4, 540, 650, "6강의실"],
    ["2026-11-26", 4, 540, 650, "6강의실"],
    ["2026-12-03", 4, 540, 650, "6강의실"],
    ["2026-12-10", 4, 540, 650, "6강의실"],
  ],
  "khu/2026/2/seoul/MEDIC201800": [
    ["2026-09-03", 4, 660, 710, "6강의실"],
    ["2026-09-10", 4, 660, 710, "6강의실"],
    ["2026-09-17", 4, 660, 710, "6강의실"],
    ["2026-10-01", 4, 660, 710, "6강의실"],
    ["2026-10-08", 4, 660, 710, "6강의실"],
    ["2026-10-15", 4, 660, 710, "6강의실"],
    ["2026-10-29", 4, 660, 710, "6강의실"],
    ["2026-11-05", 4, 660, 710, "6강의실"],
    ["2026-11-12", 4, 660, 710, "6강의실"],
    ["2026-11-19", 4, 660, 710, "6강의실"],
    ["2026-11-26", 4, 660, 710, "6강의실"],
    ["2026-12-03", 4, 660, 710, "6강의실"],
    ["2026-12-10", 4, 660, 710, "6강의실"],
  ],
  "khu/2026/2/seoul/KMS121500": [
    ["2026-09-03", 4, 540, 615, "스356"],
    ["2026-09-10", 4, 540, 615, "스356"],
    ["2026-09-17", 4, 540, 615, "스356"],
    ["2026-10-01", 4, 540, 615, "스356"],
    ["2026-10-08", 4, 540, 615, "스356"],
    ["2026-10-15", 4, 540, 615, "스356"],
    ["2026-10-29", 4, 540, 615, "스356"],
    ["2026-11-05", 4, 540, 615, "스356"],
    ["2026-11-12", 4, 540, 615, "스356"],
    ["2026-11-19", 4, 540, 615, "스356"],
    ["2026-11-26", 4, 540, 615, "스356"],
    ["2026-12-03", 4, 540, 615, "스356"],
    ["2026-12-10", 4, 540, 615, "스356"],
  ],
  "khu/2026/2/seoul/KMS121501": [
    ["2026-09-03", 4, 630, 720, "스357"],
    ["2026-09-10", 4, 630, 720, "스357"],
    ["2026-09-17", 4, 630, 720, "스357"],
    ["2026-10-01", 4, 630, 720, "스357"],
    ["2026-10-08", 4, 630, 720, "스357"],
    ["2026-10-15", 4, 630, 720, "스357"],
    ["2026-10-29", 4, 630, 720, "스357"],
    ["2026-11-05", 4, 630, 720, "스357"],
    ["2026-11-12", 4, 630, 720, "스357"],
    ["2026-11-19", 4, 630, 720, "스357"],
    ["2026-11-26", 4, 630, 720, "스357"],
    ["2026-12-03", 4, 630, 720, "스357"],
    ["2026-12-10", 4, 630, 720, "스357"],
  ],
  "khu/2026/2/seoul/KMS121700": [
    ["2026-09-04", 5, 840, 1005, "스356"],
    ["2026-12-04", 5, 840, 1005, "스356"],
    ["2026-12-11", 5, 840, 1005, "스356"],
  ],
  "khu/2026/2/seoul/KMS121701": [
    ["2026-09-01", 2, 540, 705, "스357"],
    ["2026-12-01", 2, 540, 705, "스357"],
    ["2026-12-08", 2, 540, 705, "스357"],
  ],
  "khu/2026/2/seoul/KMS122201": [
    ["2026-09-03", 4, 780, 855, "스357"],
    ["2026-09-10", 4, 780, 855, "스357"],
    ["2026-09-17", 4, 780, 855, "스357"],
    ["2026-10-01", 4, 780, 855, "스357"],
    ["2026-10-08", 4, 780, 855, "스357"],
    ["2026-10-15", 4, 780, 855, "스357"],
  ],
  "khu/2026/2/seoul/KMS122200": [
    ["2026-09-03", 4, 870, 945, "스356"],
    ["2026-09-10", 4, 870, 945, "스356"],
    ["2026-09-17", 4, 870, 945, "스356"],
    ["2026-10-01", 4, 870, 945, "스356"],
    ["2026-10-08", 4, 870, 945, "스356"],
    ["2026-10-15", 4, 870, 945, "스356"],
  ],
};
void main() {
  test(
    'KHU packet008 eleven exact physical groups preserve whole4666 and full3modeDrive',
    () {
      final old = <String, dynamic>{};
      final raw = <String, dynamic>{};
      final courses = <UniversityCourse>[];
      for (final campus in ['seoul', 'global']) {
        final previous = read('packet008-prior-$campus-whole.json');
        final current = read(
          'khu-$campus-2026-2.packet008-physical-groups-prepared.json',
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
        read('packet008-review-decisions.json')['decisions'],
        hasLength(30),
      );
      final proof = read('packet008-independent-proof.json');
      expect(proof['proofs'], hasLength(11));
      for (final p in proof['proofs']) {
        expect(
          p['previousResearchDepartmentRemarks'],
          old[p['sourceId']]['departmentRemarks'],
        );
      }
      expect(
        (raw['khu/2026/2/seoul/MGMT401200']['schedules'] as List)
            .where((m) => m['date'] == '2026-10-02')
            .single,
        {
          'date': '2026-10-02',
          'weekday': 5,
          'startMinute': 1080,
          'endMinute': 1155,
          'classroom': '',
          'deliveryMode': 'liveOnline',
        },
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
            '$schoolRemaining\n'
            '현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.',
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
      expect(originalCourses, 2677);
      expect(originalDates, 50567);
      expect(added, 135);
      expect(courses.where((c) => c.meetings.isNotEmpty), hasLength(2688));
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
        expect(restored, hasLength(2688));
        for (final c in restored) {
          expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
        }
      }
    },
  );
}
