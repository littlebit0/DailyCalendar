import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';

void main() {
  test(
    'Expanded native bounded general intensive and live remote majors plus general with native graduate exclusions current Sookmyung public snapshots preserve native provenance and partial own-term dates through three complete Drive JSON documents',
    () {
      const root =
          'work/university-research/catalog-w/sookmyung-expanded-public-partial-v19/';
      final proof =
          jsonDecode(
                File(
                  '${root}five-query-educational-proof.json',
                ).readAsStringSync(),
              )
              as Map;
      expect(proof['nativeRows'], hasLength(3491));
      expect(proof['sourceFiles'], hasLength(141));
      expect(proof['pendingParentFinalScope'], isFalse);
      expect(
        (proof['sourceFiles'] as List)[44]['selectedOptionElementId'],
        'WD5C47',
      );
      for (final source in proof['sourceFiles'] as List) {
        final snapshot =
            jsonDecode(
                  File(
                    'work/university-research/catalog-w/sookmyung/${source['file']}',
                  ).readAsStringSync(),
                )
                as Map;
        expect(snapshot['query'], source['query']);
        expect(snapshot['year'], '2026');
        expect(snapshot['semester'], '2');
        expect(snapshot['rows'], hasLength(source['rows'] as int));
        final records = (proof['nativeRows'] as List)
            .where((dynamic r) => r['query'] == source['query'])
            .toList();
        for (var i = 0; i < records.length; i++) {
          expect(
            records[i]['nativeEducationalCells'],
            (snapshot['rows'] as List)[i],
          );
        }
      }
      expect(proof['reservationScope']['end'], '2026-12-07');
      final calendar =
          proof['calendarCampusProof']['officialCurrentCalendar']['nativeMonths']
              as Map;
      final nativeMap =
          proof['calendarCampusProof']['physicalCampusProof']['nativeGroups']
              as Map;
      expect(nativeMap.values.expand((dynamic x) => x as List), hasLength(36));
      expect(
        (calendar['9'] as List).any(
          (dynamic r) =>
              r['nativeTitle'] == '[학교일정] 2학기 개강' &&
              r['nativeRange'] == '01(화)',
        ),
        isTrue,
      );
      expect(
        (calendar['9'] as List).any(
          (dynamic r) =>
              (r['nativeTitle'] as String).contains('개강 후 4주차') &&
              r['nativeRange'] == '22(화) ~ 28(월)',
        ),
        isTrue,
      );
      expect(
        (calendar['10'] as List).any(
          (dynamic r) =>
              r['nativeTitle'] == '[학교일정] 2학기 중간고사' &&
              r['nativeRange'] == '20(화) ~ 26(월)',
        ),
        isTrue,
      );
      expect(
        (calendar['12'] as List).any(
          (dynamic r) =>
              r['nativeTitle'] == '[학교일정] 2학기 보강 및 기말고사' &&
              r['nativeRange'] == '08(화) ~ 21(월)',
        ),
        isTrue,
      );
      final policies =
          proof['calendarCampusProof']['freshParentPublicUINotices'];
      expect(
        policies['opening']['originalEducationalReceipt']['educationText'],
        contains('대면 또는 실시간 비대면으로 수업 진행이 가능'),
      );
      expect(
        policies['midterm']['originalEducationalReceipt']['educationText'],
        contains('시험이 실시되지 않는 수업일에는 강의가 정상 진행'),
      );
      expect(
        proof['nationalHolidayDateReference']['conservativeUnknownOperationHoldDates'],
        containsAll(['2026-09-24', '2026-09-25', '2026-10-05', '2026-10-09']),
      );
      expect(
        proof['currentClosureGuide']['originalEducationalReceipt']['educationText'],
        contains('최종 폐강 과목은 9/7(월) 18시 이후'),
      );
      final generalRows = (proof['nativeRows'] as List)
          .where((dynamic x) => x['query'] == '교양필수-논리적사고와소프트웨어')
          .toList();
      expect(generalRows, hasLength(12));
      for (final dynamic r in generalRows) {
        expect(r['nativeHeaders'], hasLength(21));
        expect((r['values'] as Map).containsKey('코드쉐어'), isFalse);
        expect(r['values']['강의시간'], '');
        expect(r['values']['수강유의사항'], contains('1,7,14주차 실시간 수업'));
      }
      final newGeneral = (proof['nativeRows'] as List)
          .where((dynamic r) => r['query'] == '교양선택-교선핵심1영역')
          .toList();
      expect(newGeneral, hasLength(71));
      for (final dynamic r in newGeneral) {
        expect(r['nativeHeaders'], hasLength(21));
        expect((r['values'] as Map).containsKey('코드쉐어'), isFalse);
      }
      expect(newGeneral.first['values']['수강유의사항'], '해외교환학생/외국인유학생만 수강신청 가능');
      final secondGeneral = (proof['nativeRows'] as List)
          .where((dynamic r) => r['query'] == '교양선택-교선핵심2영역')
          .toList();
      expect(secondGeneral, hasLength(44));
      expect(
        secondGeneral.singleWhere(
          (dynamic r) => r['values']['과목번호'] == '21104954',
        )['values']['수강유의사항'],
        '해외교환학생/외국인유학생만 수강신청 가능',
      );
      for (final dynamic r in secondGeneral) {
        expect(r['nativeHeaders'], hasLength(21));
        expect((r['values'] as Map).containsKey('코드쉐어'), isFalse);
      }
      for (final query in ['교양선택-교선핵심6영역', '교양선택-교선핵심7영역']) {
        final source = (proof['sourceFiles'] as List).singleWhere(
          (dynamic r) => r['query'] == query,
        );
        expect(source['rows'], 0);
        expect(
          (proof['nativeRows'] as List).where(
            (dynamic r) => r['query'] == query,
          ),
          isEmpty,
        );
      }
      for (final pair in [
        ['글로벌융합학부', '융합국제학부', 72],
        ['컴퓨터과학전공', '컴퓨터과학부', 36],
        ['컴퓨터과학전공(첨단)', '컴퓨터과학부', 36],
        ['지능형전자시스템학부', '지능형전자시스템전공', 34],
      ]) {
        final left =
            (proof['nativeRows'] as List)
                .where((dynamic r) => r['query'] == pair[0])
                .map((dynamic r) => jsonEncode(r['nativeEducationalCells']))
                .toList()
              ..sort();
        final right =
            (proof['nativeRows'] as List)
                .where((dynamic r) => r['query'] == pair[1])
                .map((dynamic r) => jsonEncode(r['nativeEducationalCells']))
                .toList()
              ..sort();
        expect(left, hasLength(pair[2] as int));
        expect(left, right);
      }
      for (final query in ['IT공학과', '의약과학과', '숙명-CQU경영국제학부', '소프트웨어학부(첨단)']) {
        final source = (proof['sourceFiles'] as List).singleWhere(
          (dynamic r) => r['query'] == query,
        );
        expect(source['rows'], 0);
        expect(
          (proof['nativeRows'] as List).where(
            (dynamic r) => r['query'] == query,
          ),
          isEmpty,
        );
      }
      expect(proof['excludedGraduateRecords'], hasLength(64));
      expect(proof['undergraduateNativeRowCount'], 3427);
      expect(proof['undergraduateNativeIdentityCount'], 1485);
      final excludedKeys = (proof['excludedGraduateRecords'] as List)
          .map((dynamic x) => '${x['values']['과목번호']}-${x['values']['분반']}')
          .toSet();
      expect(excludedKeys, hasLength(43));
      final courses = <UniversityCourse>[];
      var nativeCount = 0;
      var meetingCount = 0;
      final pendingPlanProofs =
          jsonDecode(
                File(
                  'work/university-research/catalog-w/sookmyung-native-clock-pending-plan-review-v20-20261009/independent4-native-clock-source-proof.json',
                ).readAsStringSync(),
              )
              as List;
      final reviewedPendingPlanIds = {
        for (final p in pendingPlanProofs) p['sourceId'],
      };
      var heldCount = 0;
      final keys = <String>{};
      for (final campus in ['first', 'second', 'unknown']) {
        final raw =
            jsonDecode(
                  File(
                    'assets/timetable/sookmyung-$campus-2026-2.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        expect(raw['researchOnly'], isFalse);
        expect(raw['completionClaim'], isFalse);
        final ds = UniversityDataset.fromJson(raw);
        for (var i = 0; i < ds.courses.length; i++) {
          final c = ds.courses[i];
          courses.add(c);
          expect(keys.add('${c.code}-${c.section}'), isTrue);
          expect(excludedKeys.contains('${c.code}-${c.section}'), isFalse);
          final row = (raw['courses'] as List)[i] as Map;
          final records = row['metadata']['originalEducationalRecords'] as List;
          nativeCount += records.length;
          for (final dynamic original in records) {
            expect(
              original,
              (proof['nativeRows'] as List).singleWhere(
                (dynamic x) =>
                    x['query'] == original['query'] &&
                    x['sourceRowIndex0'] == original['sourceRowIndex0'],
              ),
            );
            final v = original['values'] as Map;
            expect(v['이수단계'], isNot(contains('석사')));
            expect(v['이수단계'], isNot(contains('박사')));
            expect(c.code, v['과목번호']);
            expect(c.section, v['분반']);
            expect(c.title, v['과목명']);
            expect(c.professor, v['담당교수']);
            expect(c.sourceSchedule, v['강의시간']);
            expect(
              c.credits,
              double.parse((v['학점/이론/실습'] as String).split('/').first),
            );
            expect(
              row['metadata']['queryClassifications'][original['query']],
              v['교과구분'],
            );
            expect(
              row['metadata']['queryGradeEligibility'][original['query']]['이수단계'],
              v['이수단계'],
            );
            expect(
              row['metadata']['queryGradeEligibility'][original['query']]['수강자격'],
              v['수강자격'],
            );
            expect(
              row['metadata']['queryGradeEligibility'][original['query']]['수강유의사항'],
              v['수강유의사항'],
            );
          }
          final categories = records
              .map((dynamic x) => x['values']['교과구분'])
              .toSet();
          expect(
            c.sourceClassification,
            categories.length == 1 ? categories.single : '',
          );
          final literalMatches =
              row['metadata']['newIdentityLiteralCampusMapMatches'] as List? ??
              [];
          for (final dynamic match in literalMatches) {
            expect(
              (nativeMap[match['campus']] as List).any(
                (dynamic building) =>
                    building['nativeBuilding'] == match['nativeMapBuilding'],
              ),
              isTrue,
            );
            expect(c.sourceClassroom, contains(match['sourceClassroom']));
          }
          final holds = row['metadata']['holdReasons'] as List;
          final knownPhysicalPartial =
              (c.code == '21050141' || c.code == '21102403') &&
              c.section == '001';
          if (c.code == '21050141' && c.section == '001') {
            expect(c.sourceSchedule, '월토16:30-19:20(순헌관416)');
            expect(c.meetings, hasLength(7));
            expect(c.meetings.every((m) => m.weekday == 1), isTrue);
            expect(c.period, isNull);
            expect(
              row['metadata']['sourcePublishedDiscontinuousOperatingDateRanges'],
              [
                {'startDate': '2026-09-07', 'endDate': '2026-10-03'},
                {'startDate': '2026-11-23', 'endDate': '2026-12-14'},
              ],
            );
            expect(
              row['metadata']['publishedSaturdayRemoteOperation'],
              '비대면; real-time versus recorded mode unpublished',
            );
            expect(c.remarks, contains('토요일 수업은 비대면으로 진행'));
          }
          if (c.code == '21102403' && c.section == '001') {
            expect(c.meetings, hasLength(7));
            expect(c.meetings.every((m) => m.weekday == 3), isTrue);
            expect(c.period!.contains(DateTime(2026, 9, 16)), isTrue);
            expect(c.period!.contains(DateTime(2026, 11, 4)), isTrue);
            expect(c.period!.contains(DateTime(2026, 9, 15)), isFalse);
            expect(c.period!.contains(DateTime(2026, 11, 5)), isFalse);
            expect(row['metadata']['sourcePublishedWeekdayDeliveryModes'], {
              '수요일': '대면수업',
              '토요일': '비대면 녹화강의',
            });
            expect(c.sourceSchedule, '수15:00-17:50(순헌관201)\n토15:00-17:50()');
            expect(c.remarks, contains('토요일 비대면 녹화강의 진행'));
          }
          final originalIntensive = c.code == '21003187' && c.section == '001';
          final generalIntensive = c.code == '21105703';
          final pharmacyIntensive =
              c.code == '21050396' || c.code == '21104896';
          final historyIntensive = c.code == '21001932' && c.section == '001';
          final lcbIntensive = c.code == '21003817' && c.section == '001';
          final educationIntensive = c.code == '21105380' && c.section == '001';
          final lawIntensive = c.code == '21105942' && c.section == '001';
          final mentoringIntensive =
              c.code == '21105627' && ['001', '002', '005'].contains(c.section);
          final discontinuousIntensive =
              c.code == '21105627' && c.section == '004';
          final careerIntensive =
              c.code == '21103530' && ['001', '002'].contains(c.section);
          final boundedIntensive =
              careerIntensive ||
              originalIntensive ||
              generalIntensive ||
              pharmacyIntensive ||
              historyIntensive ||
              lcbIntensive ||
              educationIntensive ||
              lawIntensive ||
              mentoringIntensive ||
              discontinuousIntensive;
          var operatingStart = DateTime(2026, 9, 1);
          var operatingEnd = originalIntensive
              ? DateTime(2026, 10, 26)
              : DateTime(2026, 12, 7);
          if (careerIntensive) {
            operatingStart = c.section == '001'
                ? DateTime(2026, 9, 2)
                : DateTime(2026, 10, 21);
            operatingEnd = c.section == '001'
                ? DateTime(2026, 10, 21)
                : DateTime(2026, 12, 9);
            expect(c.period!.start, operatingStart);
            expect(c.period!.end, operatingEnd);
            expect(
              c.period!.contains(
                operatingStart.subtract(const Duration(days: 1)),
              ),
              false,
            );
            expect(
              c.period!.contains(operatingEnd.add(const Duration(days: 1))),
              false,
            );
            expect(c.sourceSchedule, '수13:00-14:50(르네상스407)');
            expect(c.professor, '임성민');
            expect(c.remarks, contains('25,26학번 수강불가'));
            expect(c.remarks, contains('재직자전형,편입생 이수면제'));
            final dates = c.section == '001'
                ? [
                    '2026-09-02',
                    '2026-09-09',
                    '2026-09-16',
                    '2026-09-23',
                    '2026-09-30',
                    '2026-10-07',
                    '2026-10-14',
                  ]
                : [
                    '2026-10-28',
                    '2026-11-04',
                    '2026-11-11',
                    '2026-11-18',
                    '2026-11-25',
                    '2026-12-02',
                  ];
            expect(c.meetings.map((m) => m.date).toList(), dates);
          }
          if (mentoringIntensive) {
            operatingEnd = DateTime(2026, 10, 26);
            expect(c.period!.start, DateTime(2026, 9, 1));
            expect(c.period!.end, operatingEnd);
            expect(c.period!.contains(DateTime(2026, 8, 31)), isFalse);
            expect(c.period!.contains(DateTime(2026, 10, 27)), isFalse);
            for (final dynamic r in records) {
              expect(
                r['values']['수강유의사항'],
                '유연학기제(집중학기) 전반기: 2026. 9. 1~10. 26(8주 수업)',
              );
              expect(r['values']['강의형태'], '대면');
            }
          }
          if (discontinuousIntensive) {
            operatingStart = DateTime(2026, 9, 4);
            operatingEnd = DateTime(2026, 11, 6);
            expect(c.period, isNull);
            expect(c.sourceSchedule, '금11:00-14:50(명신관522)');
            expect(c.professor, '동서연');
            expect(c.meetings.map((m) => m.date).toList()..sort(), [
              '2026-09-04',
              '2026-09-11',
              '2026-09-18',
              '2026-10-02',
              '2026-10-16',
              '2026-10-30',
              '2026-11-06',
            ]);
            expect(
              row['metadata']['sourcePublishedDiscontinuousOperatingDateRanges'],
              [
                {'startDate': '2026-09-04', 'endDate': '2026-09-18'},
                {'startDate': '2026-10-02', 'endDate': '2026-10-02'},
                {'startDate': '2026-10-16', 'endDate': '2026-11-06'},
              ],
            );
            for (final dynamic r in records) {
              expect(
                r['values']['수강유의사항'],
                '유연학기제(집중학기) 비연속형: 2026. 9. 4~9. 18/10. 2/10. 16~11. 6(총 8주 수업)',
              );
              expect(r['values']['강의형태'], '대면');
            }
          }
          if (educationIntensive || lawIntensive) {
            operatingEnd = educationIntensive
                ? DateTime(2026, 10, 22)
                : DateTime(2026, 10, 26);
            expect(c.period!.start, DateTime(2026, 9, 1));
            expect(c.period!.end, operatingEnd);
            expect(c.period!.contains(DateTime(2026, 8, 31)), isFalse);
            expect(
              c.period!.contains(operatingEnd.add(const Duration(days: 1))),
              isFalse,
            );
            expect(
              c.sourceSchedule,
              educationIntensive
                  ? '화목15:00-17:50(순헌관210)'
                  : '화15:00-16:50(진리관212)',
            );
            expect(c.professor, educationIntensive ? '이유경\n최인희' : '홍성수');
            for (final dynamic r in records) {
              expect(
                r['values']['수강유의사항'],
                educationIntensive
                    ? '유연학기제(집중학기) : 전반기 (8주 수업)/2026.9.1~2026.10.22/절대평가 적용'
                    : '유연학기제(집중학기) 전반기 2026.9.1.~2026.10.26.(8주)',
              );
              expect(r['values']['교수법'], '');
              expect(r['values']['강의형태'], '대면');
            }
          }
          if (lcbIntensive) {
            operatingEnd = DateTime(2026, 10, 26);
            expect(c.period!.contains(DateTime(2026, 9, 1)), isTrue);
            expect(c.period!.contains(DateTime(2026, 10, 26)), isTrue);
            expect(c.period!.contains(DateTime(2026, 8, 31)), isFalse);
            expect(c.period!.contains(DateTime(2026, 10, 27)), isFalse);
            expect(c.sourceSchedule, '월수15:00-17:50(프라임관204)');
            expect(c.professor, '장서희');
            for (final dynamic r in records) {
              expect(
                r['values']['수강유의사항'],
                '유연학기제(집중학기) 전반기 2026.9.1.~2026.10.26.(8주)',
              );
              expect(r['values']['수강자격'], '제1전공 LCB외식경영전공');
            }
          }
          if (historyIntensive) {
            operatingEnd = DateTime(2026, 10, 26);
            expect(c.period!.contains(DateTime(2026, 9, 1)), isTrue);
            expect(c.period!.contains(DateTime(2026, 10, 26)), isTrue);
            expect(c.period!.contains(DateTime(2026, 8, 31)), isFalse);
            expect(c.period!.contains(DateTime(2026, 10, 27)), isFalse);
            expect(c.sourceSchedule, '화목15:00-17:50(명신관308)');
            expect(c.professor, '강혜경');
            for (final dynamic r in records) {
              expect(
                r['values']['수강유의사항'],
                '유연학기제(집중학기) 전반기 수업: 2026.09.01.~2026.10.26.(8주 수업)',
              );
            }
          }
          if (pharmacyIntensive) {
            final firstHalf = c.code == '21050396';
            operatingStart = firstHalf
                ? DateTime(2026, 9, 2)
                : DateTime(2026, 10, 30);
            operatingEnd = firstHalf
                ? DateTime(2026, 10, 21)
                : DateTime(2026, 12, 18);
            for (final dynamic r in records) {
              expect(
                r['values']['수강유의사항'],
                contains(
                  firstHalf
                      ? '전반기 집중학기 운영(9/2~10/21)'
                      : '후반기 집중학기 운영(10/30~12/18)',
                ),
              );
              expect(r['values']['강의형태'], '대면');
            }
            expect(c.period!.contains(operatingStart), isTrue);
            expect(c.period!.contains(operatingEnd), isTrue);
            expect(
              c.period!.contains(
                operatingStart.subtract(const Duration(days: 1)),
              ),
              isFalse,
            );
            expect(
              c.period!.contains(operatingEnd.add(const Duration(days: 1))),
              isFalse,
            );
            expect(
              c.meetings.every(
                (m) =>
                    !DateTime.parse(m.date!).isBefore(operatingStart) &&
                    !DateTime.parse(m.date!).isAfter(operatingEnd),
              ),
              isTrue,
            );
            if (!firstHalf) {
              expect(
                row['metadata']['individualMakeupFinalDaysUnknownHold'],
                isNotNull,
              );
              expect(
                c.meetings.every(
                  (m) =>
                      DateTime.parse(m.date!).isBefore(DateTime(2026, 12, 8)),
                ),
                isTrue,
              );
            }
          }
          if (generalIntensive) {
            const expectedNativeBounds = {
              '001': ['2026-09-07', '2026-10-26', '2026.09.07.-10.26.'],
              '002': ['2026-09-01', '2026-10-20', '2026.09.01.-10.20.'],
              '003': ['2026-09-07', '2026-10-26', '2026.09.07.-10.26.'],
              '004': ['2026-09-03', '2026-10-22', '2026.09.03.-10.22.'],
              '005': ['2026-09-02', '2026-10-21', '2026.09.02.-10.21.'],
              '006': ['2026-09-03', '2026-10-22', '2026.09.03.-10.22.'],
              '007': ['2026-09-01', '2026-10-20', '2026.09.01.-10.20.'],
              '008': ['2026-09-02', '2026-10-21', '2026.09.02.-10.21.'],
              '009': ['2026-09-02', '2026-10-21', '2026.09.02.-10.21.'],
            };
            final bounds = expectedNativeBounds[c.section]!;
            operatingStart = DateTime.parse(bounds[0]);
            operatingEnd = DateTime.parse(bounds[1]);
            expect(c.period!.contains(operatingStart), isTrue);
            expect(c.period!.contains(operatingEnd), isTrue);
            expect(
              c.period!.contains(
                operatingStart.subtract(const Duration(days: 1)),
              ),
              isFalse,
            );
            expect(
              c.period!.contains(operatingEnd.add(const Duration(days: 1))),
              isFalse,
            );
            for (final dynamic r in records) {
              expect(r['values']['수강유의사항'], contains(bounds[2]));
              expect(r['values']['수강자격'], '[1학년]자유전공학부');
              expect(r['values']['강의형태'], '대면');
            }
          }
          if (originalIntensive) {
            expect(
              c.sourceSchedule,
              '월15:30-18:20(명신관701)\n수15:30-18:20(명신관701)',
            );
            expect(c.professor, '정영주');
            expect(c.period!.contains(DateTime(2026, 9, 1)), true);
            expect(c.period!.contains(DateTime(2026, 10, 26)), true);
            expect(c.period!.contains(DateTime(2026, 8, 31)), false);
            expect(c.period!.contains(DateTime(2026, 10, 27)), false);
            expect(
              c.meetings.every(
                (m) => !DateTime.parse(m.date!).isAfter(DateTime(2026, 10, 26)),
              ),
              true,
            );
            expect(
              records.every(
                (dynamic x) =>
                    x['values']['수강유의사항'] ==
                    '유연학기제(집중학기) 전반기 : 2026.09.01 ~ 2026.10.26 (8주 수업)',
              ),
              true,
            );
          }
          final nativeLive = c.code == '21002656' && c.section == '001';
          if (nativeLive) {
            expect(c.sourceSchedule, '월수10:30-11:45(미래창조관202호)');
            expect(c.professor, '박종훈');
            expect(c.campus, 'unknown');
            expect(
              records.every(
                (dynamic x) =>
                    x['values']['강의형태'] == '원격(실시간)' &&
                    (x['values']['수강유의사항'] as String).contains(
                      '연세대와 공동강의로 원격강의',
                    ),
              ),
              true,
            );
          }
          final sourceRequiresHold = records.any((dynamic x) {
            final v = x['values'] as Map;
            return (v['강의형태'] != '대면' && !nativeLive) ||
                v['교수법'] == 'BL' ||
                v['수강유의사항'] == '추후 담당교원이 강의계획서 입력 예정' ||
                ((c.code == '21001065' && c.section == '004') ||
                    (c.code == '21002177' && c.section == '001') ||
                    c.code == '21000811' && c.section == '001') ||
                (!boundedIntensive &&
                    !knownPhysicalPartial &&
                    RegExp(
                      r'주차|집중|비연속|외부실습|현장실습|건강가정실습|연락',
                    ).hasMatch('${v['과목명']} ${v['수강유의사항']}'));
          });
          if (sourceRequiresHold &&
              !reviewedPendingPlanIds.contains(c.sourceId)) {
            expect(c.meetings, isEmpty);
          }
          expect(c.hasSchedulableMeetings, holds.isEmpty);
          if (holds.isNotEmpty) {
            heldCount++;
            expect(c.meetings, isEmpty);
            continue;
          }
          final expected = <String>{};
          int minute(String x) {
            final p = x.split(':');
            return int.parse(p[0]) * 60 + int.parse(p[1]);
          }

          if (knownPhysicalPartial) {
            final wednesday = c.code == '21102403';
            final dates = wednesday
                ? [
                    '2026-09-16',
                    '2026-09-23',
                    '2026-09-30',
                    '2026-10-07',
                    '2026-10-14',
                    '2026-10-28',
                    '2026-11-04',
                  ]
                : [
                    '2026-09-07',
                    '2026-09-14',
                    '2026-09-21',
                    '2026-09-28',
                    '2026-11-23',
                    '2026-11-30',
                    '2026-12-07',
                  ];
            for (final date in dates) {
              expected.add(
                wednesday
                    ? '$date/3/900/1070/순헌관201'
                    : '$date/1/990/1160/순헌관416',
              );
            }
            expect(
              row['metadata']['knownPhysicalWeekdayPartial']['heldOtherWeekday'],
              '토요일',
            );
            for (final dynamic r in records) {
              expect(r['values']['강의형태'], '대면');
              expect(
                r['values']['수강유의사항'],
                wednesday
                    ? '유연학기제(집중학기) 중반기 : 2026.9.16.~11.4.(8주 수업), 수요일 대면수업, 토요일 비대면 녹화강의 진행(강의계획서 참고)'
                    : '집중학기제로 진행 예정(9/7~10/3, 11/23~12/14), 토요일 수업은 비대면으로 진행',
              );
            }
          }
          if (!knownPhysicalPartial) {
            for (final m in RegExp(
              r'([월화수목금토일]+)(\d\d?:\d\d)-(\d\d?:\d\d)\(([^)]+)\)',
            ).allMatches(c.sourceSchedule)) {
              for (
                var d = operatingStart;
                !d.isAfter(operatingEnd);
                d = d.add(const Duration(days: 1))
              ) {
                if (!m[1]!.contains('월화수목금토일'[d.weekday - 1])) continue;
                final date = d.toIso8601String().substring(0, 10);
                if (discontinuousIntensive &&
                    ![
                      '2026-09-04',
                      '2026-09-11',
                      '2026-09-18',
                      '2026-10-02',
                      '2026-10-16',
                      '2026-10-23',
                      '2026-10-30',
                      '2026-11-06',
                    ].contains(date)) {
                  continue;
                }
                if ((proof['nationalHolidayDateReference']['conservativeUnknownOperationHoldDates']
                            as List)
                        .contains(date) ||
                    (!d.isBefore(DateTime(2026, 10, 20)) &&
                        !d.isAfter(DateTime(2026, 10, 26))) ||
                    (!d.isBefore(DateTime(2026, 12, 8)) &&
                        !d.isAfter(DateTime(2026, 12, 21)))) {
                  continue;
                }
                expected.add(
                  '${d.toIso8601String().substring(0, 10)}/${d.weekday}/${minute(m[2]!)}/${minute(m[3]!)}/${m[4]}',
                );
              }
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
          );
          meetingCount += c.meetings.length;
          expect(
            (row['schedules'] as List).every(
              (dynamic x) => nativeLive
                  ? (x as Map)['deliveryMode'] == 'liveOnline'
                  : knownPhysicalPartial
                  ? (x as Map)['deliveryMode'] == 'inPerson'
                  : !(x as Map).containsKey('deliveryMode'),
            ),
            isTrue,
          );
          expect(row['metadata']['actualAttendanceConfirmed'], isFalse);
        }
      }
      for (final nativeCode in [
        '21104936',
        '21103165',
        '21003503',
        '21105429',
        '21001956',
        '21104326',
        '21003884',
        '21102543',
      ]) {
        final course = courses.singleWhere(
          (c) => c.code == nativeCode && c.section == '001',
        );
        expect(course.sourceSchedule, '');
        expect(course.meetings, isEmpty);
      }
      final restricted = courses.singleWhere(
        (c) => c.code == '21003852' && c.section == '002',
      );
      expect(restricted.remarks, contains('재직자전형 전용 분반'));
      final departmentRestricted = courses.singleWhere(
        (c) => c.code == '21000945' && c.section == '001',
      );
      expect(departmentRestricted.remarks, contains('[제한] 행정학과(제1전공자)'));
      final malformedExamNote = courses.singleWhere(
        (c) => c.code == '21105769' && c.section == '001',
      );
      expect(malformedExamNote.meetings, isEmpty);
      expect(malformedExamNote.remarks, contains('18:30~17:30'));
      final datedCyberMath = courses.singleWhere(
        (c) => c.code == '21104653' && c.section == '001',
      );
      expect(datedCyberMath.meetings, isEmpty);
      expect(datedCyberMath.remarks, contains('10/23(금), 12/11(금) 15시~17시'));
      final airRotc = courses.singleWhere(
        (c) => c.code == '21105113' && c.section == '001',
      );
      expect(airRotc.remarks, contains('공군 학군단 후보생만 신청 가능'));
      final armyRotc = courses.singleWhere(
        (c) => c.code == '21050321' && c.section == '001',
      );
      expect(armyRotc.remarks, contains('육군 학군단 후보생만 신청가능'));
      final germanBeginner = courses.singleWhere(
        (c) => c.code == '21002089' && c.section == '001',
      );
      expect(germanBeginner.meetings, isEmpty);
      final germanPriorKnowledge = courses.singleWhere(
        (c) => c.code == '21002089' && c.section == '002',
      );
      expect(germanPriorKnowledge.hasSchedulableMeetings, isTrue);
      expect(germanPriorKnowledge.remarks, contains('선지식이 있는 학생들'));
      final germanBlArt = courses.singleWhere(
        (c) => c.code == '21105619' && c.section == '001',
      );
      expect(germanBlArt.meetings, isEmpty);
      for (final pendingCode in ['21003076', '21003994']) {
        final pending = courses.singleWhere(
          (c) => c.code == pendingCode && c.section == '001',
        );
        expect(pending.meetings, hasLength(25));
        expect(pending.remarks, contains('추후 담당교원이 강의계획서 입력 예정'));
      }
      final sensor = courses.singleWhere(
        (c) => c.code == '21102529' && c.section == '001',
      );
      expect(sensor.meetings, isEmpty);
      expect(sensor.remarks, contains('비연속형 1~7주, 14주'));
      final frenchBl = courses.singleWhere(
        (c) => c.code == '21000092' && c.section == '001',
      );
      expect(frenchBl.meetings, isEmpty);
      final japaneseTeaching = courses.singleWhere(
        (c) => c.code == '21050136' && c.section == '001',
      );
      expect(japaneseTeaching.hasSchedulableMeetings, isTrue);
      expect(japaneseTeaching.remarks, contains('이수단계 교직'));
      expect(japaneseTeaching.sourceClassification, '전공선택');
      expect(japaneseTeaching.remarks, contains('교직'));
      final skating = courses.singleWhere(
        (c) => c.code == '21000607' && c.section == '001',
      );
      expect(skating.sourceSchedule, '토11:00-12:50(순헌관109)');
      expect(skating.hasSchedulableMeetings, isTrue);
      final danceCapstone = courses.singleWhere(
        (c) => c.code == '21104611' && c.section == '001',
      );
      expect(danceCapstone.hasSchedulableMeetings, isTrue);
      for (final musicNoClock in [
        '21050029',
        '21003549',
        '21003541',
        '21003543',
        '21003545',
        '21003547',
      ]) {
        final music = courses.singleWhere(
          (c) => c.code == musicNoClock && c.section == '001',
        );
        expect(music.sourceSchedule, '');
        expect(music.meetings, isEmpty);
      }
      final orchestra = courses.singleWhere(
        (c) => c.code == '21002689' && c.section == '001',
      );
      expect(
        orchestra.sourceSchedule,
        '수10:00-11:50(르네상스201)\n금15:00-16:50(르네상스201)',
      );
      expect(orchestra.meetings.map((m) => m.weekday).toSet(), {3, 5});
      expect(orchestra.campus, 'unknown');
      final artPbl = courses.singleWhere(
        (c) => c.code == '21001592' && c.section == '001',
      );
      expect(artPbl.hasSchedulableMeetings, isTrue);
      expect(
        (proof['nativeRows'] as List).singleWhere(
          (dynamic r) =>
              r['query'] == '회화과' && r['values']['과목번호'] == '21001592',
        )['values']['교수법'],
        'PBL',
      );
      final pianoWholeProfessors = courses.singleWhere(
        (c) => c.code == '21050014' && c.section == '001',
      );
      expect(pianoWholeProfessors.professor, '박수진\n전혜수\n이혜영');
      expect(pianoWholeProfessors.hasSchedulableMeetings, isTrue);
      for (final noClockPiano in [
        '21001184',
        '21001138',
        '21001140',
        '21001142',
        '21001144',
      ]) {
        final piano = courses.singleWhere(
          (c) => c.code == noClockPiano && c.section == '001',
        );
        expect(piano.professor, '전혜수\n이혜영');
        expect(piano.sourceSchedule, '');
        expect(piano.meetings, isEmpty);
      }
      for (final noClockVoice in [
        '21001337',
        '21001244',
        '21001246',
        '21001248',
        '21001250',
      ]) {
        final voice = courses.singleWhere(
          (c) => c.code == noClockVoice && c.section == '001',
        );
        expect(voice.sourceSchedule, '');
        expect(voice.meetings, isEmpty);
        expect(voice.remarks, contains('성악과 제1/부/복수 전공생만 수강 가능'));
      }
      final voiceRestrictedWeekly = courses.singleWhere(
        (c) => c.code == '21050044' && c.section == '001',
      );
      expect(voiceRestrictedWeekly.hasSchedulableMeetings, isTrue);
      expect(voiceRestrictedWeekly.remarks, contains('성악과 제1/부/복수 전공생만 수강 가능'));
      for (final doubleRoomCode in ['21002867', '21002869']) {
        final studio = courses.singleWhere(
          (c) => c.code == doubleRoomCode && c.section == '001',
        );
        expect(studio.sourceClassroom, contains('미술대206'));
        expect(studio.sourceClassroom, contains('미술대302'));
        expect(studio.meetings, isEmpty);
        expect(studio.remarks, contains('individual room assignment unknown'));
        final separateStudio = courses.singleWhere(
          (c) => c.code == doubleRoomCode && c.section == '002',
        );
        expect(separateStudio.hasSchedulableMeetings, isTrue);
      }
      final designThreeProfessors = courses.singleWhere(
        (c) => c.code == '21001486' && c.section == '001',
      );
      expect(designThreeProfessors.professor, '강현정\n최희경\n이채린');
      final designCapstone = courses.singleWhere(
        (c) => c.code == '21101776' && c.section == '001',
      );
      expect(designCapstone.hasSchedulableMeetings, isTrue);
      final foodFourProfessors = courses.singleWhere(
        (c) => c.code == '21105576' && c.section == '001',
      );
      expect(foodFourProfessors.professor, '이재연\n주나미\n윤요한\n김성은');
      expect(foodFourProfessors.hasSchedulableMeetings, isTrue);
      expect(
        foodFourProfessors.remarks,
        contains('2026 식품영양학과 신입생 및 자유전공학부 학생만 수강 가능'),
      );
      final foodPlacement = courses.singleWhere(
        (c) => c.code == '21000797' && c.section == '001',
      );
      expect(foodPlacement.meetings, isEmpty);
      expect(foodPlacement.sourceSchedule, '');
      expect(
        foodPlacement.remarks,
        contains('영양사현장실습 완료하여 실습일지 제출 가능한 학생만 수강 가능'),
      );
      for (final section in ['001', '002']) {
        final foodBl = courses.singleWhere(
          (c) => c.code == '21000790' && c.section == section,
        );
        expect(foodBl.meetings, isEmpty);
      }
      final foreignOnlyKorean = courses.singleWhere(
        (c) => c.code == '21102829' && c.section == '001',
      );
      expect(foreignOnlyKorean.remarks, contains('외국인 유학생, 외국인 교한학생만 신청 가능'));
      for (final clothingDoubleRoom in [
        ['21050081', '001'],
        ['21050081', '002'],
        ['21001767', '001'],
        ['21102397', '001'],
        ['21102397', '002'],
        ['21103760', '001'],
        ['21102396', '001'],
        ['21102396', '002'],
      ]) {
        final course = courses.singleWhere(
          (c) =>
              c.code == clothingDoubleRoom[0] &&
              c.section == clothingDoubleRoom[1],
        );
        expect(course.meetings, isEmpty);
        expect(course.remarks, contains('individual room assignment unknown'));
      }
      final aiFashion = courses.singleWhere(
        (c) => c.code == '21105802' && c.section == '001',
      );
      expect(aiFashion.hasSchedulableMeetings, isTrue);
      expect(aiFashion.remarks, contains('소셜미디어패션마케팅(21104174) 미수강자만 수강 가능'));
      final clothingFourProfessors = courses.singleWhere(
        (c) => c.code == '21003461' && c.section == '001',
      );
      expect(clothingFourProfessors.professor, '이승희\n김혜림\n임호선\n한상경');
      final consumerDay = courses.singleWhere(
        (c) => c.code == '21003426' && c.section == '001',
      );
      final consumerNight = courses.singleWhere(
        (c) => c.code == '21003426' && c.section == '002',
      );
      expect(consumerDay.remarks, contains('소경 재직자는 수강불가'));
      expect(consumerNight.remarks, contains('재직자전형만 수강가능'));
      expect(consumerNight.remarks, contains('학점교류생 수강 불가'));
      expect(consumerNight.sourceSchedule, '수19:00-21:50(명신관215)');
      expect(consumerNight.hasSchedulableMeetings, isTrue);
      final socialFourProfessors = courses.singleWhere(
        (c) => c.code == '21105375' && c.section == '001',
      );
      expect(socialFourProfessors.professor, '주민주\n김민지\n박지선\n최지연');
      expect(socialFourProfessors.meetings, isEmpty);
      expect(socialFourProfessors.remarks, contains('오전 9시-10시'));
      final physiology = courses.singleWhere(
        (c) => c.code == '21010017' && c.section == '001',
      );
      expect(physiology.meetings, isEmpty);
      expect(physiology.remarks, contains('장소 추후 안내'));
      final industrial001 = courses.singleWhere(
        (c) => c.code == '21050279' && c.section == '001',
      );
      final industrial002 = courses.singleWhere(
        (c) => c.code == '21050279' && c.section == '002',
      );
      expect(industrial001.professor, '추석화\n전진현');
      expect(industrial002.professor, '전진현\n추석화');
      final visual001 = courses.singleWhere(
        (c) => c.code == '21002748' && c.section == '001',
      );
      expect(visual001.remarks, contains('타전공, 타학년 수강신청 불가'));
      expect(visual001.remarks, contains('1학기와 2학기 모두 동일한 분반'));
      final visualPending = courses.singleWhere(
        (c) => c.code == '21105807' && c.section == '003',
      );
      expect(visualPending.professor, '김희수');
      expect(visualPending.remarks, contains('담당 교강사 신규 채용 중으로 확정 예정'));
      final prCyber = courses.singleWhere(
        (c) => c.code == '21000978' && c.section == '001',
      );
      expect(prCyber.meetings, isEmpty);
      expect(prCyber.remarks, contains('홍보광고학과 제1전공자 수강신청 불가 (타학과 학생 대상)'));
      final physicsExcluded = (proof['excludedGraduateRecords'] as List)
          .where((dynamic r) => r['query'] == '신소재물리학부')
          .toList();
      expect(physicsExcluded, hasLength(2));
      expect(
        physicsExcluded.every(
          (dynamic r) =>
              r['values']['이수단계'] == '석사' && r['values']['수강유의사항'] == '학석사연계과목',
        ),
        isTrue,
      );
      final physicsRestriction = courses.singleWhere(
        (c) => c.code == '21104602' && c.section == '002',
      );
      expect(physicsRestriction.remarks, contains('전자공, 지능형전자시스템만 수강가능'));
      final internationalOnly = courses.singleWhere(
        (c) => c.code == '21105439' && c.section == '001',
      );
      expect(internationalOnly.remarks, contains('한류국제대학만 수강 가능'));
      expect(internationalOnly.professor, '홍소영\n박지현');
      final lcbFourProfessors = courses.singleWhere(
        (c) => c.code == '21003723' && c.section == '001',
      );
      expect(lcbFourProfessors.professor, '김수정\n마사드세바스챤드\n마통세드릭\n차희은');
      expect(lcbFourProfessors.remarks, contains('제1전공 LCB외식경영전공'));
      expect(
        lcbFourProfessors.remarks,
        contains('제1전공자 1학년 수강 필수 과목(타학년 수강 불가)'),
      );
      final kitchen = courses.singleWhere(
        (c) => c.code == '21003808' && c.section == '001',
      );
      expect(kitchen.professor, lcbFourProfessors.professor);
      expect(kitchen.sourceSchedule, '수금09:00-11:20(백주년505)');
      expect(kitchen.meetings, isEmpty);
      expect(kitchen.remarks, contains('12~14주 실습수업진행'));
      expect(kitchen.remarks, contains('실습은 분반수업임'));
      for (final code in ['21105793', '21105792']) {
        final course = courses.singleWhere(
          (c) => c.code == code && c.section == '001',
        );
        expect(course.meetings, hasLength(25));
        expect(course.remarks, contains('한류국제대학만 수강 가능'));
        expect(
          course.sourceSchedule,
          code == '21105793'
              ? '월수12:00-13:15(명신관103)'
              : '화목12:00-13:15(명신관417)',
        );
        expect(course.professor, code == '21105793' ? '한정환' : '박정아');
      }
      final pendingService = courses.singleWhere(
        (c) => c.code == '21002177' && c.section == '001',
      );
      expect(pendingService.professor, '노은정');
      expect(pendingService.sourceSchedule, '목19:00-21:50(프라임관105)');
      expect(pendingService.meetings, hasLength(12));
      expect(
        pendingService.remarks,
        contains('교강사 추후 입력 예정/강의계획서 메일 드라이브 링크 참조'),
      );
      expect(pendingService.remarks, contains('재직자 전형'));
      for (final code in ['21104001', '21104000']) {
        final course = courses.singleWhere(
          (c) => c.code == code && c.section == '001',
        );
        expect(course.sourceSchedule, '');
        expect(course.professor, '');
        expect(course.meetings, isEmpty);
        expect(course.remarks, contains('학생은 수강신청 불가'));
      }
      for (final code in ['21101031', '21101030', '21101028']) {
        final course = courses.singleWhere(
          (c) => c.code == code && c.section == '001',
        );
        expect(course.meetings, isEmpty);
        expect(
          course.remarks,
          contains('BL individual physical/remote sessions unpublished'),
        );
      }
      for (final row in [
        ['21103838', '목15:00-17:50(순헌관109)', '박영민', 12],
        ['21101547', '월13:30-16:30(순헌관109)', '노승림', 12],
        ['21101834', '화목12:00-13:15(명신관521)', '강지은\n유지민', 25],
      ]) {
        final course = courses.singleWhere(
          (c) => c.code == row[0] && c.section == '001',
        );
        expect(course.sourceSchedule, row[1]);
        expect(course.professor, row[2]);
        expect(course.meetings, hasLength(row[3] as int));
      }
      final pendingConsumer = courses.singleWhere(
        (c) => c.code == '21001065' && c.section == '004',
      );
      expect(pendingConsumer.professor, '노은정');
      expect(pendingConsumer.sourceSchedule, '화목13:30-14:45(명신관516)');
      expect(pendingConsumer.meetings, hasLength(25));
      expect(
        pendingConsumer.remarks,
        contains('교강사 추후 입력 예정/강의계획서 메일 드라이브 링크 참조'),
      );
      for (final query in ['부동산학전공', '북한과통일학전공', '비서학전공']) {
        final source = (proof['sourceFiles'] as List).singleWhere(
          (dynamic r) => r['query'] == query,
        );
        expect(source['rows'], 0);
        expect(
          (proof['nativeRows'] as List).where(
            (dynamic r) => r['query'] == query,
          ),
          isEmpty,
        );
      }
      for (final row in [
        ['21002111', '화15:00-18:50(순헌관101)', '이선희', 13],
        ['21003644', '화목16:30-17:45(진리관308)', '박영덕', 25],
        ['21105243', '화목12:00-13:15(명신관317)', '박영덕', 25],
      ]) {
        final course = courses.singleWhere(
          (c) => c.code == row[0] && c.section == '001',
        );
        expect(course.sourceSchedule, row[1]);
        expect(course.professor, row[2]);
        expect(course.meetings, hasLength(row[3] as int));
      }
      final counseling = courses.singleWhere(
        (c) => c.code == '21002111' && c.section == '001',
      );
      expect(counseling.remarks, contains('상담학 연계 전공 학생만 수강 가능'));
      expect(counseling.remarks, contains('P/F 평가 과목'));
      for (final query in ['스마트그린·케어공학전공', '안보학전공', '인재개발전공', '첨단소재·전자융합공학부']) {
        final source = (proof['sourceFiles'] as List).singleWhere(
          (dynamic r) => r['query'] == query,
        );
        expect(source['rows'], 0);
        expect(
          (proof['nativeRows'] as List).where(
            (dynamic r) => r['query'] == query,
          ),
          isEmpty,
        );
      }
      final teacherSource = (proof['sourceFiles'] as List).singleWhere(
        (dynamic r) => r['query'] == '교직',
      );
      expect(teacherSource['rows'], 19);
      final teacherNative = (proof['nativeRows'] as List)
          .where((dynamic r) => r['query'] == '교직')
          .toList();
      for (final row in teacherNative) {
        expect(row['nativeEducationalCells'], hasLength(21));
        expect(row['nativeHeaders'], isNot(contains('코드쉐어')));
        expect(row['values']['교과구분'], '교직');
        final course = courses.singleWhere(
          (c) =>
              c.code == row['values']['과목번호'] &&
              c.section == row['values']['분반'],
        );
        if (course.code == '21009837' || course.code == '21004663') {
          expect(course.professor, '');
          expect(course.sourceSchedule, '');
          expect(course.meetings, isEmpty);
          expect(course.remarks, contains('교원양성센터 홈페이지 공지사항 확인 필수'));
        } else {
          expect(course.meetings, isNotEmpty);
          expect(course.remarks, contains('교직 이수자 우선'));
        }
      }
      final curriculum = courses.singleWhere(
        (c) => c.code == '21009876' && c.section == '001',
      );
      expect(curriculum.sourceSchedule, '화16:00-17:50(명신관202)');
      expect(curriculum.professor, '박진은');
      final digitalEducation = courses.singleWhere(
        (c) => c.code == '21105381' && c.section == '001',
      );
      expect(digitalEducation.sourceSchedule, '목16:00-16:50(명신관202)');
      expect(digitalEducation.remarks, contains('교직이수기준년도 2024 부터 필수'));
      for (final query in ['교양필수-영어토론과발표', '교양필수-융합적사고와글쓰기', '공통-마이크로디그리']) {
        final source = (proof['sourceFiles'] as List).singleWhere(
          (dynamic r) => r['query'] == query,
        );
        expect(source['rows'], 0);
      }
      final branding = courses.where((c) => c.code == '21105631').toList();
      expect(branding, hasLength(31));
      for (final course in branding) {
        expect(course.remarks, contains('수강정정시 25, 26학번 모든학과 수강 가능'));
        expect(course.remarks, contains('외국인유학생 수강불가'));
        expect(
          course.meetings,
          hasLength(int.parse(course.section) <= 26 ? 25 : 11),
        );
      }
      for (final code in [
        '21102196',
        '21103465',
        '21101807',
        '21105884',
        '21105886',
        '21105758',
        '21105757',
        '21105965',
        '21104681',
      ]) {
        expect(courses.any((c) => c.code == code && c.section == '001'), false);
        expect(excludedKeys, contains('$code-001'));
      }
      final kpopMicro = courses.singleWhere(
        (c) => c.code == '21105956' && c.section == '001',
      );
      expect(kpopMicro.sourceSchedule, '화목15:00-16:15(프라임관202)');
      expect(kpopMicro.professor, '안은경');
      expect(kpopMicro.remarks, contains('마이크로디그리 신청학생 우선 확정'));
      final peace = courses.singleWhere(
        (c) => c.code == '21105930' && c.section == '001',
      );
      expect(peace.sourceSchedule, '화목10:30-11:45(명신관519)');
      expect(peace.professor, '최윤주');
      expect(courses, hasLength(1485));
      expect(nativeCount, 3427);
      expect(heldCount, 204);
      expect(meetingCount, 23676);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final before = courses
            .where((c) => c.hasSchedulableMeetings)
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final doc = TimetableSyncDocument.legacy(
          courses: before,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final after = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(after, hasLength(1281));
        final originals = {for (final c in before) c.sourceId: c};
        for (final c in after) {
          final original = originals[c.sourceId]!;
          expect(c.isValid, isTrue);
          expect(c.title, original.title);
          expect(c.professor, original.professor);
          expect(c.note, original.note);
          expect(c.period, original.period);
          expect(c.defaultMode, mode);
          expect(
            c.meetings.map((m) => m.toJson()).toList(),
            original.meetings.map((m) => m.toJson()).toList(),
          );
          for (final m in c.meetings) {
            expect(
              c.modeOn(m, DateTime.parse(m.date!)),
              c.sourceId!.endsWith('21002656-001')
                  ? LectureMode.liveOnline
                  : (c.sourceId!.endsWith('21050141-001') ||
                        c.sourceId!.endsWith('21102403-001'))
                  ? LectureMode.inPerson
                  : mode,
            );
          }
        }
      }
    },
  );
}
