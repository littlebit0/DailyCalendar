import pathlib,sys,json,hashlib,re,io
p=pathlib.Path(__file__).parent;sys.path.insert(0,str(p.parent.parent/'catalog-g'))
from audit_skku_public_operating_plans import SpacedPublic,params,education
from read_skku_published_office_plan import hwp_text
section=sys.argv[1] if len(sys.argv)>1 else '01'
result={'sourceOnly':True,'SDKExecuted':False,'rawBytesSaved':False,'offeringCode':'GELT012-'+section,'normalObservedGuestChainOnly':True,'completionClaim':False,'standaloneBlankTemplatesNotDownloaded':True,'educationPlanIncludesOwnBlankReportForm':True}
try:
 client=SpacedPublic('KO');files=client.post('/E_NHSSU900011P/selectFile2',params('GELT012',section,'selectFile2','dsMyFile2'),'',save=False).get('dsMyFile2',[]);assert len(files)==1
 q={'FILE_ID':files[0]['BIZ_PLN_FILE_ID'],'_TRANSACTION_ID':'selectDsFile2','_FIRST_OUT_DS_NM':'dsFile2','_ALL_OUT_DS_NM':'dsFile2=dsFile2','_MENU_ID':'EXT_SCHEDULE','_PGM_ID':'NHSSU030840M'};a=client.post('/E_NAttachFile/selectAttachFiles',q,'',save=False).get('dsFile2',[])
 result['observedAttachmentNames']=[x['FILE_NM'] for x in a];selected=[x for x in a if '강의계획서' in x['FILE_NM'] and not re.search(r'명부|명단|출석|성적',x['FILE_NM'])];assert len(selected)==1;item=selected[0];assert item['FILE_NM'].lower().endswith('.hwp');result['selectedEducationAttachmentName']=item['FILE_NM']
 body=client.download('https://kingoinfo.skku.edu/gaia/E_Nsystem/fileDownload.do?attachFileId='+item['DOWNLOAD_FILE_ID']+'&sequenceNumber='+item['FILE_SEQ']);result.update(sha256=hashlib.sha256(body).hexdigest(),byteCount=len(body));raw=hwp_text(body);body=None;safe,n=education(raw);safe,k=re.subn(r'[^\n]*(?:https?://[^\s]*zoom\.|회의\s*ID|Meeting ID|암호\s*:|비밀번호\s*:|Passcode|\b\d{2,3}\)\s*\d{3,4}-\d{4})[^\n]*','[contact/access details omitted]',safe,flags=re.I);raw=None;result.update(educationFullText=safe,privateLinesOmitted=n+k,fullEducationalTextRead=True,format='hwp',status='normal public full educational HWP read')
except Exception as e:result.update(status='normal observed chain stopped without bypass',failureType=type(e).__name__)
(p/('gelt012-'+section+'-full-education.json')).write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(result['status'],result.get('observedAttachmentNames'),result.get('privateLinesOmitted'))
