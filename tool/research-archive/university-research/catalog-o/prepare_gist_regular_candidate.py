"""Published planned GIST slots; no actual attendance or invented sections."""
import json,re,hashlib,datetime,collections,base64
from pathlib import Path
p=Path(__file__).parent;s=json.loads((p/'gist-current-slot-research.json').read_text())['slots'];groups={}
for slot in s:
 for i in slot['identities']:
  section=i['publishedSection'] or '';teacher=re.sub(r'\s+','',slot['professor'])
  # Published section establishes identity. Without section, distinct teacher and title stay separate.
  title=re.sub(r'\([^)]*(?:\d{1,2}:\d{2}|분반|반\)|주1회)[^)]*\)','',slot['title']);title=re.sub(r'\s+','',title)
  key=(i['code'],section,'publishedSection' if section else 'publishedLectureRecitationCompanion' if i['code'] in {'GS1001','GS2002','MM2002'} else teacher)
  groups.setdefault(key,[]).append(slot)
closures={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09','2026-11-17'}
start=datetime.date(2026,8,31);end=datetime.date(2026,12,18)
records=[];counts=collections.Counter()
for (code,section,owner),slots in groups.items():
 rawtitle=slots[0]['title'];teachers=list(dict.fromkeys(z['professor'].strip() for z in slots if z['professor'].strip()))
 meetings=sorted({(z['weekday'],z['publishedClock']['startMinute'],z['publishedClock']['endMinute'],z['classroom'].strip()) for z in slots})
 gaps=[]
 if code in {'EC3101','GS1401'}:gaps.append('PublishedLectureLabSectionLinkageUnverified')
 if any(z['deliveryUnverified'] for z in slots):gaps.append('MOOCRegularAttendanceUnverified')
 if any(re.search(r'\d+시\s+\d+시',z['title']) for z in slots):gaps.append('PerSectionHourListAllocationUnverified')
 if not section and code in {'GS1607','GS2652'}:gaps.append('PublishedCodeTitleConflict')
 schedules=[]
 if not gaps:
  for weekday,a,b,room in meetings:
   day=start
   while day<=end:
    if day.isoweekday()==weekday and day.isoformat() not in closures:
     schedules.append({'weekday':weekday,'startMinute':a,'endMinute':b,'classroom':room,'date':day.isoformat()})
    day+=datetime.timedelta(days=1)
  schedules.sort(key=lambda z:(z['date'],z['startMinute'],z['classroom']))
 identity={'printedCode':code,'printedSection':section,'publicTeachers':teachers,'publishedMeetingParts':meetings,'sourceFileSha256':json.loads((p/'gist-whole-coordinate-fixture.json').read_text())['sha256']}
 stable=base64.b32encode(hashlib.sha256(json.dumps(identity,ensure_ascii=False,sort_keys=True).encode()).digest()).decode()[:20].lower()
 remarks=['학교 공시 시간표에 따른 계획 수업이며, 실시간 변경 사항은 과목 담당자 확인이 필요합니다.','학점·이수 구분·강좌별 세부 수강조건은 현재 공개 시간표에서 확인되지 않았습니다.']
 if not section:remarks.append('분반 번호 미게시')
 if gaps:remarks.append('개별 미확정: '+', '.join(gaps))
 record={'sourceId':'gist-2026-2-'+stable,'campus':'main','academicYear':2026,'semester':'2','courseCode':code,'courseName':rawtitle,'section':section,'professor':', '.join(teachers),'credits':None,'departmentCredits':{},'classification':'','departments':['학사과정 공개 시간표'],'departmentRemarks':{'학사과정 공개 시간표':'\n'.join(remarks)},'sourceSchedule':' / '.join(f'{w}:{a}-{b}' for w,a,b,r in meetings),'sourceClassroom':' / '.join(dict.fromkeys(r for w,a,b,r in meetings)),'period':{'startDate':start.isoformat(),'endDate':end.isoformat()},'scheduleStatus':'unrecognized' if gaps else 'scheduled','schedules':schedules,'sourceMetadata':{'derivedStableIdentity':'gist-public-'+stable,'derivedIdentityFields':identity,'sourceCoordinatesAndEducationalSlots':slots,'operatingGaps':gaps,'plannedRegularTimetable':not gaps,'actualAttendanceConfirmed':False}}
 records.append(record);counts[record['scheduleStatus']]+=1
out={'schemaVersion':2,'universityId':'gist','sourceUrl':'https://www.gist.ac.kr/kr/html/sub05/050209.html?mode=V&no=222987','publishedDate':'2026-08-28','campusName':'광주과학기술원','campus':'main','academicYear':2026,'semester':'2','researchOnly':True,'completionClaim':False,'wholeOperatingAuditFinished':False,'actualAttendanceConfirmed':False,'sourceUnparsedEducationalCells':json.loads((p/'gist-current-slot-research.json').read_text())['unparsedCodeCells'],'productionActivationAllowed':False,'courses':records}
file=p/'gist-main-2026-2.planned-audited-20261008-r4.json';file.write_text(json.dumps(out,ensure_ascii=False,indent=2));audit={'researchOnly':True,'completionClaim':False,'uniquePrintedAliases':317,'derivedOfferingGroups':len(records),'counts':dict(counts),'datedMeetings':sum(len(r['schedules']) for r in records),'unpublishedSectionOfferings':sum(not r['section'] for r in records),'sourceMalformedH2840AndMergedAnnotationRemainSeparate':True,'wholeOperatingAuditFinished':False,'path':str(file.resolve()),'sha256':hashlib.sha256(file.read_bytes()).hexdigest()};(p/'gist-planned-audited-r4-audit.json').write_text(json.dumps(audit,indent=2));print(audit)
