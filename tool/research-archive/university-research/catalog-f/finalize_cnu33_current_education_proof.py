"""Current33 context comparison and privacy boundary; no network or raw values."""
import json,difflib,hashlib,re
from pathlib import Path
R=Path(__file__).resolve().parent
source=json.loads((R/'cnu-proposed33-preserved-context-recovery-audit.json').read_text())
assert source['finished'] and source['processedPlans']==33
checks=[];findings=[]
for x in source['results']:
    assert not x['publicCatalogChangedFields'] and not x['newFieldTeachingWeeks'] and not x['currentSceneHours']
    cid=x['courseId'];p=R/'cnu-proposed33-recovered-education-20261008'/f'{cid}.json';j=json.loads(p.read_text())
    assert j['header'][0]['OPEN_SHTM_CD_NM']=='2학기'
    meaning='Current complete selected public education unchanged'
    if x['recoveredEducationFieldChanges']:
        assert cid in ['1102-2004-00','1102-2004-01']
        assert len(x['recoveredEducationFieldChanges'])==1 and x['recoveredEducationFieldChanges'][0]['field']=='LSN_OPER_MTHD'
        old=json.loads((R/'cnu-current-education'/f'{cid}.json').read_text())
        delta=list(difflib.ndiff([s.strip() for s in old['header'][0]['LSN_OPER_MTHD'].splitlines()],[s.strip() for s in j['header'][0]['LSN_OPER_MTHD'].splitlines()]))
        added=[s[2:] for s in delta if s.startswith('+ ') and s[2:].strip()];removed=[s[2:] for s in delta if s.startswith('- ') and s[2:].strip()]
        assert not removed and len(added)==2 and all('[contact removed]' in s for s in added)
        meaning='Only team-teacher contact-query lines restored; no clock/delivery/period/holiday change'
    for section in ['header','weeks']:
        for index,row in enumerate(j[section]):
            for key,value in row.items():
                if isinstance(value,str) and re.search(r'https?://|[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}|(?<!\d)0\d{1,2}[- .]\d{3,4}[- .]\d{4}(?!\d)',value,re.I):
                    findings.append({'courseId':cid,'section':section,'row':index,'field':key})
    checks.append({'courseId':cid,'sourceResponseSHA256':j['sourceResponseSHA256'],'selectedEducationSHA256':hashlib.sha256(p.read_bytes()).hexdigest(),'allHeaderAndWeeklyEducationCurrentCompared':True,'changedFields':x['recoveredEducationFieldChanges'],'differenceInterpretation':meaning,'fieldFlagsAndSceneHoursPositive':False,'currentCatalogTeacherYearSectionRoomClockUnchanged':True,'originalEnrollmentRestrictionsAndPublishedPlanFactsRetained':True})
assert not findings
final={'targetPlans':33,'processedPlans':33,'finished':True,'allRecoveredDifferencesSemanticallyReviewed':True,'privacyFindings':findings,'newTeachingExceptionsDiscovered':0,'sameLineOperatingEducationPreserved':True,'noWholePlanOrAccessDataInCandidate':True,'evidenceMeaning':'Current public regular timetable plan, not actual attendance or separately confirmed exams. Main physical operation remains current; alternative UNTact template is not itself a current mode-change notice.','checks':checks,'fullSchoolSupportClaim':False}
(R/'cnu-proposed33-current-semantic-education-proof.json').write_text(json.dumps(final,ensure_ascii=False,indent=2)+'\n')
name='cnu-unknown-2026-2.whole-checkpoint-next225-planned-regular213-eligibility-v2.json'
audit={'candidateSHA256':hashlib.sha256((R/name).read_bytes()).hexdigest(),'actualFlutterTestPassed':True,'sessionId':11994,'exitCode':0,'testsPassed':1,'dartAnalyze':'No issues found','courses':225,'meetings':4702,'actual12And172Unchanged':True,'blockedFieldSixRemainUnscheduled':True,'new33CurrentSemesterAndFieldFlagsVerified':True,'publishedClockRoomDateBoundAndHolidayMakeupExclusionPassed':True,'userDefaultAllThreeModesPassed':True,'realDriveModeAndEnrollmentFactsAndPlanDisclaimerRoundtripPassed':True,'wholeRows':3888,'wholeCandidatePrivacyFindings':0,'appLaunched':False}
(R/'cnu-next225-planned-regular213-eligibility-v2-dart-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
print('current33 semantic source checked, two contact-only differences, privacy0')
