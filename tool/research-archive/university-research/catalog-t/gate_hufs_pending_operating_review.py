"""Conservatively gate individually unresolved operating context, preserving all metadata.

This produces a separate review candidate; it does not activate the school.
"""
import json,re
from collections import Counter
from pathlib import Path
ROOT=Path(__file__).resolve().parent
load=lambda p:json.loads(p.read_text())
contexts=load(ROOT/'hufs-whole-operating-contexts.json')
assert contexts['wholePlansAcquired'] and contexts['plansAcquired']==3372
# These exact source sentences were read and concern content, class recording
# prohibition, supplementary review media, attendance, or office hours.
# None states replacement of a scheduled class by a timed/video session.
indexes={36,45,47,150,151,152,153,154,155,201,209,250,304,305,307,313,318,335,351,362,364,367,370,371,372,461,497,504,529,560,566,567,636,640,647,648,649,650,678,682,693,696,772,780,781,782,787,788,823,824,833,868,875,876,878,884,885,886,887,888,988,999}
sentences=load(ROOT/'hufs-unique-operating-sentences.json')
nonoperating={sentences[i]['text'] for i in indexes}
nonoperating.add('*중간과제 및 기말보고서 작성 후 모둠을 구성하여 협의함.')
online=load(ROOT/'hufs-online-only-contexts.json')
online_nonoperating={2,3,4,5,9,10,11,12,13,14,15,24,25,26,29,30,31,33,36,37,38,39,46,47,48,49,50,51,52,54,55,56,57,59,60,61,62,63,64,65,66,67,68,70,71,72,73,76,77,78,90,91,93,96,97,98,99,100,102,103,109,110,114,115,117,120,121,124,125,126,128,130,131,134,135,143,145,147,148,151,152,154,156,157,158,159,160,161,162,164,173,175,191,194,195,197,200,205,206,207,208,209,210,211,212,213,214,215,216,219,222,225,226,227,228,237,238,240,241,243,244,245,246,247,248,251,252,253,263,264,265,267,268,269,271,272,273,276,277,278,283,285,294,297,298,302,303,304,305,306,307,308,309}
nonoperating.update(online[i]['text'] for i in online_nonoperating)
# Read separately: explicit current in-person baseline, with only contingent
# exceptional switching. None identifies an actually switched dated class.
conditional_indexes={80,145,256,316,321,338,341,382,543,633,825,828,901,932,987}
conditional_online_indexes={92,95,235}
nonoperating.update(sentences[i]['text'] for i in conditional_indexes)
nonoperating.update(online[i]['text'] for i in conditional_online_indexes)
negotiation=load(ROOT/'hufs-negotiation-contexts.json')
negotiation_nonoperating={2,3,4,6,7,8,9,10,11,12,14,16,17,18,20,22,23,24,27,28,29,31,32,33,34,37,39,40,41,42,43,44,47,48,49,50,51,55,56,57,58}
nonoperating.update(negotiation[i]['text'] for i in negotiation_nonoperating)

semantic_ledger=load(ROOT/'hufs-whole-review3-semantic-ledger.json')
reviewed_lines={item['text']:item for item in semantic_ledger['lines']}
additional_review=load(ROOT/'hufs-additional-exact-semantic-review.json')
nonoperating.update(item['text'] for item in additional_review['notOperatingSentences'])



# A field is stored as its full educational paragraph. Inspect only its
# matching lines rather than treating ordinary adjacent prose as an exception.
scope={'__file__':str(ROOT/'review_hufs_operating_contexts.py')}
exec((ROOT/'review_hufs_operating_contexts.py').read_text().split('rows=json.loads')[0],scope)
match_tags=scope['matches']
flagged={(r['campus'],r['key']):r for r in contexts['planContexts']}
rawflagged={(r['campus'],r['key']):r for r in contexts['rawContexts']}
late_closure_review={(r['campus'],r['key']):r for r in load(ROOT/'hufs-normal-late-closure-meaning-review.json')['reviewed']}
rawrecords=load(ROOT/'hufs-current-20261008/courses.json')
rawrows={(r['queryCampus'],r['row']['lssnCd']):r['row'] for r in rawrecords}
source_change_audit=[]
def raw_operating_unresolved(identity):
 row=rawrows[identity]
 notes=' '.join(row.get(k) or '' for k in ['etc','etc2'])
 if re.search(r'비대면|실시간|온라인|녹화|원격|\d{1,2}:\d{2}',notes):
  return identity[1]!='V43407301'
 if re.search(r'강의.?시간.{0,4}변경|수업.?시간.{0,4}변경|[월화수목금토일]\d.*->.*[월화수목금토일]\d',notes):
  plan=load(ROOT/'hufs-public-operating-plans'/('-'.join(identity)+'.json'))
  actual=plan['fields'].get('schedule','').splitlines()
  same=bool(actual) and re.sub(r'\s+',' ',actual[0]).strip()==re.sub(r'\s+',' ',row['dayTimeDisplay']).strip()
  source_change_audit.append({'campus':identity[0],'key':identity[1],'currentOfferingAndPlanAgree':same,'currentSchedule':row['dayTimeDisplay'],'note':row['etc'],'sourceUrl':plan['sourceUrl']})
  return not same
 # All remaining raw date markers were read: instructor change timestamps
 # or registration eligibility/opening dates, not teaching dates or clocks.
 return False
decisions=[]
for campus,rawcampus in [('seoul','H1'),('global','H2')]:
 doc=load(ROOT/f'hufs-{campus}-2026-2.whole-candidate.json')
 for course in doc['courses']:
  key=course['courseCode']+course['section'];identity=(rawcampus,key)
  if not course['schedules']:
   decisions.append({'campus':campus,'key':key,'decision':course['scheduleStatus'],'reason':'기존 근거별 미확정 또는 시간 없는 강좌'});continue
  reasons=[]
  reviewed_operating=[]
  semantic_pending=[]
  plan_document=load(ROOT/'hufs-public-operating-plans'/('-'.join(identity)+'.json'))
  missing_public_plan=plan_document.get('publicPlanMetadataStatus')=='unpublished'
  if missing_public_plan:reasons.append('현재 공개 강의계획 운영 정보가 게시되지 않아 실제 운영 미확정')
  context=flagged.get(identity)
  if context:
   unresolved=[]
   for field,value in context['contexts'].items():
    lines=[line.strip() for line in value['text'].splitlines() if line.strip() and match_tags(line)]
    # Do not call whole field safe merely because one sentence is reviewed.
    known_late=late_closure_review.get(identity)
    if known_late and field==known_late['reviewedField'] and value['text']==known_late['reviewedText']:
     assert all(meeting['weekday'] in {2,3} for meeting in course['schedules'])
     assert plan_document['fields']['schedule'].splitlines()[0]==course['sourceSchedule']==known_late['currentPlanHeader']
     continue
    if not lines or not all(line in nonoperating for line in lines):
     unresolved.append(field)
     for line in lines:
      if line not in nonoperating:
       if line in reviewed_lines:
        reviewed_operating.append({'field':field,'text':line,'tags':reviewed_lines[line]['tags'],'reason':reviewed_lines[line]['reason']})
       else:semantic_pending.append({'field':field,'text':line})
   if unresolved:reasons.append('공개 계획 '+','.join(unresolved)+'의 실제 운영 날짜·시각·장소 확정 근거 추가 필요' if not semantic_pending else '공개 계획 운영 문맥 개별 의미 검토 미완료')
  if (identity in rawflagged or re.search(r'[월화수목금토일]\d.*->.*[월화수목금토일]\d',rawrows[identity].get('etc') or '')) and raw_operating_unresolved(identity):
   reasons.append('원자료 비고에 시간·운영·날짜 표시가 있어 개별 확정 필요')
  if reasons:
   course['schedules']=[];course['scheduleStatus']='unrecognized'
   for department in course['departments']:
    course['departmentRemarks'][department]+=' · 공개 운영 일정 확인 중: 자동 시간 생성 보류'
   decisions.append({'campus':campus,'key':key,'decision':'unpublishedOperatingProof' if missing_public_plan else ('pendingOperatingReview' if semantic_pending else 'reviewedOperatingProofUnresolved'),'reviewedOperatingContexts':reviewed_operating,'unreviewedContexts':semantic_pending,'reason':' / '.join(reasons),'sourceUrl':context.get('sourceUrl') if context else None})
  else:decisions.append({'campus':campus,'key':key,'decision':'sourceRegular','reason':'공식 정기 시각 확보; 운영 표시 추출에서 추가 미확정 문맥 없음'})
 (ROOT/f'hufs-{campus}-2026-2.operating-review-candidate.json').write_text(json.dumps(doc,ensure_ascii=False,indent=2))
# The remaining flagged courses were already individually reviewed by the
# full printed-date validator, confirmed-gap review, or four scoped extras.
# They remain gated here until their separate date proof is applied downstream.
prior_date_review=load(ROOT/'hufs-explicit-dated-reviewed-audit.json')
prior_reviewed_ids={x['sourceId'] for x in prior_date_review['reviewed']+prior_date_review['attemptedUnresolved']}
prior_reviewed_ids.update(x['sourceId'] for x in load(ROOT/'hufs-confirmed-current-operating-gaps.json')['confirmedIndividualOperatingGaps'])
prior_reviewed_ids.update({'hufs/seoul/2026/2/A013991/01','hufs/seoul/2026/2/A014184/01','hufs/seoul/2026/2/U042391/01','hufs/seoul/2026/2/U042391/02'})
for decision in decisions:
 if decision.get('unreviewedContexts'):
  identity=f"hufs/{decision['campus']}/2026/2/{decision['key'][:7]}/{decision['key'][7:]}"
  if identity in prior_reviewed_ids:
   decision['priorIndividualOperatingReview']=True
   decision['separateProofRequiredContexts']=decision.pop('unreviewedContexts')
   decision['decision']='priorReviewedOperatingProof'
audit={'researchOnly':True,'completionClaim':False,'productionActivationComplete':False,'wholeSourceVerified':True,'wholePublicPlanAcquisitionVerified':True,'semanticReviewComplete':not any(d.get('unreviewedContexts') for d in decisions),'counts':dict(Counter(d['decision'] for d in decisions)),'confirmedNonOperatingSentenceCount':len(nonoperating),'currentChangedScheduleCrossCheck':source_change_audit,'decisions':decisions}
(ROOT/'hufs-pending-operating-review-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2))
print(audit['counts'])
