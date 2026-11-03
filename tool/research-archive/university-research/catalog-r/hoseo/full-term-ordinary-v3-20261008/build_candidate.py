"""Current native ordinary public reservations; research only, historical input unchanged."""
from pathlib import Path
from datetime import date, timedelta
import copy, collections, hashlib, json, re
R = Path(__file__).parent
PRIOR = R.parent / 'early-regular-partial-v2'
ROOT = R.parents[4]
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
start, end = date(2026,8,31), date(2026,12,18)
# Revised current school holiday list; anniversary label alone is not closure proof.
excluded = {'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09','2026-10-23'}
old_title_hold = 'individual lab/intensive/week/practical operatingdates unknown'
proof = json.loads((PRIOR/'educational-proof.json').read_text())
frozen = json.loads((PRIOR/'sha.json').read_text())
assert sha(PRIOR/'educational-proof.json') == frozen['educational-proof.json']
for item in proof['nativeProof']['existingSources']:
    assert sha(ROOT/'work/university-research/catalog-s'/item['file']) == item['sha256']
clock_evidence = proof['clockEvidence']
clock = {int(x['nativePeriod']):(int(x['start'][:2])*60+int(x['start'][3:]),int(x['end'][:2])*60+int(x['end'][3:])) for x in clock_evidence['validatedDayPeriods']}
assert sorted(clock)==list(range(1,9))
outputs=[]; changes=[]; baseline_hashes={}; baseline_scheduled=0; baseline_dates=0; native_count=0
for campus in ['asan','cheonan','unknown']:
    p=PRIOR/f'hoseo-{campus}-2026-2.early-planned.json'
    assert sha(p)==frozen[p.name]
    old=json.loads(p.read_text()); baseline_hashes[str(p.relative_to(ROOT))]=sha(p)
    new=copy.deepcopy(old)
    for c, prior in zip(new['courses'],old['courses']):
        meta=c['metadata']; originals=meta['originalEducationalRecords']; native_count+=len(originals)
        holds=[h for h in meta['reservationHoldReasons'] if h!=old_title_hold]
        v=originals[0]['values']; blocks=[]
        # Preserve actual source operation markers; plain lab/practical/project/course titles are not proof of changed dates.
        notes=' '.join(str(x['values'][12] or '') for x in originals)
        if re.search(r'집중|[0-9]+\s*주차|[0-9]+\s*주\s*(?:운영|수업)|실습배치|병원실습|외부실습',notes):
            holds.append('explicit native individual operation requires date/allocation proof')
        if not holds:
            matches=list(re.finditer(r'([월화수목금])([1-8])(?:~([1-8]))?',str(v[9] or '')))
            assert ','.join(m.group(0) for m in matches).replace(' ','')==str(v[9]).replace(' ','')
            for m in matches:
                first,last=int(m[2]),int(m[3] or m[2]); assert first<=last
                blocks.append({'weekday':'월화수목금'.index(m[1])+1,'startMinute':clock[first][0],'endMinute':clock[last][1],'classroom':v[10]})
            for i,b in enumerate(blocks):
                assert not any(b['weekday']==a['weekday'] and max(b['startMinute'],a['startMinute'])<min(b['endMinute'],a['endMinute']) for a in blocks[i+1:])
        meetings=[]
        if not holds:
            d=start
            while d<=end:
                if d.isoformat() not in excluded:
                    meetings.extend({'date':d.isoformat(),**b} for b in blocks if b['weekday']==d.isoweekday())
                d+=timedelta(days=1)
            old_keys={json.dumps(x,sort_keys=True) for x in prior['schedules']}
            meetings=copy.deepcopy(prior['schedules'])+[x for x in meetings if json.dumps(x,sort_keys=True) not in old_keys]
        else:
            assert not prior['schedules'],(c['sourceId'],holds)
        baseline_scheduled+=bool(prior['schedules']); baseline_dates+=len(prior['schedules'])
        assert meetings[:len(prior['schedules'])]==prior['schedules']
        c['schedules']=meetings; c['scheduleStatus']='scheduled' if meetings else 'unrecognized'
        meta['priorV2ReservationHoldReasons']=copy.deepcopy(meta['reservationHoldReasons'])
        meta['reservationHoldReasons']=holds; meta['heldReason']='; '.join(holds)
        meta['selectedDateSubset']=['2026-08-31','2026-12-18']
        meta['reservationScope']={'start':'2026-08-31','end':'2026-12-18','meaning':'ordinary public reservation inside own published term; actual lecture/exam/individual exception days unconfirmed'}
        meta['regularReservationOnly']=True; meta['individualOperatingDaysVerified']=False
        meta['nativeClockRoomBlocks']=blocks
        meta['titleOnlyOperatingHoldRemoved']=old_title_hold in prior['metadata']['reservationHoldReasons']
        original_note=' '.join(str(x['values'][12] or '') for x in originals)
        c['remarks']=('공개 정규예약 계획 2026-08-31–12-18, 자체 현재 개강·학기종료 범위입니다. 실제출석/수업량/개별수업·시험·보강·수시시험 날짜 및 교수승인 예외 미확인. 학교 시험규정은 정기 또는 수시 실시·1주전 공고이며 현재 공개 중간/기말 날짜를 만들지 않았습니다. 현행휴업일9/24–25·10/5·10/9·10/23제외,9/26·10/3국가공휴일도 보류합니다. 9/28개교기념일은 학사달력 행사표기이며 별도휴업근거없어 정규예약 유지, 실제수업여부 미확인입니다. 현재1–8교시 시작10–17시와 주간50분/휴식10분 직접규정만 사용; 9+교시·야간/원격·복수실대응·원문충돌은 보류. 실험/실습/PBL/프로젝트/진로 과목명만으로 별도집중운영을 단정하지 않습니다. 대면은원문metadata이며 날짜별 실제방식은미확인으로 override없이 사용자3방식선택 유지. 캠퍼스는 현재PDF직접인쇄82개만기존대로, 나머지unknown. 최신학교전체폐강·통합시스템최종변경 미확인. 원문비고: '+original_note+(' 예약보류: '+'; '.join(holds) if holds else ''))
        changes.append({'sourceId':c['sourceId'],'baselineDates':len(prior['schedules']),'candidateDates':len(meetings),'removedTitleOnlyHold':meta['titleOnlyOperatingHoldRemoved'],'nativeHoldReasons':holds})
        for k in prior:
            if k not in ['metadata','schedules','scheduleStatus','remarks']:assert c[k]==prior[k]
        for k in prior['metadata']:
            if k not in ['reservationHoldReasons','heldReason','selectedDateSubset']:assert meta[k]==prior['metadata'][k]
    new['candidateRevision']='full-term-ordinary-v3'
    out=R/f'hoseo-{campus}-2026-2.ordinary-planned.json'
    out.write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n');outputs.append(new)
allcourses=[c for x in outputs for c in x['courses']]
assert len(allcourses)==2499 and native_count==2627 and baseline_scheduled==1059 and baseline_dates==3627
assert len({c['sourceId'] for c in allcourses})==2499
assert sum(bool(c['schedules']) for c in allcourses)==1497
save=lambda n,x:(R/n).write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
audit={'researchOnly':True,'completionClaim':False,'nativeCourses':2499,'nativeOccurrences':2627,'scheduled':sum(bool(c['schedules']) for c in allcourses),'datedMeetings':sum(len(c['schedules']) for c in allcourses),'held':sum(not c['schedules'] for c in allcourses),'baselineScheduled':1059,'baselineDatesDeepPreserved':3627,'newScheduledFromTitleOnlyHold':438,'campusCounts':dict(collections.Counter(c['campus'] for c in allcourses)),'productionChanged':False}
save('audit.json',audit);save('reservation-extension-audit.json',changes)
save('educational-proof.json',{'researchOnly':True,'completionClaim':False,'baselineFilesSHA256':baseline_hashes,'baselineEducationProof':{'path':str((PRIOR/'educational-proof.json').relative_to(ROOT)),'SHA256':sha(PRIOR/'educational-proof.json')},'currentClockEvidence':clock_evidence,'reservationScope':{'start':'2026-08-31','end':'2026-12-18','actualLectureExamDistinctionConfirmed':False},'excludedDates':sorted(excluded),'exactSchoolHolidayDates':['2026-09-24','2026-09-25','2026-10-05','2026-10-09','2026-10-23'],'additionalConservativeHolds':['2026-09-26','2026-10-03'],'anniversarySeptember28':json.loads((R/'anniversary-current-school-rule-education.json').read_text()),'currentTermAndExamRechecked':{'calendarUrl':'https://www.hoseo.ac.kr/Home/Contents.mbz?action=MAPP_2405312496','examRuleUrl':'https://www.hoseo.ac.kr/Home/Contents.mbz?action=MAPP_1708230107','observedDate':'2026-10-08','midtermFinalRangePublished':False,'examNoticeMinimumDays':7},'revisedSchoolHolidaySource':{'path':'work/university-research/catalog-s/hoseo-current-2026-calendar-revised-1.pdf','SHA256':sha(ROOT/'work/university-research/catalog-s/hoseo-current-2026-calendar-revised-1.pdf'),'revisionDate':'2026-08-10','publishedNoticeDate':'2026-08-13'},'currentExamClosureNormalPublicSearch':'bounded official search found no current undergraduate exact midterm/final range or whole final closed-course rows; graduate/other-university results excluded','wholeClosureVerified':False,'counts':audit})
print(json.dumps(audit,ensure_ascii=False))
