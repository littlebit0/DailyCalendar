import pathlib,json,copy,re,unicodedata,collections,urllib.request,hashlib
from lxml import html
D=pathlib.Path(__file__).parent;a=json.loads((D/'native-education-rows.json').read_text());current=json.loads(pathlib.Path('assets/timetable/ulsan-main-2026-2.json').read_text());notice=a['noticeUrl']
with urllib.request.urlopen(notice,timeout=25) as r:b=r.read()
(D/'notice.html').write_bytes(b);(D/'notice.txt').write_text(html.fromstring(b,parser=html.HTMLParser(encoding='utf-8')).text_content())
def norm(v):return re.sub(r'\s+','',unicodedata.normalize('NFKC',v))
old=collections.defaultdict(list)
for c in current['courses']:old[norm(c['courseName'])].append(c)
out={k:copy.deepcopy(current[k]) for k in ['schemaVersion','universityId','institutionId','campus','campusName','academicYear','semester','termStartDate','termEndDate'] if k in current}
out.update(sourceUrl=notice,sourceUrls=[notice,a['sourceUrl']],candidateRevision='public-2026-2-general-openings-metadata-693-v1',publishedDate='2026-07-31',publishedDateMeaning='officialNoticePublicationDate',completionClaim=False,researchOnly=True,productionIntegrationEnabled=False,wholeOperatingVerified=False,courses=[])
collisions=[]
for r in a['rows']:
 c=r['cells'];code=c['G'];section=c['H'].zfill(2);owner=c['D'];title=c['F'];sourceId=a['sourceUrl']+'#Sheet1-row-'+str(r['row'])
 course={'sourceId':sourceId,'referenceKind':'internalDocumentLocator','academicYear':2026,'semester':'2','campus':out['campus'],'courseCode':code,'courseName':title,'section':section,'professor':'','credits':float(c['I']),'classification':c['E'],'departments':[owner],'departmentClassifications':{owner:c['E']},'departmentCredits':{owner:float(c['I'])},'departmentRemarks':{owner:c.get('K','')},'sourceSchedule':'','sourceClassroom':'','scheduleStatus':'unprinted','schedules':[],'sourceEducation':{'sourceUrl':a['sourceUrl'],'noticeUrl':notice,'sourceSHA256':a['sha256'],'nativeWorksheet':'Sheet1','nativeRow':r['row'],'nativeFields':c,'sourceCoverage':'2026-2 교양 강좌 개설 현황 only; not entire university offerings','sourceTimeNotPublished':True,'sourceProfessorNotPublished':True,'sourceRoomNotPublished':True,'campusPhysicalRoomProof':False,'wholeSchoolCompletionClaim':False}}
 out['courses'].append(course)
 if norm(title) in old:collisions.append({'candidateRow':r['row'],'nativeCourseCode':code,'nativeSection':c['H'],'nativeTitle':title,'nativeOwner':owner,'nativeCredits':c['I'],'existingSourceIds':[x['sourceId'] for x in old[norm(title)]],'identityEstablished':False,'reason':'Exact normalized title overlap only; source does not publish professor/room/time. No title-only canonical join or duplicate insertion authorized.'})
(D/'ulsan-main-2026-2-general-openings-candidate.json').write_text(json.dumps(out,ensure_ascii=False,indent=2))
receipt={'candidateRows':693,'uniqueNativeCodeSection':693,'newTimedRows':0,'normalizedTitleOverlapRows':len(collisions),'nonTitleOverlappingCandidateRows':693-len(collisions),'collisions':collisions,'canReplaceExistingTimedCourses':False,'mergeNotPerformed':True,'sourceHashes':{'xlsx':a['sha256'],'notice':hashlib.sha256(b).hexdigest()}}
(D/'candidate-receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2));print({k:v for k,v in receipt.items() if k!='collisions'})
