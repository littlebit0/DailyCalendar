import pathlib,sys,json,re,hashlib
p=pathlib.Path(__file__).parent
sys.path.insert(0,str(p.parent.parent/'catalog-g'))
from audit_skku_public_operating_plans import SpacedPublic,params
raw=json.loads((p.parent.parent/'catalog-g/skku-public-operating-plan-audit.json').read_text());client=SpacedPublic('KO');out=[]
for key in ['EPN3018-01','GBA3017-01']:
 code,section=key.rsplit('-',1);r=next(x for x in raw['records'] if x['offeringCode']==key);row={'offeringCode':key,'sourceOnly':True,'normalObservedGuestOnly':True,'cachedCurrentWholeListRow':r['sourceRow'],'currentNativeSameCodeSections':[x['offeringCode'] for x in raw['records'] if x['sourceRow']['HAKSU_NO']==code],'ownPrintedCodeSectionAbsent':True,'otherSemesterLocatorQueryPerformed':False,'otherSemesterSharingNotClaimedAbsent':True}
 try:
  query=params(code,section,'selectFile2','dsMyFile2');files=client.post('/E_NHSSU900011P/selectFile2',query,'',save=False).get('dsMyFile2',[]);row['actualCurrentMetadataQuery']=query;row['actualObservedCurrentFileRows']=files;loc=[]
  for f in files:
   fileid=f['BIZ_PLN_FILE_ID'];q={'FILE_ID':fileid,'_TRANSACTION_ID':'selectDsFile2','_FIRST_OUT_DS_NM':'dsFile2','_ALL_OUT_DS_NM':'dsFile2=dsFile2','_MENU_ID':'EXT_SCHEDULE','_PGM_ID':'NHSSU030840M'};ats=client.post('/E_NAttachFile/selectAttachFiles',q,'',save=False).get('dsFile2',[])
   for a in ats:
    name=a['FILE_NM'];assert not re.search(r'명단|명부|연락처|출석부|성적|학생목록',name)
    loc.append({'observedBusinessPlanFileId':fileid,'observedPublicFileName':name,'observedDownloadFileId':a['DOWNLOAD_FILE_ID'],'observedSequenceNumber':a['FILE_SEQ'],'sourceURL':'https://kingoinfo.skku.edu/gaia/E_Nsystem/fileDownload.do?attachFileId='+a['DOWNLOAD_FILE_ID']+'&sequenceNumber='+a['FILE_SEQ'],'downloadPerformedInThisMetadataAudit':True})
  row['actualCurrentCodeSectionPublicAttachmentLocators']=loc
  expectedfolder='skku-held-own-operation-v90-20261009'
  education=json.loads((p.parent/expectedfolder/(key.lower()+'-full-education.json')).read_text());assert len(loc)==1
  bytesCurrent=client.download(loc[0]['sourceURL']);currentSHA=hashlib.sha256(bytesCurrent).hexdigest();bytesCurrent=None
  row['downloadedCurrentLocatorRawSHAOnly']=currentSHA;row['frozenFullEducationRawSHA']=education['sha256'];row['currentLocatorBytesEqualFrozenEducation']=currentSHA==education['sha256'];row['rawBytesSaved']=False
  assert row['currentLocatorBytesEqualFrozenEducation'];row['status']='normal current direct offering-specific public metadata chain observed'
 except Exception as e:row['status']='stopped no retry or bypass';row['failureType']=type(e).__name__
 out.append(row);print(key,row['status'],len(row.get('actualCurrentCodeSectionPublicAttachmentLocators',[])))
(p/'current-primary-public-locators.json').write_text(json.dumps({'sourceOnly':True,'SDKExecuted':False,'completionClaim':False,'records':out},ensure_ascii=False,indent=2)+'\n')
