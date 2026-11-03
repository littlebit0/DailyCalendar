"""Review source-specific makeup mode before applying any school common date."""
import json
from pathlib import Path
R=Path(__file__).resolve().parent
cases={
'1190-7004-00':('datedCurrentInpersonOverridesExplicit2021Field','Current2026-2 explicitlyinperson; separate2021-2 mixedZoom field ishistorical, notcurrentconversion. Sourcecurrentindividualfinal/date/makeupactualnotconfirmed.'),
'1190-7004-01':('datedCurrentInpersonOverridesExplicit2021Field','Current2026-2 explicitlyinperson; historical2021remote/makeup-info instructionnotactualcurrentdate. CurrentMon/Thusectionclock/roomretain; actualindividualperiod/makeupunknown.'),
'1190-7004-02':('datedCurrentInpersonOverridesExplicit2021Field','2026-2 explicitlyinperson,2021-2 remote policy separate. Sourceweeklytopic ordercanchange; do notreuseoldremoteoperations; actualcurrentperiod/final/makeupunconfirmed.'),
'1101-2006-00':('holidayFileUploadAndConditionalInpersonMakeup','Headerinpersondefault versusremote/filepolicy. Ruleholidayfilesuploadedatregularclock; ifinpersonthenholidayclosed/designatedmakeup. Sourceactualcurrentbranch,videoavailabilitywindow and actualmakeupclock/modeunknown; no centraldatedinpersoncopy.'),
'1102-3008-01':('conditionalVideoMakeupAndRemoteFieldConflict','Currentmethodinperson+videofornecessarymakeup; separateinitialZoomuntilvaccine/stabilityfieldnotdated. ActualmakeupVODwindows andindividualperiodnotprinted inselectedcache; no automaticnormalattendancecreation.'),
'1102-4006-00':('inpersonDefaultOptionalVideoMakeup','Currentinperson, videoonlyifmakeupneeded. OptionalpolicydoesnotproveactualVODdate; normalperiodandactualholidaymakeupclock/modeunknown.'),
'1103-7004-00':('allHolidayMakeupIsVideo','Explicitallholidaymakeupsarevideo. Do notapplycentralSep24→Dec10atnormalThuclassroomasactualinperson. VODrelease/deadline windows andcourseactualperiodnotconfirmed.'),
'1103-3017-00':('allHolidayMakeupIsVideo','Explicitallholidaymakeupsarevideo; currentFri10-12 cannotbeclonedforSep25/Oct9 schoolmakeupdatesasclassattendance. Actualvideowindows/endperiodpending.'),
'1103-4006-00':('allHolidayMakeupIsVideo','Allholidaymakeups explicitlyvideo; currentTue/Thustarts/rooms preservemetadataonly. CentralThursdaymakeup notdirectinstructionproof. ActualVODwindow/normalperiodunknown.'),
'1104-1004-00':('exactSeptember24SameDayVideoAndActualClockOverride','CurrentnormalTue13-15/Thu14-15 table differssourceactual13-14:50/14-14:50 teaching. SourceexplicitSep24same-dayvideomakeup, so noDec10automaticinpersonmakeup. Videoactualstart/release/deadlineunknown; neither50minnorroundedcatalogclockinventedforvideo.'),
'1104-7001-01':('currentMonWedAndRemoteWedFriConflict','CurrentMon/Wed inpersondefault, neededvideomakeuplaterannounced. SeparateWedlive/FriVODmatchesdifferentweekdaythanMon/Wed currenttable andcannotbeappliedblindly. OTuploadisresourcesnotattendancewindow; actualindividualperiod/makeupsunconfirmed.'),
'1104-7003-02':('May5VideoDirectiveOutsideCurrentFall','CurrentTue/Thuinpersondefault, videoifnotice2weeksbefore. ExplicitMay5same-dayvideomakeup liesoutsidecurrentfall; do notuseitforSep24 orclaimcurrentvideo. Actualcurrentperiod/holidaymakeupunconfirmed.')}
reviews=[]
for cid,(kind,text) in cases.items():
 d=json.loads((R/'cnu-current-education'/f'{cid}.json').read_text());reviews.append({'courseId':cid,'sourceResponseSHA256':d['sourceResponseSHA256'],'currentDisplayedClockRoom':d['header'][0].get('TLSN_ANNM',''),'classification':kind,'finding':text,'scheduleAllowed':False,'selectedEducationalCacheScope':'Preserved whitelist education only; initial contact-line removal may have omitted nearbysource, so missingcurrentdate is notfull-original absenceproof.'})
(R/'cnu-reviewed-twelve-makeup-operation-contexts-20261008.json').write_text(json.dumps({'wholeSemanticReviewComplete':False,'fullCacheReusedNoRefetch':True,'reviews':reviews},ensure_ascii=False,indent=2)+'\n')
p=R/'build_cnu_structural_review_queue.py';s=p.read_text().replace("for filename in ['cnu-reviewed-nine-chapter", "for filename in ['cnu-reviewed-twelve-makeup-operation-contexts-20261008.json','cnu-reviewed-nine-chapter");p.write_text(s)
print('12 holiday operation contexts reviewed; actual video overrides preserved')
