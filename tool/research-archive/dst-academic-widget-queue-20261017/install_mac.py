from pathlib import Path
import hashlib,json,plistlib,shutil,subprocess,datetime
root=Path.cwd();out=root/'work/dst-academic-widget-queue-20261017'
old=Path('/Users/kimhwi/Applications/Daily Test.app')
built=Path('/private/tmp/daily-flutter-build/macos/Build/Products/Debug/Daily Test.app')
def run(args): return subprocess.check_output(args,stderr=subprocess.STDOUT)
def info(p): return plistlib.loads((p/'Contents/Info.plist').read_bytes())
def ent(p):
 x=run(['codesign','-d','--entitlements',':-',str(p)])
 return plistlib.loads(x[x.index(b'<?xml'):])
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert '** BUILD SUCCEEDED **' in (out/'mac-build.log').read_text()
assert 'No issues found!' in (out/'analysis.log').read_text()
for name in ['tests.log']:
 assert 'All tests passed!' in (out/name).read_text()
a,b=info(old),info(built);e,f=ent(old),ent(built)
assert a['CFBundleIdentifier']==b['CFBundleIdentifier']=='com.littlebit0.daily.test'
assert a['CFBundleShortVersionString']==b['CFBundleShortVersionString']=='4.0.0'
for key in ['keychain-access-groups','com.apple.application-identifier','com.apple.developer.team-identifier','com.apple.security.application-groups']:
 assert e.get(key)==f.get(key),key
run(['codesign','--verify','--deep','--strict',str(built)])
assets=Path('Contents/Frameworks/App.framework/Versions/A/Resources/flutter_assets')
hashes={}
for folder in ['assets/academic','assets/timetable']:
 for file in (root/folder).rglob('*'):
  if file.is_file():
   rel=file.relative_to(root);digest=sha(file)
   assert sha(built/assets/rel)==digest,rel
   assert sha(old/assets/rel)==digest,rel
   hashes[str(rel)]=digest
framework=Path('Contents/Frameworks/App.framework/Versions/A/App')
assert not (built/assets/'kernel_blob.bin').exists()
assert sha(old/framework)!=sha(built/framework),'Require new AOT code'
assert b'_kDartVmSnapshot' in run(['nm','-g',str(built/framework)])
(out/'backups').mkdir(exist_ok=True)
backup=(out/'backups')/('daily-test-before-dst-academic-widget-queue-'+datetime.datetime.now().strftime('%Y%m%dT%H%M%S')+'.tar.gz')
subprocess.run(['tar','-czf',str(backup),'-C',str(old.parent),old.name],check=True)
run(['gzip','-t',str(backup)])
try:
 run(['rsync','-a','--delete',str(built)+'/',str(old)+'/'])
 run(['codesign','--verify','--deep','--strict',str(old)])
 assert info(old)==b and ent(old)==f
 assert sha(old/framework)==sha(built/framework)
 for rel,digest in hashes.items(): assert sha(old/assets/rel)==digest
except BaseException:
 run(['tar','-xzf',str(backup),'-C',str(old.parent)])
 raise
receipt={'installedPath':str(old),'bundleIdentifier':b['CFBundleIdentifier'],'version':b['CFBundleShortVersionString'],'backup':str(backup),'signatureVerified':True,'secureEntitlementsPreserved':True,'AOTProfileBuild':True,'assetHashesPreserved':hashes,'installedFrameworkSha256':sha(old/framework),'appLaunched':False,'productionDataAccountsKeychainUntouched':True,'universityWorkResumed':False}
ls='/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'
run([ls,'-u',str(built)]);shutil.rmtree(built);run([ls,'-f',str(old)]);run(['mdimport',str(old)])
(out/'install-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
print('Canonical Mac test app updated; identity, signature, secure entitlements and assets verified; no launch.')
