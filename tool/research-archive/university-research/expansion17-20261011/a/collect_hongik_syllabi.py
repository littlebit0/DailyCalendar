import requests,json,pathlib,urllib.parse,time,xml.etree.ElementTree as E
P=pathlib.Path(__file__).parent;d=json.load(open(P/'hongik-syllabus-network.json'));r=next(r for r in d if r['url'].endswith('/service'));payload=dict(urllib.parse.parse_qsl(r['postData']));payload.pop('html5_uuid',None)
held=json.load(open(P/'hongik-seoul-2026-2.json'))['heldRows'];reports={}
for row in held:
 if row['reason'].startswith('official'):continue
 code,section=row['code'].split('-');payload['mrd_param']=f'/rmmldistributed /rfn [https://rd.hongik.ac.kr/DataServer/rdagent.jsp] /rv yy[2026] hakgi[2] haksu[{code}] bunban[{section}]'
 z=requests.post(r['url'],data=payload,timeout=30);name=f'hongik-syllabus-{code}-{section}.mml';P.joinpath(name).write_text(z.text)
 try:root=E.fromstring(z.text);ts=[x.text or ''for x in root.iter('TL')];reports[row['code']]={'status':z.status_code,'file':name,'texts':ts}
 except Exception as error:reports[row['code']]={'status':z.status_code,'file':name,'error':str(error)}
 print(row['code'],z.status_code,len(z.content),flush=True);time.sleep(.25)
P.joinpath('hongik-syllabi-texts.json').write_text(json.dumps(reports,ensure_ascii=False,indent=2))
