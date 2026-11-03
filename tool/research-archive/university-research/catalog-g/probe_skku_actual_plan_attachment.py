import json,time,io,re,urllib.request
from pypdf import PdfReader
from probe_skku_public_educational_plan import NoSavePublic,params,P
from skku_public import UA,REFERER
p=NoSavePublic('KO');output=[]
for code,section in [('BIZ2021','01'),('BIZ2021','03')]:
 item={'courseCode':code,'section':section,'attachments':[]}
 source=p.post('/E_NHSSU900011P/selectFile2',params(code,section,'selectFile2','dsMyFile2'),'',save=False).get('dsMyFile2',[]);time.sleep(.8)
 for row in source:
  fileid=row.get('BIZ_PLN_FILE_ID')
  if not fileid:continue
  q={'FILE_ID':fileid,'_TRANSACTION_ID':'selectDsFile2','_FIRST_OUT_DS_NM':'dsFile2','_ALL_OUT_DS_NM':'dsFile2=dsFile2','_MENU_ID':'EXT_SCHEDULE','_PGM_ID':'NHSSU030840M'}
  attachments=p.post('/E_NAttachFile/selectAttachFiles',q,'',save=False).get('dsFile2',[]);time.sleep(.8)
  for a in attachments:
   name=a.get('FILE_NM','');suffix=name.rsplit('.',1)[-1].lower()
   safe={'suffix':suffix}
   if suffix=='pdf':
    url='https://kingoinfo.skku.edu/gaia/E_Nsystem/fileDownload.do?attachFileId='+a['DOWNLOAD_FILE_ID']+'&sequenceNumber='+a['FILE_SEQ']
    body=p.op.open(urllib.request.Request(url,headers={'User-Agent':UA,'Referer':REFERER}),timeout=45).read();time.sleep(.8)
    reader=PdfReader(io.BytesIO(body));text='\n'.join(x.extract_text() or '' for x in reader.pages)
    safe.update({'pages':len(reader.pages),'currentYearAndTerm':bool(re.search(r'2026.*(?:2.*학기|Fall|Autumn)',text,re.I)), 'courseCodePresent':code in text, 'operatingContexts':[re.sub(r'\s+',' ',line)[:400] for line in text.splitlines() if re.search(r'휴강|보강|추석|모듈|module|온라인|offline|offline|flipped|remote|online|비대면',line,re.I) and not re.search(r'@|\d{2,3}-\d{3,4}-\d{4}|PER_ID|전화|연락',line,re.I)][:30]});body=None;text=None
   item['attachments'].append(safe)
 output.append(item)
(P/'skku-actual-plan-attachment-probe.json').write_text(json.dumps(output,ensure_ascii=False,indent=2));print(output)
