import json,pathlib
p=pathlib.Path('work/university-research/catalog-g')
entries=[]
def add(codes,kind,summary,unresolved=False,exceptions=None):
 for code in codes.split(): entries.append({'courseCode':code,'contextClassification':kind,'review':summary,'periodDateExpressionsReconciled':True,'completeOperatingScheduleVerified':False,'unresolvedMakeupOrDelivery':unresolved,'explicitExceptions':exceptions or []})
add('61225001 61225002 61225003','textbook_sections','Ch2.2–2.5, Ch2.6–2.12 and Ch4.1–4.3 denote textbook sections, not meeting dates.')
add('61684001','historical_events','5.4 movement and 6.25 war are historical subject matter, not 2026 meeting dates.')
add('61066001','assignment','October13 PPT submission precedes the scheduled class; no additional meeting asserted.')
add('61314002','scheduled_exam','October8 midterm falls on the listed Thursday course day.')
add('61402001','scheduled_exam','October8 and November19 exams fall on listed Thursday course days.')
add('61431002','scheduled_exam','October21 and November18 exams fall on listed Wednesday course days.')
add('61431007','scheduled_exam_and_assignment','September23, October7, October23, November20 quiz/exam dates match Wednesday/Friday meetings. October4, November8, November18 23:59 are project deadlines, not extra class meetings.')
add('61524001','scheduled_exam_and_assignment','October6/November10 are assignment dates; October7/November11 exams match Wednesday meetings.')
add('61586001','scheduled_exam','October13 10:00–11:50 exam matches listed Tuesday2/3, subject to official clock table validation.')
add('61490001','scheduled_activity','Published Monday/Tuesday dated lectures match timetable. October5 field trip is explicit, but additional location/clock are not published.',False,[{'date':'2026-10-05','kind':'field_trip','time':'not additionally published'}])
add('60000060','entrance_exam_notice','November30/December1 are university entrance essay dates; this plan does not explicitly cancel class or state online delivery.',False)
add('60000070','online_exception','November30 and December1 are explicitly online because of building control.',False,[{'date':'2026-11-30','kind':'online'},{'date':'2026-12-01','kind':'online'}])
add('61142001 61142002','online_exception','September24 and25 explicitly non-face-to-face; October8 midterm matches normal Thursday.',False,[{'date':'2026-09-24','kind':'online'},{'date':'2026-09-25','kind':'online'}])
add('61170001','online_exception','October5 explicitly non-face-to-face due to substitute holiday.',False,[{'date':'2026-10-05','kind':'online'}])
add('61395001 61395002','weekly_online_exception','Week4 Chuseok online replacement and week6 Hangul Day online expert lecture. Only original Thursday/Friday occurrences inside these named ranges apply; no new meeting clock inferred.',False,[{'week':4,'kind':'online_replacement'},{'week':6,'kind':'online_expert_lecture'}])
add('61674001','online_exception','September24 explicitly recorded online lecture.',False,[{'date':'2026-09-24','kind':'recorded_online'}])
add('61330001','makeup_exception','September17 Thursday canceled →September20 Sunday15:00; October1 Thursday canceled →October4 Sunday15:00. Makeup end/room not published. September24 realtime online.',True,[{'canceledDate':'2026-09-17','date':'2026-09-20','startClock':'15:00','endClock':None,'kind':'makeup'},{'canceledDate':'2026-10-01','date':'2026-10-04','startClock':'15:00','endClock':None,'kind':'makeup'},{'date':'2026-09-24','kind':'realtime_online'}])
add('61330005','unspecified_makeup','Week4 Chuseok and week6 Hangul Day compensated in November makeup week; exact date/time not published.',True)
add('61033001','unspecified_makeup','Chuseok closure and planned makeup; date/time not published.',True)
add('61415002','unspecified_makeup','September25/October9 replacement class by later consultation; exact replacement date/time not published.',True)
add('61475001','unspecified_makeup','September25 canceled for Chuseok; makeup time to be decided.',True)
add('60015001','weekly_online_exception','Week4 and week6 explicitly online; timetable Friday6–8.',False,[{'week':4,'kind':'online'},{'week':6,'kind':'online'}])
add('60000049','delivery_notice','Week13 entrance essay non-face-to-face, without exact day; do not mark every meeting of week online.',True)
add('61442001','online_activity','Week5 plan submission, week7 field work and week12 final report are non-face-to-face activities; do not infer blanket cancellation of scheduled meetings.',False)
add('61274001','unspecified_makeup','Hangul Day makeup planned, date/time not published.',True)
add('61310001 61310002','online_exception','National Foundation Day substitute holiday explicitly non-face-to-face; official 2026 calendar identifies October5.',False,[{'date':'2026-10-05','kind':'online'}])
add('61314001','weekly_online_exception','Week4 explicitly online Zoom.',False,[{'week':4,'kind':'online_zoom'}])
add('61322002','unspecified_makeup','Week4 Chuseok cancellation and separate makeup; date/time not published.',True)
add('61414001','subject_matter','Online surveys are research subject matter, not proof of online delivery.')
add('61541001 61541002','weekly_online_exception_and_exam_notice','Week5/6 explicitly non-face-to-face; midterm date and location to be announced.',True,[{'week':5,'kind':'online'},{'week':6,'kind':'online'}])
add('61577001','subject_matter','Collecting comments on an AI online platform is learning subject matter, not an online delivery exception.')
add('61588001','subject_matter','AI online monitoring/advocacy is learning subject matter, not an online delivery exception.')
add('61137001','online_activity','Week5 EBS video, online discussion and team activities do not prove every scheduled physical meeting is canceled.',False)
raw={r['sourceRow']['HAKSU_NO']:r for f in ['gachon-short-report-context-audit.json','gachon-short-report-operating-audit.json'] for r in json.loads((p/f).read_text())['reports']}
for e in entries:
 assert e['courseCode'] in raw,e['courseCode']
 e['publicSchedulingContexts']=raw[e['courseCode']]['publicSchedulingContexts']
 e['sourceTime']=raw[e['courseCode']]['sourceRow']['TIME']
 e['reportIdentity']=raw[e['courseCode']]['report']
b={'researchOnly':True,'completionClaim':False,'term':'2026-2','source':'Current anonymous public course report; selected scheduling context only; no original PDF, internal identifier or contact persisted','reviewedCount':len(entries),'rows':entries}
(p/'gachon-short-report-context-review.json').write_text(json.dumps(b,ensure_ascii=False,indent=2))
print('reviewed',len(entries))
