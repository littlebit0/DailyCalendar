# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet015-50-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={
701:[(2,810,885,'멀109'),(4,810,885,'멀109')],702:[(2,900,975,'멀109'),(4,900,975,'멀109')],703:[(2,900,975,'멀201'),(4,900,975,'멀201')],704:[(2,990,1065,'멀201'),(4,990,1065,'멀201')],705:[(1,540,615,'멀206'),(3,540,615,'멀206')],706:[(1,630,705,'멀206'),(3,630,705,'멀206')],707:[(1,810,885,'멀207'),(3,810,885,'멀207')],708:[(1,900,975,'멀207'),(3,900,975,'멀207')],709:[(1,900,975,'멀401'),(3,900,975,'멀401')],710:[(1,990,1065,'멀401'),(3,990,1065,'멀401')],711:[(2,540,615,'멀207'),(4,540,615,'멀207')],712:[(2,630,705,'멀207'),(4,630,705,'멀207')],713:[(1,720,795,'멀408'),(3,720,795,'멀408')],714:[(1,810,885,'멀408'),(3,810,885,'멀408')],715:[(1,630,705,'멀610'),(3,630,705,'멀610')],716:[(1,720,795,'멀610'),(3,720,795,'멀610')],717:[(1,900,975,'멀610'),(3,900,975,'멀610')],718:[(2,630,705,'멀410'),(4,630,705,'멀410')],719:[(2,720,795,'멀410'),(4,720,795,'멀410')],720:[(1,630,705,'멀407'),(3,630,705,'멀407')],721:[(1,720,795,'멀407'),(3,720,795,'멀407')],722:[(5,540,705,'멀408')],723:[(5,720,885,'멀408')],724:[(2,630,705,'멀610'),(4,630,705,'멀610')],725:[(5,720,885,'멀611')],726:[(1,630,705,'멀611'),(3,630,705,'멀611')],727:[(1,720,795,'멀611'),(3,720,795,'멀611')],728:[(1,990,1065,'멀611'),(3,990,1065,'멀611')],729:[(4,540,705,'멀603')],730:[(4,720,885,'멀603')],731:[(1,540,615,'멀410'),(3,540,615,'멀410')],732:[(1,630,705,'멀410'),(3,630,705,'멀410')],733:[(1,810,885,'멀410'),(3,810,885,'멀410')],734:[(1,900,975,'멀410'),(3,900,975,'멀410')],735:[(1,810,885,'멀611'),(3,810,885,'멀611')],736:[(1,900,975,'멀611'),(3,900,975,'멀611')],737:[(2,720,795,'멀610'),(4,720,795,'멀610')],738:[(2,810,885,'멀610'),(4,810,885,'멀610')],739:[(5,720,885,'멀107')],740:[(3,540,705,'멀607')],741:[(3,900,1065,'멀607')],742:[(2,540,615,'멀409'),(4,540,615,'멀409')],743:[(2,630,705,'멀409'),(4,630,705,'멀409')],744:[(3,540,705,'멀601')],745:[(3,900,1065,'멀601')],746:[(3,720,885,'멀815')],747:[(3,900,1065,'멀815')],748:[(5,720,885,'멀604')],749:[(5,900,1065,'멀604')],750:[(1,720,795,'멀409'),(3,720,795,'멀409')]}
remove={703:[10],704:[10],709:[9],710:[9],715:[15],716:[15],717:[15],718:[15],719:[15],722:[4,6],723:[4,6],729:[15],730:[15],731:[15],732:[7,15],733:[15],734:[13],735:[15],736:[15],737:[15],738:[15],739:[9,15],740:[15],741:[15],742:[4,15],743:[4,15],744:[15],746:[11,14,15],747:[11,14,15],748:[10],749:[10],750:[15]}
weeks={n:[w for w in W if w not in remove.get(n,[])] for n in HH}
allowedWeekdays={};exceptDates={711:{'2026-10-08'},712:{'2026-10-08'}};examExceptions={};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={}
reasons={
701:'Ownphysicalwritingdefault; futureconditionalonline notallocatedcurrentreplacement. Allwritingdoneinclass andactualwithinclassindividualfeedback notprivateappointment. Sep24holidayonlineexcluded; ownNov10/12 andDec3peerreview consistent. Prereq/firstyearban preserved.',
702:'Ownseparatephysicalwriting15:00wholeHH androom; owncurrentplanidentities verified. Inclassfeedback andpeerreview retained; holidayonline notbooked. Allnativefirstyear/prereqrestrictions remain.',
703:'Ownphysicalwholewriting withauxiliarye-campusactivities; week10online libraryeducation lacksindividualdayallocation whole10held. Classfeedback15retained, personalessaytopic notprivateclass.',
704:'Ownseparatephysicalwriting16:30; whole10libraryrecordingallocationheld. Allclasswriting/feedback normalnativeHH, no selectinglibraryday orroom.',
705:'Ownexplicit100percentphysicalwriting, onlinepeerreview auxiliarynotwholeclassreplacement; allnormalweeklygroups retained. Materialsuploadedonline notremoteclass.',
706:'Ownseparate100percentphysicalwriting10:30; actualcode/prof/classroom andfirstyearpriority preserved, auxiliaryonlinepeerreview notblockedwholeclass.',
707:'Ownphysicalwriting, onlyholidayfuturevideo replacementunallocated; regularwholeclassHH andfeedback retained, worksheetstyping notremote.',
708:'Ownseparatephysicalwriting15:00, firstyearpriority preserved; futureholidayvideo notordinarybooking. Allactualnormalgroups retained.',
709:'Ownphysicalwriting; week9one-to-oneindividualinterview allocationunknown whole9held. Week15studentpresentation+Q&A entireclass notprivateappointment.',
710:'Ownseparatephysicalwriting16:30; ownindividualinterview9held, publicstudentpresentation15 retained. No titleonlyidentityjoin.',
711:'Ownphysicalwriting; exactOct8online library excluded onlyThu, ownTueOct6 regularclass retained. Exam8mixedreview withoutexactnormaldayheld. Regular15debate retained.',
712:'Ownseparatephysicalwriting10:30 exactOct8libraryexcluded; TueOct6 retained. Wholeexam8 noindependentMMDDpriorityheld. Allrestrictions/room/raw preserved.',
713:'Ownwholeordinaryclass firststudentpresentation thenlecture, online onlyfuturemakeup ande-campushomework; notcurrentallocatedremote. OwnOct21/Dec16assessmentsheld, regularwholeHH preserved.',
714:'Ownseparatewholelecture/presentation13:30 withfutureonlineonlynonregularmakeup. ActualnormalnativeMonWedHH retained, assessment8/16 notreservation.',
715:'Ownexplicitinpersonvalueclass; whole15mixeddiscussion/finalassessmentheld. Regularordinarygroups retainnativeHH; digitalcontenttheorynotdelivery.',
716:'Ownseparateinpersonvalueclass12:00; mixedfinal15unknownallocationheld. Nativefirstyearpriority andmaterials unchanged.',
717:'Ownseparateinpersonvalueclass15:00; mixedfinal15held, classroom/sourcecode verified. Textbookexamples notremoteclasses.',
718:'Ownexplicitphysicalvalueclass; unknownliveORvideo genericmakeup15held. Allotherordinarywholegroups nativeTueThuHH confirmed.',
719:'Ownseparatephysicalvalueclass12:00; unallocatedmakeup15held, unknownextraonlineHH notgenerated; wholeeducationrestriction preserved.',
720:'OwnphysicalCosmosbookdiscussion. Week8teachingvideo ismaterialnotdelivery, butassessmentcalendar withoutliteralnormaldate held. Allotherwholegroups retained.',
721:'Ownwholeclasslecture/inclassopinions, e-campusPDF/submissionsauxiliary; graduatefaculty affiliation doesnotchangeUGoffering. ExactOct5nonliveclosureexcluded; Oct21/Dec16assessmentheld.',
722:'OwnphysicalFriday09whole165minuteclass first75lecture+second75dialog. Oct9explicitwholelive excludedfromphysical packet, candidatependingseparateproof; Sep25closed. Actualexam09–10:15 notregular165booking.',
723:'OwnseparatephysicalFriday12whole165minuteclass, actualOct9wholeliveexcludedphysical; ownexam12–13:15notregular165. LiteralMMDDconsecutiveanchor andsourcefull preserved.',
724:'Ownexplicitphysicalvalueclass, futureonlineholidaymakeupnotordinarydelivery. NativeTueThu10:30HH androom, restrictions/materials retained.',
725:'ExplicitflippedpreclassVOD MonTue/WedThu distinctfromactualwholeFridayphysicalclass12:00. Preclassvideo windows notweeklyclasses.',
726:'OwnphysicalMonWed10:30 actualwholeHH distinctfrompreclass2dayVOD SatSun/MonTue. No lecturevideoreservation; no removingflippedteachingformat.',
727:'OwnseparatephysicalMonWed12:00; samepreclasswindowexplicitdistinctbutownnativeidentity independentlychecked. AuxiliaryVOD notphysicalclassreplacement.',
728:'OwnseparatephysicalMonWed16:30; preclassVODdistinctfromattendanceclass. Allnativepriority/title/prof/room preserved.',
729:'Ownphysicalworldcitizenwholelecture/debate; GCPoutsideclassactivities distinctfromwholeclass. Explicitno-midterm8regularlecture lacksliteralMMDD exception so conservativeheld8; actualfinal15held.',
730:'OwnseparatephysicalThursday12worldcitizenwholeclass. No-midterm8normaltopic noexactdatedexception withheldconservatively; final15held. GCPfieldworkoutsideordinaryclass notnewHH.',
731:'Ownexplicitphysicalvalueclass; genericmakeup15futureliveconditional allocationunknownheld. OthernativewholeMonWedregularclasses retained.',
732:'Ownphysicalvalueclass; week7normaltopicbutactualBIGOinpersonexam contradiction heldwhole7 withoutselectingone. Generic15makeupheld; rawconflict preserved.',
733:'Ownseparatephysicalvalueclass13:30; futureconditionalonline makeup15unknownwholemodeheld, notreservation. Ownwholecode/prof/room verified.',
734:'Ownseparatephysicalvalueclass15:00; week13genericmakeuplabel couldonline unknownheld. Week15normalwholelecture retained. No overwritingactualweeklyallocation.',
735:'Ownphysicalvalueclass; classroomattendance ande-campuspeerresponses auxiliary; futureholidaynonliveonly excluded. Week15actualfinalheld.',
736:'Ownseparatephysicalvalueclass15:00; rawfutureZoomattendance condition notactualwholemode. Final15held; remainingphysicalregularclasses retained.',
737:'OwnseparatephysicalTueThu12:00valueclass; ordinarylectures andpeerdiscussion retainwholeHH. Final15held andholidayonline unallocated.',
738:'OwnseparatephysicalTueThu13:30valueclass; actualcode/room checked. Final15held, Zoomfutureattendancepolicy notcurrentreplacementgroup.',
739:'Ownphysicaldefaultworldcitizenregularlecture; week7fieldresearchpresentation/debate inclassnotfieldtrip. Week9actualinterview/researchfieldallocationunknownheld,15finalassessmentheld.',
740:'Ownphysicalworldcitizenwholeclass; video9actualteachingmaterialnotdelivery. StudentGCPfieldvisits/videos assignmentsoutsideclass notallclassreservation. Final15assessmentheld, exam16finishnoMMDDexceptionheld.',
741:'OwnseparatephysicalworldcitizenWed15:00; video/materialandoutsideGCPassignment separatefromwholeclass. Final15held and16examcalendar withheld; nativepriority/specialty preserved.',
742:'Ownphysicalvalueclass; whole4labelChuseokholiday createsuncertainSep22allocation so4held. Generic15makeuppossiblyonlineunknownheld. Allremainingwholegroups exactnative.',
743:'Ownseparatephysicalvalueclass10:30; ownwhole4holidayallocationuncertainheld,15genericmakeupheld; no guessedSep22specialclass.',
744:'Ownexplicitphysicalworldcitizen; onlineplatform/media subjects andprojecttools notdelivery. Week15finalassessmentheld,8groupfeedbacknotfixedindividualclass. Whole14groupactivityinclass retained.',
745:'Ownwholeworldcitizen theory/lecture/inclassgroupdiscussion, onlineplatformonlysubject/tool. No actualwholeonline replacementgroup. Week15GCPpresentationgroupactivity normalwholeclass (final16), nativeEnglishtrackpriority andall-English restriction preserved.',
746:'Ownwholeworldcitizenlecture/groupdiscussion andinclassGCP expresslyactualwholeclass; week11onlineconsultingunknownlivevsrecordedheld. Actualfinalpresentations14/15held. Futuremethodschange conditionalnotcurrentreplacement.',
747:'Ownseparatewholeworldcitizen15:00actualclass; own11onlineconsultingheld, final14/15held. Firstclassmandatory andnativefirstyearpriority preserved; no overridingplannedonlineweek.',
748:'Ownexplicitphysicaldefaultworldcitizen; week10autonomousGCPfieldallocationunknownheld. Week15wholeworkshop/presentationdiscussion retained, finalreportoutsideclass notwholeexam. Futuremodechangeunallocated noextraHH.',
749:'OwnseparatephysicalFriday15worldcitizen, actualautonomous10held. Whole15workshopnormalclass, fieldtopicnotallfieldwork; nativeeducation fields preserved.',
750:'Ownexplicitrealtimeinpersonvaluelecture, e-campustopicdiscussion auxiliary. Week15holidaymakeuppossiblyonline unknownallocationheld. Classmediaexamples notwholemode, nativeMonWed12HH unchanged.'}
assert len(HH)==len(reasons)==50
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-701];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
 old=json.load(open(P/f'khu-{campus}-2026-2.packet014-physical-groups-prepared.json'));(P/f'packet015-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':15}
 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet015-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet015-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2503,'baselineDates':47247,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2503+len(selected),'totalDates':47247+count})
