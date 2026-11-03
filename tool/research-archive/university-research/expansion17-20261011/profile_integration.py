import json
from pathlib import Path
p=Path(__file__).parent;root=Path.cwd();receipt=json.loads((p/'integration-receipt.json').read_text());enabled={x['university']for x in receipt['assets']}
keys={'inje':('0000164',['0000164','0000166'],'gimhae'),'hongik':('0000212',['0000212','0002949'],'seoul'),'wsu':('0000240',['0000240'],'unknown'),'iccu':('0000168',['0000168','0000167'],'songdo'),'ewha':('0000163',['0000163'],'unknown'),'eulji':('0000161',['0000161','0000162','0002911'],'seongnam'),'kentech':('0003139',['0003139'],'main'),'hansei':('0000201',['0000201'],'main'),'hyupsung':('0000207',['0000207'],'main'),'sungkyul':('0000131',['0000131'],'main'),'sunmoon':('0000129',['0000129'],'unknown'),'sangji':('0000119',['0000119'],'main'),'nambu':('0000216',['0000216'],'main'),'kangnam':('0000051',['0000051'],'main'),'konyang':('0000054',['0000054','0000055'],'nonsan'),'dju':('0000095',['0000095'],'main'),'pcu':('0000113',['0000113'],'main')}
f=root/'lib/core/academic/academic_profile.dart';s=f.read_text();branches=[];allowed=[];campuses=[]
for key in keys:
 if key not in enabled:continue
 institution,ids,default=keys[key]
 branches.append('    '+ ' ||\n    '.join([f"'institution:academyinfo:{institution}'",*[f"'academyinfo:{i}'"for i in ids]])+f" => '{key}',")
 allowed.append(f"      '{key}' => const ["+', '.join(f"'academyinfo:{i}'"for i in ids)+'],')
 if key=='inje':campuses.append("      ('inje', 'academyinfo:0000166') => null,")
 if key=='eulji':campuses.extend(["      ('eulji', 'academyinfo:0000161') => null,","      ('eulji', 'academyinfo:0002911') => 'uijeongbu',"])
 if key=='iccu':campuses.append("      ('iccu', 'academyinfo:0000168') => null,")
 if key=='hongik':campuses.append("      ('hongik', 'academyinfo:0002949') => 'sejong',")
 campuses.append(f"      ('{key}', _) => '{default}',")
s=s.replace('String? get timetableUniversity => switch (universityId) {','String? get timetableUniversity => switch (universityId) {\n'+'\n'.join(branches),1)
s=s.replace('final allowed = switch (timetableUniversity) {','final allowed = switch (timetableUniversity) {\n'+'\n'.join(allowed),1)
s=s.replace('return switch ((timetableUniversity, selectedCampusId)) {','return switch ((timetableUniversity, selectedCampusId)) {\n'+'\n'.join(campuses),1)
# A timetable does not constitute an annual calendar implementation.
if 'eulji' in enabled and "=> 'eulji'" not in s[s.index('String? get academicSourceId'):]:
 s=s.replace('String? get academicSourceId => switch (universityId) {',"String? get academicSourceId => switch (universityId) {\n    'institution:academyinfo:0000161' || 'academyinfo:0000161' || 'academyinfo:0000162' || 'academyinfo:0002911' => null,",1)
f.write_text(s)
labels={'inje':'인제대학교','hongik':'홍익대학교','wsu':'우송대학교','iccu':'인천가톨릭대학교','ewha':'이화여자대학교','eulji':'을지대학교','kentech':'한국에너지공과대학교','hansei':'한세대학교','hyupsung':'협성대학교','sungkyul':'성결대학교','sunmoon':'선문대학교','sangji':'상지대학교','nambu':'남부대학교','kangnam':'강남대학교','konyang':'건양대학교','dju':'대전대학교','pcu':'배재대학교'}
f=root/'lib/features/timetable/presentation/university_course_page.dart';s=f.read_text();s=s.replace("context.tr(switch (widget.university) {","context.tr(switch (widget.university) {\n"+'\n'.join(f"                              '{key}' => '{labels[key]}',"for key in keys if key in enabled),1);f.write_text(s)
(p/'profile-integration.json').write_text(json.dumps({'enabled':sorted(enabled),'identities':{k:keys[k]for k in enabled}},ensure_ascii=False,indent=2)+'\n')
print('Connected',sorted(enabled))
