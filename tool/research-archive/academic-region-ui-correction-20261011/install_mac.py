import hashlib,json,os,pathlib,plistlib,shutil,subprocess
root=pathlib.Path.cwd()
installed=pathlib.Path('/Users/kimhwi/Applications/Daily Test.app')
built=pathlib.Path('/private/tmp/daily-flutter-build/macos/Build/Products/Debug/Daily Test.app')
out=root/'work/academic-region-ui-correction-20261011'
def run(args):return subprocess.check_output(args,stderr=subprocess.STDOUT)
def info(p):return plistlib.loads((p/'Contents/Info.plist').read_bytes())
def entitlements(p):
 x=run(['codesign','-d','--entitlements',':-',str(p)])
 return plistlib.loads(x[x.index(b'<?xml'):])
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
log=(out/'mac-build.log').read_text()
assert '** BUILD SUCCEEDED **' in log
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
for file in [*(root/'assets/timetable').glob('*.json'), *(root/'assets/academic').glob('*.json')]:
 rel=file.relative_to(root)
 assert sha(file)==sha(built/assetroot/rel),rel
 jsons[str(rel)]=sha(file)
k=assetroot/'kernel_blob.bin'
oldkernel,newkernel=sha(installed/k),sha(built/k)
assert newkernel!=oldkernel,'New region UI must have a different compiled kernel'
backup=pathlib.Path('/private/tmp/daily-test-before-academic-region-ui-correction-20261011.tar.gz')
assert not backup.exists(),'Avoid replacing existing backup'
run(['tar','-czf',str(backup),'-C',str(installed.parent),installed.name])
run(['gzip','-t',str(backup)])
run(['rsync','-a','--delete',str(built)+'/',str(installed)+'/'])
run(['codesign','--verify','--deep','--strict',str(installed)])
assert info(installed)==new
assert entitlements(installed)==newent
assert sha(installed/k)==newkernel
for rel,digest in jsons.items():assert sha(installed/assetroot/rel)==digest
ls='/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'
run([ls,'-u',str(built)])
shutil.rmtree(built)
run([ls,'-f',str(installed)])
run(['mdimport',str(installed)])
receipt={
 'scope':'Compact geographic buttons and uniform scale unlabeled islands; requested region merges and captions',
 'build':'Mac Debug success, test-only deployment14.0',
 'installedPath':str(installed),'bundleIdentifier':new['CFBundleIdentifier'],
 'version':new['CFBundleShortVersionString'],'signingTeam':'A6Y73X2ZLS',
 'signaturesVerified':True,'secureStorageEntitlementsUnchanged':True,
 'backup':str(backup),'kernelHashBefore':oldkernel,'kernelHashAfter':newkernel,
 'timetableSourceBuiltInstalledJsonHashes':jsons,
 'generatedBuildAppUnregisteredAndRemoved':True,'appLaunched':False,
 'productionAppDataAccountsKeychainUntouched':True,
 'verification':{'uniqueRelatedTestsPassed':24,'changedScopeAnalyzer':'no issues','receipt':'work/academic-region-ui-correction-20261011/verification-receipt.json'},
 'dataPreserved':'Existing academic/calendar/timetable source JSON unchanged; one new sourced geographic selector asset',
 'universityExpansionCompletionClaim':False,
}
(out/'install-receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
print('Updated canonical Mac test app; source/built/installed timetable assets match; signature and identity verified; generated app removed.')
