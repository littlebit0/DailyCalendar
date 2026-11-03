"""Read selected education context, avoid promoting bibliography/policy/material dates."""
import json
from pathlib import Path
R=Path(__file__).resolve().parent
cases={
'1001-7010-00':('bibliographyDatesAndLiveScreenAttendance','December2009/2004 are reference-paper dates, not teaching. Public method uses instructor-paused lecturevideo plusstudentdiscussion; rules require screen/microphone andscreenattendance, so notindependentVODwindow. Actualcurrentmode/fixedattendanceperiodstillunconfirmed.'),
'1101-3020-00':('historicalMediaReleaseAndConditionalMixedTeaching','2024December11/19 is interviewvideo publication, notcurrentclassdates. Currentin-persondefault allowsflippedlearning, rules>30studentsmixed; remoteparagraph hasvoice-videoandassignmentdiscussion. Do notderive currentactualmode perweek fromvideoreferenceorCOVIDcondition.'),
'1154-1008-00':('observationAssignmentAndNormalTheoryPractice','Decembernightobjects selection is observationhomework month, not actualDecembermeeting. Currentin-person1hlecture/3hpractice andMon2h/Wed2h clocks known; individualactualperiod/examdates andinstruction/practiceallocationnotprinted inpreservededucation.'),
'1163-2008-00':('excusedAbsenceDeadlineAndConditionalEmergencyRemote','Beforefinalclass documentation requirement isgeneralattendancepolicy, notactualenddate. Balletpractical inpersondefault, onlyemergencyremotecondition; mid/finalexamcontent announced1-2weeksbefore. Noexactactualexam/enddatesconfirmed.'),
'1242-3005-00':('technicalTopicNotClosingDate','Hybridvigour breeding topic contains종강 aspartof잡종강세육종, notlastclass. Audio-visualmaterials/groupcooperative laboratoryinstructionnotindependentVOD. CurrentThu09-11/11-13 lab clockknown, actualindividualperiod/makeupnotconfirmed.'),
'1309-1004-00':('afterFinalPortfolioDeadlineNotTeachingPeriod','Photographinginkchangesandpost-finalportfolio submission ispracticeassessmentpolicy, notactualfinaldate. CurrentWed09-13 practicalandtheoryeducationknown; actualnormalperiod/examdateunconfirmed.'),
'1514-2001-01':('explicitOld2017ExamsNotCurrentFridayCourse','REFexplicit2017Oct25/Dec13Wednesday20:30starts areoldyear anddifferentweekdaythan2026Friday19-22 ordinarycourse. Do notconvertto2026 exams orreuseends. Currentweekly3htheory/assignmentknown; individualnormalperiodandcurrentexamdateunknown.')}
reviews=[]
for cid,(classification,finding) in cases.items():
 d=json.loads((R/'cnu-current-education'/f'{cid}.json').read_text());reviews.append({'courseId':cid,'sourceResponseSHA256':d['sourceResponseSHA256'],'currentDisplayedClockRoom':d['header'][0].get('TLSN_ANNM',''),'classification':classification,'finding':finding,'scheduleAllowed':False,'gates':['actual current individual attendance period','current actual exams/makeup where applicable'],'selectedEducationalCacheScope':'Only preserved selected fields inspected; removed contact lines may omit adjacent source text, so full-original absence not proven.'})
(R/'cnu-reviewed-seven-date-policy-material-contexts-20261008.json').write_text(json.dumps({'wholeSemanticReviewComplete':False,'fullCacheReusedNoRefetch':True,'reviews':reviews},ensure_ascii=False,indent=2)+'\n')
p=R/'build_cnu_structural_review_queue.py';s=p.read_text().replace("for filename in ['cnu-reviewed-seven-additional", "for filename in ['cnu-reviewed-seven-date-policy-material-contexts-20261008.json','cnu-reviewed-seven-additional");p.write_text(s)
print('Seven context distinctions preserved; source clocks are not fabricated as dates')
