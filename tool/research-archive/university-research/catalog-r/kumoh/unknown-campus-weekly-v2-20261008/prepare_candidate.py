import copy,datetime,hashlib,json,pathlib,re
P=pathlib.Path(__file__).parent
B=P/'prior-packaged-unknown73-baseline.json'
base=json.loads(B.read_text());candidate=copy.deepcopy(base)
raw=json.loads(pathlib.Path('work/university-research/catalog-m/kumoh-current-educational-recheck-20261008.json').read_text());native={r['SBJCT_CD_DCLSS']:r for r in raw}
clock={str(i):((8+i)*60,(8+i)*60+50) for i in range(10)};clock.update({s:(1080+i*55,1130+i*55) for i,s in enumerate('ABCDE')})
exclude={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
receipts=[];held=[]
for c in candidate['courses']:
 meta=c['metadata'];r=meta['originalEducationalFields'];ident=meta['nativeIdentity'];assert r==native[ident]
 if meta['heldReason']!='원문 강의실 실제 캠퍼스 대응 미확인':held.append(c['sourceId']);continue
 assert r['DEPT_SE_NM']=='학부' and r['YR']=='2026' and str(r['SCTM'])=='2' and r['LSN_OPER_MTHD_NM']=='대면수업'
 spans=[]
 for part in r['TIME_LCTRM_INFO'].split(','):
  m=re.fullmatch(r'([월화수목금토일])([0-9A-E]+)/(.+)',part);assert m
  wd='월화수목금토일'.index(m[1])+1;assert wd<=5
  for period in m[2]:
   s,e=clock[period];spans.append({'weekday':wd,'startMinute':s,'endMinute':e,'classroom':m[3]})
 assert len({tuple(s.values()) for s in spans})==len(spans)
 meetings=[];date=datetime.date(2026,9,1)
 while date<=datetime.date(2026,12,7):
  if date.isoformat() not in exclude:
   meetings.extend(dict(s,date=date.isoformat()) for s in spans if s['weekday']==date.isoweekday())
  date+=datetime.timedelta(days=1)
 assert meetings
 c['schedules']=meetings;c['scheduleStatus']='scheduled'
 c['remarks']=c['remarks'].replace(' 예약 보류: 원문 강의실 실제 캠퍼스 대응 미확인','')+' 물리 캠퍼스는 미확인으로 유지합니다. 학교 공통 교시표와 원문 요일·강의실에 따른 정규 예약이며 개별 실제 출석일 확정이 아닙니다.'
 meta['priorHeldReason']=meta['heldReason'];meta['heldReason']='';meta['reservationDateBasis']='current native weekday/room and own school-wide2026-2 period clocks; regular booking, not individual attendance dates';meta['researchOnly']=True
 receipts.append({'sourceId':c['sourceId'],'nativeIdentity':ident,'originalEducationalFields':r,'directNativePeriodGeometry':spans,'reservations':len(meetings),'physicalCampusClaim':False,'sourceClockScope':'current2026-2undergraduate guide school-wide period table'})
candidate['researchOnly']=True;candidate['completionClaim']=False;candidate['wholeActualAttendanceConfirmed']=False
outfile=P/'kumoh-unknown-2026-2.weekly-reservations-v2.json';outfile.write_text(json.dumps(candidate,ensure_ascii=False,indent=2)+'\n')
(P/'new53-native-education-receipts.json').write_text(json.dumps(receipts,ensure_ascii=False,indent=2)+'\n')
changed={x['sourceId'] for x in receipts};old={c['sourceId']:c for c in base['courses']}
for c in candidate['courses']:
 if c['sourceId'] not in changed:assert c==old[c['sourceId']]
 for k in ['sourceId','campus','courseCode','section','courseName','credits','classification','professor','departments','departmentCredits','departmentClassifications','sourceSchedule','sourceClassroom','period']:
  assert c.get(k)==old[c['sourceId']].get(k)
assert len(changed)==53 and len(candidate['courses'])==73 and len(held)==20
proof=json.loads(pathlib.Path('work/university-research/catalog-r/kumoh/kumoh-current-source-proof-v1.json').read_text())
assert hashlib.sha256(pathlib.Path('work/university-research/catalog-m/kumoh-2026-2-attachment-1.pdf').read_bytes()).hexdigest()==proof['guideClockPdfSha256']
(P/'clock-calendar-closure-source-education.json').write_text(json.dumps({k:proof[k] for k in ['sourceGuideUrl','guideAttachments','guideClockSource','guideClockPdfSha256','currentClosureUrl','closureCatalogIntersection','currentEducationalCalendar','termEnd','termEndPrinted','termEndDerivation','ordinaryReservationEnd','ordinaryEndDerivation','concentratedSourceWarning']},ensure_ascii=False,indent=2)+'\n')
audit={'wholeUnknownNative':73,'newScheduled':53,'newReservations':sum(len(c['schedules']) for c in candidate['courses']),'unchangedHeld':20,'allSchoolNative':957,'priorOtherCampusScheduled':863,'baselinePath':str(B),'baselineSHA256':hashlib.sha256(B.read_bytes()).hexdigest(),'rawIndependentSHA256':hashlib.sha256(pathlib.Path('work/university-research/catalog-m/kumoh-current-educational-recheck-20261008.json').read_bytes()).hexdigest(),'pythonIndependentIdentityGeometryAndDateChecks':'PASS','actualModelThreeModeDriveVerified':False,'sdkCalls':0,'productChanged':False,'campusUnknownDoesNotBlockReservation':True,'completionClaim':False,'actualAttendanceConfirmed':False,'heldSourceIds':held}
(P/'audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n');print(json.dumps(audit,ensure_ascii=False)[:800])
