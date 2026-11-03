"""Final current outsider selector census, after the single operating audit completes.
Only public educational fields survive; sessions/internal teacher IDs remain in memory.
"""
import json,collections,sys
from datetime import datetime,timezone
from audit_skku_public_operating_plans import SpacedPublic,P,CATALOG_FIELDS,education
if __name__=='__main__':
    audit=json.loads((P/'skku-public-operating-plan-audit.json').read_text())
    partial='--partial-operating-registration' in sys.argv
    if partial and not audit['stopped']:
        raise SystemExit('Single-owner operating collector must checkpoint and stop before partial registration census.')
    if not partial and (not audit['allCurrentDetailsFetched'] or audit['count']!=2782):
        raise SystemExit('Whole current operating audit remains incomplete; final census not claimed.')
    major=json.loads((P/'skku-ko-major-all-2026-2.json').read_text());general=json.loads((P/'skku-ko-general-all-2026-2.json').read_text())
    old={r['HAKSU_NO_BUNBAN']:{k:education(r.get(k))[0] for k in CATALOG_FIELDS} for r in json.loads((P/'skku-ko-all-2026-2.json').read_text())['records']};new={};index=[]
    result={'researchOnly':True,'completionClaim':False,'scopeStable':False,'queries':index,'expectedWholeCount':2814,'previousMajorSelectors':411,'previousGeneralCategorySelectors':42,'previousPublishedDepartmentSelectorScopeOnly':True,'wholeOperatingAuditFinished':audit['allCurrentDetailsFetched'],'partialOperatingRegistrationScopeOnly':partial,'currentCensusCompleted':False}
    def post(path,action,params,out):
        q={**params,'_TRANSACTION_ID':action,'_FIRST_OUT_DS_NM':out,'_ALL_OUT_DS_NM':out+'='+out,'_MENU_ID':'EXT_SCHEDULE','_PGM_ID':'NHSSU030840M'}
        data=p.post(path+'/'+action,q,'',save=False)
        if out not in data:raise ValueError('Actual dataset absent')
        return data[out]
    def retain(rows):
        for r in rows:
            row={k:education(r.get(k))[0] for k in CATALOG_FIELDS};key=row['HAKSU_NO_BUNBAN']
            if row['GAESUL_YEAR']!='2026' or row['GAESUL_TERM']!='20':raise ValueError('Unexpected actual term')
            if key in new:
                # Course can appear in multiple curricula, but real clock/mode
                # conflicts across the source selectors must not be concealed.
                checked=('CAMPUS_GB','GYOSI_NAME','GWAMOK_NAME','BIGO','HAKJUM','PER_NAME','HAKBU_JIBJUNG_GB','SUUP_TYPE_CD')
                if any(new[key][k]!=row[k] for k in checked):raise ValueError('Public selector educational conflict')
            else:new[key]=row
    try:
        p=SpacedPublic('KO')
        for query in major['index']:
            q={k:query[k] for k in ('YEAR','TERM','HAKGWA_CD','ROAD_MAP','CAMPUS_GB','HAK_JIBJUNG')}
            rows=post('/E_NHSSU900020M','selectMain',q,'dsGrdMain');retain(rows);index.append({'type':'major','campus':q['CAMPUS_GB'],'departmentCode':q['HAKGWA_CD'],'rowCount':len(rows)})
        for campus in ('1','2','3'):
            common={'YEAR':'2026','TERM':'20','CAMPUS_GB':campus,'HAK_JIBJUNG':'0'};subjects=set()
            for query in general['index']:
                if query['campus']!=campus:continue
                rows=post('/E_NHSSU900010M','selectMain02',{**common,'YUNGYUK_ETC_CD':query['category']},'dsGrdMain02');subjects.update(r['HAKSU_NO'] for r in rows);index.append({'type':'general-category','campus':campus,'category':query['category'],'subjectCount':len(rows)})
            for code in sorted(subjects):
                rows=post('/E_NHSSU900010M','selectMain03',{**common,'HAKSU_NO':code},'dsGrdMain03');retain(rows);index.append({'type':'general-full-sections','campus':campus,'courseCode':code,'rowCount':len(rows)})
        result['currentWholeCount']=len(new)
        result['added']=sorted(new.keys()-old.keys());result['removed']=sorted(old.keys()-new.keys())
        # Missing and empty representation is equivalent for optional SSV fields.
        result['changed']=[{'offeringCode':k,'fields':[f for f in CATALOG_FIELDS if str(old[k].get(f) or '')!=str(new[k].get(f) or '')]} for k in sorted(old.keys()&new.keys()) if any(str(old[k].get(f) or '')!=str(new[k].get(f) or '') for f in CATALOG_FIELDS)]
        result['scopeStable']=len(new)==2814 and not result['added'] and not result['removed'] and not result['changed']
        closed=json.loads((P/'skku-ko-manifest.json').read_text())['cancellationCrosscheck'];result['previousPublishedCancellationNoticeCourseCount']=closed['cancelledCount'];result['knownCancelledStillPresent']=sorted(set(closed['cancelledIds'])&new.keys());result['scopeStable']&=not result['knownCancelledStillPresent']
        result['sourceDegreeCounts']=dict(collections.Counter(r['JUKYONGHAKWI_GB'] for r in new.values()))
        result['currentCensusCompleted']=True
        (P/'skku-final-current-educational-source.json').write_text(json.dumps({'researchOnly':True,'records':list(new.values())},ensure_ascii=False,indent=2))
    except BaseException as e:
        result['stopped']=True;result['failureType']=type(e).__name__;result['failure']='Normal current public census stopped; no private exception or bypass.'
    result['checkedAt']=datetime.now(timezone.utc).isoformat();path=P/'skku-final-current-scope-check.json';tmp=path.with_suffix('.tmp');tmp.write_text(json.dumps(result,ensure_ascii=False,indent=2));tmp.replace(path)
    print({k:result.get(k) for k in ('currentWholeCount','scopeStable','stopped')})
