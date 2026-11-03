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
             'reviewPolicy': '53 current published live-title weekly plans. Source explicit live mode retained, individual remote quizzes/reports, physical or shorter/TBA assessment, recorded video and unknown makeup weeks omitted. Generic exams alone retain normal frames. Two original public period lists reconstruct exact contiguous blocks after real exception normalization; no fake clock/room. Three contradictory holiday copies, HyFlex and incomplete weekly scopes excluded.', 'productionProjectionPermitted':'validated2793PublishedPlansOnly',
             'previousManifest': 'gachon-published-regular-2740-short-normal-v2-next-sha-manifest-20261008.json'}
    for campus in ['global', 'medical']:
        name = f'gachon-{campus}-2026-2.published-regular-2740-short-normal-v2-next-20261008.json'
        original = read(name)
        data = copy.deepcopy(original)
        for c in data['courses']:
            key = ('20' if campus == 'global' else '21', c['courseCode'] + c['section'])
            review, report, base = reviews[key], reports[key], bases[key]
            method = report['teachingMethodEducationalExcerpt']
            targets = {'M3495001', '05713001', '15290003', '14250002', '11353001', '13978005', '14931002', '11965001', '12403001', '11352001', '13837002', '15078001', '05285001', '15694008', '16027001', '15290010', '14724002', 'K0025005', '14572001', '15290041', '15563001', '07251007', '13212002', '09376002', '13548002', '13828001', '09374002', 'M3753001', '15565001', '13979005', '09374001', '13827001', '12408002', '13212001', '13476003', '61394002', '14289001', '15290014', '10605003', '12408001', '61330002', '08306007', '15290021', '14716001', '13978004', 'M3495002', '13838001', '11342001', '09376003', '09486001', '13014001', '09808002', '05284001'}
            if c['scheduleStatus'] != 'unrecognized' or key[1] not in targets:
                continue
            assert report['educationalParserVersion'] == 6
            assert all(report['report'][k] for k in ['headerCourseCodeMatches', 'currentTermMatches', 'catalogProfessorAppearsInReport'])
            blocks = copy.deepcopy(base['schedules'])
            assert base['deliveryMode'] == 'liveOnline'
            assert '실시간화상강의' in report['sourceRow']['SUBJECT_NM_KOR']
            if key[1] in {'11965001','16027001'}:
                assert not blocks
                slots = base['publishedActualSlots']
                assert len(slots) == 2 and slots[0]['weekday'] == slots[1]['weekday'] and slots[1]['period'] == slots[0]['period'] + 1
                blocks = [{'weekday': slots[0]['weekday'], 'firstPeriod': slots[0]['period'], 'lastPeriod': slots[-1]['period'], 'startMinute': slots[0]['startMinute'], 'endMinute': slots[-1]['endMinute'], 'classroom': base['rawRoom'], 'deliveryMode':'liveOnline'}]
            else:
                assert base['schedulingDecision'] == 'regularCandidate' and not base['blockingReasons']
            assert blocks and all(b['deliveryMode'] == 'liveOnline' for b in blocks)
            result = current_period_weekly_rows_consistent(report, base)
            assert result is True, (key, result)
            assert not any(w['operatingContextTruncationDetected'] or w['operatingContextLimitReached'] for w in report['weeklyRows'])
            weekly_contexts = [t for w in report['weeklyRows'] for t in w['operatingContexts']]
            omitted_weeks_by_offering = {'05284001': [8, 15], '05285001': [8, 15], '05713001': [7, 8, 14, 15], '09374001': [15], '09374002': [8, 15], '09376002': [4], '09376003': [8, 14], '09486001': [7, 8, 14, 15], '09808002': [7, 15], '10605003': [7, 13, 15], '11342001': [8, 15], '11352001': [8, 15], '11353001': [8, 15], '11965001': [5, 8, 15], '12403001': [7, 15], '12408001': [8, 14, 15], '12408002': [8, 14, 15], '13212001': [7, 8, 14, 15], '13212002': [7, 8, 14, 15], '13548002': [4, 8, 15], '13838001': [14], '13978004': [8, 15], '13978005': [8, 15], '14250002': [8, 15], '14289001': [8, 15], '14572001': [8, 15], '14716001': [8, 15], '14724002': [8, 15], '14931002': [7, 8, 14, 15], '15290003': [8, 15], '15290010': [8, 15], '15290014': [8, 15], '15290021': [8, 15], '15290041': [8, 15], '15563001': [8, 15], '15565001': [8], '16027001': [8, 15], '61394002': [5, 12], 'M3495001': [8, 15], 'M3495002': [8, 15], 'M3753001': [7, 13, 15]}
            omitted = [w for w in report['weeklyRows'] if w['week'] in omitted_weeks_by_offering.get(key[1], [])]
            omitted_ranges = [tuple(dt.date(2026,*map(int,w[k].split('/'))) for k in ['startMonthDay','endMonthDay']) for w in omitted]
            begin, end = (dt.date.fromisoformat(c['period'][k]) for k in ['startDate', 'endDate'])
            meetings = []
            for block in blocks:
                day = begin
                while day <= end:
                    if day.isoweekday() == block['weekday'] and day.isoformat() not in HOLIDAYS and day.isoweekday() != 7 and not any(a <= day <= z for a,z in omitted_ranges):
                        meetings.append({k: v for k, v in {**block, 'date': day.isoformat()}.items() if k not in ['firstPeriod', 'lastPeriod']})
                    day += dt.timedelta(days=1)
            assert meetings
            prior = copy.deepcopy(c['departmentRemarks'])
            # Remove only the generated uncertainty sentence, preserving enrollment notes.
            auto = '수업 운영 미확인: 공개 수업 계획의 날짜·시간·수업 방식을 확인 중입니다.'
            remarks = {d: '\n'.join([*(s for s in r.split('\n') if s != auto), NOTE]) for d, r in prior.items()}
            if omitted:
                labels = '·'.join(str(w['week']) for w in omitted)
                remarks = {d:r+f'\n{labels}주차의 별도 평가·자료제출·녹화영상·짧은 수업 또는 미확정 보강은 정규 실시간 강의 시각과 운영이 달라 자동 일정에서 제외했습니다. 해당 학교 공지를 확인하세요.' for d,r in remarks.items()}
            if key[1] in {'13827001','13828001'}:
                remarks = {d:r+'\n중간·기말 대면평가는 별도 시각이 미확정입니다. 현재 주차별 이론 수업의 공시 계획과 구분하며 별도 시험 이벤트를 생성하지 않았습니다.' for d,r in remarks.items()}
            if key[1] == '09374001':
                remarks = {d:r+'\n중간고사가 없어 8주차도 정상 수업합니다. 기말 대면시험은 예음홀에서 진행되어 별도 공지 확인이 필요합니다.' for d,r in remarks.items()}
            if key[1] in {'M3495001','M3495002'}:
                remarks = {d:r+'\n현재 평가표와 필수 보고서 안내가 서로 일치하지 않아 평가주차를 별도로 확인해야 합니다. 과제 제출 지연은 감점, 필수 보고서 미제출은 F입니다.' for d,r in remarks.items()}
            if key[1] == '16027001':
                remarks = {d:r+'\n최종 대면평가는 12월16일 09:00–10:50 예술체육대학2 예음홀로 안내되어 있습니다. 일반수업 기간 밖 별도 시험이며 정규 수업 반복이나 확정 시험 이벤트로 생성하지 않았습니다.' for d,r in remarks.items()}
            if key[1] == '15565001':
                remarks = {d:r+'\n수업 중 팀토론 참여를 위한 마이크가 필수입니다. 별도 수업 외 팀활동은 없으며 8주차 대면평가 미응시 시 F입니다. 15주차는 종합 성찰 활동입니다.' for d,r in remarks.items()}
            if key[1] == '61330002':
                remarks = {d:r+'\n실시간 비대면 수업을 위한 카메라·마이크를 반드시 준비해야 합니다.' for d,r in remarks.items()}
            if key[1] == '14250002':
                remarks = {d:r+'\n실습을 위해 컴퓨터로 수업에 참여해야 합니다. 중간·기말 대면평가 시각은 별도 학교 공지를 확인하세요.' for d,r in remarks.items()}
            c.update(scheduleStatus='scheduled', schedules=meetings, unresolvedReasons=[],
                     departmentRemarks=remarks, sourceDepartmentRemarks=prior,
                     sourceEducation={'projection': 'publishedRegularTimetable', 'actualAttendanceConfirmed': False,
                         'sourceDeliveryMode': 'liveOnlineFromOfficialTitleAndCurrentPlan', 'sourceCampusExplicit': key[0],
                         'dateProof': 'Current individual weekly teaching bounds and published regular clock.',
                         'holidayProof': 'gachon-current-undergraduate-holiday-rule-20261008.json:Article13',
                         'calendarProof': 'gachon-current-fall-calendar-boundary-proof-20261008.json',
                         'semanticRecheck': review['decision'], 'omittedUnresolvedAssessmentWeeks': omitted, 'supplementalVideoCreatesNoExtraCalendarEvents': True, 'materialsSemanticBasis': 'Official explicit real-time video course title plus current plan and source live mode. Normal lectures retained outside individually reviewed replaced/changed weeks. Generic exams do not add new events. School-published planning only, not actual attendance.'})
            audit['promoted'].append({'sourceId': c['sourceId'], 'offering': key[1], 'campus': campus,
                'previousReason': review['decision'], 'currentTeachingMethod': report['teachingMethodEducationalExcerpt'],
                'weeklyOperatingContexts': weekly_contexts, 'omittedUnresolvedAssessmentWeeks': omitted, 'originalClockBlocks': blocks,
                'period': c['period'], 'datedMeetingCount': len(meetings),
                'generatedUncertaintyRemovedOnly': auto, 'sourceEnrollmentEvidence': review['enrollmentReview']})
        data['currentFullOperatingAuditFinished'] = False
        outname = f'gachon-{campus}-2026-2.published-regular-2793-live-weekly-partial-next-20261008.json'
        out = ROOT / outname
        assert not out.exists()
        out.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
        audit['datasets'].append({'file': outname, 'sha256': hashlib.sha256(out.read_bytes()).hexdigest(),
            'campus': campus, 'courseCount': len(data['courses']),
            'counts': dict(collections.Counter(c['scheduleStatus'] for c in data['courses'])),
            'datedMeetingCount': sum(len(c['schedules']) for c in data['courses'])})
    assert len(audit['promoted']) == 53
    audit['scheduledCount'] = sum(d['counts']['scheduled'] for d in audit['datasets'])
    assert audit['scheduledCount'] == 2793
    audit['datedMeetingCount'] = sum(d['datedMeetingCount'] for d in audit['datasets'])
    for filename, content in [('gachon-published-regular-2793-live-weekly-partial-next-audit-20261008.json', audit),
        ('gachon-published-regular-2793-live-weekly-partial-next-sha-manifest-20261008.json', {k: v for k, v in audit.items() if k != 'promoted'})]:
        out = ROOT / filename
        assert not out.exists()
        out.write_text(json.dumps(content, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in audit.items() if k not in ['promoted', 'reviewPolicy']}, ensure_ascii=False))

if __name__ == '__main__':
    main()
