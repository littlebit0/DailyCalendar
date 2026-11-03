"""After whole audit, repair only proven truncated/old-unread educational attachments.
No second parallel collector, whole requery loop, print route or protection bypass.
"""
import json,zipfile
from datetime import datetime,timezone
from audit_skku_public_operating_plans import P,SpacedPublic,params,text_evidence,pdf_evidence,docx_evidence,ProtectedPdfEducationalSource
from read_skku_published_office_plan import hwp_text,hwpx_text,pptx_text,doc_text,ProtectedPublishedOfficeSource
from pypdf.errors import EmptyFileError,PdfReadError
from read_skku_published_image_plan import image_education_text
READERS={'pdf':pdf_evidence,'docx':docx_evidence}
TEXT_READERS={'hwp':hwp_text,'hwpx':hwpx_text,'pptx':pptx_text,'doc':doc_text}
IMAGE_FORMATS={'jpg','jpeg','png'}
if __name__=='__main__':
    path=P/'skku-public-operating-plan-audit.json';audit=json.loads(path.read_text())
    if not audit['allCurrentDetailsFetched'] or audit['count']!=2782:
        raise SystemExit('Whole single-owner audit still running; no duplicate public collector permitted.')
    targets=[r for r in audit['records'] if not r.get('targetedAttachmentRepairCheckedAt') and any(a.get('contextTruncated') or (a['format'] in set(TEXT_READERS)|set(READERS)|IMAGE_FORMATS and 'educationalOperatingContexts' not in a and not a.get('protectionPresent') and not a.get('educationalContentIncomplete') and 'not safely readable' not in a.get('status','')) for a in r['attachments'])]
    manifest={'researchOnly':True,'completionClaim':False,'targetCount':len(targets),'finished':[],'wholeScopeRequery':False}
    def save():
        tmp=path.with_suffix('.tmp');tmp.write_text(json.dumps(audit,ensure_ascii=False,indent=2));tmp.replace(path)
        (P/'skku-targeted-attachment-repair-status.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
    try:
        p=SpacedPublic('KO')
        for record in targets:
            code=record['sourceRow']['HAKSU_NO'];section=record['sourceRow']['BUNBAN'];new=[]
            if not record['detail'] or record['detail'][0]['INPUT_TYPE_GB']!='1':
                raise ValueError('Cached actual UI route is not file input')
            files=p.post('/E_NHSSU900011P/selectFile2',params(code,section,'selectFile2','dsMyFile2'),'',save=False).get('dsMyFile2',[])
            for f in files:
                fileid=f.get('BIZ_PLN_FILE_ID')
                if not fileid:continue
                q={'FILE_ID':fileid,'_TRANSACTION_ID':'selectDsFile2','_FIRST_OUT_DS_NM':'dsFile2','_ALL_OUT_DS_NM':'dsFile2=dsFile2','_MENU_ID':'EXT_SCHEDULE','_PGM_ID':'NHSSU030840M'}
                attachments=p.post('/E_NAttachFile/selectAttachFiles',q,'',save=False).get('dsFile2',[])
                for a in attachments:
                    suffix=a.get('FILE_NM','').rsplit('.',1)[-1].lower();item={'format':suffix}
                    if suffix in READERS or suffix in TEXT_READERS or suffix in IMAGE_FORMATS:
                        url='https://kingoinfo.skku.edu/gaia/E_Nsystem/fileDownload.do?attachFileId='+a['DOWNLOAD_FILE_ID']+'&sequenceNumber='+a['FILE_SEQ'];body=p.download(url)
                        try:
                            if suffix in READERS:item.update(READERS[suffix](body,code,section,record['sourceRow']['PER_NAME']))
                            elif suffix in IMAGE_FORMATS:
                                text,flags=image_education_text(body);item.update(text_evidence(text,code,section,record['sourceRow']['PER_NAME']));item.update(flags);item['educationalParserVersion']=3;item['byteCount']=len(body);text=None
                            else:
                                text=TEXT_READERS[suffix](body);item.update(text_evidence(text,code,section,record['sourceRow']['PER_NAME']));item['educationalParserVersion']=2;item['byteCount']=len(body);text=None
                        except (ProtectedPublishedOfficeSource,ProtectedPdfEducationalSource):
                            item.update({'protectionPresent':True,'status':'Actual protected/distributed HWP left unread; no bypass.'})
                        except (EmptyFileError,PdfReadError):
                            item.update({'byteCount':len(body),'educationalContentIncomplete':True,'status':'Actual public PDF empty or unreadable; individual education remains blocked without retry.'})
                        except (ValueError,KeyError,zipfile.BadZipFile):
                            item['status']='Normal installed reader could not safely extract this actual public attachment; education remains unverified.'
                        body=None
                    else:item['status']='Actual format requires separate normal educational review; no inference of current operational content.'
                    new.append(item)
            record['attachments']=new;record['targetedAttachmentRepairCheckedAt']=datetime.now(timezone.utc).isoformat();manifest['finished'].append(record['offeringCode']);save()
        manifest['allTargetsFinished']=True;save();print('Targeted repair',len(targets),'finished')
    except BaseException as e:
        manifest['stopped']=True;manifest['failureType']=type(e).__name__;manifest['failure']='Normal targeted request/reader stopped, no private exception data or bypass.';save();raise SystemExit(1)
