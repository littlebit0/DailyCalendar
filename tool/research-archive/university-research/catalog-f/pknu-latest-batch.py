import subprocess,json,time,xml.etree.ElementTree as E
from pathlib import Path
r=Path(__file__).parent;out=r/'pknu-latest';out.mkdir(exist_ok=True);departments=json.loads((r/'pknu-current-departments.json').read_text());combined={};errors=[]
for i,dept in enumerate(departments):
 name='pknu-latest/'+dept;p=r/(name+'.xml')
 if not p.exists():
  args={'YY':'2026','SHTM_CD':'U0003002','UNIV_GRSC_CLSF':'','COLG_CD':'','OPEN_SUST_MJ_CD':dept,'SBJT_NM':'','STAFF_NM':'','SBJ_FG':''}
  q=subprocess.run(['python3',str(r/'pknu-read-query.py'),name,'LtPdocInq.findLtPdocInq',json.dumps(args)],capture_output=True,text=True)
  time.sleep(.25)
 try:
  root=E.parse(p);error=root.find('.//{*}Parameter[@id="ErrorCode"]')
  if error is None or error.text!='0':raise ValueError('Non-success response')
  rows=[{x.attrib['id']:x.text for x in row} for row in root.findall('.//{*}Row')]
  for x in rows:
   if x['UNIV_GRSC_CLSF']=='학부':combined[x['COURSE_NO']+'-'+x['DCLSS_NO']]=x
 except Exception as e:errors.append({'dept':dept,'error':str(e)})
 if i%15==0:print(i+1,'/',len(departments),'undergraduate',len(combined),'errors',len(errors),flush=True)
(r/'pknu-latest-rows.json').write_text(json.dumps(list(combined.values()),ensure_ascii=False,indent=2));(r/'pknu-latest-audit.json').write_text(json.dumps({'departments':len(departments),'uniqueUndergraduate':len(combined),'errors':errors,'completeAppSupportVerified':False},ensure_ascii=False,indent=2));print('DONE',len(combined),len(errors),flush=True)
