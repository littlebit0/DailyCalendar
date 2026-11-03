import hashlib,json,os,pathlib,plistlib,shutil,subprocess
root=pathlib.Path.cwd()
installed=pathlib.Path('/Users/kimhwi/Applications/Daily Test.app')
built=pathlib.Path('/private/tmp/daily-flutter-build/macos/Build/Products/Debug/Daily Test.app')
out=root/'work/university-support-suspension-20261012'
def run(args):return subprocess.check_output(args,stderr=subprocess.STDOUT)
def info(p):return plistlib.loads((p/'Contents/Info.plist').read_bytes())
def entitlements(p):
 x=run(['codesign','-d','--entitlements',':-',str(p)])
 return plistlib.loads(x[x.index(b'<?xml'):])
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
log=(out/'mac-build.log').read_text()
assert '** BUILD SUCCEEDED **' in log
verification=json.loads((out/'verification-receipt.json').read_text())
assert verification['implementationComplete'] and verification['approvedScopeVerificationPassed']
assert verification['testsFailuresInScopeAfterCorrections']==0
old,new=info(installed),info(built)
for key in ['CFBundleIdentifier','CFBundleShortVersionString']:
 assert old[key]==new[key],key
assert new['CFBundleIdentifier']=='com.littlebit0.daily.test'
oldent,newent=entitlements(installed),entitlements(built)
for key in ['keychain-access-groups','com.apple.application-identifier','com.apple.developer.team-identifier','com.apple.security.application-groups']:
 assert oldent.get(key)==newent.get(key),key
assert newent.get('com.apple.developer.team-identifier')=='A6Y73X2ZLS'
run(['codesign','--verify','--deep','--strict',str(built)])
assetroot=pathlib.Path('Contents/Frameworks/App.framework/Versions/A/Resources/flutter_assets')
jsons={}
for file in [*(root/'assets/timetable').rglob('*.json'), *(root/'assets/academic').glob('*.json'), *(root/'assets/academic/logos').glob('*.png')]:
 rel=file.relative_to(root)
 assert sha(file)==sha(built/assetroot/rel),rel
 jsons[str(rel)]=sha(file)
removed=assetroot/'assets/academic/logos/institution-academyinfo-0000288.png'
assert not (built/removed).exists(),'Rejected corporate substitute must not remain bundled'
k=pathlib.Path('Contents/Frameworks/App.framework/Versions/A/App')
assert not (built/assetroot/'kernel_blob.bin').exists(), 'Profile must be AOT, not debug kernel'
oldkernel,newkernel=sha(installed/k),sha(built/k)
assert oldkernel != newkernel, 'Require freshly rebuilt suspension code'
assert b'_kDartVmSnapshot' in run(['nm','-g',str(built/k)]), 'Require AOT snapshot symbols'
backup=pathlib.Path('/private/tmp/daily-test-before-university-suspension-20261012.tar.gz')
if not backup.exists():
 run(['tar','-czf',str(backup),'-C',str(installed.parent),installed.name])
run(['gzip','-t',str(backup)])
run(['rsync','-a','--delete',str(built)+'/',str(installed)+'/'])
run(['codesign','--verify','--deep','--strict',str(installed)])
assert not (installed/removed).exists()
assert info(installed)==new
assert entitlements(installed)==newent
assert sha(installed/k)==newkernel
assert not (installed/assetroot/'kernel_blob.bin').exists()
for rel,digest in jsons.items():assert sha(installed/assetroot/rel)==digest
ls='/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'
run([ls,'-u',str(built)])
shutil.rmtree(built)
run([ls,'-f',str(installed)])
run(['mdimport',str(installed)])
receipt={
 'scope':'User stopped expansion;86 registered timetable schools temporarily unsupported;10 retained; academic and saved user schedules preserved',
 'build':'Mac profile/AOT via Debug test identity configuration; optimized native code; deployment14.0',
 'installedPath':str(installed),'bundleIdentifier':new['CFBundleIdentifier'],
 'version':new['CFBundleShortVersionString'],'signingTeam':'A6Y73X2ZLS',
 'signaturesVerified':True,'secureStorageEntitlementsUnchanged':True,
 'backup':str(backup),'appFrameworkHashBefore':oldkernel,'appFrameworkHashAfter':newkernel,'profileAOTVerified':True,'hardwareFPSMeasured':False,
 'timetableAcademicAndLogoSourceBuiltInstalledHashes':jsons,
 'generatedBuildAppUnregisteredAndRemoved':True,'appLaunched':False,
 'productionAppDataAccountsKeychainUntouched':True,
 'verification':{'combinedResult':json.loads((out/'verification-receipt.json').read_text())['verificationGroups'],'changedScopeAnalyzer':'no issues','receipt':'work/university-support-suspension-20261012/verification-receipt.json'},
 'dataPreserved':'Existing user data/accounts/keychain and original timetable source files unchanged',
 'universityExpansionCompletionClaim':False,
}
(out/'install-receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
print('Updated canonical Mac test app; source/built/installed timetable assets match; signature and identity verified; generated app removed.')
