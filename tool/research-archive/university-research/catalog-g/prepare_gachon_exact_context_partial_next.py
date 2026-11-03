"""Re-evaluate previously reviewed supplemental preclass activity, without changing published plans."""
import collections
import copy
import datetime as dt
import hashlib
import json
from pathlib import Path
from prepare_gachon_dated_regular_candidate import HOLIDAYS, NOTE
from validate_gachon_individual_weekly_period import current_period_weekly_rows_consistent

ROOT = Path(__file__).resolve().parent

def read(name):
    return json.loads((ROOT / name).read_text())

def main():
    reports = {(r['campus'], r['sourceRow']['HAKSU_NO']): r for r in read('gachon-full-operating-report-audit.json')['reports']}
    reviews = {(r['campus'], r['officialOfferingCode']): r for r in read('gachon-full-operating-semantic-review.json')['rows']}
    bases = {(c['campusSourceCode'], c['officialOfferingCode']): c for c in read('gachon-full-normalized-source-candidates.json')['courses']}
    audit = {'completionClaim': False, 'productionRegistered': False,
             'currentFullCollectionComplete': True, 'currentFullOperatingApprovalComplete': False,
             'excludedNationalHolidays': sorted(HOLIDAYS), 'datasets': [], 'promoted': [],
             'reviewPolicy': '37 current plans with date/clock markers reviewed in actual educational context. Chapter decimals,scale ratios,history dates,recall/incubation durations and assignment deadlines not attendance changes. Exact ordinary source slots retained; actual autonomous9plus, even-week only,09:30early/advanced1-7, differing lab rooms/subgroup,report-only/physical-assessment/counselling/finaloutside-period scopes held individually. Exact admission/video/activity/field dates withheld with no cancellation claim or fake replacement. Current normal planning not contact-duration or exam-time assertion.', 'productionProjectionPermitted':'validated2841PublishedPlansOnly',
             'previousManifest': 'gachon-published-regular-2804-operating-partial-v3-next-sha-manifest-20261008.json'}
    for campus in ['global', 'medical']:
        name = f'gachon-{campus}-2026-2.published-regular-2804-operating-partial-v3-next-20261008.json'
        original = read(name)
        data = copy.deepcopy(original)
        for c in data['courses']:
            key = ('20' if campus == 'global' else '21', c['courseCode'] + c['section'])
            review, report, base = reviews[key], reports[key], bases[key]
            method = report['teachingMethodEducationalExcerpt']
            targets = {'M0859002', '15459001', '15530001', '11351001', '09130002', '61225003', '14329001', '12016001', '11670005', '09130001', '61586001', '12016002', '15744002', '61290001', 'M1124001', '60000060', '13310001', '15903001', '15314013', '61431002', '11351002', '61225001', '61225002', '61490001', '15343001', '13829001', '07392001', '61390001', '61431007', '11699001', 'M1124002', '14931003', '03129001', '61524001', '61065001', 'M0152001', 'M0859004'}
            if c['scheduleStatus'] != 'unrecognized' or key[1] not in targets:
                continue
            assert report['educationalParserVersion'] == 6
            assert all(report['report'][k] for k in ['headerCourseCodeMatches', 'currentTermMatches', 'catalogProfessorAppearsInReport'])
            blocks = copy.deepcopy(base['schedules'])
            if key[1] == '61490001':
                assert not blocks
                slots = base['publishedActualSlots']
                assert [(v['weekday'],v['period']) for v in slots] == [(1,4),(1,5),(2,1),(2,2)]
                for group in [slots[:2],slots[2:]]:
                    blocks.append({'weekday':group[0]['weekday'],'firstPeriod':group[0]['period'],'lastPeriod':group[-1]['period'],'startMinute':group[0]['startMinute'],'endMinute':group[-1]['endMinute'],'classroom':base['rawRoom']})
            else:
                assert base['schedulingDecision'] == 'regularCandidate' and not base['blockingReasons']
            assert blocks
            result = current_period_weekly_rows_consistent(report, base)
            assert result is True, (key, result)
            assert not any(w['operatingContextTruncationDetected'] or w['operatingContextLimitReached'] for w in report['weeklyRows'])
            weekly_contexts = [t for w in report['weeklyRows'] for t in w['operatingContexts']]
            omitted_weeks_by_offering = {'09130001': [9, 10, 11, 12, 13, 14, 15], '09130002': [9, 10, 11, 12, 13, 14, 15], '11670005': [8], '12016001': [15], '12016002': [15], '15314013': [14], '15459001': [7, 8, 14, 15], '61065001': [4, 5], '61225001': [1, 3, 5, 7, 9, 11], '61225002': [1, 3, 5, 7, 9, 11], '61431007': [6, 12], 'M0859002': [1, 2, 3, 4, 5, 6, 7], 'M0859004': [1, 2, 3, 4, 5, 6, 7], 'M1124001': [4, 6], 'M1124002': [4, 6]}
            omitted = [w for w in report['weeklyRows'] if w['week'] in omitted_weeks_by_offering.get(key[1], [])]
            held_dates_by_offering = {'03129001':['2026-12-01'],'13829001':['2026-12-01'],'14931003':['2026-12-01'],'11670005':['2026-10-05','2026-11-30'],'15343001':['2026-09-24','2026-10-05','2026-11-30'],'60000060':['2026-11-30','2026-12-01'],'61490001':['2026-10-05']}
            held_dates = held_dates_by_offering.get(key[1], [])
            omitted_ranges = [tuple(dt.date(2026,*map(int,w[k].split('/'))) for k in ['startMonthDay','endMonthDay']) for w in omitted]
            begin, end = (dt.date.fromisoformat(c['period'][k]) for k in ['startDate', 'endDate'])
            meetings = []
            for block in blocks:
                day = begin
                while day <= end:
                    if day.isoweekday() == block['weekday'] and day.isoformat() not in HOLIDAYS and day.isoformat() not in held_dates and day.isoweekday() != 7 and not any(a <= day <= z for a,z in omitted_ranges):
                        meetings.append({k: v for k, v in {**block, 'date': day.isoformat()}.items() if k not in ['firstPeriod', 'lastPeriod']})
                    day += dt.timedelta(days=1)
            assert meetings
            prior = copy.deepcopy(c['departmentRemarks'])
            # Remove only the generated uncertainty sentence, preserving enrollment notes.
            auto = '수업 운영 미확인: 공개 수업 계획의 날짜·시간·수업 방식을 확인 중입니다.'
            remarks = {d: '\n'.join([*(s for s in r.split('\n') if s != auto), NOTE]) for d, r in prior.items()}
            if omitted:
                labels = '·'.join(str(w['week']) for w in omitted)
                remarks = {d:r+f'\n{labels}주차는 자율 프로젝트·보고서 제출·개별 상담·홀수 주차 운영·실습실 또는 평가·수업 시각 변경이 미확정이므로 해당 정규 시각의 자동 일정을 보류했습니다.' for d,r in remarks.items()}
            if held_dates:
                remarks = {d:r+'\n별도 운영 보류 날짜: '+', '.join(held_dates)+' (입시로 인한 강의실 이용, 영상·별도 활동 대체 또는 필드트립의 실제 운영 시각·방식·장소 확인이 필요합니다. 일반 휴강으로 단정하거나 별도 시각을 만들지 않았습니다).' for d,r in remarks.items()}
            if key[1] in {'09130001','09130002'}:
                remarks = {d:r+'\n중간평가 전에는 사전영상 후 정규 수업 중 조별활동·발표로 운영됩니다. 중간평가 이후 자율 프로젝트는 정규 출석 시각으로 생성하지 않았습니다.' for d,r in remarks.items()}
            if key[1] in {'61225001','61225002'}:
                remarks = {d:r+'\n현재 계획서가 짝수 주차에만 강의를 명시하므로 2·4·6·8·10·12주차의 정규 공시 시각만 표시합니다. 홀수 주차의 운영은 임의 확정하지 않았습니다.' for d,r in remarks.items()}
            if key[1] in {'M0859002','M0859004'}:
                remarks = {d:r+'\n중간고사 이전 매 강의는 09:30 시작이고 7주차가 앞당겨진 것으로 안내됩니다. 실제 각 날짜의 종료·이동 운영은 미확정이라 1–7주차를 보류하고 8–15주차 현재 정규 시각만 표시합니다.' for d,r in remarks.items()}
            if key[1] == '61065001':
                remarks = {d:r+'\n4·5주차는 218호 조리실에서 20명 실습으로 안내되어 있으며 원공시 교육대학원512호와 다릅니다. 실제 분반별 장소·시각을 임의 연결하지 않았습니다. 24시간 회상법은 식사 섭취 조사 방법이며 수업 시작 시각이 아닙니다.' for d,r in remarks.items()}
            if key[1] in {'M1124001','M1124002'}:
                remarks = {d:r+'\n4·6주차 실습은 516호로 안내되어 있어 원공시 908·907호와 다릅니다. 조별 운영·실제 장소를 확인하기 전 해당 주차를 보류했습니다. 48·72시간은 배양 실습 특성이며 수업 시작 시각이 아닙니다.' for d,r in remarks.items()}
            if key[1] == '15459001':
                remarks = {d:r+'\n8주차 보고서 제출 안내에는 2025년 날짜가 있어 현재 학기 제출 시점이 서로 일치하지 않습니다. 과제·보고서·자료 제출 날짜를 별도 수업이나 시험 일정으로 생성하지 않았습니다.' for d,r in remarks.items()}
            if key[1] in {'12016001','12016002'}:
                remarks = {d:r+'\n15주차 최종 크리틱의 종강일이 학교 일반 수업기간 밖 12/15 또는 12/16으로 안내되어 해당 운영은 별도 확인이 필요합니다.' for d,r in remarks.items()}
            if key[1] in {'11351001','11351002','13310001','15530001'}:
                remarks = {d:r+'\n수업 전 지정된 텍스트 읽기와 리딩 공유·토론 참여가 필요합니다. 과제 제출·텍스트 활동 날짜를 별도 일정으로 만들지 않았습니다.' for d,r in remarks.items()}
            if key[1] == '61431007':
                remarks = {d:r+'\n6·12주차 대면 지필평가의 실제 시각은 별도 확인이 필요합니다. 프로젝트 제출 마감 23:59는 수업 시각이 아닙니다.' for d,r in remarks.items()}
            if key[1] == '61431002':
                remarks = {d:r+'\n주피터 실습용 노트북을 지참해야 합니다. 조별 프로젝트와 모의투자 활동이 포함됩니다.' for d,r in remarks.items()}
            if key[1] == '61524001':
                remarks = {d:r+'\nGoogle Colab 실습이 포함됩니다. 명시된 과제 마감과 평가 날짜는 정규 공시 계획의 맥락이며 별도 이벤트를 만들지 않았습니다.' for d,r in remarks.items()}
            c.update(scheduleStatus='scheduled', schedules=meetings, unresolvedReasons=[],
                     departmentRemarks=remarks, sourceDepartmentRemarks=prior,
                     sourceEducation={'projection': 'publishedRegularTimetable', 'actualAttendanceConfirmed': False,
                         'sourceDeliveryMode': 'unknownUserSelectionRequired', 'sourceCampusExplicit': key[0],
                         'dateProof': 'Current individual weekly teaching bounds and published regular clock.',
                         'holidayProof': 'gachon-current-undergraduate-holiday-rule-20261008.json:Article13',
                         'calendarProof': 'gachon-current-fall-calendar-boundary-proof-20261008.json',
                         'semanticRecheck': review['decision'], 'heldExactDates':held_dates, 'wholeSlotSemantics':'publishedReservationNotContactDurationOrAssessmentClock', 'omittedUnresolvedAssessmentWeeks': omitted, 'supplementalVideoCreatesNoExtraCalendarEvents': True, 'materialsSemanticBasis': 'Educational chapter/scale/history/duration/deadline markers distinguished from real clock changes and operating scopes. Current ordinary published source reservations retained; no invented assessment/contact clock, field allocation or student subgroup. Exact current partial exceptions and mandatory preparations disclosed.'})
            audit['promoted'].append({'sourceId': c['sourceId'], 'offering': key[1], 'campus': campus,
                'previousReason': review['decision'], 'currentTeachingMethod': report['teachingMethodEducationalExcerpt'],
                'weeklyOperatingContexts': weekly_contexts, 'heldExactDates':held_dates, 'omittedUnresolvedAssessmentWeeks': omitted, 'originalClockBlocks': blocks,
                'period': c['period'], 'datedMeetingCount': len(meetings),
                'generatedUncertaintyRemovedOnly': auto, 'sourceEnrollmentEvidence': review['enrollmentReview']})
        data['currentFullOperatingAuditFinished'] = False
        outname = f'gachon-{campus}-2026-2.published-regular-2841-exact-context-partial-v2-next-20261008.json'
        out = ROOT / outname
        assert not out.exists()
        out.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
        audit['datasets'].append({'file': outname, 'sha256': hashlib.sha256(out.read_bytes()).hexdigest(),
            'campus': campus, 'courseCount': len(data['courses']),
            'counts': dict(collections.Counter(c['scheduleStatus'] for c in data['courses'])),
            'datedMeetingCount': sum(len(c['schedules']) for c in data['courses'])})
    assert len(audit['promoted']) == 37
    audit['scheduledCount'] = sum(d['counts']['scheduled'] for d in audit['datasets'])
    assert audit['scheduledCount'] == 2841
    audit['datedMeetingCount'] = sum(d['datedMeetingCount'] for d in audit['datasets'])
    for filename, content in [('gachon-published-regular-2841-exact-context-partial-v2-next-audit-20261008.json', audit),
        ('gachon-published-regular-2841-exact-context-partial-v2-next-sha-manifest-20261008.json', {k: v for k, v in audit.items() if k != 'promoted'})]:
        out = ROOT / filename
        assert not out.exists()
        out.write_text(json.dumps(content, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in audit.items() if k not in ['promoted', 'reviewPolicy']}, ensure_ascii=False))

if __name__ == '__main__':
    main()
