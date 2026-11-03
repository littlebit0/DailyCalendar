import pathlib,sys,json,io,hashlib,re
p=pathlib.Path(__file__).parent
sys.path.insert(0,str(p.parent.parent/'catalog-g'))
from audit_skku_public_operating_plans import SpacedPublic,params,education,PRIVATE
from pypdf import PdfReader
result={'sourceOnly':True,'offeringCode':'IKS3027-01','normalObservedGuestChainOnly':True,'rawBytesSaved':False,'SDKExecuted':False,'completionClaim':False}
try:
 client=SpacedPublic('KO')
 files=client.post('/E_NHSSU900011P/selectFile2',params('IKS3027','01','selectFile2','dsMyFile2'),'',save=False).get('dsMyFile2',[])
 assert len(files)==1
 fileid=files[0]['BIZ_PLN_FILE_ID']
 q={'FILE_ID':fileid,'_TRANSACTION_ID':'selectDsFile2','_FIRST_OUT_DS_NM':'dsFile2','_ALL_OUT_DS_NM':'dsFile2=dsFile2','_MENU_ID':'EXT_SCHEDULE','_PGM_ID':'NHSSU030840M'}
 a=client.post('/E_NAttachFile/selectAttachFiles',q,'',save=False).get('dsFile2',[])
 assert len(a)==1
 assert len(a)==1 and a[0]['FILE_NM'].lower().endswith('.docx')
 assert not re.search(r'명단|명부|연락처|출석부|성적|학생목록',a[0]['FILE_NM'])
 url='https://kingoinfo.skku.edu/gaia/E_Nsystem/fileDownload.do?attachFileId='+a[0]['DOWNLOAD_FILE_ID']+'&sequenceNumber='+a[0]['FILE_SEQ']
 result['currentFileRow']=files[0];result['observedAttachmentRows']=a;result['sourceURL']=url;body=client.download(url);result['sha256']=hashlib.sha256(body).hexdigest();result['byteCount']=len(body);
 from docx import Document
 raw='\n'.join([x.text for x in Document(io.BytesIO(body)).paragraphs]+[' | '.join(c.text for c in r.cells) for tab in Document(io.BytesIO(body)).tables for r in tab.rows])
 body=None;result['format']='docx';result['fullEducationalTextRead']=True

 candidates=re.findall(r'(?im)^\s*(?:Instructor|Professor|담당교수)\s*[:：]\s*([^\n]+)',raw)
 role_names=[]
 for value in candidates:
  name=re.split(r'(?i)email|e-mail|phone|tel:|mailto|https?://|\(|[A-Za-z0-9._%+-]+@|\d{2,3}[-)]',value,1)[0].strip(' ,;')
  if name and re.fullmatch(r'[A-Za-z가-힣\s.,\-’\']{1,80}',name):role_names.append(name)
 result['ownPrintedEducationalInstructorNames']=role_names
 result['safeRoleLabelExtractionBeforeContactSuppression']=True
 safe,n=education(raw);safe=re.sub(r'https?://\S+','[connection URL suppressed]',safe);safe=re.sub(r'[^\n]*(?:https?://[^\s]*zoom\.|회의\s*ID|Meeting ID|암호\s*:|비밀번호\s*:|Passcode)[^\n]*','[meeting access details omitted]',safe,flags=re.I)
 safe,k=re.subn(r'[^\n]*\b\d{2,3}\)\s*\d{3,4}-\d{4}[^\n]*','[public office contact omitted]',safe);result['privateLinesOmitted']=n+k;result['educationFullText']=safe;result['privacySuppressedLinesRecovered']=False;result['status']='normal public full educational PDF read; exact scope needs independent review';raw=None
except Exception as e:
 result['status']='normal public chain stopped without retry/bypass';result['failureType']=type(e).__name__
(p/'iks3027-01-full-education.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(result['status'],result.get('format'),result.get('privateLinesOmitted'))
