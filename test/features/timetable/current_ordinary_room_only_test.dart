// Historical frozen-source packet regression. Latest packaged sources are
// checked by packaged_asset_source_integrity_test and resumed_batch_changed_courses_test.
import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const root =
    'work/university-research/remaining-ordinary-native-clock-audit-v1-20261009/';
Map<String, dynamic> read(String path) {
  final actual =
      path.endsWith('.room-only-ordinary-candidate.json') &&
          !path.contains('skku-humanities-')
      ? 'work/university-research/resume-batch-20261010/before-projection/${path.split('/').last.replaceAll('.room-only-ordinary-candidate', '')}'
      : path;
  final data =
      jsonDecode(fixtureFile(actual).readAsStringSync())
          as Map<String, dynamic>;
  if (data['courses'] is List) {
    for (final c in data['courses']) {
      if (c['metadata']?.containsKey('researchOnly') == true) {
        c['metadata']['researchOnly'] = false;
      }
    }
  }
  return data;
}

const dates = {
  1: [
    '09-07',
    '09-14',
    '09-21',
    '09-28',
    '10-12',
    '10-19',
    '11-02',
    '11-09',
    '11-16',
    '11-23',
    '11-30',
    '12-07',
  ],
  4: [
    '09-03',
    '09-10',
    '09-17',
    '10-01',
    '10-08',
    '10-15',
    '10-22',
    '10-29',
    '11-05',
    '11-12',
    '11-19',
    '11-26',
    '12-03',
    '12-10',
    '12-17',
  ],
};
const rules = {
  'MGT4090-01': [1, 720, 780, ''],
  'CFTD088-01': [4, 810, 885, '50305'],
  'CFTD086-01': [4, 1080, 1150, '31506'],
};
const campuses = {
  'dongguk-seoul-2026-2': [2359, 2080, 38188],
  'skku-humanities-2026-2': [1469, 926, 23536],
};
void main() {
  test(
    'three native ordinary room-only rows preserve full education and all3826 other whole objects',
    () {
      final proof =
          jsonDecode(
                fixtureFile(
                  '${root}independent3-native-source-proof.json',
                ).readAsStringSync(),
              )
              as List;
      expect(proof, hasLength(3));
      final calendar =
          jsonDecode(
                fixtureFile(
                  '${root}own-calendar-native-receipts.json',
                ).readAsStringSync(),
              )
              as List;
      for (final p in calendar) {
        expect(
          sha256.convert(fixtureFile(p['file']).readAsBytesSync()).toString(),
          p['sha256'],
        );
        expect(read(p['file']), p['education']);
      }
      final skkuCalendar = calendar.singleWhere(
        (p) => p['file'].contains('skku-current-term'),
      )['education'];
      expect(skkuCalendar['term']['startDate'], '2026-08-31');
      expect(skkuCalendar['term']['endDate'], '2026-12-18');
      expect(skkuCalendar['closureRule']['schoolSpecificClosures'], [
        '2026-09-25',
        '2026-09-28',
      ]);
      final donggukText = calendar
          .singleWhere(
            (p) => p['file'].contains('dongguk/'),
          )['education']['tables']
          .join(' ');
      expect(donggukText, contains('2026.09.01.'));
      expect(donggukText, contains('2026.10.20. ~ 2026.10.26.'));
      expect(donggukText, contains('2026.12.08. ~ 2026.12.14.'));
      int added = 0;
      int unchanged = 0;
      for (final name in campuses.keys) {
        final before = read('$root$name.baseline118.json');
        final now = read('$root$name.room-only-ordinary-candidate.json');
        final old = {for (final c in before['courses']) c['sourceId']: c};
        expect(now['courses'], hasLength(campuses[name]![0]));
        for (final c in now['courses']) {
          final key = '${c['courseCode']}-${c['section']}';
          final b = old[c['sourceId']];
          if (!rules.containsKey(key)) {
            expect(c, b);
            unchanged++;
            continue;
          }
          added++;
          final p = proof.singleWhere((p) => p['sourceId'] == c['sourceId']);
          expect(p['baselineRow'], b);
          expect(
            sha256
                .convert(
                  fixtureFile(
                    p['originalNativeEducationPath'],
                  ).readAsBytesSync(),
                )
                .toString(),
            p['originalNativeEducationSHA256'],
          );
          final original = read(p['originalNativeEducationPath']);
          final rows = key == 'MGT4090-01'
              ? original['rows']
              : original['dsGrdMain03'];
          final native = rows.singleWhere(
            (r) =>
                (key == 'MGT4090-01' ? r['학수번호'] : r['HAKSU_NO_BUNBAN']) == key,
          );
          expect(native, p['originalNativeRow']);
          expect(
            read(p['currentOperatingEducationPath']),
            p['ownOperatingRecord'],
          );
          expect(
            sha256
                .convert(
                  fixtureFile(
                    p['currentOperatingEducationPath'],
                  ).readAsBytesSync(),
                )
                .toString(),
            p['currentOperatingEducationSHA256'],
          );
          final rule = rules[key]!;
          final expected = [
            for (final d in dates[rule[0]]!)
              {
                'date': '2026-$d',
                'weekday': rule[0],
                'startMinute': rule[1],
                'endMinute': rule[2],
                'classroom': rule[3],
              },
          ];
          expect(c['schedules'], expected);
          expect(c['scheduleStatus'], 'scheduled');
          for (final k in b.keys.where(
            (k) => ![
              'schedules',
              'scheduleStatus',
              'unresolvedReasons',
              'period',
              'metadata',
              'remarks',
            ].contains(k),
          )) {
            expect(c[k], b[k], reason: 'native $key/$k');
          }
          if (key == 'MGT4090-01') {
            expect(
              c['remarks'],
              (b['remarks'] as String).replaceAll(
                '일정 보류: 실제 강의실 미공개.',
                '강의실 미공개: 원문 시각으로 일정 생성.',
              ),
            );
            expect(c['remarks'], isNot(contains('일정 보류: 실제 강의실 미공개.')));
            expect(c['professor'], '');
            expect(c['sourceClassroom'], '');
            expect(c['campus'], 'seoul');
            expect(c['period'], b['period']);
            final meta = Map<String, dynamic>.from(c['metadata']);
            final oldMeta = Map<String, dynamic>.from(b['metadata']);
            expect(oldMeta.remove('heldReasons'), ['실제 강의실 미공개']);
            expect(meta.remove('heldReasons'), []);
            expect(meta, oldMeta);
            final n = meta['nativeEducationalRow'];
            expect(n['요일/교시'], '월 4교시(12:00) ~ 4.5교시(13:00)');
            expect(n['강의실'], isNull);
            expect(n['강의유형'], '이론');
            expect(n['강의형태'], '일반강의');
            expect(n['집중이수학기기간'], isNull);
            expect(n['강의지역'], '서울');
            expect(n['비고'], '별도 면담 후 신청 가능');
          } else {
            final record = p['ownOperatingRecord'];
            final row = record['sourceRow'];
            final detail = record['detail'].single;
            expect(row['GAESUL_YEAR'], '2026');
            expect(row['GAESUL_TERM'], '20');
            expect(row['HAKSU_NO_BUNBAN'], key);
            expect(row['CAMPUS_GB'], '1');
            expect(row['HAKBU_JIBJUNG_GB'], 'N');
            expect(row['SUUP_TYPE_CD'], '33');
            expect(row['SUUP_TYPE_NM'], '플립러닝(온라인[사전제작]+오프라인)');
            expect(row['BIGO'], contains('${rule[3]}호'));
            expect(c['sourceExplicitRemarkRoom'], rule[3]);
            expect(c['sourceClassroom'], '미지정');
            expect(row['PER_NAME'], c['professor']);
            expect(detail['PER_NAME'], c['professor']);
            expect(detail['GAESUL_YEAR'], '2026');
            expect(detail['GAESUL_TERM'], '20');
            expect(record['currentDetailIdentityConfirmed'], true);
            expect(
              c['sourceEducationalMetadata'],
              b['sourceEducationalMetadata'],
            );
            expect(
              c['rawMeetingFrameForReviewOnly'],
              b['rawMeetingFrameForReviewOnly'],
            );
            expect(c['period'], {
              'startDate': '2026-08-31',
              'endDate': '2026-12-18',
            });
            expect(c['unresolvedReasons'], []);
            expect(
              c['schedules'].every((m) => !m.containsKey('deliveryMode')),
              true,
            );
            if (key == 'CFTD088-01') {
              expect(
                c['sourceSchedule'],
                '목13:30-14:45【미지정】【0.5h(ON)+1.5h(OFF)】',
              );
              expect(detail['INPUT_TYPE_GB'], '0');
              expect(detail['CLASS_INFO'], contains('발표수업'));
            } else {
              expect(
                c['sourceSchedule'],
                '목18:00-19:10【미지정】【0.5h(ON)+1.5h(OFF)】',
              );
              final attachment = record['attachments'].single;
              expect(attachment['year2026Present'], true);
              expect(attachment['currentTermPresent'], true);
              expect(attachment['headerCourseCodePresent'], true);
              expect(attachment['catalogProfessorPresent'], true);
              expect(attachment['byteCount'], 53575);
              expect(attachment['contextLimitReached'], false);
              expect(attachment['contextTruncated'], false);
              expect(attachment['privacySuppressedLineCount'], 0);
              expect(
                attachment['educationalOperatingContexts'].join(' '),
                contains('2026/2'),
              );
            }
          }
        }
      }
      expect(added, 3);
      expect(unchanged, 3826);
      // Medical/clinical room-only labels do not authorize an ordinary-semester fallback.
      final untouched =
          jsonDecode(
                fixtureFile(
                  '${root}all16-room-only-reason-full-native-rows.json',
                ).readAsStringSync(),
              )
              as List;
      expect(
        untouched.where(
          (r) => r['baselineRow']['courseCode'].toString().startsWith('MED'),
        ),
        hasLength(13),
      );
    },
  );
  test(
    'all3007 dated offerings full three user modes and Drive roundtrip keep native clocks and restrictions',
    () {
      for (final name in campuses.keys) {
        final dataset = UniversityDataset.fromJson(
          read('$root$name.room-only-ordinary-candidate.json'),
        );
        final scheduled = dataset.courses
            .where((c) => c.hasSchedulableMeetings)
            .toList();
        expect(scheduled, hasLength(campuses[name]![1]));
        expect(
          scheduled.fold<int>(0, (n, c) => n + c.meetings.length),
          campuses[name]![2],
        );
        for (final mode in [
          LectureMode.inPerson,
          LectureMode.liveOnline,
          LectureMode.video,
        ]) {
          final records = <String, TimetableSyncValue>{};
          for (final c in scheduled) {
            final t = c.toTimetable(id: c.sourceId, mode: mode);
            expect(t.isValid, true);
            expect(t.defaultMode, mode);
            expect(TimetableClass.fromJson(t.toJson()).toJson(), t.toJson());
            final key = timetableCourseSyncKey(t);
            expect(records.containsKey(key), false);
            records[key] = TimetableSyncValue(
              {...t.toJson(), 'id': key},
              DateTime.utc(2026, 10, 9),
              'research',
            );
          }
          final document = TimetableSyncDocument.records(courses: records);
          expect(
            TimetableSyncDocument.fromJson(
              jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>,
            ).toJson(),
            document.toJson(),
          );
        }
      }
    },
  );
}
