"""Whole current public education identities, date-specific native periods only."""
import collections,datetime,hashlib,json,re
from pathlib import Path
R=Path(__file__).resolve().parent;D=R/'current-weeks-education-complete-20261008'
DAY={'월':('MON',1),'화':('TUE',2),'수':('WED',3),'목':('THU',4),'금':('FRI',5),'토':('SAT',6)}
groups=collections.defaultdict(list);duplicates=[];unparsed=[]
for wi in range(1,16):
 p=D/f'week-{wi}.json';d=json.loads(p.read_text());seen=set()
 for row in d['courses']:
  key=(row['GWAMOK_CD'],row['BUNBAN'])
  if key in seen:duplicates.append({'week':wi,'identity':key})
  seen.add(key);assert row['YEAR']=='2026' and row['HAKGI']=='2' and row['CORS_GB']=='1'
  source=row['SIGANPYO2'];parts=[]
  # Every location binds only its following native weekday/period sequence.
  pattern=r'([^:]+?)\s*:\s*((?:[월화수목금토일]\([\d,]+\),?\s*)+)'
  matches=list(re.finditer(pattern,source));consumed=''.join(m.group() for m in matches)
  if source and re.sub(r'\s','',consumed)!=re.sub(r'\s','',source):unparsed.append({'week':wi,'identity':key,'schedule':source})
  for m in matches:
   place=m.group(1).strip()
   for day,ps in re.findall(r'([월화수목금토일])\(([\d,]+)\)',m.group(2)):
    assert day in DAY
    field,weekday=DAY[day];date=datetime.datetime.strptime(d['week'][field+'_SUEOP_DT'],'%Y%m%d').date();assert date.isoweekday()==weekday
    periods=[int(x) for x in ps.split(',')];assert periods==sorted(set(periods))
    parts.append({'date':date.isoformat(),'weekday':weekday,'nativePeriods':periods,'location':place,'clockPending':True})
  groups[key].append({'week':wi,'weekStart':d['week']['STT_DT'],'weekEnd':d['week']['END_DT'],'originalPublicEducation':row,'sourceFile':p.name,'sourceFileSHA256':hashlib.sha256(p.read_bytes()).hexdigest(),'datedNativePeriodParts':parts,'datesMeaning':'School-published weekly plan date mapping, not confirmed actual attendance.'})
assert len(groups)==742 and not duplicates and not unparsed
courses=[]
for (code,section),items in sorted(groups.items()):
 courses.append({'courseId':code+'-'+section,'code':code,'section':section,'nativeTitles':sorted({x['originalPublicEducation']['GWAMOK_NM'] for x in items}),'nativeProfessors':sorted({x['originalPublicEducation']['GYOSU_NM'] for x in items}),'nativeClassifications':sorted({x['originalPublicEducation']['ISU_GB_NM'] for x in items}),'nativeDepartments':sorted({x['originalPublicEducation']['JEONGONG_NM'] for x in items}),'publishedWeeks':items,'weeklyScheduleChanges':len({x['originalPublicEducation']['SIGANPYO2'] for x in items})>1,'schoolTermStart':'2026-08-31','schoolTermEnd':'2026-12-11','actualAttendanceIndividuallyConfirmed':False})
out={'universityId':'knue','institutionId':'institution:academyinfo:0000031','wholePublicCourseCount':742,'changedWeeklyCourses':sum(x['weeklyScheduleChanges'] for x in courses),'whole15PublicWeeksPreserved':True,'allEducationFieldsPreserved':True,'clockAndHolidayDecisionPending':True,'completionClaim':False,'courses':courses}
p=R/'knue-whole742-current-weekly-education-review-pending.json';p.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
print({'whole742':len(courses),'weeklyChanges':out['changedWeeklyCourses'],'allWeeklyRows':sum(len(x['publishedWeeks']) for x in courses),'parseErrors':len(unparsed),'duplicateIdentitiesPerWeek':len(duplicates),'SHA256':hashlib.sha256(p.read_bytes()).hexdigest()})
