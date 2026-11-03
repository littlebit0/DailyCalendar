"""Extract source educational tables without fabricating class identity or schedules."""
import collections,hashlib,json,re
from pathlib import Path
import openpyxl
D=Path(__file__).parent/'daegu-current-20261008'
def write(name,data): (D/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
def clean(x): return re.sub(r'\s+',' ',str(x or'')).strip()
rows=[];gaps=[]
for table in json.loads((D/'native-timetable-tables.json').read_text()):
 h=[re.sub(r'\s+','',str(v or''))for v in table['rows'][0]];last={};lastrow=None
 for n,r in enumerate(table['rows'][1:],2):
  d=dict(zip(h,[clean(v) for v in r]));code=d.get('수강번호','')
  if not code:
   if any(clean(v)for v in r):gaps.append({'pdfPage':table['pdfPage'],'tableIndex':table['tableIndex'],'row':n,'cells':r,'reason':'source table row lacks native registration number; not projected'})
   continue
  if not re.fullmatch(r'\d{4}',code):gaps.append({'pdfPage':table['pdfPage'],'cells':r,'reason':'unrecognized native registration notation'});continue
  for field in ['구분','학년']:
   if d.get(field):last[field]=d[field]
   elif field in last:d[field]=last[field]
  rows.append({'sourcePage':table['pdfPage'],'tableIndex':table['tableIndex'],'sourceRow':n,'sourceTitleLines':table['title'],'nativeRegistrationNumber':code,'nativeSection':'','nativeCanonicalCourseCodePublished':False,'education':d,'sourceCells':r})
wb=openpyxl.load_workbook(D/'closure-2026-2.xlsx',data_only=True);s=wb.active;heads=[clean(x)for x in next(s.values)];closures=[]
for n,r in enumerate(list(s.values)[1:],2):
 if r[8]:closures.append({'sourceRow':n,'education':dict(zip(heads,[clean(x)for x in r]))})
closed={x['education']['수강번호']for x in closures};by=collections.defaultdict(list)
for r in rows:by[r['nativeRegistrationNumber']].append(r)
active={k:v for k,v in by.items()if k not in closed and k not in {'1316','2210'}}
conflicts=[]
for k,v in by.items():
 for field in ['교과목명','강의시간','강의실','담당교수']:
  values=sorted({r['education'].get(field,'')for r in v})
  if len(values)>1:conflicts.append({'registrationNumber':k,'field':field,'values':values,'sourcePages':[r['sourcePage']for r in v]})
write('educational-source-offerings.json',rows);write('closure-educational-rows.json',closures)
write('source-extraction-audit.json',{'completionClaim':False,'tableCount':342,'sourceRows':len(rows),'nativeRegistrationNumbers':len(by),'sourceRowGaps':gaps,'nativeIdentity':'source-published 4-digit 수강번호; canonical course code and separate section not present; no invented section','closureRows':len(closures),'closureNativeRegistrationNumbers':len(closed),'closureOriginalRows':sum(x['education']['합반']=='원반'for x in closures),'closureMergedRows':sum(x['education']['합반']=='합반'for x in closures),'closureMatchesSnapshot':len(closed&set(by)),'closureNotInSnapshot':sorted(closed-set(by)),'laterLawClosures':['1316','2210'],'remainingSourceIdentityCount':len(active),'conflictingRepeatedNativeIdentity':conflicts,'categories':dict(collections.Counter(r['education'].get('구분','')for r in rows)),'sourceSnapshotCaution':'July27 notice PDF may be changed in TIGERS. Public actual changes and closure supplements need audit before dated candidate.'})
# Restrict indexed plain text to educational catalog / calendar, no administrative contact pages.
f=D/'timetable-2026-2.txt';txt=f.read_text();parts=re.split(r'\n###PDFPAGE ',txt);kept=[]
for part in parts[1:]:
 num=int(part.split('\n',1)[0])
 if num not in {5,6,7,8,37}:kept.append('\n###PDFPAGE '+part)
f.write_text(''.join(kept))
print(json.dumps({'rows':len(rows),'uniqueNativeNumbers':len(by),'closureRows':len(closures),'closureMatches':len(closed&set(by)),'sourceRowGaps':len(gaps),'conflicts':len(conflicts),'remaining':len(active)},ensure_ascii=False))
