"""Single-owner targeted public education repair; canonical audit is untouched."""
import argparse,collections,datetime,io,json,os,re,zipfile
from concurrent.futures import ThreadPoolExecutor,wait,FIRST_COMPLETED
from pathlib import Path
import audit_skku_public_operating_plans as old
from skku_inline_private_education_filter import filter_education,education,REMAINING_PRIVATE,PHONE,EMAIL,CONTACT_EXTENSION,CONTACT_LOCAL_PHONE
from read_skku_published_office_plan import hwp_text,hwpx_text,pptx_text,doc_text,ProtectedPublishedOfficeSource
from pypdf import PdfReader
P=Path(__file__).resolve().parent
TARGET_FILE=P/'skku-inline-privacy-education-repair-audit.json'
LOCK=P/'skku-inline-privacy-education-repair.lock'
original_text_evidence=old.text_evidence

def text_evidence(text,code,section,professor):
 safe,masked,lost=filter_education(text)
 result=original_text_evidence(safe,code,section,professor)
 result.update({'privacyMaskedTokenCount':masked,'privacySuppressedLineCount':lost,'contactTokensRemovedWithoutDiscardingAdjacentEducation':True,'educationalParserVersion':4})
 for context in result['educationalOperatingContexts']:
  assert not EMAIL.search(context) and not PHONE.search(context) and not REMAINING_PRIVATE.search(context) and not CONTACT_EXTENSION.search(context) and not CONTACT_LOCAL_PHONE.search(context)
 return result

old.education=education
old.text_evidence=text_evidence

def collect(client,row):
 record=old.fetch_record(client,row)
 # The original public collector reads native PDF/DOCX/HWP/HWPX/PPTX.
 # DOC/TXT are additionally parsed through already-installed native readers.
 if any(a.get('format') in ('doc','txt') for a in record['attachments']):
  code,section=row['HAKSU_NO'],row['BUNBAN']
  files=client.post('/E_NHSSU900011P/selectFile2',old.params(code,section,'selectFile2','dsMyFile2'),'',save=False).get('dsMyFile2',[])
  replacements=[]
  for f in files:
   fileid=f.get('BIZ_PLN_FILE_ID')
   if not fileid:continue
   q={'FILE_ID':fileid,'_TRANSACTION_ID':'selectDsFile2','_FIRST_OUT_DS_NM':'dsFile2','_ALL_OUT_DS_NM':'dsFile2=dsFile2','_MENU_ID':'EXT_SCHEDULE','_PGM_ID':'NHSSU030840M'}
   for attachment in client.post('/E_NAttachFile/selectAttachFiles',q,'',save=False).get('dsFile2',[]):
    suffix=attachment.get('FILE_NM','').rsplit('.',1)[-1].lower()
    if suffix not in ('doc','txt'):continue
    url='https://kingoinfo.skku.edu/gaia/E_Nsystem/fileDownload.do?attachFileId='+attachment['DOWNLOAD_FILE_ID']+'&sequenceNumber='+attachment['FILE_SEQ']
    body=client.download(url)
    try:
     text=doc_text(body) if suffix=='doc' else body.decode('utf8',errors='replace')
     replacements.append({'format':suffix,**text_evidence(text,code,section,row['PER_NAME'])});text=None
    except ProtectedPublishedOfficeSource:replacements.append({'format':suffix,'protectionPresent':True,'status':'Protected source left unread, no bypass'})
    body=None
  record['attachments']=[a for a in record['attachments'] if a.get('format') not in ('doc','txt')]+replacements
 record['isolatedEducationRepairCheckedAt']=datetime.datetime.now(datetime.timezone.utc).isoformat()
 record['canonicalAuditNotChanged']=True
 return record

def stopped_collect(client,row):
 try:return collect(client,row)
 except BaseException:
  old.STOP_REQUESTS.set();raise

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--limit',type=int);args=parser.parse_args()
 canonical=json.loads((P/'skku-public-operating-plan-audit.json').read_text());assert canonical['allCurrentDetailsFetched'] and canonical['count']==2782
 decisions=json.loads((P/'skku-planned-regular-20261008-r25-scope-decisions.json').read_text())['decisions']
 target_keys={d['offeringCode'] for d in decisions if any(r['kind']=='filteredEducationalContextIncomplete' for r in d.get('reasons',[]))}
 targets=[r['sourceRow'] for r in canonical['records'] if r['offeringCode'] in target_keys]
 audit=json.loads(TARGET_FILE.read_text()) if TARGET_FILE.exists() else {'researchOnly':True,'completionClaim':False,'targetCount':len(targets),'canonicalAuditModified':False,'records':[],'wholeScopeRequery':False,'maximumConcurrentAnonymousSessions':2,'globalRequestStartSpacingSeconds':.8,'noRetryOrBypass':True}
 done={r['offeringCode'] for r in audit['records']};remaining=[r for r in targets if r['HAKSU_NO_BUNBAN'] not in done]
 if args.limit is not None:remaining=remaining[:args.limit]
 if not remaining:print('No new target rows');return
 fd=os.open(LOCK,os.O_CREAT|os.O_EXCL|os.O_WRONLY);os.write(fd,str(os.getpid()).encode());os.close(fd)
 pool=None
 def save():
  audit['count']=len(audit['records']);audit['allTargetRequestsFinished']=len(done)==len(targets);audit['updatedAt']=datetime.datetime.now(datetime.timezone.utc).isoformat()
  temp=TARGET_FILE.with_suffix('.tmp');temp.write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n');temp.replace(TARGET_FILE)
 try:
  audit['stopped']=False;old.STOP_REQUESTS.clear()
  clients=[old.SpacedPublic('KO'),old.SpacedPublic('KO')];rows=iter(remaining);pool=ThreadPoolExecutor(max_workers=2);pending={}
  for i,client in enumerate(clients):
   row=next(rows,None)
   if row is not None:pending[pool.submit(stopped_collect,client,row)]=i
  while pending:
   finished,_=wait(pending,return_when=FIRST_COMPLETED)
   for future in finished:
    i=pending.pop(future);record=future.result();key=record['offeringCode'];assert key not in done
    audit['records'].append(record);done.add(key);save()
    print('Isolated educational repair',len(done),'of',len(targets),flush=True)
    row=next(rows,None)
    if row is not None and not old.STOP_REQUESTS.is_set():pending[pool.submit(stopped_collect,clients[i],row)]=i
  save()
 except BaseException as error:
  old.STOP_REQUESTS.set();audit['stopped']=True;audit['failureType']=type(error).__name__;audit['failure']='Normal public request/reader stopped; private exception content not retained. No retry/bypass.';save();raise SystemExit(1)
 finally:
  old.STOP_REQUESTS.set()
  if pool is not None:pool.shutdown(wait=True,cancel_futures=True)
  LOCK.unlink(missing_ok=True)

if __name__=='__main__':main()
