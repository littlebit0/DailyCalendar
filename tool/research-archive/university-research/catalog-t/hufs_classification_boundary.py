"""School code-based classification; preserve detailed source area as a remark."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parent
PREFIX={'1':'','2':'교양 · ','3':'대학기초 · ','4':'마이크로전공 · '}
rows=json.loads((ROOT/'hufs-current-20261008/courses.json').read_text())
by_alias={}
for record in rows:
    row=record['row'];campus='seoul' if record['queryCampus']=='H1' else 'global'
    alias=PREFIX[record['queryCategory']]+record['queryDepartment']
    key=(campus,row['lssnCd'],alias)
    if key in by_alias:
        assert by_alias[key]['comptFldCd']==row['comptFldCd']
    by_alias[key]=row

def classification(row):
    code=row['comptFldCd'];name=row['comptFldNm']
    if code.startswith('7'):
        assert row['crsStrctCd'] in {'AUE01','AUE02'}
        return '대학기초','학교 기초 세부 영역: '+name
    if code=='362':return '마이크로디그리(영어)','학교 교양 교육과정의 마이크로디그리(영어) 영역'
    if code=='61':return '군사학',''
    if code in {'305','306','30B','332','334','337','338','351','358','359','35A','35D','35E','361','32Z'}:
        assert row['crsStrctCd'] in {'AUA01','AUA02','AZHA1'}
        return '교양','학교 교양 세부 영역: '+name
    if code=='41':return '교직',''
    if code in {'12','13'}:
        assert name in {'전공','이중(부)전공','이중(제2)'}
        return ('전공필수','공식 이수구분: '+name) if row['encessFlag']=='Y' else (name,'')
    raise ValueError('Unverified classification code: '+code)

def normalize(course):
    changes=[]
    for alias in course['departments']:
        row=by_alias[(course['campus'],course['courseCode']+course['section'],alias)]
        value,note=classification(row)
        old=course['departmentClassifications'][alias]
        course['departmentClassifications'][alias]=value
        if note and note not in course['departmentRemarks'][alias]:
            course['departmentRemarks'][alias]+=(' · ' if course['departmentRemarks'][alias] else '')+note
        changes.append({'sourceId':course['sourceId'],'department':alias,'sourceClassificationCode':row['comptFldCd'],'sourceClassificationName':row['comptFldNm'],'normalizedClassification':value,'previousClassification':old,'sourceStructure':row['crsStrctCd']})
    return changes
