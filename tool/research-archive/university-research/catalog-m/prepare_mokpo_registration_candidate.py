"""Conservative educational checkpoint, not production registration.
Uses existing full current collection; no HTTP and no student/employee fields.
Only currently reconciled ordinary rules without unresolved operating changes
enter the dated ordinary candidate. Generic assessment headings do not cancel
the source timetable or create separate exam events. Week numbers are never
converted into attendance dates. All remaining educational rows stay searchable.
"""
from pathlib import Path
import json,re,collections,datetime
P=Path(__file__).parent
HOLIDAYS=['2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09','2026-10-31']
EXAM=re.compile(r'시험|고사|exam|test|quiz|평가',re.I)
RISK=re.compile(r'휴강|휴업|보강|수업\s*없|no\s*class|reading\s*week|현장|교외|임상|집중|격주|비대면|원격|온라인|on[- ]?line|zoom|녹화|VOD|동영상\s*수업|미정|추후|변경\s*가능',re.I)
def dump(name,data):
 (P/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
def selected_week_text(row):
 return '\n'.join([row.get('BANGBEOP',''),row.get('BIGO',''),*row.get('operatingContentExcerpts',[]),*row.get('operatingAssignmentExcerpts',[])])
def prepare():
 raw=json.loads((P/'mokpo-current-four-year-research-educational-20261008.json').read_text())
 consistency=json.loads((P/'mokpo-current-whole-operating-consistency-review-20261008.json').read_text())['courses']
 clock=json.loads((P/'mokpo-current-whole-time-review-unregistered.json').read_text())['courses']
 bykey=lambda rows:{(r['courseCode'],r['section']):r for r in rows}
 reviews=bykey(consistency);clocks=bykey(clock)
 datasets={c:dict(schemaVersion=2,universityId='mokpo',campus=c,campusName={'dorim':'도림','damyang':'담양','unknown':'위치 미확인'}[c],academicYear=2026,semester='2',publishedDate='2026-10-08',sourceUrl='https://www.mokpo.ac.kr/www/242/subview.do',courses=[]) for c in ['dorim','damyang','unknown']}
 audit=[];classification=[]
 for r in raw:
  key=(r['GYOGWAMOK_CD'],r['BUNBAN']);review=reviews[key];time=clocks[key]
  plan=json.loads((P/'mokpo-current-plan-operating-20261008'/('-'.join(key)+'.json')).read_text())['educationalDatasets']
  weeks=plan.get('ds_out3',[]);main=plan.get('ds_out',[])
  texts=[selected_week_text(w) for w in weeks]
  reasons=list(review['reasons'])+time['individualBlockedReasons'];state='insufficientEvidence'
  if review['status']=='currentPlanClockConsistentNoSelectedException':
   state='reviewPending'; reasons=[]
   actual={int(re.search(r'\d+',w.get('JUCHA',''))[0]):selected_week_text(w).strip() for w in weeks if re.search(r'\d+',w.get('JUCHA',''))}
   full='\n'.join(texts+[x for m in main for x in m.get('operatingNoteExcerpts',[])])
   if RISK.search(full):reasons.append('Additional literal operating-context reference requires individual semantic review; topic text is not automatically treated as a mode.')
   if re.search(r'\d{1,2}\s*[./]\s*\d{1,2}|\d{1,2}\s*월\s*\d{1,2}\s*일',full):reasons.append('Printed numerical attendance/deadline date needs individual semantic review; no date inferred.')
   if not reasons:state='ordinaryCandidate'
  elif review['status']=='operatingContextReviewRequired':state='reviewPending'
  elif review['status']=='explicitOnlineUntimedCurrentPlan':state='verifiedUntimed'
  campus=time['campus'];department=r['HAKGWA_NM'];classification_name=r['ISU_GBNM'];sourceid=f'mokpo/{campus}/2026/2/{key[0]}/{key[1]}'
  notes=[x for m in main for x in m.get('operatingNoteExcerpts',[])]
  notes+= [f['exactEducationalText'] for f in review['findings'] if f.get('category')=='specificEligibilityInstruction' and f['exactEducationalText'] not in notes]
  schedules=[]
  if state=='ordinaryCandidate':
   day=datetime.date(2026,9,1)
   while day<=datetime.date(2026,12,7):
    if day.isoformat() not in HOLIDAYS:
     for meeting in time['clockReview']:
      if day.isoweekday()==meeting['weekday']:
       schedules.append({k:meeting[k] for k in ['weekday','startMinute','endMinute']}|{'date':day.isoformat(),'classroom':r.get('BIGO_GANGUISIL') or ''})
    day+=datetime.timedelta(days=1)
  remarks=f"원 이수구분: {r['ISU_GBCD']} {classification_name}. "+'\n'.join(notes)
  if reasons:remarks+='\n운영 검토: '+' | '.join(reasons)
  course=dict(sourceId=sourceid,sourceDepartmentCode=r['HAKGWA_CD'],sourceClassificationCode=r['ISU_GBCD'],campus=campus,academicYear=2026,semester='2',courseCode=key[0],courseName=r['GYOGWAMOK_NM'],section=key[1],professor=r.get('BIGO_GYOSU') or '',credits=float(r['HAKJEOM']),departmentCredits={department:float(r['HAKJEOM'])},departments=[department],departmentClassifications={department:classification_name},departmentRemarks={department:remarks},sourceSchedule=r.get('BIGO_TIME') or '',sourceClassroom=r.get('BIGO_GANGUISIL') or '',scheduleStatus='scheduled' if schedules else 'unscheduled' if state=='verifiedUntimed' else 'unrecognized',schedules=schedules)
  if schedules:course['period']={'startDate':'2026-09-01','endDate':'2026-12-07'}
  datasets[campus]['courses'].append(course)
  audit.append(dict(sourceId=sourceid,courseCode=key[0],section=key[1],state=state,reasons=reasons,ordinaryDatedMeetings=len(schedules),previousOperatingStatus=review['status'],educationalFindings=review['findings'],currentPlanFile='mokpo-current-plan-operating-20261008/'+ '-'.join(key)+'.json'))
  classification.append(dict(sourceId=sourceid,department=department,sourceCode=r['ISU_GBCD'],sourceName=classification_name,normalizedName=classification_name))
 for campus,dataset in datasets.items():dump(f'mokpo-{campus}-2026-2.registration-candidate.json',dataset)
 result=dict(checkedAt='2026-10-08',productionReady=False,completionClaim=False,wholeScope=1307,newCollectionPerformed=False,ordinaryWindow={'start':'2026-09-01','end':'2026-12-07'},schoolRegularHolidayPolicy='mokpo-current-ordinary-window-policy-review-20261008.json',schoolCalendar='mokpo-current-ordinary-calendar-20261008.html',officialPublicHolidaySource='https://www.kasa.go.kr/bbs/BBSMSTR_000000000010/view.do?nttId=B000000001860Pe2zT3',excludedRegularClosureDates=HOLIDAYS,anniversarySource='Current official October calendar labels 2026-10-31 개교기념일.',laterMakeupAndExamUnresolved=True,weekNumberDateInference=False,genericAssessmentHeadingsDoNotCancelSourceTimetable=True,counts=dict(collections.Counter(c['state'] for c in audit)),campusCounts={c:len(d['courses']) for c,d in datasets.items()},courses=audit)
 dump('mokpo-registration-candidate-audit-20261008.json',result)
 dump('mokpo-registration-classification-audit-20261008.json',dict(source='actual current ISU_GBCD/ISU_GBNM, not query college or department inference',mappings=classification,counts=dict(collections.Counter(r['ISU_GBNM'] for r in raw)),unmappedSourceNamePreserved='전문교양'))
 return result
if __name__=='__main__':
 result=prepare();print(result['counts'],result['campusCounts'])
