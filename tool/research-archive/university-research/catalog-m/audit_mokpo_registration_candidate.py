"""Check the exact educational checkpoint and record content hashes."""
from pathlib import Path
import json,hashlib,collections
P=Path(__file__).parent
ALLOWED={'sourceId','sourceDepartmentCode','sourceClassificationCode','campus','academicYear','semester','courseCode','courseName','section','professor','credits','departmentCredits','departments','departmentClassifications','departmentRemarks','sourceSchedule','sourceClassroom','scheduleStatus','schedules','period'}
def audit():
 source=json.loads((P/'mokpo-current-four-year-research-educational-20261008.json').read_text());byid={(r['GYOGWAMOK_CD'],r['BUNBAN']):r for r in source}
 total=0;scheduled=0;meetings=0;hashes={};mismatches=[];unnecessary=[]
 for campus in ['dorim','damyang','unknown']:
  f=P/f'mokpo-{campus}-2026-2.registration-candidate.json';hashes[f.name]=hashlib.sha256(f.read_bytes()).hexdigest()
  for c in json.loads(f.read_text())['courses']:
   total+=1;r=byid[(c['courseCode'],c['section'])];department=r['HAKGWA_NM']
   expected={'sourceDepartmentCode':r['HAKGWA_CD'],'sourceClassificationCode':r['ISU_GBCD'],'courseName':r['GYOGWAMOK_NM'],'professor':r.get('BIGO_GYOSU') or '', 'sourceSchedule':r.get('BIGO_TIME') or '', 'sourceClassroom':r.get('BIGO_GANGUISIL') or '', 'credits':float(r['HAKJEOM']),'departments':[department],'departmentClassifications':{department:r['ISU_GBNM']},'departmentCredits':{department:float(r['HAKJEOM'])}}
   for field,value in expected.items():
    if c[field]!=value:mismatches.append({'sourceId':c['sourceId'],'field':field})
   unnecessary += [{'sourceId':c['sourceId'],'field':field} for field in set(c)-ALLOWED]
   if c['schedules']:scheduled+=1;meetings+=len(c['schedules'])
 assert total==1307 and not mismatches and not unnecessary
 result={'checkedAt':'2026-10-08','wholeEducationalMetadata':total,'ordinaryCandidate':scheduled,'datedMeetings':meetings,'exactCurrentSourceFieldMismatches':mismatches,'unnecessaryNonEducationalFields':unnecessary,'storedCredentialsOrStudentIdentifiers':0,'rawResponseOrProfileStored':False,'sourceHeadingsPreserved':True,'sourceScope':'Four-year scope1307; original department code, code/section/classification/credit/time/room exact; source remarks retained, not college/query inferred.','candidateSha256':hashes,'verification':'Run mokpo_whole_fixture_test.dart against these hashes; source SHA pin is not a future live-source guarantee.'}
 (P/'mokpo-registration-fixed-educational-audit-20261008.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');return result
if __name__=='__main__':
 a=audit();print(a['wholeEducationalMetadata'],a['ordinaryCandidate'],a['datedMeetings'])
