"""Preserve all UG/cross-degree educational metadata; unresolved operation stays blocked.
No production registration authority. Whole source freshness remains a separate gate.
"""
import json,re,collections,datetime
from pathlib import Path
P=Path(__file__).resolve().parent
source=json.loads((P/'skku-ko-all-2026-2.json').read_text())['records']
source=[r for r in source if r['JUKYONGHAKWI_GB']!='05'];assert len(source)==2782
major=json.loads((P/'skku-ko-major-all-2026-2.json').read_text())['records'];general=json.loads((P/'skku-ko-general-all-2026-2.json').read_text())['records']
names={r['COM_CD']:r['CD_NM'] for r in json.loads((P/'skku-ko-major-departments.json').read_text())}
departments=collections.defaultdict(set)
for r in major:
    if r.get('queryDepartment') in names:departments[r['HAKSU_NO_BUNBAN']].add(names[r['queryDepartment']])
for r in general:departments[r['HAKSU_NO_BUNBAN']].add('공통교양')
audit=json.loads((P/'skku-public-operating-plan-audit.json').read_text());proof={r['offeringCode']:r for r in audit['records']}
CAMPUSES={'1':('humanities','인문사회과학캠퍼스'),'2':('naturalScience','자연과학캠퍼스'),'3':('icampus','i-Campus')}
DAY={d:i+1 for i,d in enumerate('월화수목금토일')}
CLOCK=re.compile(r'([월화수목금토일])(\d{2}):(\d{2})-(\d{2}):(\d{2})【([^】]+)】')
BASE_PERIOD={'startDate':'2026-08-31','endDate':'2026-12-18'}
EXCEPTION=re.compile(r'휴강|휴업|보강|수업\s*없|수업\s*안|집중|모듈|no\s+(?:class|lecture)|cancel(?:led|ed)\s+class|make[- ]?up|intensive|reschedul|일정.*변경|시간.*변경|zoom|비대면|화상|remote',re.I)
PLACEMENT=re.compile(r'개별연구|현장실습|임상실습|인턴|사회봉사|individual\s+research|clinical\s+practice',re.I)
RESTRICTION=re.compile(r'(?:p\s*roficien\w*.{0,60}(?:Korean|English).{0,50}required|sufficient\s+proficiency.{0,50}(?:Korean|English)|no\s+special\s+accommodations.{0,60}Korean)|수강.{0,60}(?:불가|제한|대상|중복|금지|필수)|(?:학생|학부생|학과생).{0,40}(?:불가|제한|추가.{0,10}신청|우선)|중복\s*수강|선수\s*과목|prerequisite|only.{0,50}student|(?:not|cannot).{0,50}(?:enrol|register|take.{0,20}course)|(?:students?|majors?|undergraduate|graduate|senior).{0,60}(?:only|required|priority|not permitted|without|background)|(?:intended|restricted|limited).{0,60}(?:students?|majors?)|priority.{0,50}(?:students?|majors?)|(?:requires?|required).{0,60}students?|(?:must|need to|required to).{0,60}(?:bring|attend|have|complete|study|submit)|(?:노트북|PC|프로그래밍).{0,50}(?:필수|필요)|공동강의|(?:교수님|교강사).{0,50}(?:강의|수업)',re.I)
outputs=collections.defaultdict(list);counts=collections.Counter()
for row in source:
    code=row['HAKSU_NO_BUNBAN'];p=proof.get(code);campus,campus_name=CAMPUSES[row['CAMPUS_GB']]
    dpts=sorted(departments[code]);assert dpts,(code,'Missing original public curriculum attribution')
    clock=row['GYOSI_NAME'];frames=[]
    for m in CLOCK.finditer(clock):
        start=int(m[2])*60+int(m[3]);end=int(m[4])*60+int(m[5]);assert 0<=start<end<=1440
        frames.append({'weekday':DAY[m[1]],'startMinute':start,'endMinute':end,'classroom':m[6]})
    residual=CLOCK.sub('',clock)
    residual=re.sub(r'【[\d.]+h\(ON\)\+[\d.]+h\(OFF\)】','',residual).strip(', ')
    reasons=[];status='unrecognized';meetings=[]
    if not p:reasons.append('Current public per-offering operating evidence has not yet been fetched.')
    elif not p.get('currentDetailIdentityConfirmed'):reasons.append('Current code/year/term/section detail identity is incomplete.')
    if not frames:
        status='unscheduled'
        reasons=[]
    elif residual:reasons.append('Printed clock has a module or unrecognized remaining token; not an ordinary semester fallback.')
    if row['HAKBU_JIBJUNG_GB']=='C':reasons.append('Current Challenge/concentrated individual dates need direct proof.')
    if p and p['detail']:
        detail=p['detail'][0]
        if PLACEMENT.search(row['GWAMOK_NAME']+' '+detail.get('CLASS_INFO','')):reasons.append('Individual clinical/placement/research operation requires actual subgroup dates.')
        if code in ('MED3096-41','MED3148-41','MED3173-41'):reasons.append('Known current medical full-clock source missing/previous and inconsistent; no old dates reused.')
        if p.get('weekly'):
            texts=' '.join(w.get('PLAN_WEEK_CONT','')+' '+w.get('BIGO','') for w in p['weekly'])
            if EXCEPTION.search(texts):reasons.append('Current weekly source contains an operating marker needing semantic review; a topic word alone is not a proved cancellation/change.')
        if any(a.get('contextLimitReached') or a.get('contextTruncated') or a.get('privacySuppressedLineCount') for a in p.get('attachments',[])):
            reasons.append('Some educational attachment context is incomplete after size/privacy filtering; current exact context needs review.')
    if frames:reasons.append('Actual current delivery/period/weekly exceptions and common school closure dates still need semantic approval before scheduling.')
    notes=[value for value in (row.get('BIGO'),row.get('INFORM'),row.get('HYUNGTAE'),row.get('SUUP_TYPE_NM')) if value]
    secondary=list(dict.fromkeys(value for value in (row.get('ISU_NAME2'),row.get('ISU_NAME3')) if value and value!=row['ISU_NAME']))
    if secondary:notes.append('이수 구분 원문 보조 표기: '+' / '.join(secondary))
    if row.get('BOKSUJUNGONG_YN_NAME'):notes.append('복수전공 안내: '+row['BOKSUJUNGONG_YN_NAME'])
    if row.get('ABEEK_YN'):notes.append('공학교육인증 원문: '+row['ABEEK_YN'])
    if p and p['detail']:
        detail=p['detail'][0]
        for key,label in (('SUGANGDAESANG_HAKGWA','수강 대상'),('PRE_HAKSU_NAME','선수과목'),('FOREIGNER_GB_NM','수강 조건'),('BIGO','수업 비고')):
            if detail.get(key):notes.append(label+': '+detail[key])
        restriction_contexts=[]
        texts=[detail.get('CLASS_INFO','')]+[context for attachment in p.get('attachments',[]) for context in attachment.get('educationalOperatingContexts',[])]
        for text in texts:
            for match in RESTRICTION.finditer(text):
                context=re.sub(r'\s+',' ',text[max(0,match.start()-100):min(len(text),match.end()+160)]).strip()
                if context and context not in restriction_contexts:restriction_contexts.append(context)
        if restriction_contexts:notes.append('계획서 수강 조건 원문: '+' / '.join(restriction_contexts))
    if status=='unrecognized':notes.append('수업 운영 미확인: 실제 날짜·수업 방식·휴강·보강을 확인 중입니다.')
    elif not frames:notes.append('공개 시간표에 정해진 수업 시각이 게시되어 있지 않습니다. 학교가 공지하는 세부 일정을 확인하세요.')
    credits=float(re.match(r'\d+(?:\.\d+)?',row['HAKJUM'])[0])
    record={'sourceId':'skku-2026-2-'+code,'universityId':'skku','campus':campus,'academicYear':2026,'semester':'2','courseCode':row['HAKSU_NO'],'section':row['BUNBAN'],'courseName':row['GWAMOK_NAME'],'professor':row['PER_NAME'],'credits':credits,'sourceSchedule':clock,'sourceClassroom':','.join(dict.fromkeys(m['classroom'] for m in frames)),'scheduleStatus':status,'schedules':meetings,'departments':dpts,'departmentCredits':{d:credits for d in dpts},'departmentClassifications':{d:row['ISU_NAME'] for d in dpts},'departmentRemarks':{d:'\n'.join(notes) for d in dpts},'researchOnly':True,'unresolvedReasons':list(dict.fromkeys(reasons)),'rawMeetingFrameForReviewOnly':frames,'sourceDegreeCode':row['JUKYONGHAKWI_GB'],'sourceTeachingTypeCode':row['SUUP_TYPE_CD'],'sourceConcentratedType':row['HAKBU_JIBJUNG_GB'],'sourceEducationalMetadata':{key:row.get(key) for key in ('HAKWI_NAME','GRADE_NAME','ISU_NAME','ISU_NAME2','ISU_NAME3','GWAMOK_ENG_NAME','HYUNGTAE','SUUP_TYPE_NM','BOKSUJUNGONG_YN_NAME','ABEEK_YN','HAKBU_JIBJUNG_GB_NM','LECTURE_PLAN_TYPE','INFORM','BIGO')}}
    # Base period is provenance only until ordinary-semester operation is proved.
    record['ordinaryTermFrameForReviewOnly']=BASE_PERIOD
    outputs[campus].append(record);counts[status]+=1
for campus,records in outputs.items():
    payload={'schemaVersion':2,'universityId':'skku','campus':campus,'campusName':next(name for c,name in CAMPUSES.values() if c==campus),'academicYear':2026,'semester':'2','publishedDate':datetime.date.today().isoformat(),'sourceUrl':'https://kingoinfo.skku.edu/gaia/nxui/outdex.html?menuId=NHSSU030840M','researchOnly':True,'productionActivationAllowed':False,'completionClaim':False,'allCurrentDetailsFetched':audit['allCurrentDetailsFetched'],'courses':records}
    path=P/f'skku-{campus}-2026-2.metadata-safe-unregistered.json';tmp=path.with_suffix('.tmp');tmp.write_text(json.dumps(payload,ensure_ascii=False,indent=2));tmp.replace(path)
status={'researchOnly':True,'completionClaim':False,'productionActivationAllowed':False,'originalSourceCount':2814,'excludedGraduateOnly05':32,'wholeUndergraduateCrossDegreeCount':2782,'fetchedEducationalEvidenceCount':audit['count'],'allCurrentDetailsFetched':audit['allCurrentDetailsFetched'],'currentWholeScopeFreshnessRecheckDone':False,'counts':dict(counts),'campusCounts':{c:len(r) for c,r in outputs.items()}}
(P/'skku-metadata-safe-status.json').write_text(json.dumps(status,ensure_ascii=False,indent=2));print(status)
