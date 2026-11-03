# -*- coding: utf-8 -*-
"""Export conservative educational-only HUFS registration checkpoint."""
import json,re,collections
from datetime import date,timedelta
from hufs_classification_boundary import normalize as normalize_classification
from hufs_verified_printed_extras import recover as recover_printed_extras, proofs as verified_extras
from pathlib import Path
ROOT=Path(__file__).resolve().parent
load=lambda f:json.loads((ROOT/f).read_text())
prepared={(x['campus'],x['identity']):x for x in load('hufs-whole-prepared-audit.json')['decisions']}
gated={(x['campus'],x['key']):x for x in load('hufs-pending-operating-review-audit.json')['decisions']}
dated=load('hufs-explicit-dated-reviewed-audit.json')
dated_ids={x['sourceId'] for x in dated['reviewed']}
dated_missing={x['sourceId']:x['reason'] for x in dated['attemptedUnresolved']}
confirmed_gaps={x['sourceId']:x for x in load('hufs-confirmed-current-operating-gaps.json')['confirmedIndividualOperatingGaps']}
allowed={'sourceId','universityId','campus','academicYear','semester','courseCode','section','courseName','professor','credits','sourceSchedule','sourceClassroom','scheduleStatus','schedules','departments','departmentCredits','departmentClassifications','departmentRemarks','period'}
meta={'schemaVersion','universityId','campus','campusName','academicYear','semester','publishedDate','sourceUrl','courses'}
audit={'researchOnly':True,'completionClaim':False,'wholeSemanticReviewComplete':load('hufs-pending-operating-review-audit.json')['semanticReviewComplete'],'candidateActivationScope':'partial educational checkpoint; unresolved courses individually blocked','courseCount':0,'counts':{},'campuses':{},'unresolved':[],'privacy':{'forbiddenContactOrAccessMarkers':0,'nonEducationalFields':0},'restrictionPreservation':True,'normalDerivedDateProof':{'sourceCalendarUrl':'https://www.hufs.ac.kr/schdulmanage/hufs/40/yearSchdul.do','repeatedTeachingStart':'2026-09-01','repeatedTeachingEnd':'2026-12-07','excludedSchoolClosureDates':['2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'],'derivedDates':True,'individuallyPrintedDates':False,'schoolRuleEvidence':'hufs-current-school-closure-rule-evidence.json','ruleBasis':'학칙 제9조 정기휴업 및 시행세칙 제38조 휴강/보강; 현재 학교 연간 학사력과 대조','holidayPracticeExceptions':'명시 휴업일 실험/실습·교외·특별운영이 남은 강좌는 개별 차단'},'normalRepeatedRules':[]}
classification_changes=[]
counts=collections.Counter()
for campus in ['seoul','global']:
    doc=load(f'hufs-{campus}-2026-2.dated-reviewed-candidate.json')
    original=load(f'hufs-{campus}-2026-2.whole-candidate.json')
    baseline={c['sourceId']:c for c in original['courses']}
    clean={k:v for k,v in doc.items() if k in meta}
    cc=collections.Counter()
    for c in clean['courses']:
        assert set(c)<=allowed, set(c)-allowed
        raw=baseline[c['sourceId']]
        if c['sourceId'] in verified_extras:
            recovered=recover_printed_extras(raw);c.clear();c.update(recovered)
        for field in ['courseCode','section','courseName','professor','credits','sourceSchedule','sourceClassroom','departments','departmentCredits']:
            assert c[field]==raw[field],(c['sourceId'],field)
        for department,note in raw['departmentRemarks'].items():assert c['departmentRemarks'][department].startswith(note)
        classification_changes.extend(normalize_classification(c))
        identity=(campus,c['courseCode']+c['section']);entry=gated[identity]
        if c['schedules']:
            kind='regularWithVerifiedExtras' if c['sourceId'] in verified_extras else 'datedVerified' if c['sourceId'] in dated_ids else 'regularVerified'
            if kind=='regularVerified':
                repeated=[dict(meeting) for meeting in c['schedules']]
                actual=[]
                cursor=date(2026,9,1)
                while cursor<=date(2026,12,7):
                    if cursor.isoweekday()!=7 and cursor.isoformat() not in audit['normalDerivedDateProof']['excludedSchoolClosureDates']:
                        actual.extend({**meeting,'date':cursor.isoformat()} for meeting in repeated if cursor.isoweekday()==meeting['weekday'])
                    cursor+=timedelta(days=1)
                c['schedules']=actual
                audit['normalRepeatedRules'].append({'sourceId':c['sourceId'],'sourceRepeatedRule':repeated,'derivedDates':[m['date'] for m in actual]})
            assert all(s.get('classroom','')==raw['schedules'][0]['classroom'] for s in c['schedules']) if kind=='datedVerified' else True
        elif c['scheduleStatus']=='unscheduled':kind='untimed'
        else:
            if c['sourceId'] in confirmed_gaps:
                kind='confirmedOperatingGap';reason=confirmed_gaps[c['sourceId']]['reason']
            elif entry['decision']=='unrecognized':
                kind='evidenceInsufficient';reason=prepared[identity]['reason']
            elif entry['decision']=='unpublishedOperatingProof':kind='unpublishedOperatingProof';reason=entry['reason']
            elif c['sourceId'] in dated_missing:kind='datedProofUnresolved';reason=dated_missing[c['sourceId']]
            elif entry['decision']=='reviewedOperatingProofUnresolved':kind='reviewedOperatingProofUnresolved';reason=entry['reason']
            else:kind='semanticReviewPending';reason=entry['reason']
            audit['unresolved'].append({'sourceId':c['sourceId'],'campus':campus,'kind':kind,'reason':reason,'reviewedOperatingContexts':entry.get('reviewedOperatingContexts',[])})
        counts[kind]+=1;cc[kind]+=1;audit['courseCount']+=1
        payload=json.dumps(c,ensure_ascii=False)
        assert not re.search(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}|(?:zoom\.us|webex\.com|calendly\.com)|(?:password|access_token|empId|cookie|secret)\s*[":=]',payload,re.I),c['sourceId']
    audit['campuses'][campus]={'courseCount':len(clean['courses']),'counts':dict(cc)}
    (ROOT/f'hufs-{campus}-2026-2.registration-candidate.json').write_text(json.dumps(clean,ensure_ascii=False,indent=2))
audit['counts']=dict(counts)
audit['verifiedPrintedExtras']=verified_extras
assert audit['courseCount']==3372 and sum(counts.values())==3372
(ROOT/'hufs-registration-checkpoint-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2))
(ROOT/'hufs-classification-source-audit.json').write_text(json.dumps({'checkedDate':'2026-10-08','researchOnly':True,'wholeAliasCount':len(classification_changes),'mappings':classification_changes,'classificationNotDefaultedToMajor':True},ensure_ascii=False,indent=2))
print(audit['counts'])
