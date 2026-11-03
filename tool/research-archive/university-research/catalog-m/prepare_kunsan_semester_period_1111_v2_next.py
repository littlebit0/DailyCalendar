"""Separate official semester endpoint from narrower generated ordinary meeting scope."""
import copy,hashlib,json
from pathlib import Path
P=Path(__file__).parent
previous=json.loads((P/'kunsan-published-regular-1111-numeric-partial-next-audit-20261008.json').read_text());audit=copy.deepcopy(previous);audit['datasets']=[]
note='학교의 이번 학기는8월31일~12월17일입니다. 반영된 정규 수업·지정 보강 예약 범위는12월10일까지이며, 중간·기말 시험 일정은 정규 교시로 별도 생성하지 않았습니다.12월10일을 이 과목의 실제 조기 종강으로 의미하지 않습니다.'
for entry in previous['datasets']:
 old=json.loads((P/entry['file']).read_text());d=copy.deepcopy(old)
 for c in d['courses']:
  if not c['schedules']:continue
  assert c['period']=={'startDate':'2026-08-31','endDate':'2026-12-10'}
  c['period']['endDate']='2026-12-17'
  c['sourceEducation'].update(officialSemesterPeriod={'startDate':'2026-08-31','endDate':'2026-12-17'},generatedOrdinaryMakeupDateScopeEnd='2026-12-10',courseEarlyEndConfirmed=False,semesterBoundaryProof='kunsan-current-calendar-operating-review-20261008.json:개강08/31+종강12/17')
  c['departmentRemarks']={k:v+'\n'+note for k,v in c['departmentRemarks'].items()};c['remarks']+='\n'+note
 for a,b in zip(old['courses'],d['courses']):
  for key in a:
   if key not in ['period','sourceEducation','departmentRemarks','remarks']:assert a[key]==b[key]
 name=entry['file'].replace('1111-numeric-partial-next','1111-numeric-partial-v2-next');f=P/name;assert not f.exists();f.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');audit['datasets'].append({**entry,'file':name,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()})
audit.update(previousAudit='kunsan-published-regular-1111-numeric-partial-next-audit-20261008.json',datedMeetingsAndAllNativeEducationUnchanged=True,officialSemesterPeriod={'startDate':'2026-08-31','endDate':'2026-12-17'},generatedOrdinaryMakeupDateScopeEnd='2026-12-10',semesterBoundaryProof='kunsan-current-calendar-operating-review-20261008.json',sourceCalendarResponseSHA256='dd2f24279ff006603fd1380308488a52699898d6632fd4a0164f916dd2680109',limits='Current official semester endDec17 restored. Last generated ordinary/makeup dateDec10 does not establish individual course early end. Dated22802 unchanged, exam attendance not invented. Existing partial circled and final-active limitations remain.')
f=P/'kunsan-published-regular-1111-numeric-partial-v2-next-audit-20261008.json';assert not f.exists();f.write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n');print(audit['datasets'])
