"""Keep unresolved individual reasons visible; prior immutable snapshot untouched."""
import copy,hashlib,json
from pathlib import Path
P=Path(__file__).parent
old=json.loads((P/'tuk-published-regular-1346-next-audit-20261008.json').read_text());a=copy.deepcopy(old);a['datasets']=[];changed=[]
for e in old['datasets']:
 d=json.loads((P/e['file']).read_text())
 for c in d['courses']:
  if c['scheduleStatus']!='unrecognized':continue
  if c['sourceEducation']['heldOnlineScope']:continue
  reasons=c['individualBlockingReasons'];note=''
  if any('ER/fieldwork/service' in x for x in reasons):note+=' 원표의 현장연구/현장실습/사회봉사는 개인별 실제 활동 날짜·시각이 미확인으로, 기재 교시를 매주 출석처럼 만들지 않았습니다.'
  if any('원격중심' in x for x in reasons):note+=' 원문 수업진행구분이 원격중심이지만 실시간/동영상 및 주차별 출석 여부가 미확인이라 원격 교시를 일정으로 확정하지 않았습니다.'
  if any('theory is video' in x for x in reasons):note+=' 현행 수강안내는 이론 동영상 혼합수업을 명시하지만 월요일/토요일 중 어느 슬롯이 동영상인지 미확인이라 전체 교시를 실시간/대면으로 확정하지 않았습니다.'
  assert note
  c['departmentRemarks']={k:v+'\n미반영 사유:'+note for k,v in c['departmentRemarks'].items()};c['remarks']+='\n미반영 사유:'+note;changed.append(c['sourceId'])
 f=P/e['file'].replace('1346-next','1346-v2-next');assert not f.exists();f.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');a['datasets'].append({**e,'file':f.name,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()})
assert len(changed)==65
a.update(previousAudit='tuk-published-regular-1346-next-audit-20261008.json',only65HeldNotesClarified=True,allNativeAndDatedSlotsUnchanged=True,changedHeldNotesSourceIds=changed)
f=P/'tuk-published-regular-1346-v2-next-audit-20261008.json';assert not f.exists();f.write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n')
s=(P/'tuk_published_1346_fixture_test.dart').read_text().replace('tuk-published-regular-1346-next-audit','tuk-published-regular-1346-v2-next-audit');(P/'tuk_published_1346_v2_fixture_test.dart').write_text(s)
print(a['datasets'])
