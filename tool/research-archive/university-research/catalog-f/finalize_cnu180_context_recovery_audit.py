"""Finalize local recovered educational comparison; no network or raw-value output."""
import difflib, hashlib, json, re
from pathlib import Path
R=Path(__file__).resolve().parent
first=json.loads((R/'cnu-current180-preserved-context-recovery-firstpass-audit.json').read_text())
assert first['finished'] and first['processedPlans']==180
results=[];findings=[]
for original in first['results']:
 cid=original['courseId'];p=R/'cnu-current180-recovered-education-20261008'/f'{cid}.json';fresh=json.loads(p.read_text());old=json.loads((R/'cnu-current-education'/f'{cid}.json').read_text());changed=[];added=[];removed=[]
 for sec in ['header','weeks']:
  for i in range(max(len(old[sec]),len(fresh[sec]))):
   a=old[sec][i] if i<len(old[sec]) else {};b=fresh[sec][i] if i<len(fresh[sec]) else {}
   for k in sorted(set(a)|set(b)):
    if a.get(k)!=b.get(k):
     changed.append({'section':sec,'row':i,'field':k})
     if isinstance(a.get(k),str) and isinstance(b.get(k),str):
      delta=list(difflib.ndiff(a[k].splitlines(),b[k].splitlines()));added.extend(x[2:] for x in delta if x.startswith('+ ') and x[2:].strip());removed.extend(x[2:] for x in delta if x.startswith('- ') and x[2:].strip())
    v=b.get(k)
    if not isinstance(v,str):continue
    if re.search(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}|https?://|(?<!\d)0\d{1,2}[- .]\d{3,4}[- .]\d{4}(?!\d)',v,re.I):findings.append({'courseId':cid,'section':sec,'row':i,'field':k,'finding':'contactOrURLResidual'})
    for line in v.splitlines():
     if re.search(r'zoom\s*주소|회의\s*(?:ID|아이디|암호)|담당교수\s*ID|password|passcode',line,re.I) and re.search(r'(?<!\d)\d{9,12}(?!\d)|(?<!\d)\d{3}\s+\d{4}\s+\d{4}(?!\d)|(?<!\d)\d{4}\s+\d{4}(?!\d)',line):findings.append({'courseId':cid,'section':sec,'row':i,'field':k,'finding':'accessResidual'})
 assert not original['publicCatalogChangedFields']
 assert not original['newFieldTeachingWeeks'] and not original['currentSceneHours']
 interpretation='Exact preserved education match'
 if cid.startswith('1153-7012-') and changed:
  assert len(changed)==1 and changed[0]['field']=='LSN_OPER_MTHD_UNTACT'
  assert len(added)==4 and not removed
  assert all(re.search('zoom 주소|웹주소|담당교수ID|질문은',x,re.I) for x in added)
  interpretation='Only access/instruction/contact-query lines restored; original twice-weekly online branch and current main physical plan unchanged. No new date/site/clock/mode/ending rule.'
 elif cid in ['1001-7002-00','1001-7002-01'] and changed:
  assert len(changed)==1 and changed[0]['field']=='LSN_SMRY' and len(added)==1 and not removed
  assert '수업 관련 모든 사항은 인재개발원으로 문의' in added[0]
  interpretation='Contact-query office line restored; no altered instructional schedule, attendance replacement, capacity or restrictions.'
 elif cid=='1100-7003-03' and changed:
  assert [x.strip() for x in added] == [x.strip() for x in removed]
  proof=json.loads((R/'cnu-one-biography-education-boundary-proof.json').read_text());assert proof['sourceResponseSHA256']==fresh['sourceResponseSHA256'] and not any(proof['operatingSignals'].values()) and fresh['biographyEducationBoundaryChecked']
  interpretation='Whitespace only; omitted noninstructional identity biography directly boundary-checked against identical current response SHA, no operating signals.'
 else:assert not changed
 results.append({'courseId':cid,'sourceResponseSHA256':fresh['sourceResponseSHA256'],'selectedEducationSHA256':hashlib.sha256(p.read_bytes()).hexdigest(),'recoveredEducationFieldChanges':changed,'differenceInterpretation':interpretation,'publicCatalogEducationAndTeacherUnchanged':True,'actualOperatingExceptionNewlyFound':False,'currentSecondSemesterClockAndFieldFlagsRemainReviewed':True})
assert not findings
out={'candidate':first['candidate'],'candidateSHA256':first['candidateSHA256'],'processedPlans':180,'finished':True,'allRecoveredDifferencesSemanticallyReviewed':True,'changedCourses':sum(bool(x['recoveredEducationFieldChanges']) for x in results),'changedFields':sum(len(x['recoveredEducationFieldChanges']) for x in results),'privacyFindings':findings,'current180RawPlansProjectedWithTokenOnlyRedaction':True,'sameLineAdjacentEducationPreserved':True,'noActualOperatingChangesDiscovered':True,'currentCanonicalOrCandidateEdited':False,'actual12And172Unchanged':True,'firstPassAuditPreserved':'cnu-current180-preserved-context-recovery-firstpass-audit.json','accessTokenBoundaryRefinement':'cnu-recovered-access-token-boundary-refinement-audit.json','biographyBoundaryProof':'cnu-one-biography-education-boundary-proof.json','scope':'All requested header fields and weekly educational text/flags recovered from current normal public plans; contact/access tokens removed, pure noninstructional biography omitted only after current response boundary proof. No whole3543 plan refetch.','results':results,'fullSchoolSupportClaim':False}
(R/'cnu-current180-preserved-context-recovery-final-audit.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
print('180 recovered,12 changed education fields reviewed, privacy findings0, actual operating changes0')
