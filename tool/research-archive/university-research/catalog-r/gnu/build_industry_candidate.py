import json,re,datetime,hashlib
from pathlib import Path
root=Path('work/university-research/catalog-r/gnu');cases=[];count=0;scheduled=0
clock={'금':{11:(1140,1185),12:(1190,1235),13:(1240,1285),14:(1290,1335)},'토':{i:(480+i*60,530+i*60) for i in range(1,11)}}
clockProof={'researchOnly':True,'url':'https://www.gnu.ac.kr/industry/cm/cntnts/cntntsView.do?cntntsId=3443&mi=6229','verifiedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'verificationMethod':'web open official current page lines218..238,297','pageUpdatedAt':'2026-06-18T10:18:39','educationalContext':'산업경영학과 학부과정 교육과정 강의시간','weekdaySpecificClock':clock,'noOtherDepartmentClockInference':True,'noSaturdayZeroOr11PlusInferred':True,'noPrivateOrContactDataStored':True}
(root/'gnu-industry-current-undergraduate-clock-v2.json').write_text(json.dumps(clockProof,ensure_ascii=False,indent=2)+'\n')
makeup=json.loads((root/'gnu-research-clock-applicability-held-v1-audit.json').read_text())['makeup']
manifest={}
for path in sorted(root.glob('gnu-*-2026-2.research-clock-applicability-held-v1.json')):
 data=json.loads(path.read_text())
 for c in data['courses']:
  raw=c['metadata']['originalEducationalFields'];c['schedules']=[]
  m=re.fullmatch(r'([금토])([0-9,]+)\[(.*?)\]',raw['schedule'])
  eligible=(raw['department']=='산업경영학과' and raw['method']=='대면수업' and not raw['remoteType'] and not raw['closedFirstAnnouncement'] and not raw['closedSecondAnnouncement'] and m and all(int(p) in clock[m[1]] for p in m[2].split(',')))
  reason='현재 운영·개별 수업 시각 확인 중'
  if not raw['schedule']:reason='공개 수업 시각 없음'
  if raw['closedFirstAnnouncement'] or raw['closedSecondAnnouncement']:reason='공개 폐강 공고 대상'
  if eligible:
   periods=[int(p) for p in m[2].split(',')];assert periods==list(range(periods[0],periods[-1]+1))
   day={'금':5,'토':6}[m[1]];date=datetime.date(2026,9,1)
   while date<=datetime.date(2026,12,7):
    if date.isoweekday()==day:
     text=date.isoformat()
     if text!='2026-10-03':
      actual=makeup.get(text,text);d=datetime.date.fromisoformat(actual)
      c['schedules'].append({'date':actual,'weekday':d.isoweekday(),'startMinute':clock[m[1]][periods[0]][0],'endMinute':clock[m[1]][periods[-1]][1],'classroom':m[3],'deliveryMode':'inPerson'})
    date+=datetime.timedelta(days=1)
   c['schedules'].sort(key=lambda x:x['date']);scheduled+=1;count+=len(c['schedules']);reason='산업경영학과 공개 학부 교시표 범위의 수업 계획'
   c['metadata']['weekdaySpecificClockSource']=clockProof['url'];c['metadata']['nativePeriods']=periods;c['metadata']['clockSecondSemesterApplicabilityConfirmed']=True
   cases.append({'sourceId':c['sourceId'],'nativeWeekday':day,'nativePeriods':periods,'expectedStartMinute':clock[m[1]][periods[0]][0],'expectedEndMinute':clock[m[1]][periods[-1]][1],'meetings':c['schedules']})
  else:c['metadata']['clockSecondSemesterApplicabilityConfirmed']=False
  c['metadata']['holdReason']=reason
  c['scheduleStatus']='scheduled' if eligible else ('unscheduled' if not raw['schedule'] else 'unrecognized')
  c['remarks']='2026-07-24 공개 원본이며 최신 변경은 통합서비스에서 확인해야 합니다. '+reason+'. 산업경영학과 학부 교시표는 금요일 11~14교시(45분)·토요일 1~10교시(50분)만 적용했습니다. 토요일 0·11·12교시, 다른 학과·캠퍼스 시각은 확인 중입니다. 표시 블록은 교시 사이 휴식을 포함하는 공개 계획이며 실제 출석 기록이 아닙니다. 10월 3일 토요일 개천절 및 개별 보강 시각, 12월 15~21일 기말시험의 개별 시각은 확인되지 않아 추가하지 않았습니다. '+raw['remarks']
 out=root/path.name.replace('research-clock-applicability-held-v1','industry-scoped-planned-v2');out.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n');manifest[out.name]=hashlib.sha256(out.read_bytes()).hexdigest()
audit={'researchOnly':True,'completionClaim':False,'permanentlyImpossible':False,'wholeCurrentLatestChangesConfirmed':False,'nativeRows':4842,'scheduledRows':scheduled,'meetings':count,'heldOrUntimed':4842-scheduled,'knownClockSource':clockProof['url'],'makeup':makeup,'omittedSaturdayHolidayNoIndividualMakeupClock':'2026-10-03','individualFinalExamDatesOmitted':['2026-12-15','2026-12-21'],'cases':cases,'sha256':manifest}
(root/'gnu-industry-scoped-planned-v2-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n');print(scheduled,count)
