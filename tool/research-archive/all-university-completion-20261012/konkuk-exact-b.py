import json,re
from pathlib import Path
O=Path('work/all-university-completion-20261012');txt=(O/'b-sources/konkuk-english-2026.txt').read_text()
# Official row sections on admissions booklet printed pages20-21. No host/teacher inference.
bounds=[('Liberal Arts','Liberal \nArts\n','Sciences\nMathematics'),('Sciences','Sciences\nMathematics','Architecture\nArchitecture'),('Architecture','Architecture\nArchitecture','Engineering\nCivil'),('Engineering','Engineering\nCivil','Social\nSciences\nPolitical'),('Social Sciences','Social\nSciences\nPolitical','Business\nBusiness Administration'),('Business','Business\nBusiness Administration','PART 01\nAdmissions Guide\nKonkuk University\n21'),('Real Estate','Real Estate\nReal Estate Studies','Institute of \nScience'),('Institute of Science and Technology','Institute of \nScience and \nTechnology\nAdvanced','Life \nScience\nAnimal'),('Life Science','Life \nScience\nAnimal','Veterinary \nMedicine\nVeterinary'),('Art & Design','Art & Design\nCommunication','Education\nJapanese'),('Education','Education\nJapanese','International \nCollege\n* Exclusive')]
def norm(s):return re.sub(r'[^A-Z0-9]','',s.upper().replace('&','AND'))
rows=json.load(open('assets/timetable/organizations/konkuk.json'))['mappings'];out=[]
import sys
sys.path.insert(0,'/private/tmp/daily-college-source-parser')
import fitz
pdf=fitz.open(O/'b-sources/konkuk-english-2026.pdf')
for page in [19,20]:
 current=None
 for row in pdf[page].find_tables().tables[0].extract()[1:]:
  if row[0]:current=' '.join(row[0].split())
  exact=[(row[1]or'').replace('★','')]+[(q or'').strip()for q in (row[5]or'').split(',')]
  for m in rows:
   d=m.get('department')or''
   if not d or norm(d)not in [norm(v)for v in exact]:continue
   out.append({'university':'konkuk','department':d,'sourceLabel':m['sourceLabel'],'campus':m.get('campus','*'),'college':current,'officialCollegeEnglish':current,'group':None,'officialGroups':[],'kind':'ordinaryCollege','sourceUrl':'https://ciss.konkuk.ac.kr/bbs/ciss/1482/1206284/download.do','sourceFile':str(O/'b-sources/konkuk-english-2026.pdf'),'evidence':'Official Fall2026 Undergraduate Admissions Colleges&Majors table printedpp20-21 college='+current+' exact cell/explicit DetailedMajor='+d+'. Rowspan college inherited from same table; whitespace,case,&/and only normalized, not substring or Korean legacy inference.'})
(O/'konkuk-exact-b.json').write_text(json.dumps({'entries':out},ensure_ascii=False,indent=2));print(len(out),[m['department']for m in rows if m.get('department')and m['department']not in{e['department']for e in out}])
