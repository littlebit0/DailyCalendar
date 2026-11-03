# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet014-50-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={
651:[(3,840,950,'멀103')],653:[(2,1020,1130,'전205'),(4,1020,1130,'전205')],654:[(1,900,975,'B09'),(3,900,975,'B09')],655:[(5,600,710,'전205')],656:[(4,540,705,'예103')],657:[(1,810,885,'B07'),(3,810,885,'B07')],658:[(2,630,705,'전137'),(4,630,705,'전137')],659:[(2,780,890,'B07'),(4,780,890,'B07')],660:[(2,630,705,'B07'),(4,630,705,'B07')],661:[(2,780,890,'B06'),(4,780,890,'B06')],662:[(2,900,975,'전220'),(4,900,975,'전220')],665:[(2,900,1010,'B06'),(4,900,1010,'B06')],666:[(2,1080,1245,'전137')],667:[(2,720,795,'전136'),(4,720,795,'전136')],668:[(2,540,615,'전B07'),(4,540,615,'전B07')],669:[(2,810,1040,'우정원B133(창업센터-15)')],672:[(4,810,1040,'예713')],674:[(1,720,795,'외301'),(3,720,795,'외301')],675:[(1,630,705,'멀703'),(3,630,705,'멀703')],676:[(5,540,705,'멀108')],677:[(2,630,705,'멀108'),(4,630,705,'멀108')],678:[(2,810,885,'멀401'),(4,810,885,'멀401')],679:[(1,810,885,'멀703'),(3,810,885,'멀703')],680:[(1,900,975,'멀703'),(3,900,975,'멀703')],683:[(2,810,885,'멀207'),(4,810,885,'멀207')],684:[(2,990,1065,'멀205'),(4,990,1065,'멀205')],685:[(1,720,795,'멀201'),(3,720,795,'멀201')],686:[(1,810,885,'멀201'),(3,810,885,'멀201')],687:[(2,720,795,'멀206'),(4,720,795,'멀206')],688:[(2,810,885,'멀206'),(4,810,885,'멀206')],689:[(5,720,885,'멀401')],690:[(5,900,1065,'멀205')],691:[(1,540,615,'멀205'),(3,540,615,'멀205')],692:[(2,540,615,'멀206'),(4,540,615,'멀206')],693:[(2,630,705,'멀206'),(4,630,705,'멀206')],694:[(2,540,615,'멀201'),(4,540,615,'멀201')],695:[(2,630,705,'멀201'),(4,630,705,'멀201')],696:[(5,540,705,'멀206')],697:[(5,720,885,'멀206')],698:[(5,540,705,'멀201')],699:[(2,900,975,'멀101'),(4,900,975,'멀101')],700:[(2,990,1065,'멀101'),(4,990,1065,'멀101')]}
remove={651:[7,13,15],653:[15],654:[15],655:[4,6],656:[5,10,15],657:[15],658:[14,15],659:[2,15],660:[15],661:[14],662:[6,15],665:[2,15],666:[2],669:[3,7,13,15],675:[],676:[14],677:[14],678:[14],683:[6,15],684:[6,15],685:[15],686:[15],691:[15],692:[4],693:[4],696:[4,6],697:[4,6],698:[3,15]}
weeks={n:[w for w in W if w not in remove.get(n,[])] for n in HH}
weeks[668].append(8);weeks[675].append(8)
allowedWeekdays={};exceptDates={668:{'2026-10-20','2026-12-10'},675:{'2026-10-26','2026-12-14'}};examExceptions={668:{'2026-10-22'},675:{'2026-10-21'}};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={}
reasons={
651:'Explicit100percentphysical career wholeclass; mid7/final15 and blank13 held. Individualfeedback happens insideclass, not separateallocation. Wholeworksheet and 1–4year recommendation preserved.',
652:'Held: actualoperatingadditionalexplanation saysnone, notebook versus desktopifremote conditional does notestablish physicalwholemode; actualweek2YouTube and otherunallocateddelivery remainraw, not bannedforsoftwaretopic.',
653:'Ownphysical programming wholelab, holidaynonliveonly unscheduled; final15 held. Exactmicrodegree, loanednotebook and departmental variants preserved.',
654:'Ownphysical softwareengineering plus teammeetings withinwholeHH; onlyfutureconferencemakeupconditional, final15 held.',
655:'Ownphysical expertguestlectures; possiblefutureZoomnotcurrentallocatedremote; explicitclosures4/6 held,15regularlecture retained.',
656:'Ownexplicitwholephysical cloudcapstone; TBD denotes topic notclock. Actualpresentationassessments5/10/15 held; unknownfutureweekendZoom not generated. Ownarts103 literal retained.',
657:'Ownphysical robotics, holiday/reservetrainingfuturevideos notfixedHH; final15 held, robotcontrol andSLAM subjects notfieldallocation.',
658:'Ownphysical explainableAI; actualfinal14 andfinalpresentation15 held. Proposal10 is regulargroupclass, ownprof/campus preserved.',
659:'Ownphysical gameprogramming exceptweek2bodySep9Wednesday externalpresentation conflictsnativeTue/Thu andpossiblemakeup; whole2held. Final15held, actualSep24closed, Sep22regularretained.',
660:'Ownoffline machinelearning unlessunavoidablefutureevent; final15held; Stanfordmaterial andprereq2022/MLPnotice preserved withouteligibilityguess.',
661:'Ownphysical AIprogramming entiretheory+lab, GoogleColab/cloud aretools notremotedelivery; actualfinalprojectpresentation14held,15Transformerstheory retained.',
662:'Ownphysical softwareintro; actualnonliveholidayexcluded; week6Chuseokspecialoutspan inconsistentheld, mixedfinal15held. Studentdemo videos areassignmentsnotdelivery.',
663:'Held: professor-coordinatedschedule plusphysical/live combination andseparateseminarroom unspecified. No nativeweeklyregularbooking until actualallocation.',
664:'Held: actualindividualweeklymeetings andscheduleonlyhighpossibility plus plannedSep11remote. Own16unifiedpresentationdate/HH unknown; not regularsemesterrepeat.',
665:'Ownphysical gameengineering; week2bodySep9Wednesday conflictsnativeTue/Thu withplannedremotemakeup, whole2held. Final15held, Sep24closure only; textbookcopyright andAIpermissionrestrictions preserved.',
666:'Ownplan explicitly saysactualclassfollows timetable despiteweeklyindividualprojectmeetings. SourcefutureSep9Wedmakeup conflictsnativeTue whole2held, remainingwholephysicalteamclass regularHH retained, unknown16final withheld.',
667:'Ownprimarilyface-to-face numericaltheory+laptoplab; recordings onlysupplement not actualreplacementgroup. EachnativewholeHH retained; futureassignmentchanges unallocated.',
668:'ActualpreclassopenMOOC distinctfrom twiceweeklyclasshands-onkit/coaching. ExplicitOct22Thursdayregularsensorclass insideexam retained, Oct20proposalassessmentheld. Dec8Tueownholidaymakeupclass once, Dec10Thuexplicitnoclass. Scansoutsideclasshomeworknotfieldclass. Final16assessmentwithheld.',
669:'Ownweeklyphysical XRPBL despiteinstructorgraduateaffiliation; nativeundergraduateoffering scope preserved. Fieldvisits3/13 andmid7/final15assessmentheld; no campusorvisitorplaceguess.',
670:'Held: hybridgraduationthesis with eachadvisorindividualfieldguidance allocation unknown. Sourcecode/campus/prof remains, no studentresearchduration manufactured.',
671:'Held: selectedindividualadvisorthesis, firstweeke-campusrecording andresearchdeadlinesnotclasses; actualDec4presentationassessment not weeklylecture.',
672:'Ownphysical artproject wholelecture/lab including inclassindividualfeedback; futureunavoidablelive conditionalonly. Week15explicittheorylabmakeup regularHH retained, exam8/16held.',
673:'Held: physicalANDlive project withteam-specifictimetable, actualmode/daygroup allocation unconfirmed; no choosing one mode.',
674:'Ownnativewholeordinarylanguagelecture; neededonlyfutureZoom conditional notallocatedreplacement. Weeklytextlecturecurrentclass andtypingtest16 preserved; no particularZoomdate orHHextra.',
675:'Own100percentface-to-face English; actualOct21review insideexam ownMMDD exception, Oct26midheld. Dec9Wedfixedmakeuplesson retained; Dec14Monexplicitno class. MyEnglishLabassignments areauxiliary not remoteclass. Artsstudentonly restriction preserved.',
676:'OwnalwaysofflineEnglish; onlineEnglishLab andTEDreview materials areauxiliary; week14June6no-class outspandate conflictheld, not correctedtoDecember. OwnFridayHH unchanged.',
677:'OwnseparatealwaysofflineEnglish section; sameownweek14staleJune6 dateconflictheld; titleonlytimesborrow0.',
678:'OwnseparatealwaysofflineEnglish13:30 section; actualownwholeclock androom, week14June6conflictheld. Diagnosticrestriction retained.',
679:'Ownface-to-face English withwholeinclasswriting/peerediting, onlineTEDonlyteachingmaterial. Mid8mixedreview/exam cannot assigndatewithoutMMDD proof, whole8held;15regularreview retained.',
680:'Ownseparateface-to-face English15:00 section, actualwholemethods not copiedidentity; mixedexam8held,15regularhistory/review.',
681:'Heldpendingownmode: actualonline/offlinepeerreview bothused withoutclearwholeclassphysicalallocation; individualfeedback6 andfinal14exam notnormalclass. Preserveallnativeforlaterproof, not subjectbasedexclusion.',
682:'Heldpendingownmode: actual3–4onlinepeerreviews andinclasspeerdiscussion not clearlyseparate allocatedactualgroups; final14assessment andotherwholemetadata preserved. No selectingphysicalfromcheckboxheaders.',
683:'Own100percentphysical writing; librarytraining6on/offline datevariable/unallocated held. Week15one make-up andone cancelled unknownspecificday held. Internationalstudentonly andAIban retained.',
684:'Own100percentphysical writing; librarytraining6differentinformationroom anddatevariable, whole6held;15one class/one closure no actualweekdayallocationheld. Firstyearpriority preserved.',
685:'Ownphysical writing; publicinclassediting supportswhole13/14, notseparateprivateappointments. Generic15makeup mayliveonline needsallocationheld; personalessaytopicsnotdelivery.',
686:'Ownseparatephysicalwriting exact13:30HH; wholepubliceditingretained, unallocated15makeupheld; prerequisites and1styearban retained.',
687:'Ownwholelecture, groupwriting andclassdiscussion; e-campusdocumentdownload/communication/onlinepeerreview areauxiliaryactivities not evidence ofactualclassreplacement. No selectedonline orlive mode generated; userchoice remains. AIusepermissions preserved.',
688:'Ownseparatewholelecture/writing/grouppeerreview class, e-campusauxiliarysamebutowncode/HH/prof verified. No VOD orlive replacementdate generated; priorrestrictions remain.',
689:'Ownphysical topicwriting, futureunavoidableecampusonly; individualinterview explicitlyoutsideclass notone-to-oneweeklyreservation. NormalgroupwholeHH retained; presentation/peerfeedback notremote.',
690:'Ownphysical writing withfutureconditionalonline, studentwriting andgroupdiscussion wholeHH. Standardplanchanges onlyfuturecondition; ownfinal16 assessment held.',
691:'Ownwholeclassofflinegrouppeerreview explicitlydistinctfrome-campusonlinepeerreview withregularlecture/writing/commenttime; auxiliaryonline not wholeclassreplacement. Actualfinal15held, withinwholeindividualfeedback notprivateallocation.',
692:'Ownphysical writing, futureunavoidableliveonly, classroome-campusresponses auxiliary; libraryeducation4 actualroom/mode/dayunconfirmedheld. Experiences areessayhomework notfieldclasses;15wholegroupactivity retained.',
693:'Ownseparatephysicalwriting section withsameunknownlibrarygroup4held; own10:30clockverified; individualessay subjectsnotactualindividualclassschedule.',
694:'Ownphysicalfirstweekonward writing; holidaysZoomORvideo excludedcalendar, e-campusmaterials andessay feedback areauxiliarywholeclassactivities. Possibleadditionalindividualmeeting noextraHH.',
695:'Ownseparatephysicalwriting10:30, holidayreplacement excludednotinvented, allassessmentessay submissiondeadline notbooking.',
696:'Ownwholetextbooklecture/groupdiscussion/writing withattendance atstartandafterbreak, onlyactualonlinewholegroup6explicitHangeulday andclosure4held. Onlinecampus specialnotordinaryHH, sourcehomeworknotclassreplacement.',
697:'Ownseparatewholetextbookwritingclass Friday12:00, attendancewholeHH andgrouppeerreview preserved; actualonline6 andholiday4held, no priorFriday09clockborrow.',
698:'Ownphysical writing exceptactualSep18Fridaylibrarynonliverecording3held; actualfinal15held, librarymaterialsgenericnotordinaryHH.',
699:'Ownallphysicalwholewriting explicitlyconfirmed; futureconditionalonline notcurrentreplacement. Individualessayfeedback15withinclass no newallocatedprivateHH; exactprereq/firstyearban remains.',
700:'Ownseparateallphysicalwriting16:30 nativeHH; futureconditionalonline only andwholeclassessayfeedback retained, no titleonlyjoin.'}
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-651];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
 assert native and not re.sub(r'[\s,]','',slot.sub('',c['sourceSchedule']))
 assert [('월화수목금토일'.index(m[1])+1,int(m[2])*60+int(m[3]),int(m[4])*60+int(m[5]),m[6].strip()) for m in native]==HH[n] or False,(n,c['sourceSchedule'],HH[n])
 if False:
  native=native[1:]
  assert [('월화수목금토일'.index(m[1])+1,int(m[2])*60+int(m[3]),int(m[4])*60+int(m[5]),m[6].strip()) for m in native]==HH[n]
 for plan,z in zip(plans,x['plans']):
  assert plan['campus']=={'seoul':'서울','global':'국제'}[c['campus']];assert plan['header']==['2026학년도 2학기 강의계획서'] and plan['lectureCode']==c['sourceEducationalVariants'][0]['lecture_cd']
  assert plan['queriedProfessorName'] in [v['teach_na'] for v in c['sourceEducationalVariants']]
  basic=next(s['rows'] for s in plan['educationalSections'] if s['section']=='기본정보');assert [r[1] for r in basic if r[0]=='학수번호']==[plan['lectureCode']]
  normal=re.sub(r'\s+','',next(r[1] for r in basic if r[0]=='강의시간강의실'))
  for m in native:assert m[1]+m[2]+':'+m[3]+'-'+m[4]+':'+m[5] in normal and re.sub(r'\s+','',m[6]) in normal,(n,normal)
  shas[z['file']]=hashlib.sha256(pathlib.Path(z['file']).read_bytes()).hexdigest()
 rows=next(s['rows'] for s in plans[0]['educationalSections'] if s['section']=='주별강의내용');own={int(r[0][:-1]):r for r in rows if r and re.fullmatch(r'\d+주',r[0])};spans=[]
 for w in ws:
  r=own[w];a,b,z,d=map(int,re.fullmatch(r'(\d+)/(\d+)\s*~\s*(\d+)/(\d+)',r[1]).groups());spans.append((dt.date(2026,a,b),dt.date(2026,z,d),r))
 def permitted(day):
  if day.isoformat() in exceptDates.get(n,set()) or (day.isoformat() in closed and day.isoformat() not in holidayExceptions.get(n,set())):return False
  if n in explicitDates and day.isoformat() not in explicitDates[n]:return False
  return day.isoformat() in examExceptions.get(n,set()) or (not dt.date(2026,10,20)<=day<=dt.date(2026,10,26) and not dt.date(2026,12,15)<=day<=dt.date(2026,12,21))
 def actualRoom(r,base):
  w=int(r[0][:-1]);room=roomOverride.get(n,{}).get(w,base)
  if w in roomOverride.get(n,{}):assert room in ' '.join(r),(n,w,room)
  if any(k[0] in roomUnconfirmedWeekdays.get(n,set()) and k[3]==base for k in HH[n]):room=''
  return room
 meetings=[];independent=[]
 for m in native:
  if n in allowedWeekdays and ('월화수목금토일'.index(m[1])+1) not in allowedWeekdays[n]:continue
  wd='월화수목금토일'.index(m[1])+1
  for a,b,r in spans:
   day=a
   while day<=b:
    if day.isoweekday()==wd and permitted(day):meetings.append({'date':day.isoformat(),'weekday':wd,'startMinute':int(m[2])*60+int(m[3]),'endMinute':int(m[4])*60+int(m[5]),'classroom':actualRoom(r,m[6].strip())})
    day+=dt.timedelta(days=1)
 for a,b,r in spans:
  for wd,st,en,room in HH[n]:
   if n in allowedWeekdays and wd not in allowedWeekdays[n]:continue
   day=a+dt.timedelta(days=(wd-a.isoweekday())%7)
   while day<=b:
    if permitted(day):independent.append((day.isoformat(),wd,st,en,actualRoom(r,room)))
    day+=dt.timedelta(days=7)
 assert len(set(independent))==len(meetings);assert set(independent)=={(r['date'],r['weekday'],r['startMinute'],r['endMinute'],r['classroom']) for r in meetings}
 selected[c['sourceId']]=meetings;count+=len(meetings)
 proof.append({'packetOrdinal':n,'sourceId':c['sourceId'],'wholePlans':plans,'nativeClock':c['sourceSchedule'],'ownCampus':plans[0]['campus'],'literalNativeHH':HH[n],'allowedPhysicalWeeksLiteral':ws,'physicalRowsLiteral':[r for a,b,r in spans],'semanticReason':reasons[n],'explicitUnscheduledDatesLiteral':sorted(exceptDates.get(n,set())),'independentDates':sorted({k[0] for k in independent}),'literalIndependentMeetings':[list(k) for k in sorted(independent)],'ownExamNormalExceptionsLiteral':sorted(examExceptions.get(n,set())),'ownHolidayNormalExceptionsLiteral':sorted(holidayExceptions.get(n,set())),'ownExplicitDatesLiteral':sorted(explicitDates.get(n,set())),'ownRoomOverridesLiteral':roomOverride.get(n,{}),'roomUnconfirmedWeekdaysLiteral':sorted(roomUnconfirmedWeekdays.get(n,set())),'allowedWeekdaysLiteral':sorted(allowedWeekdays.get(n,set())),'newDateCount':len(meetings),'previousResearchDepartmentRemarks':c['departmentRemarks'],'remoteHoursGenerated':0})
for campus in ['seoul','global']:
 old=json.load(open(P/f'khu-{campus}-2026-2.packet013-physical-groups-prepared.json'));(P/f'packet014-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':14}
 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet014-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet014-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2461,'baselineDates':46345,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2461+len(selected),'totalDates':46345+count})
