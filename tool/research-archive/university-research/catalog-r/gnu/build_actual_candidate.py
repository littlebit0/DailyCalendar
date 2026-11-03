# coding: utf-8
import json,re,datetime,hashlib
from pathlib import Path
root=Path('work/university-research/catalog-r/gnu');proof=json.loads((root/'gnu-industry-current-actual-education-hwp-v3.json').read_text());pub=proof['rows'];cases=[];conflicts=[];manifest={}
makeup=json.loads((root/'gnu-industry-scoped-planned-v2-audit.json').read_text())['makeup']
for p in sorted(root.glob('gnu-*-2026-2.industry-scoped-planned-v2.json')):
 d=json.loads(p.read_text())
 for c in d['courses']:
  c['schedules']=[];raw=c['metadata']['originalEducationalFields'];matched=[r for r in pub if r['courseCode']==c['courseCode'] and r['section']==c['section'] and r['title']==c['courseName']]
  reason='공개 시각·현재 운영 변경 확인 중';current=None
  if matched and not(raw['closedFirstAnnouncement'] or raw['closedSecondAnnouncement']):
   assert len(matched)==1;current=matched[0];m=re.fullmatch(r'([금토])([0-9,]+)\[(.*)\]',current['schedule']);day={'금':5,'토':6}[m[1]]
   if day==6:start,end=proof['actualSaturdayBlocks'][m[2]]
   else:assert m[2]=='11,12,13';start,end=1140,1285
   date=datetime.date(2026,9,1)
   while date<=datetime.date(2026,12,7):
    if date.isoweekday()==day and date.isoformat()!='2026-10-03':
     actual=makeup.get(date.isoformat(),date.isoformat());a=datetime.date.fromisoformat(actual);c['schedules'].append({'date':actual,'weekday':a.isoweekday(),'startMinute':start,'endMinute':end,'classroom':m[3],'deliveryMode':'inPerson'})
    date+=datetime.timedelta(days=1)
   c['schedules'].sort(key=lambda x:x['date']);reason='2026-07-29 산업경영학과 수정 공지의 실제 시각 계획';c['professor']=current['professor'];c['sourceSchedule']=current['schedule'];c['metadata']['currentPublishedEducationalRow']=current;c['metadata']['actualSaturdayClockOverridesNominal']=day==6;c['metadata']['clockSecondSemesterApplicabilityConfirmed']=True
   if '산업경영학과' not in c['departments']:c['departments'].append('산업경영학과');c['departmentCredits']['산업경영학과']=float(current['credits']);c['departmentClassifications']['산업경영학과']=current['classification']
   cases.append({'sourceId':c['sourceId'],'nativeWeekday':day,'nativePeriods':[int(x) for x in m[2].split(',')],'expectedStartMinute':start,'expectedEndMinute':end,'meetings':c['schedules']})
  else:c['metadata']['clockSecondSemesterApplicabilityConfirmed']=False
  # Native identities with discrepant new source names/codes are never silently relinked.
  conflict=[r for r in pub if (r['courseCode']==c['courseCode'] and r['section']==c['section'] and r['title']!=c['courseName']) or (r['title']==c['courseName'] and r['section']==c['section'] and r['courseCode']!=c['courseCode'])]
  if conflict and not matched:c['metadata']['currentPublishedNativeIdentityConflict']=conflict;conflicts.append(c['sourceId']);reason='학과 수정 공지의 교과목 코드·분반·명칭 불일치 확인 중'
  c['metadata']['holdReason']=reason;c['scheduleStatus']='scheduled' if c['schedules'] else ('unscheduled' if not raw['schedule'] else 'unrecognized')
  c['remarks']='2026-07-24 공개 원본과 2026-07-29 산업경영학과 수정 공지에 따른 계획이며 최신 변경은 통합서비스에서 확인해야 합니다. '+reason+'. 토요일 실제 시각은 수정 공지의 0·1·2교시=09:00~11:00, 3·4·5교시=11:00~13:00, 7·8·9교시=14:00~16:00, 10·11·12교시=16:00~18:00을 적용했습니다. 금요일 야간 11~13교시는 학과 학부 교시표의 19:00~21:25(각 45분) 공개 예약 블록입니다. 실제 출석 기록이 아닙니다. 10월 3일 토요일 개천절의 개별 보강 시각 및 12월 15~21일 기말시험의 개별 시각은 확인되지 않아 추가하지 않았습니다. '+raw['remarks']+'\n'+'\n'.join(proof['publishedStudentNotes'])
 out=root/p.name.replace('industry-scoped-planned-v2','industry-actual-planned-v3');out.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');manifest[out.name]=hashlib.sha256(out.read_bytes()).hexdigest()
a={'researchOnly':True,'completionClaim':False,'permanentlyImpossible':False,'nativeRows':4842,'scheduledRows':len(cases),'meetings':sum(len(x['meetings']) for x in cases),'heldOrUntimed':4842-len(cases),'cases':cases,'nativeIdentityConflictIds':conflicts,'source':proof['sourceUrl'],'wholeCurrentLatestChangesConfirmed':False,'sha256':manifest}
(root/'gnu-industry-actual-planned-v3-audit.json').write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n');print(len(cases),a['meetings'],conflicts)
