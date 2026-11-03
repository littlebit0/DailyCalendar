import re,pathlib,json
out=pathlib.Path(__file__).parent;base=pathlib.Path('lib/core/academic')
sources={}
for f in base.glob('*.dart'):
 text=f.read_text()
 for m in re.finditer(r'class\s+(\w+AcademicSource)\b',text):
  tail=text[m.end():];stop=re.search(r'\n(?:class|abstract class) ',tail);tail=tail[:stop.start()] if stop else tail
  ie=re.search(r'String get id\s*=>\s*([^;]+);',tail)
  if not ie:continue
  sources[m.group(1)]={'file':str(f),'idExpression':ie[1],'possibleIds':re.findall(r"'([^']+)'",ie[1]),'declaredAnnualText':bool(re.search(r'annual|연간|March.{0,5}February',tail,re.I)),'yearMinusOneFetch':bool(re.search(r'year\s*-\s*1',tail)),'monthLoopFetch':bool(re.search(r'for\s*\([^)]*(?:month|offset)',tail)), 'sourceLiveVerifiedThisPass':False}
prov=pathlib.Path('lib/core/di/app_providers.dart').read_text();block=prov[prov.index('sources: ['):prov.index('],\n    store:',prov.index('sources: ['))]
registry=[]
for m in re.finditer(r'(\w+AcademicSource)(?:\.(\w+))?\(([^)]*)\)',block):
 name,named,args=m.groups();e=sources[name];ids=e['possibleIds'];chosen=ids
 if len(ids)==2:
  if named:chosen=[{'knue': 'knue','kunsan':'kunsan','sunchon':'sunchon','changwon':'changwon'}[named]]
  else:chosen=[ids[0] if 'true' in args else ids[1]]
 registry += [{**e,'constructor':name,'named':named,'arguments':args,'registeredId':i} for i in chosen]
profile=pathlib.Path('lib/core/academic/academic_profile.dart').read_text();pbody=profile[profile.index('String? get academicSourceId'):profile.index('bool get timetableSupported')]
outputs=set(re.findall(r"(?:=>|\?|:)\s*'([a-z][a-z-]+)'",pbody));outputs|={'smu','dku','jnu'} # explicitly fallback to known integrated timetable University IDs
regids={e['registeredId'] for e in registry}
directory=pathlib.Path('lib/core/academic/university_directory.dart').read_text();dbody=directory[directory.index('bool get supportsAcademicFeatures'):directory.index('String get displayName')];supportids=set(re.findall(r"'institution:academyinfo:(\d+)'",dbody));profileinst=set(re.findall(r"'institution:academyinfo:(\d+)'",pbody))
data=json.load(open('assets/academic/universities.json'))
fixtures=list(pathlib.Path('test/fixtures/academic').glob('*'));existing=[]
for e in registry:
 id=e['registeredId'];aliases={'bu':['bu','baekseok'],'sunchon':['sunchon','scnu'],'changwon-geochang':['geochang'],'changwon-namhae':['namhae'],'dongguk-seoul':['dongguk-seoul','dongguk'],'dku':['dku','dankook'],'jnu':['jnu','chonnam'],'smu':['smu','sangmyung']}.get(id,[id])
 fs=[str(f) for f in fixtures if any(re.match(re.escape(alias)+r'(?:-|\.)',f.name) for alias in aliases)]
 existing.append({**e,'existingAcademicFixtures':fs,'fixtureYears':sorted({y for f in fs for y in re.findall(r'20\d\d',pathlib.Path(f).name)}),'wholeAnnualRawVerifiedThisPass':False,'coverageNote':'Existing source and fixture paths inspected only; parser execution/live completeness not performed.'})
missingdisplay=[{'institutionId':'institution:academyinfo:'+i,'schools':[r['name'] for r in data['universities'] if r.get('institutionId')=='institution:academyinfo:'+i]} for i in sorted(profileinst-supportids)]
report={'scope':'Static current registry/profile/directory + existing fixture provenance; no SDK/live completeness check','registeredInstances':len(registry),'registeredDistinctIds':len(regids),'profilePossibleOutputs':sorted(outputs),'profileOutputsNotRegistered':sorted(outputs-regids),'displayMissingForExplicitInstitutionSource':missingdisplay,'registrationPKNU':'Already fixed by root, registered at app_providers.dart:376; no edits made','annualSourceInventory':existing,'wholeSourceAnnualCompleteClaim':False,'productChanges':0,'sdkTestsBuildInstall':0}
(out/'registry-profile-source-receipt.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print({k:v for k,v in report.items() if k!='annualSourceInventory'})
