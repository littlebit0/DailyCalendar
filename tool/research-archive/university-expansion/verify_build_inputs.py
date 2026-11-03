import hashlib
import json
import zipfile
from pathlib import Path

out = Path(__file__).resolve().parent
root = out.parents[1]
baseline = json.loads((out / 'build-source-manifest.json').read_text())
changed = [name for name, digest in baseline.items()
           if hashlib.sha256((root / name).read_bytes()).hexdigest() != digest]
if changed:
    raise RuntimeError('Build source changed: ' + ', '.join(changed))
bundles = {
    'macos': root / 'build/macos/Build/Products/Debug/Daily Test.app/Contents/Frameworks/App.framework/Resources/flutter_assets',
    'ios': Path.home() / 'Library/Developer/Xcode/DerivedData/Runner-erkgopnohejsmsejvraojecbsyqk/Build/Products/Debug-iphonesimulator/Runner.app/Frameworks/App.framework/flutter_assets',
}
assets = {name: digest for name, digest in baseline.items()
          if name.startswith('assets/') and Path(name).suffix in ('.json', '.png')}
report = {'sourceFiles': len(baseline), 'bundledAssetsPerPlatform': len(assets), 'verified': []}
for platform, bundle in bundles.items():
    for name, digest in assets.items():
        if hashlib.sha256((bundle / name).read_bytes()).hexdigest() != digest:
            raise RuntimeError(platform + ' asset mismatch: ' + name)
    report['verified'].append(platform)
with zipfile.ZipFile(root / 'build/app/outputs/flutter-apk/app-debug.apk') as apk:
    for name, digest in assets.items():
        if hashlib.sha256(apk.read('assets/flutter_assets/' + name)).hexdigest() != digest:
            raise RuntimeError('Android asset mismatch: ' + name)
report['verified'].append('android')
(out / 'build-input-verification.json').write_text(json.dumps(report, indent=2))
print(json.dumps(report))
