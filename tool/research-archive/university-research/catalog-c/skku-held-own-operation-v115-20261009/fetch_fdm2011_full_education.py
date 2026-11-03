import pathlib,sys,json,io,re,hashlib
p=pathlib.Path(__file__).parent;sys.path.insert(0,str(p.parent.parent/'catalog-g'))
from audit_skku_public_operating_plans import SpacedPublic,params,education
from pypdf import PdfReader
key='FDM2011-01';client=SpacedPublic('KO');ledger={'sourceOnly':True,'offeringCode':key,'normalObservedGuestOnly':True,'SDKExecuted':False,'completionClaim':False,'originalRawBytesSaved':False,'files':[]}
try:
 q=params('FDM2011','01','selectFile2','dsMyFile2');files=client.post('/E_NHSSU900011P/selectFile2',q,'',save=False).get('dsMyFile2',[]);ledger['actualCurrentMetadataQuery']=q;ledger['actualObservedCurrentFileRows']=files
 for f in files:
  aq={'FILE_ID':f['BIZ_PLN_FILE_ID'],'_TRANSACTION_ID':'selectDsFile2','_FIRST_OUT_DS_NM':'dsFile2','_ALL_OUT_DS_NM':'dsFile2=dsFile2','_MENU_ID':'EXT_SCHEDULE','_PGM_ID':'NHSSU030840M'};attachments=client.post('/E_NAttachFile/selectAttachFiles',aq,'',save=False).get('dsFile2',[])
  for a in attachments:
   if re.search(r'명단|명부|연락처|출석부|성적|학생목록',a['FILE_NM']):ledger['files'].append({'privateRosterNameFlagSkipped':True});continue
   if not a['FILE_NM'].lower().endswith('.pdf'):ledger['files'].append({'unrequestedFormatSkipped':True});continue
   url='https://kingoinfo.skku.edu/gaia/E_Nsystem/fileDownload.do?attachFileId='+a['DOWNLOAD_FILE_ID']+'&sequenceNumber='+a['FILE_SEQ'];rawbody=client.download(url);r={'sourceOnly':True,'offeringCode':key,'normalObservedGuestChainOnly':True,'rawBytesSaved':False,'SDKExecuted':False,'completionClaim':False,'sourceURL':url,'observedPublicFileName':a['FILE_NM'],'currentFileRow':f,'sha256':hashlib.sha256(rawbody).hexdigest(),'byteCount':len(rawbody),'format':'pdf'};reader=PdfReader(io.BytesIO(rawbody));text='\n'.join(page.extract_text(extraction_mode='layout') or '' for page in reader.pages);rawbody=None;r['pages']=len(reader.pages);r['fullEducationalTextRead']=True
   names=[]
   for role in re.findall(r'(?im)^\s*(?:Instructor|Professor|담당교수)\s*[:：]\s*([^\n]+)',text):
    name=re.split(r'(?i)email|e-mail|phone|tel:|mailto|https?://|\(|[A-Za-z0-9._%+-]+@|\d{2,3}[-)]',role,1)[0].strip(' ,;')
    if name and re.fullmatch(r'[A-Za-z가-힣\s.,\-’\']{1,80}',name):names.append(name)
   r['ownPrintedEducationalInstructorNames']=names;r['safeRoleLabelExtractionBeforeContactSuppression']=True;safe,n=education(text);safe=re.sub(r'https?://\S+','[connection URL suppressed]',safe);safe=re.sub(r'[^\n]*(?:회의\s*ID|Meeting ID|암호\s*:|비밀번호\s*:|Passcode)[^\n]*','[meeting access details omitted]',safe,flags=re.I);r['educationFullText']=safe;r['privateLinesOmitted']=n;r['status']='normal public full educational PDF read; actual scope review pending';name=f'fdm2011-01-attachment{len(ledger["files"])+1}-full-education.json';(p/name).write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n');ledger['files'].append({'educationalFile':name,'rawSHA256':r['sha256'],'sourceURL':url});text=None
 ledger['status']='bounded observed current public chain finished'
except Exception as e:ledger['status']='stopped without retry/bypass';ledger['failureType']=type(e).__name__
(p/'current-multiple-public-attachment-source.json').write_text(json.dumps(ledger,ensure_ascii=False,indent=2)+'\n');print(ledger['status'],len(ledger['files']))
