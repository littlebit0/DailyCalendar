# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet016-50-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={751:[(1,810,885,'멀409'),(3,810,885,'멀409')],752:[(1,990,1065,'멀204'),(3,990,1065,'멀204')],753:[(1,990,1065,'멀608'),(3,990,1065,'멀608')],754:[(5,540,705,'멀210')],755:[(5,720,885,'멀602')],756:[(5,540,705,'멀411')],757:[(5,540,705,'멀826')],758:[(5,720,885,'멀826')],759:[(1,720,795,'멀210'),(3,720,795,'멀210')],760:[(1,900,975,'멀513'),(3,900,975,'멀513')],761:[(2,720,885,'멀512')],762:[(1,630,705,'멀612'),(3,630,705,'멀612')],763:[(1,630,705,'멀826'),(3,630,705,'멀826')],764:[(1,810,885,'멀612'),(3,810,885,'멀612')],765:[(5,540,705,'멀602')],766:[(2,540,615,'멀704'),(4,540,615,'멀704')],767:[(2,810,885,'멀513'),(4,810,885,'멀513')],768:[(1,810,885,'멀513'),(3,810,885,'멀513')],769:[(1,540,615,'멀704'),(3,540,615,'멀704')],770:[(3,540,705,'멀602')],771:[(1,540,650,'체B120호')],772:[(3,900,1065,'멀512')],773:[(4,540,650,'체215-3호')],774:[(4,660,770,'체215-3호')],775:[(3,600,710,'글403')],776:[(2,630,740,'체215-3호')],777:[(5,540,705,'멀612')],778:[(2,900,975,'멀612'),(4,900,975,'멀612')],779:[(1,900,975,'멀608'),(3,900,975,'멀608')],780:[(3,720,885,'멀512')],781:[(3,1080,1130,'외402')],782:[(2,630,705,'멀513'),(4,630,705,'멀513')],783:[(1,540,615,'멀608'),(3,540,615,'멀608')],784:[(1,630,705,'멀208'),(3,630,705,'멀208')],785:[(1,720,795,'멀208'),(3,720,795,'멀208')],786:[(2,810,885,'멀704'),(4,810,885,'멀704')],787:[(2,900,975,'멀512'),(4,900,975,'멀512')],788:[(2,720,795,'멀704'),(4,720,795,'멀704')],789:[(2,810,885,'멀702'),(4,810,885,'멀702')],790:[(2,900,975,'멀702'),(4,900,975,'멀702')],792:[(1,630,705,'멀513'),(3,630,705,'멀513')],793:[(5,630,795,'멀204')],794:[(4,540,650,'멀402')],795:[(3,660,770,'멀402')],796:[(1,810,920,'멀402')],797:[(3,660,770,'멀604')],798:[(3,810,920,'멀604')],799:[(4,720,770,'멀402')],800:[(4,930,980,'멀402')]}
remove={751:[15],752:[5,15],754:[4,6,15],756:[15],759:[4,6,15],761:[15],763:[15],764:[15],765:[4,6,9],766:[1,2,7],769:[9],770:[14,15],771:[5,15],773:[4],774:[4],775:[1,15],776:[15],777:[4,6,15],779:[15],780:[15],781:[6,7],784:[15],785:[15],786:[15],787:[15],788:[15],792:[15],793:[15],794:[15],795:[15],797:[15],798:[15],799:[4],800:[4]}
weeks={n:[w for w in W if w not in remove.get(n,[])] for n in HH}
allowedWeekdays={};exceptDates={789:{'2026-10-01','2026-11-26'},790:{'2026-10-01','2026-11-26'}};examExceptions={};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={}
reasons={
751:'Ownrealtimeinpersonvalueclass, auxiliarye-campusdiscussion; unallocatedonlinepossiblemakeup15held. OwnMonWed13:30HH preserved.',
752:'OwnphysicalevolutionmedicinegeneralUGtheory, holidaylivepotential notextraHH. Week5Oct1Chuseokclosurebody conflictsownMonWed/currentcalendar contextheld; mixedfinal15held. Disease/patientreportassignment notclinicalplacement.',
753:'Ownphysicalriverculturetheory withteachingvideos; localriverfieldvisitreport ishomeworknotwholefieldclass. Futureoptionalnonlive notcurrentallocation. Regularwholeclass retained.',
754:'Ownphysicalclimatetheory; documentaryvideos arematerialsnotremotegroups. Actualholiday4/6excluded andunallocatedmakeup15held; instructorSeoulemployment notInternationalofferingcampus.',
755:'Ownphysicalmindtheory UGscope despitegraduatefacultydepartment; hypotheticalfutureholidayrecordingnotregularmode. Allordinarywholeclasses retained.',
756:'Own100percentphysicalviolencetheory; futureunableattendance nonliveonly, unknownmakeup15held. Violentbehavior subjectnotfieldactivity; exactawards preserved.',
757:'Ownphysicalpersuasionlecture+ingrouppractice; media/materialupload auxiliary. OwnFriday09wholeHH andregular15speechpractice retained, examcalendarheld.',
758:'OwnseparatephysicalpersuasionFriday12wholeHH. Actuallecture+speechpractice regularclass, digitalmaterialnotremotedelivery; awards/assessments preserved.',
759:'Ownphysicalsciencelecture. ActualSep23/28online4held; week6bodyOct5outspanplannedonline conflictwhole6held. Exam8onlineOct26unknownmode notreserved;15finalheld. Onlineattendancevideoaux notallclassmode.',
760:'Ownphysicalclassicalartlecture withaudiovisualmaterials, nonliveonlyfutureholidaymakeup. Actualordinarywholegroups retained; artworkcities notfieldtravel.',
761:'Ownphysicalarttheory; exhibitionvisit isoutsideclassreportassignment notwholefieldtimetable. Final15assessmentheld, reserve16unknownheld; imagesonlineonlyclassmaterials.',
762:'Ownwholelecture/discussion andvideo+QA teachingmaterial; no publishedremoteclassreplacement. Chinesecivilizationtravel6 issubjectnotactualfieldtour allocation. NativeordinaryMonWedwholeclock retained.',
763:'Ownphysicallanguageclass; Oct5onlyactualVODholidayexcluded. Whole15actualDec14finalassessmentandotherdayunallocatedheld; exam8/16noextraordinarydates. OnlinePDFanddiscussionhomework auxiliary.',
764:'Ownseparatephysicalsemantics13:30, textbookBrainSurgery-TheVideo andFilm11:00 aretopics notlessonmodeorclock. Actualmixedfinal15held, Oct5VODclosureexcluded.',
765:'Ownphysicalmindfulness+meditationpractice; actual6Hangeulday realtimeZoom excludedphysicalcandidate (separateexactproofneeded). Actual9midtermheld;8ordinarytopicbutexamcalendarnoMMDDpriorityheld.',
766:'Ownface-to-facelawclasses; actual1/2audioPPTandselfpaced24hattendance areprerecordedgroupsheld. Whole7mixedtakehomeassessmentheld; allremainingnormallecture/presentations sourcephysical. Detailedprivatefutureplan notinvented.',
767:'Ownphysicaleconomicstheory/whiteboardlecture; legalholidaysnonliveorfuturemakeupunallocated. Uploadedslides notactualonlineclass. Allnativewholeeducationfields retained.',
768:'OwnphysicalEuropeanculturelecture; futureholidaynonliveconditional only. Europeancitylist anddocumentaries aretheorysubjects/material notactualfieldtravel.',
769:'OwnphysicalKoreanissueslecture; fieldvisit explicitlyforassignment notordinaryclass. Actual9midtermheld;8normaltheory lacksdatedexamexceptionheld. FutureZoommakeup notgenerated.',
770:'Ownphysicalfilmtheory withclipsscreenedinsideclass, alltheorydiscussion regularHH. Actual14finalprojectassessment and15finalheld. Filmviewingnotprerecordedlesson.',
771:'Ownphysicalselfdefensepractice; whole5holidayonlineORclosureplannedheld and15conditionalearlyfinalheld. Futureweatheroutdoors unallocatedcannotinventnewroom/day; currentnativegym andallwarnings remain.',
772:'Ownphysicalsportssocietytheory, multimedia20percent ismaterials notremote orsportpractice. E-campusassignments/slidesauxiliary; allnormalwholeclasses preserved.',
773:'Ownphysicalbadminton atownpublishedgym, whole4Chuseokclosureheld and8/16practicalassessmentheld. GroupA/B/Clevelpracticeinsidewholeclass notnewsections; viewingmatchreportoutsideclass.',
774:'Ownseparatephysicalbadminton11:00gymwholeHH. Actual4closure andpracticalexamsheld; classleaguepractice notfieldcourseorallocatedindividualappointments.',
775:'Owncurrentphysicalpilatespractice, actual1nonliveorientationheld and15blankheld. Weather6/7possibleactivitychanges notactualalternatewholemode; futuremodechanges unallocated, preservesrawconditions.',
776:'OwnphysicalbadmintonTue10:30wholegymHH; actual15mixedfinaltermheld. Normal8practice sourceexistsbutexamcalendarnoactualMMDDexception withheldconservative. Courtpracticeindividualskillnotprivateclass.',
777:'Ownphysicalbigdatatheory/lab, holidayrecordings4/6excluded and15finalassessmentheld. Surfing/socialmedia/videos areanalysiscase topicsnotfieldorwholeonlineclasses. Sportsdivisiononlyrestriction preserved.',
778:'Ownwholetheory/discussionlectures andinclassattendance/electroniccheck+randomcalls; onlinewrittenresponse andwatchingassignedfilmsauxiliary. Remote/futuretech islessoncontent notdelivery. Exam8/16conditionalreplacementheld.',
779:'OwnwholeinclassSFlecturer+studentQA; film/drama/YouTubeactualteachingmaterials notprerecordedlessons. Oct5onlyholidayrecordingexcluded,15makeupscopeunknownheld.',
780:'Ownexplicitphysicalmobilitytheory; remotelyconnectedsociety andvideo-conference aretopicsnotdelivery. GCPinclassfeedbackregular11/14, actual15finalreportpresentationassessmentheld.',
781:'Ownwholeordinaryseminar/presentation/dialogue, Zoomonlyifneededfuture. Actualindividualcounseling6/7unknownallocationheld; normal15wholegroupdialogueretained, foreignfreshmanonly restrictionintact.',
782:'Ownphysicalengineeringmanagementtheory; futureonlinewholegroup announcedonlyifneeded unallocated. E-campusuploadnotdelivery andbusinessscenarioexercise notfieldassignment.',
783:'OwnphysicalJapanesetextbookpronunciationclass; Oct5onlyonlineholidayexcluded, videos areculturelearningmaterials. Japanese/Japanese-majorban preserved, individualconversationwithinclassnotprivateallocation.',
784:'Owncurrent2026-2physicalSpanish; actual15makeupORnonliveallocationunknownheld. Songs/videos insideclass notrecordedclassdelivery. Spanishnational/major andpriorSpanishstudyorstayrestrictions preserved.',
785:'OwnseparatephysicalSpanish12:00, actualsamewholemethods butownclock/sourceidentity verified. Unknown15makeupheld andschoolenrollmentban preserved.',
786:'OwnphysicalKorean1languagepractice; onlineuploadedvideoonlyfuturemakeup unknown16held, actual15finalheld. Allforeignstudentonlyfields preserved.',
787:'OwnseparatephysicalKorean2languagepractice exactTueThu15:00; actual15finalheld, onlinefuturemakeupnotextraHH. Originalforeignstudentonlyscope retained.',
788:'OwnwholeJapaneseteacherexplanation+repeatpronunciation/materialfilm practice withactualclassparticipation. Japaneseculturestroll islearningcornernotfieldtrip;15finalheld. NativeJapanese-national/majorban unchanged.',
789:'OwnphysicalKoreanwriting; Sep24holidayvideo excluded andownOct1/Nov26explicitnoclass withheld. Assignment5rewritingsubmissiondeadline notreservation; normal15wholeclasswritingretained.',
790:'OwnseparatephysicalKoreanvocabulary15:00; explicitdatedTue/Thu ownanchors agree2026. ActualOct1/Nov26noclass excluded, Sep24VODnotbooked. Padletpreparationtheninclassgroupdiscussion auxiliary.',
791:'Held: explicitphysicalANDrealtimeonlinewholeclasses withparticularfilm/musicfocusremote, butactualweeklymethod tabledoesnotselectmodeforgroups. Outdoor12allocationunknown andfinal15/16assessment. No selectingphysicalbytopdefault orassumingrecordedclock.',
792:'Ownphysicaldigitaltransformationtheory; remoteera/networks/mobile/videoaretopicsnotallocatedonlineclasses. Unknown15makeupheld; SWmicrodegree/allmajorsnotice exactpreserved.',
793:'Ownflippreclasswatchingexplicitlydistinctfromcomingtoinclassdiscussion/gameprogrammingwholelab. Final15held; notebook/codinggame isactivitynotremoteclass, allmicrodegree/replacementcoursefields remain.',
794:'Ownwholecollaborativeclasslecture+PPTpresentation+20–30minactualclassdiscussion. Online/offlineteachertraining4issubjectnotcoursemode. Actual15finalheld, no-midterm8noownMMDDexception withheld.',
795:'Ownseparateteacherpracticalwholecollaborativelecture/presentation/discussion withactualWednesday11:00HH. Online/offlinetrainingtheorynotclassdelivery;15finalheld andallassignmentoptionspreserved.',
796:'Ownallphysicalschoolviolenceclass; actualvideo13forinclassdiscussionmaterial notremoteclass. Holidaymakeupgeneric noactualdateprioritynotinvented, normal15wholediscussionretained.',
797:'Ownphysicalschoolviolencetheory andmockcounselingwithinclass, actual15individuallearningunallocatedheld. Teaching-practicumalternatetasksforcertainstudents notwholeclasssemesterperiod.',
798:'Ownphysicaleducationhistorytheory; actual15individuallearningORmakeupallocationunknownheld. E-campusPDF/assignmentuploadsauxiliary; individualteaching-practicumadjustmentkeptraw.',
799:'Ownphysicaldigitaleducationlecture/lab, preclassLMS explicitbeforeattendingregularclass. AIvideocreationtopicnotprerecordedmode. Exact4closureheld, assessments8/16held, normal15literacyclassretained.',
800:'Ownseparatephysicaldigitaleducation15:30whole50minuteHH; priorLMSlearningexplicitbeforeclass distinctfromactualattendancegroup. Allowncode/room/educationfields retained, no borrowing12:00clock.'}
assert len(HH)==49 and len(reasons)==50
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-751];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
 old=json.load(open(P/('packet015b-exact-oct9-live/khu-global-2026-2.exact-oct9-live-prepared.json' if campus=='global' else 'khu-seoul-2026-2.packet015-physical-groups-prepared.json')));(P/f'packet016-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':16}
 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet016-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet016-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2553,'baselineDates':48342,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2553+len(selected),'totalDates':48342+count})
