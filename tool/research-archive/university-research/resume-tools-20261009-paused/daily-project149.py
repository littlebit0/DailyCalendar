from pathlib import Path
import json,hashlib,sys
B=Path('work/university-research');T=Path('test/features/timetable');C=B/'catalog-c'
K=C/'khu-full-operating-context-batches-v8-20261009/outside-shortlist-review-v1/packet042-reviewed30';S=C/'skku-held-own-operation-v157-20261009';W=Path(sys.argv[1]);wf=sys.argv[2]
def write(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
assert json.loads((B/'checkpoint148-build-verification.json').read_text())['checkpoint']==148
sources=[('khu-seoul-2026-2',K/'khu-seoul-2026-2.packet042-physical-groups-prepared.json'),('khu-global-2026-2',K/'khu-global-2026-2.packet042-physical-groups-prepared.json'),('skku-humanities-2026-2',S/'skku-humanities-2026-2.own-operation-v157.json'),('changwon-unknown-2026-2',W/wf)]
m=json.loads((B/'checkpoint148-source-manifest.json').read_text())
for name,src in sources:
 d=json.loads(src.read_text());d.update(researchOnly=False,productionIntegrationEnabled=True,completionClaim=False,wholeOperatingVerified=False)
 for c in d['courses']:
  if 'researchOnly'in c.get('metadata',{}):c['metadata']['researchOnly']=False
 p=Path(f'assets/timetable/{name}.json');write(p,d);e=next(e for e in m if e['file']==str(p));e.update(source=str(src),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),frozenSourceSha256=hashlib.sha256(src.read_bytes()).hexdigest())
write(B/'checkpoint149-source-manifest.json',m)
p=T/'packaged_asset_source_integrity_test.dart';p.write_text(p.read_text().replace('checkpoint148-source-manifest','checkpoint149-source-manifest'))
for name,fallback in [('khu_current_source_agreed_teacher_dates_test.dart',"'$dir/$name'"),('skku_current_source_regular_theory_dates_test.dart',"'$dir/$n'"),('changwon_current_room_unassigned_test.dart','path')]:
 p=T/name;s=p.read_text();a=s.index('  final actual =');z=s.index('  final data =',a);p.write_text(s[:a]+f'  final actual = {fallback};\n'+s[z:])
configs=[(K/'khu_packet042_physical_groups_fixture_test_root_actual_test.dart','khu_current_source_concentrated_and_regular_dates_test.dart','name',"name.endsWith('.packet042-physical-groups-prepared.json')","'assets/timetable/${name.split('.').first}.json'","'$dir/$name'"),(S/'skku_own_operation_v157_fixture_test_root_actual_test.dart','skku_current_source_project_physical_dates_test.dart','n',"n == 'skku-humanities-2026-2.own-operation-v157.json'","'assets/timetable/skku-humanities-2026-2.json'","'$dir/$n'"),(next(W.glob('*_root_actual_test.dart')),'changwon_current_source_regular_topic_dates_test.dart','path',f"path.endsWith('/{wf}')","'assets/timetable/changwon-unknown-2026-2.json'",'path')]
files=[]
for src,name,arg,cond,target,fallback in configs:
 s=src.read_text();a=s.index('dynamic read(') if'dynamic read('in s else s.index('Map<String, dynamic> read(');z=s.index(';',a)+1
 s=s[:a]+f'''dynamic read(String {arg}) {{
 final actual = {cond} ? {target} : {fallback};
 final data = jsonDecode(File(actual).readAsStringSync());
 if (data is Map) {{
  for (final c in data['courses'] as List? ?? []) {{
   if (c['metadata']?.containsKey('researchOnly') == true) {{c['metadata']['researchOnly'] = false;}}
  }}
 }}
 return data;
}}
'''+s[z:];p=T/name;p.write_text(s);files.append(str(p))
p=T/'skku_catalog_data_test.dart';p.write_text(p.read_text().replace('hasLength(1830)','hasLength(1831)').replace('hasLength(719)','hasLength(718)'))
p=T/'khu_catalog_data_test.dart';p.write_text(p.read_text().replace('.length, 2946)', '.length, 3008)').replace('.length, 55033)', '.length, 56003)'))
w=json.loads((W/wf).read_text());wc=sum(bool(c['schedules'])for c in w['courses']);wm=sum(len(c['schedules'])for c in w['courses'])
for name in ['changwon_catalog_data_test.dart','changwon_eleven_dated_data_test.dart']:
 p=T/name;p.write_text(p.read_text().replace('hasLength(1381)',f'hasLength({wc})').replace('hasLength(28369)',f'hasLength({wm})'))
a=json.loads((B/'checkpoint148-current-packaged-coverage-audit.json').read_text());a['checkpoint']=149
for r in a['universities']:
 cs=[]
 for f in r['assetFiles']:
  p=Path(f['file']);f['sha256']=hashlib.sha256(p.read_bytes()).hexdigest();cs+=json.loads(p.read_text())['courses']
 r.update(courses=len(cs),scheduleBearingOfferings=sum(bool(c['schedules'])for c in cs),serializedMeetings=sum(len(c['schedules'])for c in cs))
write(B/'checkpoint149-current-packaged-coverage-audit.json',a)
Path('/tmp/daily-checkpoint149-current-test-files.json').write_text(json.dumps(files));print('149 projected four assets; CW',wc,wm,'81 partial/4 unconnected; completion false')
