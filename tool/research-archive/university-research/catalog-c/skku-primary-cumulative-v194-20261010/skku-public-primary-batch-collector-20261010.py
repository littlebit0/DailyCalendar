"""Current observed anonymous attachment chain; no credentials, raw bodies, retries or bypass."""
import pathlib,sys,json,io,re,hashlib,datetime,time
P=pathlib.Path(__file__).parent;sys.path.insert(0,str(P.parent/'catalog-g'))
from audit_skku_public_operating_plans import SpacedPublic,params,education
from read_skku_published_office_plan import hwp_text,hwpx_text,doc_text,pptx_text
from pypdf import PdfReader
from docx import Document
out=pathlib.Path(sys.argv[1]);out.mkdir(exist_ok=True)
queue=json.load(open(P/'skku-held-batch-v191-20261010/all-held-source-processing-queue.json'))
queue=[x for x in queue if x['category'] in ['excerptOnlyNeedsFullPrimarySource','inlineOnlyNoPublicAttachmentCached']]
queue.sort(key=lambda x:(x['category']=='inlineOnlyNoPublicAttachmentCached',x['offeringCode']))
ledgerfile=out/'collection-progress.json';state=json.load(open(ledgerfile)) if ledgerfile.exists() else {'sourceOnly':True,'SDKExecuted':False,'productModified':False,'completionClaim':False,'rawBodiesSaved':False,'totalQueue':len(queue),'records':[],'startedAt':datetime.datetime.now().astimezone().isoformat()}
state.pop('stoppedAtExplicitRequest',None)
finished={r['offeringCode'] for r in state['records']};client=SpacedPublic('KO');stopfile=out/'STOP_REQUESTED';PRIVATEFILE=re.compile(r'명단|명부|연락처|출석부|성적|학생목록|수강생|조편성|조배정|실험조',re.I)
def save():
 state['updatedAt']=datetime.datetime.now().astimezone().isoformat();state['processedOfferings']=len(state['records']);state['remainingOfferings']=len(queue)-len(state['records']);ledgerfile.write_text(json.dumps(state,ensure_ascii=False,indent=2)+'\n')
def safe_text(raw):
 text,n=education(raw);kept=[];extra=0
 for line in text.splitlines():
  if re.search(r'회의\s*ID|meeting\s*ID|passcode|비밀번호|\bpassword\b|암호\s*[:=]|zoom\.[^\s]*[?&]|(?:phone|tel|문의|연락|전화).{0,15}\d{7,12}|\b0(?:10|11|16|17|18|19)\d{7,8}\b',line,re.I):extra+=1;continue
  kept.append(re.sub(r'https?://\S+','[connection URL suppressed]',line))
 return '\n'.join(kept),n+extra
prior_failed={'GEDM001-E6':'previousProtectedPublishedOfficeSourceNoRetry','USS2001-01':'previousEmptyFilePathNoRetry','MED2033-41':'previousMetadataPathFailureNoRetry','MED2037-41':'previousMetadataPathFailureNoRetry'}
for q in queue:
 key=q['offeringCode']
 if key in finished:continue
 if stopfile.exists():state['stoppedAtExplicitRequest']=True;save();break
 if key in prior_failed:
  state['records'].append({'offeringCode':key,'category':q['category'],'status':'previousPublicPathFailureSkippedWithoutRetry','reason':prior_failed[key],'originalBodyDownloadedCount':0,'newHumanWholeReadClaim':False});save();continue
 code,section=key.split('-');rec={'offeringCode':key,'category':q['category'],'normalObservedGuestChainOnly':True,'originalBodyDownloadedCount':0,'newHumanWholeReadClaim':False,'results':[]}
 try:
  files=client.post('/E_NHSSU900011P/selectFile2',params(code,section,'selectFile2','dsMyFile2'),'',save=False).get('dsMyFile2',[]);rec['observedCurrentFileRows']=files
  if not files:rec['status']='noPublishedAttachmentLocator';state['records'].append(rec);save();continue
  for fr in files:
   if (fr.get('GAESUL_YEAR'),fr.get('GAESUL_TERM'),fr.get('HAKSU_NO'),fr.get('BUNBAN'))!=('2026','20',code,section):rec['results'].append({'status':'identityMismatchHeld'});continue
   fileid=fr.get('BIZ_PLN_FILE_ID')
   if not fileid:continue
   ap={'FILE_ID':fileid,'_TRANSACTION_ID':'selectDsFile2','_FIRST_OUT_DS_NM':'dsFile2','_ALL_OUT_DS_NM':'dsFile2=dsFile2','_MENU_ID':'EXT_SCHEDULE','_PGM_ID':'NHSSU030840M'}
   attachments=client.post('/E_NAttachFile/selectAttachFiles',ap,'',save=False).get('dsFile2',[])
   if not attachments:rec['results'].append({'status':'publishedLocatorHasNoPublicFile'});continue
   for i,a in enumerate(attachments):
    name=a.get('FILE_NM','');ext=name.rsplit('.',1)[-1].lower();result={'observedPublicFileName':name,'extension':ext,'fileSequence':a.get('FILE_SEQ')}
    if PRIVATEFILE.search(name):result['status']='potentialPrivateRosterAttachmentNotDownloaded';rec['results'].append(result);continue
    if ext not in ['pdf','hwp','hwpx','docx','doc','pptx','txt']:result['status']='unsupportedFormatHeldWithoutBodyDownload';rec['results'].append(result);continue
    url='https://kingoinfo.skku.edu/gaia/E_Nsystem/fileDownload.do?attachFileId='+a['DOWNLOAD_FILE_ID']+'&sequenceNumber='+a['FILE_SEQ'];body=client.download(url);rec['originalBodyDownloadedCount']+=1;originalsha=hashlib.sha256(body).hexdigest();result['rawSHA256']=originalsha
    try:
     if ext=='pdf':
      pdf=PdfReader(io.BytesIO(body))
      if pdf.is_encrypted:raise ValueError('ProtectedPDFNoPasswordAttempt')
      raw='\n'.join(page.extract_text() or '' for page in pdf.pages);result['pages']=len(pdf.pages)
     elif ext=='hwp':raw=hwp_text(body)
     elif ext=='hwpx':raw=hwpx_text(body)
     elif ext=='doc':raw=doc_text(body)
     elif ext=='pptx':raw=pptx_text(body)
     elif ext=='txt':raw=body.decode('utf-8',errors='replace')
     else:
      doc=Document(io.BytesIO(body));raw='\n'.join([x.text for x in doc.paragraphs]+[' | '.join(c.text for c in row.cells) for tab in doc.tables for row in tab.rows])
     text,suppressed=safe_text(raw);raw=None;body=None
     if not text.strip():raise ValueError('EmptyEducationalTextHeld')
     filename=key.lower()+f'-attachment{i+1}-education-cache.json';d={'sourceOnly':True,'offeringCode':key,'normalObservedGuestChainOnly':True,'currentFileRow':fr,'publicAttachmentRow':{k:a.get(k) for k in ['FILE_ID','FILE_SEQ','FILE_NM','FILE_EXT_VAL','FILE_SIZE']},'sourceURL':url,'sha256':originalsha,'rawBytesSaved':False,'format':ext,'fullEducationalTextRead':False,'educationalTextExtractionSucceeded':True,'humanWholeReadClaim':False,'privacySuppressedLineCount':suppressed,'educationFullText':text,'potentialGlyphExtractionGap':text.count('\ufffd')>5 or len(text.strip())<50,'completeTextCacheFlagDoesNotProveSourceVisualCompleteness':True};(out/filename).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');result.update(status='privacySafeEducationalJSONExtracted',educationalFile=filename,characters=len(text));rec['results'].append(result)
    except Exception as e:body=None;result.update(status='protectedOrExtractionGapHeldWithoutRetry',failureType=type(e).__name__);rec['results'].append(result)
  rec['status']='normalPublicCurrentChainProcessedNoRetry'
 except Exception as e:
  rec.update(status='singlePublicPathFailureHeldNoRetry',failureType=type(e).__name__)
  if isinstance(e,RuntimeError) and ('protection' in str(e).lower() or 'html' in str(e).lower()):state['publicProtectionBoundaryStopped']=True;state['records'].append(rec);save();break
 state['records'].append(rec);save()
 if len(state['records'])%20==0:print('processed',len(state['records']),'remaining',state['remainingOfferings'],flush=True)
else:state['queueProcessingComplete']=True;save()
print('done',state['processedOfferings'],state['remainingOfferings'],flush=True)
