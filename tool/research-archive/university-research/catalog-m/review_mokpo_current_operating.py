"""Current educational public-plan consistency review, never production approval.
Keyword matches are review findings, not inferred course delivery modes.
"""
from pathlib import Path
import json,re,collections,datetime
from prepare_mokpo_time_review import parse_clock
P=Path(__file__).parent
IDENTITY={'YEAR':'2026','HAKGI':'0002'}
PATTERNS={
 'holidayOrMakeupInstruction':r'휴강|대체공휴일|추석.{0,12}(휴|강)|한글날.{0,12}(휴|강)|공휴일.{0,12}(보강|class\s*off)|no\s+class|make.?up\s+class',
 'intensiveOperatingInstruction':r'집중\s*이수|집중\s*수업|\d+\s*주간.{0,12}(강의|수업)|\d+\s*주.{0,12}이론수업',
 'fieldOperatingInstruction':r'교외교육|현장실습|현장체험교육|교외학습|집중이수\s*기간|field.?trip',
 'deliveryOperatingInstruction':r'본\s*(강의|수업|교과목).{0,40}(비대면\s*(수업|강의)|원격\s*(수업|강의)|혼합형\s*수업|온라인\s*(수업|강의|교과목)|온라인으로)|금요일.{0,20}온라인\s*수업|온라인\s*(교과목|강의임)|원격\s*(재택|영상|수업)|강의\s*동영상|^\s*비대면\s*$|직강/비대면|비대면\s*강의\s*\(ZOOM|실시간\s*비대면|온라인으로\s*진행될\s*경우|온라인에서\s*출결|격주로\s*대면|\b(online|remote|hybrid|blended|recorded)\s+(lecture|course|class|session)|\b(lecture|class).{0,25}(via|using)\s+(zoom|teams)|asynchronous|synchronous',
 'actualAttendanceDateInstruction':r'수업시간\s*:|\d{1,2}\s*월\s*\d{1,2}\s*일.{0,60}(저녁|교외|현장|수업|휴강)|\d{1,2}[/.]\d{1,2}\s*휴강',
 'specificEligibilityInstruction':r'선수\s*(과목|교과)|수강.{0,20}(불가|제한|허용|대상)|전공생|타학과|본\s*학과.{0,20}(학생|전공)|only.{0,25}(student|major)|prerequisit',
}
def attendance_date_conflicts(text):
    """Check printed educational operating dates, never history/assignment dates."""
    conflicts=[]
    pattern=r'(?:(\d{4})\s*년\s*)?(\d{1,2})\s*월\s*(\d{1,2})\s*일\s*(?:\(([월화수목금토일])(?:요일)?\))?'
    context_year=2026
    for match in re.finditer(pattern,text):
        if match[1]:context_year=int(match[1])
        year=context_year;month=int(match[2]);day=int(match[3])
        try:date=datetime.date(year,month,day)
        except ValueError:
            conflicts.append('Invalid printed actual operating date: '+match[0]);continue
        if year!=2026:conflicts.append('Printed operating year differs from current 2026 offering: '+date.isoformat())
        if match[4] and '월화수목금토일'[date.weekday()]!=match[4]:
            conflicts.append('Printed calendar date and weekday contradict: '+match[0])
        if not datetime.date(2026,9,1)<=date<=datetime.date(2026,12,7):
            conflicts.append('Printed operating date outside bounded ordinary window: '+date.isoformat())
    for match in re.finditer(r'\b(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[A-Za-z]*\s+(\d{1,2})\b',text,re.I):
        month=['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'].index(match[1].upper())+1
        if month<9:conflicts.append('Printed English operating month outside current second semester: '+match[0])
    return conflicts
def operating_findings(datasets):
    findings=[]
    main=datasets.get('ds_out',[])
    texts=[]
    for r in main:
        texts += [('main.YUUI_SAHANG',s) for s in r.get('operatingNoteExcerpts',[])]
        for field,lines in r.get('additionalOperatingExcerpts',{}).items():texts += [('main.'+field,s) for s in lines]
    for r in datasets.get('ds_out3',[]):
        prefix='week'+str(r.get('JUCHA'))+'.'
        for field in ['BANGBEOP','BIGO']:
            texts += [(prefix+field,s.strip()) for s in (r.get(field) or '').splitlines() if s.strip()]
        texts += [(prefix+'CONTENTS',s) for s in r.get('operatingContentExcerpts',[])]
        # Assignment dates are retained by the collector but deliberately not
        # interpreted as attendance weekday/date changes.
    seen=set()
    for field,text in texts:
        for category,pattern in PATTERNS.items():
            if re.search(pattern,text,re.I) and (field,text,category) not in seen:
                finding={'category':category,'sourceField':field,'exactEducationalText':text,'requiresContextReview':True}
                if category in ['holidayOrMakeupInstruction','fieldOperatingInstruction','actualAttendanceDateInstruction']:
                    finding['printedOperatingDateConflicts']=attendance_date_conflicts(text)
                findings.append(finding);seen.add((field,text,category))
    return findings

def review_course(row,doc):
    reasons=[];findings=[]
    if doc is None:return {'status':'freshPlanPending','reasons':['Current public print refresh not yet complete.'],'findings':[]}
    ds=doc['educationalDatasets'];main=ds.get('ds_out',[])
    if len(main)!=1:reasons.append('Current registered plan main row absent or ambiguous.')
    else:
        m=main[0]
        for field,want in {**IDENTITY,'GYOGWAMOK_CD':row['GYOGWAMOK_CD'],'BUNBAN':row['BUNBAN']}.items():
            if m.get(field)!=want:reasons.append('Current main identity mismatch: '+field)
        raw=m.get('BIGO_TIME');expected=row.get('BIGO_TIME')
        if raw and expected:
            try:
                if parse_clock(raw)!=parse_clock(expected):reasons.append('Actual public print time conflicts with whole-catalogue time.')
            except ValueError:reasons.append('Print/current source clock not supported by verified clock grammar.')
        elif expected:reasons.append('Current plan print time missing despite whole-catalogue time.')
        else:reasons.append('Actual scheduled clock absent; explicit online evidence reviewed separately.')
        print_room=m.get('BIGO_GANGUISIL')
        whole_room=row.get('BIGO_GANGUISIL')
        if print_room and whole_room and re.sub(r'\s+','',print_room)!=re.sub(r'\s+','',whole_room):
            reasons.append('Current public print classroom differs from whole-catalogue classroom.')
        for w in ds.get('ds_out3',[]):
            for field,want in {**IDENTITY,'GYOGWAMOK_CD':row['GYOGWAMOK_CD'],'BUNBAN':row['BUNBAN']}.items():
                if w.get(field)!=want:reasons.append('Weekly educational identity mismatch: '+field)
        findings=operating_findings(ds)
    if reasons:status='individualReviewRequired'
    elif findings:status='operatingContextReviewRequired'
    else:status='currentPlanClockConsistentNoSelectedException'
    return {'status':status,'reasons':sorted(set(reasons)),'findings':findings}

def prepare():
    rows=json.loads((P/'mokpo-current-four-year-research-educational-20261008.json').read_text());out=[]
    prior=json.loads((P/'mokpo-current-whole-time-review-unregistered.json').read_text())
    clock_review={(r['courseCode'],r['section']):r for r in prior['courses']}
    for r in rows:
        f=P/'mokpo-current-plan-operating-20261008'/(r['GYOGWAMOK_CD']+'-'+r['BUNBAN']+'.json')
        doc=json.loads(f.read_text()) if f.exists() else None
        if doc and doc.get('operatingSelectionSchema')!=3:doc=None
        result=review_course(r,doc)
        previous=clock_review[(r['GYOGWAMOK_CD'],r['BUNBAN'])]
        result['previousClockReviewStatus']=previous['reviewStatus']
        result['previousIndividualBlockedReasons']=previous['individualBlockedReasons']
        if previous['reviewStatus']=='explicitOnlineUntimed' and doc and len(doc['educationalDatasets'].get('ds_out',[]))==1:
            clock_absent='Actual scheduled clock absent; explicit online evidence reviewed separately.'
            result['reasons']=[reason for reason in result['reasons'] if reason!=clock_absent]
            if not result['reasons']:
                result['status']='explicitOnlineUntimedCurrentPlan'
        if previous['individualBlockedReasons'] and result['status']!='freshPlanPending':
            result['status']='individualReviewRequired'
            result['reasons']=sorted(set(result['reasons']+previous['individualBlockedReasons']))
        out.append({'courseCode':r['GYOGWAMOK_CD'],'section':r['BUNBAN'],'courseName':r['GYOGWAMOK_NM'],'sourceTime':r.get('BIGO_TIME'),**result})
    return {'checkedAt':'2026-10-08','productionReady':False,'completionClaim':False,'requestedWholeScope':1307,'selectedOperatingFindingsNotDeliveryInference':True,'ordinaryDatesStillSeparate':True,'counts':dict(collections.Counter(r['status'] for r in out)),'courses':out}
if __name__=='__main__':
    result=prepare();(P/'mokpo-current-whole-operating-consistency-review-20261008.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(result['counts'])
