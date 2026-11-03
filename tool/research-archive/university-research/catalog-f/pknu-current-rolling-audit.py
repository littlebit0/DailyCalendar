import pathlib,json,re,collections,datetime
p=pathlib.Path(__file__).parent;old={x['identity']:x for x in json.loads((p/'pknu-course-rows.json').read_text())};current={x['COURSE_NO']+'-'+x['DCLSS_NO']:x for x in json.loads((p/'pknu-latest-rows.json').read_text())};counts=collections.Counter();diff=[];parseWarnings=[];dateEvidence=[]
def slots(s):
 s=s or ''
 for a,b in [('Monday','월'),('Mon','월'),('Tuesday','화'),('Tue','화'),('Wednesday','수'),('Wed','수'),('Thursday','목'),('Thu','목'),('Friday','금'),('Fri','금'),('Saturday','토'),('Sat','토'),('Sunday','일'),('Sun','일')]:s=re.sub(r'\b'+a+r'[.]?',b,s,flags=re.I)
 out=set()
 for day,nums in re.findall(r'([월화수목금토일])\s*([0-9]+(?:\s*[-~,]\s*[0-9]+)*)',s):
  for n in re.split(',',nums):
   parts=re.split('[-~]',n.strip())
   if len(parts)==1:out.add((day,int(parts[0])))
   elif len(parts)==2:
    a,b=map(int,parts)
    if a>b:raise ValueError('Reversed actual period')
    out.update((day,j)for j in range(a,b+1))
 return sorted(out)
def rooms(s):return sorted(set(re.findall(r'\b[A-Z]\d{1,2}-\d+[A-Z]?',s or '')))
for ident,r in current.items():
 f=p/'pknu-current-syllabus'/(ident+'.json');u=p/'pknu-current-syllabus'/(ident+'.unavailable.json');e=p/'pknu-current-syllabus'/(ident+'.error.json')
 if not f.exists():counts['unpublished' if u.exists() else 'unresolvedError' if e.exists() else 'pending']+=1;continue
 x=json.loads(f.read_text())
 if x.get('parserVersion')!=2:counts['legacyParser']+=1;continue
 if x.get('identity')!=ident or x.get('fields',{}).get('학수번호')!=r['COURSE_NO'] or x.get('fields',{}).get('분반')!=r['DCLSS_NO']:raise ValueError('Bad verified identity')
 counts['currentVerified']+=1;fields=x['fields'];t=fields.get('강의시간','');room=fields.get('강의실','');newSlots=slots(t)
 if t and not newSlots:parseWarnings.append({'identity':ident,'time':t,'room':room})
 counts['timeBearing']+=bool(newSlots);counts['noTime']+=not bool(newSlots)
 if x.get('periodRestrictionEvidence'):dateEvidence.append({'identity':ident,'title':r.get('SBJT_KOR_NM'),'evidence':x['periodRestrictionEvidence']})
 if ident not in old:counts['newNoJulyMatch']+=1;continue
 o=old[ident];oldTime=' '.join(v for v in o['periods']if v);oldRoom=' '.join(v for v in o['rooms']if v);oldSlots=slots(oldTime);rs1,rs2=rooms(oldRoom),rooms(room)
 if oldSlots!=newSlots or rs1!=rs2:
  diff.append({'identity':ident,'title':r.get('SBJT_KOR_NM'),'oldTimeRaw':o['periods'],'currentTimeRaw':t,'oldRoomRaw':o['rooms'],'currentRoomRaw':room,'timeDifference':oldSlots!=newSlots,'roomDifference':rs1!=rs2,'normalizedOldSlots':oldSlots,'normalizedCurrentSlots':newSlots,'normalizedOldRooms':rs1,'normalizedCurrentRooms':rs2})
out={'partial':counts['pending']>0 or counts['unresolvedError']>0,'asOf':datetime.datetime.now().isoformat(timespec='seconds'),'currentTotal':len(current),'verifiedCurrentV2':counts['currentVerified'],'coverage':dict(counts),'comparisonCount':len(diff),'differences':diff,'timeParseWarnings':parseWarnings,'academicDateRestrictionEvidence':dateEvidence,'scopeLimitations':['120 July organizations not verified against whole current organization combo','152 current public plan buttons absent; active fullinstitution support not proven','50/75 unit still authoritative July metadata; current report itself no explicit minuteunit','Periods/physicalroom comparison uses sets; perday room association mustremainseparate','Evidence regex is discovery not complete proof of no dated exceptions'],'completeAppSupportClaim':False}
(p/'pknu-v2-rolling-comparison.json').write_text(json.dumps(out,ensure_ascii=False,indent=2));print(json.dumps({'coverage':out['coverage'],'changedTime':sum(x['timeDifference']for x in diff),'changedRoom':sum(x['roomDifference']for x in diff),'parseWarnings':len(parseWarnings),'academicEvidenceCourses':len(dateEvidence)},ensure_ascii=False))
