"""Record exact reviewed meanings; no operational dates are whitelisted as prose.

The source lists are immutable review snapshots. This research ledger records
all remaining contexts, including facts that cannot yet produce an exact class.
"""
import json
from pathlib import Path
from collections import Counter
ROOT=Path(__file__).resolve().parent
load=lambda name:json.loads((ROOT/name).read_text())
remote=load('hufs-review3-remote-lines.json')
exception=load('hufs-review3-exception-lines.json')
other=load('hufs-review3-other-lines.json')
# Exact lines read in this pass. Preparatory/illustrative videos, content about
# cyber security, and produced assignment videos are not remote class events.
remote_safe={10,20,115,116,117,118,120,122,124,134,137,138,139,141,143,146,151,152,153,154,156,157,162,164,165,175,182,183,192,193,195,196,202,206,212,215,217,220,221,222,226,229,230,231,232,244,246,253,256,257,258,260,261,262,263,264,274,280,281,283,287,290,291,304,306,309,311,312,313,321,325,328,330,335,336,337,338}
# Generic revision/absence policies and literal holiday/corroboration topics.
# A future conditional make-up WEEK is not globally safe: real extra classes
# still need dates and clock proof, so all such rows remain operational.
exception_safe={47,148,153,159,247,253,258,274,275,276,296,297,369,400,405,406,416,438,441,447,448,451,459,461,509,532,664,683,684}
other_safe=set()
def add(*values):
 for value in values:
  if isinstance(value,range):other_safe.update(value)
  else:other_safe.add(value)
add(155,204,205,206,207,208,209,210,211,213,234,235,range(236,242),244,246,range(251,273),range(277,281),476,477,478,479,483,485,486,487,494,495,496,497,499,500,501,504,range(505,516),range(517,545),546,547,548,range(572,578),580,range(581,609),range(610,615),628,640,643,732,747,759,853,854,919,range(927,936),937,range(939,976),979,range(980,1011),range(1012,1042),range(1045,1105),range(1108,1112),range(1113,1121),1128,1234,range(1235,1253),1259,range(1261,1277),range(1280,1293),range(1296,1303),1319,1320,1321,1327,1328,1330,range(1360,1366),range(1370,1384),1391,1392,1393,1409,1415,1417,1429,1463,1464,1465,1466,1467,1480,range(1483,1491),range(1492,1501),1524,1525,1527,1529,1530,1540,1541,1542)
# Calendar dates hidden among numbered headings remain operating evidence.
remote_safe.discard(156)
remote_safe.add(259)  # adjacent lines explicitly place video preparation before classroom Q&A/practice
other_safe.discard(506)  # approximate lecture duration alone does not prove the whole class end
# Fixed whole-class segments/attendance and material allocation agree with
# the current source header; no start, end, weekday or classroom changes.
other_safe.update({11,12,13,15,16,481,1367,1416,1526})
other_safe.difference_update({207,628,640,643,747,759,853,854,919,1003,1004,1005,1006,1007,1037,1038,1039,1041,1072,1073,1074,1075,1100,1101})
# Fractional teaching/assessment counts, source revisions, bibliography dates,
# chapter numbers and movie playback offsets have been read as such. These
# exact selections contain no real no-class, makeup, excursion, or mode switch.
ledger=[]
for group,rows,safe in [('remote',remote,remote_safe),('exception',exception,exception_safe),('other',other,other_safe)]:
 assert max(safe)<len(rows)
 for index,row in enumerate(rows):
  nonoperating=index in safe
  if nonoperating:
   reason={'remote':'보조 시청각 자료·사전학습 후 강의실 활동·과제 제작·교육 주제·수업 외 상담·조건부 출석 정책; 실제 원격 차시 지정 아님','exception':'교육 주제 또는 일반 부재/계획변경 정책; 실제 휴강·보강·교외 수업 지정 아님','other':'장절·평가 비율·영상 재생구간·과제 제출/참고문헌/원문 수정일; 실제 수업 날짜·시간 변경 아님'}[group]
  elif group=='remote':reason='원격/녹화·혼합 운영 또는 특정 차시 원격 표시. 고정 강의실 시각만으로 실제 대면·실시간·VOD 범위 및 개별 날짜·종료시각을 확정할 수 없어 운영 증거 추가 필요'
  elif group=='exception':reason='휴강·보강·수업 없는 주차·집중/교외 운영 표시. 원문에 적힌 날짜·장소는 보존하되 전체 실제 차시와 개별 시작·종료·장소를 검증하기 전 자동 생성 보류'
  else:reason='실제 날짜·수업 세부 시간·요일 표시. 전체 주차/개강일/휴업일/시험·보강 구간과 고정 교시·강의실의 일치를 검증하기 전 자동 생성 보류'
  ledger.append({**row,'group':group,'groupIndex':index,'semanticDecision':'reviewedNonOperating' if nonoperating else 'reviewedOperatingProofUnresolved','reason':reason})
assert len(ledger)==2663
assert len({x['index'] for x in ledger})==2663
# A final whole retained-evidence pass found additional no-class wording.
for extra_index,(text,refs) in enumerate(load('hufs-review3-extra-no-class-signals.json').items()):
 safe=text.startswith('본 과목은 실기 위주로') or text.startswith('4주차부터는 학생 중심의')
 ledger.append({'text':text,'references':refs,'tags':['exceptions'],'group':'additionalNoClass','groupIndex':extra_index,'index':2663+extra_index,'semanticDecision':'reviewedNonOperating' if safe else 'reviewedOperatingProofUnresolved','reason':'일반 참여 규칙 또는 강의자료 없이 토론하는 교육 방식; 수업 취소 아님' if safe else '수업·강의 없음 또는 Reading week가 명시됨; 해당 실제 날짜와 보강/시험 시각 확정 필요'})
additional=load('hufs-additional-exact-semantic-review.json')
additional['notOperatingSentences']=[x for x in additional['notOperatingSentences'] if x.get('reviewBatch')!='whole-review-3']
known={x['text'] for x in additional['notOperatingSentences']}
for row in ledger:
 if row['semanticDecision']=='reviewedNonOperating' and row['text'] not in known:
  additional['notOperatingSentences'].append({'text':row['text'],'references':row['references'],'reason':row['reason'],'reviewBatch':'whole-review-3'});known.add(row['text'])
(ROOT/'hufs-additional-exact-semantic-review.json').write_text(json.dumps(additional,ensure_ascii=False,indent=2))
output={'researchOnly':True,'completionClaim':False,'reviewScope':'all 2663 remaining exact flagged source lines for 1073 pending courses plus 17 additional no-class signals; semantic interpretation is distinct from exact date/clock proof','allRemainingSemanticLinesReviewed':True,'counts':dict(Counter(x['semanticDecision'] for x in ledger)),'lines':ledger}
(ROOT/'hufs-whole-review3-semantic-ledger.json').write_text(json.dumps(output,ensure_ascii=False,indent=2))
print(output['counts'])
