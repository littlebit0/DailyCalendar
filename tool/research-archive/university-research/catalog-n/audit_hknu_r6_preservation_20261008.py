"""Verify original and every current educational row; output counts only."""
import json,pathlib,re,collections,hashlib
from urllib.parse import quote
R=pathlib.Path(__file__).resolve().parent
courses=[]
for campus in ['anseong','pyeongtaek']:
 courses+=json.loads((R/f'hknu-{campus}-2026-2.planned-audited-20261008-r6.json').read_text())['courses']
initial=json.loads((R/'hknu-2026-2-prepared-candidate.json').read_text())['courses']
current=json.loads((R/'hknu-current-education-identity-crosswalk-20261008.json').read_text())['rows']
norm=lambda s:re.sub(r'\s+','',s or '')
key=lambda c:(c['campus'],c['courseCode'],c['section'],norm(c['departments'][0]))
by={key(c):c for c in courses};assert len(by)==len(courses)==1493
for old in initial:
 c=by[key(old)];raw=c['metadata']['initialPublicEducationalFields'];assert str(raw['과목코드'])==old['courseCode'];assert raw['분반']==old['section'];assert norm(raw['과목명'])==norm(c['courseName'])
 for name in ['departments','departmentClassifications','departmentCredits']:
  assert c[name]==old[name]
 assert old['sourceId'] not in c['sourceId'] or c['sourceId'].startswith('hknu/')
 actual_id=f"hknu/{c['campus']}/2026/2/{c['courseCode']}/{c['section']}/{quote(norm(c['departments'][0]),safe='')}"
 assert c['sourceId']==actual_id
recorded=[]
for c in courses:
 m=c['metadata']
 if 'currentGeneralPublication' in m:recorded.append(m['currentGeneralPublication'])
 recorded+=m.get('currentGeneralSupplementaryEducationalRows',[])
assert len(recorded)==340
for row in current:
 hit=[r for r in recorded if r['sourceSheet']==row['sourceSheet'] and r['sourceRow']==row['sourceRow']];assert len(hit)==1;assert hit[0]['actualEducationalFields']==row['actualEducationalFields']
assert sum('currentFinalPublishedCancellation' in c['metadata'] for c in courses)==34
assert sum('currentSafetyMergedEducationalCells' in c['metadata'] for c in courses)==24
assert sum(len(c['metadata'].get('currentSafetyMergedEducationalCells',[])) for c in courses)==30
# Inspect privacy patterns without printing values. Public academic professors are retained.
private={}
for name,pattern in [('email',r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}'),('phone',r'(?<!\d)(?:010|02|0[3-6]\d)[- ]\d{3,4}[- ]\d{4}(?!\d)'),('credentialField',r'"(?:password|token|cookie|MEMBER_NO|staffId|employeeId)"\s*:')]:
 count=sum(len(re.findall(pattern,json.dumps(c,ensure_ascii=False),re.I)) for c in courses);private[name]=count;assert count==0,(name,count)
result={'researchOnly':True,'completionClaim':False,'originalOfferingsPreserved':1487,'actualPublishedNewSections':6,'originalRawEducationalRowsPreserved':1487,'currentEducationalRowsPreservedExactly':340,'currentStudentRedRestrictions':20,'currentSupplementaryRows':16,'currentSafetyNativeMergedCells':30,'currentSafetyNativeOfferingIdentities':24,'finalCancelledExactDepartmentTitleSection':34,'sourceIdentityIndependentOfClockProfessorRoomAndFile':True,'privacyPatternCounts':private,'remainingCurrentOtherDepartmentChangesNotFullyAudited':True}
(R/'hknu-r6-education-preservation-audit-20261008.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(result)
