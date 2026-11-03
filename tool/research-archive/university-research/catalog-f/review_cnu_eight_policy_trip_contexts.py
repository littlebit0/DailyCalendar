import json
from pathlib import Path
R=Path(__file__).resolve().parent
cases={
'1106-7003-02':('currentTueWedAgainstRemoteMonThu','CurrentTue/Wed inperson firstOT actualclassnotattendancecount. Remotefield Mon10:30/Thu13:30 plusvideosweeks1/2,7/8,14/15conflicts currenttable; exactcurrentpolicy/period/holidaymakeupunknown.'),
'1106-7003-03':('currentTueWedAgainstRemoteMonThu','OwnTue15-16:30/Wed12-13:30inpersonmethod. AlternateMon/ThuZoom+multipleexam/firstweekvideos notcurrentfixedweekday; actualmode/dateperiodneedsreconciliation. Notattendancecountdoesnotmeanfirstweeknoclass.'),
'1106-3026-00':('catalogWedThuAgainstMethodTueWed','CurrentWed10-12/Thu14-15 versusmethodTue/Wedinperson andcybermakeup. Remotefielddoesnotresolveweekday oractualmakeupwindows. Actualdateperiodunconfirmed.'),
'1107-2012-00':('conditionalHolidayRemote','Inpersondefault, holiday/makeupmayberemote. MaybedirectiveisconditionalnotconfirmedVODattendance; schoolcentraldatealoneinsufficienttofixmode/clock. Actualperiod/endunknown.'),
'1108-1006-00':('individualMissedExamPolicyNotSchoolMakeup','EnglishMake-up policy concernsindividualmissedquiz/exam onlyillness/familycrisis/extremeconditions; notactualscheduledholidayreplacement. Instructorlecture/studentdiscussionhalf ispedagogicsnotseparateonlineclock. LMSavailabilitystatementdoesnotdirectlycreateVODwindows.'),
'1109-1006-00':('current2026FallTripBudgetConditionalNoDates','Sourceexplicit26-2academictrip2/4, participationregistration/PF notordinaryfixedteaching. Actualtripoccurrence anddetailslaternoticeconditionalbudgetapproval; noactualdate/clock/room. Preserveeligibility/graduation/publicexcusedabsence notes withoutcreatingtrip.'),
'1109-1008-00':('supplementaryExplanationNotCancelledClass','보충 강의 meansinstructorexplanationafterreading/studentpresentation. SeparateZoomremote methodfutureunconfirmedcurrentmode. Noactualholidaymakeupmeetingsimpliedbyword; normalperiodpending.'),
'1109-2018-00':('current2026FallTripBudgetConditionalNoDates','Exactsame26-2 academictrip2/4eligibility/PF instructions as1109-1006; actualtripconditionalbudgetapprovalandlaternotice. Noactualeventdate/clock/room orordinaryclassclock; courseidentityretainedseparately.')}
reviews=[]
for cid,(kind,text) in cases.items():
 d=json.loads((R/'cnu-current-education'/f'{cid}.json').read_text());reviews.append({'courseId':cid,'sourceResponseSHA256':d['sourceResponseSHA256'],'currentDisplayedClockRoom':d['header'][0].get('TLSN_ANNM',''),'classification':kind,'finding':text,'scheduleAllowed':False,'selectedEducationalCacheScope':'Only preserved education whitelist; original neighboring education might be omitted by initialcontact-line removal. No full-originalabsence claim.'})
(R/'cnu-reviewed-eight-policy-trip-contexts-20261008.json').write_text(json.dumps({'wholeSemanticReviewComplete':False,'fullCacheReusedNoRefetch':True,'reviews':reviews},ensure_ascii=False,indent=2)+'\n')
p=R/'build_cnu_structural_review_queue.py';s=p.read_text().replace("for filename in ['cnu-reviewed-ten-further", "for filename in ['cnu-reviewed-eight-policy-trip-contexts-20261008.json','cnu-reviewed-ten-further");p.write_text(s)
print('8 additional actual operation and policy contexts reviewed')
