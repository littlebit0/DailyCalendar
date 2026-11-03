import pathlib,sys,json,io,hashlib,re
p=pathlib.Path(__file__).parent
sys.path.insert(0,str(p.parent.parent/'catalog-g'))
from audit_skku_public_operating_plans import SpacedPublic,params,education,PRIVATE
from pypdf import PdfReader
result={'sourceOnly':True,'offeringCode':'FTM2071-02','normalObservedGuestChainOnly':True,'rawBytesSaved':False,'SDKExecuted':False,'completionClaim':False}
try:
 client=SpacedPublic('KO')
 files=client.post('/E_NHSSU900011P/selectFile2',params('FTM2071','02','selectFile2','dsMyFile2'),'',save=False).get('dsMyFile2',[])
 assert len(files)==1
 fileid=files[0]['BIZ_PLN_FILE_ID']
 q={'FILE_ID':fileid,'_TRANSACTION_ID':'selectDsFile2','_FIRST_OUT_DS_NM':'dsFile2','_ALL_OUT_DS_NM':'dsFile2=dsFile2','_MENU_ID':'EXT_SCHEDULE','_PGM_ID':'NHSSU030840M'}
 a=client.post('/E_NAttachFile/selectAttachFiles',q,'',save=False).get('dsFile2',[])
 assert len(a)==1 and a[0]['FILE_NM'].lower().endswith('.pdf')
 assert not re.search(r'명단|명부|연락처|출석부|성적|학생목록',a[0]['FILE_NM'])
 url='https://kingoinfo.skku.edu/gaia/E_Nsystem/fileDownload.do?attachFileId='+a[0]['DOWNLOAD_FILE_ID']+'&sequenceNumber='+a[0]['FILE_SEQ']
 body=client.download(url);result['sha256']=hashlib.sha256(body).hexdigest();result['byteCount']=len(body);reader=PdfReader(io.BytesIO(body));assert not reader.is_encrypted;result['pages']=len(reader.pages);assert len(reader.pages)<=8
 raw='\n'.join(page.extract_text() or '' for page in reader.pages);body=None
 safe,n=education(raw);safe=re.sub(r'[^\n]*(?:https?://[^\s]*zoom\.|회의\s*ID|Meeting ID|암호\s*:|비밀번호\s*:|Passcode)[^\n]*','[meeting access details omitted]',safe,flags=re.I)
 result['privateLinesOmitted']=n;result['educationFullText']=safe;result['privacySuppressedLinesRecovered']=False;result['status']='normal public full educational PDF read; exact scope needs independent review';raw=None
except Exception as e:
 result['status']='normal public chain stopped without retry/bypass';result['failureType']=type(e).__name__
(p/'ftm2071-02-full-education.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(result['status'],result.get('pages'),result.get('privateLinesOmitted'))
