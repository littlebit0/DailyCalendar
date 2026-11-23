import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';

const _weekStarts = [
  540,
  600,
  660,
  720,
  780,
  840,
  900,
  960,
  1020,
  1120,
  1175,
  1230,
  1290,
  1345,
];
const _weekEnds = [
  600,
  660,
  690, // 반교시 2.5교시(11:00~11:30), 사용자 결정 2026-11-23

  720,
  780,
  840,
  900,
  960,
  1020,
  1080,
  1175,
  1230,
  1290,
  1345,
  1400,
  1440,
];
const _satStarts = [
  540,
  600,
  660,
  720,
  780,
  840,
  895,
  950,
  1005,
  1060,
  1115,
  1170,
  1225,
];
const _satEnds = [
  600,
  660,
  720,
  780,
  840,
  895,
  950,
  1005,
  1060,
  1115,
  1170,
  1225,
  1280,
];

void main() {
  test(
    'Hanbat scoped reservations retain unknown delivery in all modes and Drive JSON',
    () {
      const root = 'work/university-research/catalog-r/hanbat/';
      final originals =
          (jsonDecode(
                    fixtureFile(
                      '${root}hanbat-current-2026-2-native-education-rows-v1.json',
                    ).readAsStringSync(),
                  )
                  as Map)['rows']
              as List;
      final native = {
        for (final row in originals) '${row['nativeLectureId']}': row,
      };
      final scheduled = <dynamic>[];
      var total = 0;
      var appointments = 0;
      for (final campus in ['daejeon', 'sejong']) {
        final raw =
            jsonDecode(
                  fixtureFile(
                    'assets/timetable/hanbat-$campus-2026-2.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        final dataset = UniversityDataset.fromJson(raw);
        final rows = raw['courses'] as List;
        expect(raw['researchOnly'], isFalse);
        expect(raw['completionClaim'], isFalse);
        for (var i = 0; i < dataset.courses.length; i++) {
          final c = dataset.courses[i];
          final r = rows[i] as Map;
          final metadata = r['metadata'] as Map;
          total++;
          expect(
            metadata['originalEducationalFields'],
            native[(metadata['originalEducationalFields']
                    as Map)['nativeLectureId']
                .toString()],
          );
          expect(
            (metadata['originalEducationalFields'] as Map)['campus'],
            raw['campusName'],
          );
          expect(
            c.sourceId.endsWith(
              '/${(metadata['originalEducationalFields'] as Map)['nativeLectureId']}',
            ),
            isTrue,
          );
          expect(
            c.sourceClassification,
            (metadata['originalEducationalFields'] as Map)['classification'],
          );
          expect(metadata['actualAttendanceConfirmed'], isFalse);
          expect(metadata['actualPhysicalDatesConfirmed'], isFalse);
          expect(c.code, matches(RegExp(r'^[A-Z]+\d+$')));
          expect(c.section, matches(RegExp(r'^\d{2}$')));
          if (!c.hasSchedulableMeetings) continue;
          scheduled.add(c);
          for (final m in c.meetings) {
            appointments++;
            if (m.originalStartMinute == 0) {
              // 15교시는 학과 공표 시간표(23:15~00:05)대로 자정을 넘어 다음 날
              // 00:00~00:15로 이어진다. 전날 같은 강의실 구간은 24:00에 끝난다.
              expect(m.originalEndMinute, 15);
              final prev = DateTime.parse(
                m.date!,
              ).subtract(const Duration(days: 1)).toIso8601String();
              expect(
                c.meetings.any(
                  (p) =>
                      prev.startsWith(p.date!) &&
                      p.originalEndMinute == 1440 &&
                      p.classroom == m.classroom,
                ),
                isTrue,
              );
              continue;
            }
            // 학사안내 교시표: 쉬는 시간(주간 10분, 야간·토요일 14시 이후 5분)을 포함한
            // 슬롯의 시작·끝만 허용하고, 연속 교시는 한 구간으로 합친다.
            // 야간 12교시 슬롯(1230~1290)만 60분이라 그 뒤 쉬는 시간은 10분이다. 이 교시표
            // 원문은 저장소에 없어 원문 미확인이다(#950).
            final starts = m.weekday == 6 ? _satStarts : _weekStarts;
            final ends = m.weekday == 6 ? _satEnds : _weekEnds;
            expect(starts, contains(m.originalStartMinute));
            expect(ends, contains(m.originalEndMinute));
            expect(m.originalEndMinute, greaterThan(m.originalStartMinute));
            final date = DateTime.parse(m.date!);
            expect(date.weekday, m.weekday);
            expect(m.date!.compareTo('2026-09-01'), greaterThanOrEqualTo(0));
            expect(m.date!.compareTo('2026-12-14'), lessThanOrEqualTo(0));
            expect([
              '2026-09-24',
              '2026-09-25',
              '2026-10-05',
              '2026-10-09',
              '2026-09-26',
              '2026-10-03',
            ], isNot(contains(m.date)));
            expect(m.originalStartMinute, greaterThanOrEqualTo(540));
            expect(m.originalEndMinute, lessThanOrEqualTo(1440));
            expect(
              (r['schedules'] as List).every(
                (dynamic s) => !(s as Map).containsKey('deliveryMode'),
              ),
              isTrue,
            );
          }
        }
      }
      expect(total, 1698);
      expect(scheduled, hasLength(1647));
      expect(appointments, 25101);
      // 공식 교시표 밖 14교시는 13교시 슬롯(55분)으로 이어 계산한다(apply_hanbat_held_periods.py).
      final bodybuilding = scheduled.singleWhere(
        (dynamic c) => c.sourceId == 'hanbat/daejeon/2026-2/2026200616',
      );
      expect(bodybuilding.meetings.first.weekday, 1);
      expect(bodybuilding.meetings.first.originalStartMinute, 1290);
      expect(bodybuilding.meetings.first.originalEndMinute, 1400);
      // 화13~15교시는 21:30~24:00과 다음 날 00:00~00:15로 나뉜다.
      final control = scheduled.singleWhere(
        (dynamic c) => c.sourceId == 'hanbat/daejeon/2026-2/2026200011',
      );
      expect(control.meetings.first.originalStartMinute, 1290);
      expect(control.meetings.first.originalEndMinute, 1440);
      expect(control.meetings[1].date, '2026-09-02');
      expect(control.meetings[1].originalEndMinute, 15);
      // '수1,수2.5'는 1교시(09:00~10:00)와 2교시 끝 직후 반교시(11:00~11:30).
      final capstone = scheduled.singleWhere(
        (dynamic c) => c.sourceId == 'hanbat/daejeon/2026-2/2026201752',
      );
      expect(capstone.meetings[1].originalStartMinute, 660);
      expect(capstone.meetings[1].originalEndMinute, 690);
      // 토요일 5~7교시(13:00~15:50)와 월~금 6~8교시(14:00~17:00)는
      // 쉬는 시간을 포함해 각각 한 구간이 된다.
      expect(
        scheduled.any(
          (dynamic c) => c.meetings.any(
            (dynamic m) =>
                m.weekday == 6 &&
                m.originalStartMinute == 780 &&
                m.originalEndMinute == 950,
          ),
        ),
        isTrue,
      );
      expect(
        scheduled.any(
          (dynamic c) => c.meetings.any(
            (dynamic m) =>
                m.weekday != 6 &&
                m.originalStartMinute == 840 &&
                m.originalEndMinute == 1020,
          ),
        ),
        isTrue,
      );
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = scheduled
            .map(
              (dynamic c) =>
                  c.toTimetable(id: c.sourceId, mode: mode) as TimetableClass,
            )
            .toList();
        final document = TimetableSyncDocument.legacy(
          courses: classes,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(restored, hasLength(1647));
        final before = {for (final c in classes) c.sourceId: c};
        for (final c in restored) {
          final original = before[c.sourceId]!;
          expect(c.isValid, isTrue);
          expect(c.defaultMode, mode);
          expect(c.note, original.note);
          expect(c.note, contains('공개 예약 계획, 실제 등교'));
          expect(
            c.meetings.map((m) => m.toJson()).toList(),
            original.meetings.map((m) => m.toJson()).toList(),
          );
          for (final m in c.meetings) {
            expect(c.modeOn(m, DateTime.parse(m.date!)), mode);
          }
        }
      }
    },
  );
}
