from pathlib import Path
import base64,os,subprocess
root=Path.cwd();out=root/'work/dst-academic-widget-queue-20261017'
config=root/'macos/Flutter/ephemeral/Flutter-Generated.xcconfig'
defines=next((x.split('=',1)[1] for x in config.read_text().splitlines() if x.startswith('DART_DEFINES=')), '')
endpoint=None
for encoded in defines.split(','):
 try: decoded=base64.b64decode(encoded).decode()
 except Exception: continue
 if decoded.startswith('DAILY_ANALYTICS_ENDPOINT='): endpoint=decoded
# The generated config and the installed app both carry no analytics endpoint
# (Dot-suspension build); keep it unchanged rather than inventing a value.
print('analytics endpoint in build config:', bool(endpoint))
env=dict(os.environ,FLUTTER_ROOT=str(root/'development/flutter-sdk'),PUB_CACHE=str(root/'development/pub-cache'))
with (out/'mac-build.log').open('w') as log:
 subprocess.run(['xcodebuild','-workspace','macos/Runner.xcworkspace','-scheme','Runner','-disableAutomaticPackageResolution','-onlyUsePackageVersionsFromResolvedFile','-configuration','Debug','-destination','platform=macOS','-derivedDataPath','build/macos','MACOSX_DEPLOYMENT_TARGET=14.0','FLUTTER_BUILD_MODE=profile','SWIFT_OPTIMIZATION_LEVEL=-O','GCC_OPTIMIZATION_LEVEL=s','ENABLE_NS_ASSERTIONS=NO','MTL_ENABLE_DEBUG_INFO=NO','CURRENT_PROJECT_VERSION=4.0.0','FLUTTER_BUILD_NUMBER=4.0.0','MARKETING_VERSION=4.0.0','build'],env=env,stdout=log,stderr=subprocess.STDOUT,check=True)
print('Mac optimized profile build succeeded; no launch.')
