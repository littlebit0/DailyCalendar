from pathlib import Path
import json,sys
cp=int(sys.argv[1]);B=Path('work/university-research');proof=json.loads((B/f'checkpoint{cp}-build-verification.json').read_text());audit=json.loads((B/f'checkpoint{cp}-current-packaged-coverage-audit.json').read_text());by={r['requestedName']:r for r in audit['universities']};p=Path('docs/UNIVERSITY_SUPPORT_STATUS_2026-10-06.json');d=json.loads(p.read_text())
for u in d['universities']:
 if u['requestedName'] not in by:continue
 r=by[u['requestedName']];t=u['timetable'];t['currentPackagedSnapshot']=r;t['testAppInstalledCheckpoint']=cp;t['currentPackageVerification']={'checkpoint':cp,'proof':str(B/f'checkpoint{cp}-build-verification.json'),'sharedTestsPassed':proof['sharedTestsPassed'],'sharedTestsSkipped':proof['sharedTestsSkipped'],'analyzer':'clean','macBuild':'succeeded','installedJsonCount':proof['verifiedJsonCount'],'appLaunched':False,'completionClaim':False};u['testAppInstalled']=f"checkpoint{cp};{proof['verifiedJsonCount']}source/built/installedJSONSHAequal;shared{proof['sharedTestsPassed']}PASS1skip/analyzer clean/Macbuild/signature/backup verified. No launch/UI/liveDrive/device/otherplatformacceptance."
 if u['requestedName'] in ['충남대','성균관대','경희대','삼육대','교통대','명지대','청주교대','대구과기원','창원대']:
  t.update(courses=r['courses'],scheduled=r['scheduleBearingOfferings'],plannedDatedMeetings=r['serializedMeetings'],sourceCheckpoint=cp,currentEvidence=[str(B/f'checkpoint{cp}-source-manifest.json'),str(B/f'checkpoint{cp}-build-verification.json')]);t['currentRemainingSummary']=f"Current packaged {r['courses']} offerings / {r['scheduleBearingOfferings']} schedule-bearing / {r['serializedMeetings']} serialized reservations; partial, whole operating support not verified."
 if u['requestedName']=='청주교대':
  t['verification']=f"checkpoint{cp} source/model/full-test/analyzer/Mac build and in-place installed asset/signature verification passed; one planned date only. No interactive acceptance or general school clock claim."
 t['remaining']=f"Current packaged {r['courses']} offerings / {r['scheduleBearingOfferings']} schedule-bearing / {r['serializedMeetings']} serialized reservations; partial, whole operating support not verified."
d.update(checkedAt='2026-10-09',installedMacTestCheckpoint=cp,completionClaim=False);p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
print('actual installed status recorded',cp)
