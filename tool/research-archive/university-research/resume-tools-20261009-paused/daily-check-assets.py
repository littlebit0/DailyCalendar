import json,hashlib,plistlib,subprocess,sys,re
from pathlib import Path
cp=int(sys.argv[1]);stage=sys.argv[2]
b=Path('build/macos/Build/Products/Debug/Daily Test.app') if stage=='built' else Path('/Users/kimhwi/Applications/Daily Test.app')
assert plistlib.loads((b/'Contents/Info.plist').read_bytes())['CFBundleIdentifier']=='com.littlebit0.daily.test'
subprocess.run(['codesign','--verify','--deep','--strict',str(b)],check=True)
def hashes(p):return {str(f.relative_to(p)):hashlib.sha256(f.read_bytes()).hexdigest()for f in p.rglob('*.json')}
x=hashes(Path('assets/timetable'));z=b/'Contents/Frameworks/App.framework/Resources/flutter_assets/assets/timetable';expected=len(json.loads(Path('assets/timetable/catalog.json').read_text()))+2;assert len(x)==expected and x==hashes(z)
proof=Path(f'/tmp/daily-checkpoint{cp}-source-build-hashes.json')
if stage=='built':
 assert '** BUILD SUCCEEDED **' in Path(f'/tmp/daily-checkpoint{cp}-build.log').read_text()
 proof.write_text(json.dumps(x,indent=2)+'\n')
else:
 assert x==json.loads(proof.read_text())
 testlog=Path(f'/tmp/daily-checkpoint{cp}-full-tests-repeat.log');testlog=testlog if testlog.exists() else Path(f'/tmp/daily-checkpoint{cp}-full-tests.log')
 t=testlog.read_text();assert 'All tests passed!' in t
 counts=re.findall(r'\+(\d+) ~([0-9]+): All tests passed!',t);assert counts
 analyzelog=Path(f'/tmp/daily-checkpoint{cp}-analyze-repeat.log');analyzelog=analyzelog if analyzelog.exists() else Path(f'/tmp/daily-checkpoint{cp}-analyze.log')
 assert 'No issues found!' in analyzelog.read_text()
 backup=f'/private/tmp/daily-test-checkpoint{cp}-before-update.tar.gz';subprocess.run(['gzip','-t',backup],check=True)
 d={'checkpoint':cp,'completionClaim':False,'academicCurrentSources':85,'timetablePartialConnected':len(json.loads(Path(f'work/university-research/checkpoint{cp}-current-packaged-coverage-audit.json').read_text())['universities']),'timetableUnconnected':85-len(json.loads(Path(f'work/university-research/checkpoint{cp}-current-packaged-coverage-audit.json').read_text())['universities']),'verifiedJsonCount':len(x),'hashes':x,'sharedTestsPassed':int(counts[-1][0]),'sharedTestsSkipped':int(counts[-1][1]),'analyzer':'clean','macBuild':'succeeded','builtAndInstalledSignatures':'deep strict verified','backup':backup,'backupExitCode':0,'appLaunched':False,'liveDriveVerified':False,'accountChanged':False,'otherPlatformVerified':False}
 Path(f'work/university-research/checkpoint{cp}-build-verification.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
print(f'checkpoint{cp}: {stage} signature/identity and{len(x)} source JSON verified')
