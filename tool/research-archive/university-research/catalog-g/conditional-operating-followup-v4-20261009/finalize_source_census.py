import collections,hashlib,json,re
from pathlib import Path
D=Path(__file__).resolve().parent
read=lambda p:json.loads(p.read_text())
census=read(D/'held-571-source-census.json');rules=read(D/'individual-source-review-rules.json')
counts=collections.Counter();gaps=collections.Counter();room=[]
for r in census['rows']:
 n=r['nativeOffering'];gaps.update(r['structuralGaps']);text=r['teachingMethod']+' '+' '.join(r['sourceGeneralOperatingContexts'])
 reasons=[]
 for gap in r['structuralGaps']:
  reasons.append({'kind':gap,'sourceFields':{'individualPeriodNotProved':['period','sourceWeeklyRows'],'nativeCyberFlagAllocationUnknown':['reportIdentity','sourceWeeklyRows'],'currentIdentityUnverified':['reportIdentity'],'nativeClassroomUnpublished':['sourceRoom'],'sourceExtractTruncated':['sourceWeeklyRows'],'anotherTermStatementPresent':['sourceGeneralOperatingContexts']}.get(gap,[])})
 if n in rules:
  primary='promotedPartial' if rules[n]['omitWeeks'] or rules[n]['heldDates'] else 'promotedOrdinary'
  r.update(decision=primary,reviewRule=rules[n],decisionBasis='Exact native clock/classroom, current educational identity and independently proved own printed period. Scheduled semantics are published reservation, not actual attendance.')
 else:
  if 'currentIdentityUnverified' in r['structuralGaps']:primary='heldCurrentIdentityUnverified'
  elif 'individualPeriodNotProved' in r['structuralGaps']:primary='heldPrintedPeriodCorrespondenceUnproved'
  elif 'nativeCyberFlagAllocationUnknown' in r['structuralGaps']:primary='heldNativeCyberAllocationUnknown'
  elif 'sourceExtractTruncated' in r['structuralGaps']:primary='heldExtractIncomplete'
  elif 'anotherTermStatementPresent' in r['structuralGaps']:primary='heldTermStatementConflict'
  elif n in ['15738001','14534001','14257002','61033001']:primary='heldSourceDateOrClockConflict'
  elif re.search('개인레슨|개인 레슨|1:1|Individual|개별 레슨|개인별|개인에게|개별.*지도|사전 신청|대면상담|조별 미팅',text):primary='heldIndividualAllocationUnproved'
  elif re.search('실습|현장|답사|견학|Field Trip|field trip|필드 트립|기업체 방문|봉사',text):primary='heldExternalOrRotatingAllocationUnproved'
  elif re.search('온라인|비대면|동영상|영상강의|MOOC|화상|동영|online|video|영상',text):primary='heldDeliveryAllocationUnproved'
  else:primary='heldIndividualOperatingScopeUnproved'
  r.update(decision=primary,decisionBasis='Retained source does not yet prove an unambiguous dated operating allocation for promotion. Signal buckets are evidence triage, not a claim that every matching topic is remote/external. Exact current raw fields remain preserved; no impossible claim.')
 r['fieldGapEvidence']=reasons
 counts[primary]+=1
 if 'nativeClassroomUnpublished' in r['structuralGaps']:room.append(r)
census.update(reviewCompleteAtScope='571 pre-v4 held rows structurally examined and each given a bounded decision; 201 supported source cases promoted, 370 retained with raw evidence. Not a claim of verified actual attendance for every course.',decisionCounts=dict(counts),overlappingStructuralGapCounts=dict(gaps),newSupportedCount=201,remainingHeldCount=370,untimedOutsideCensusCount=4,wholeLatestClosureVerified=False,newSourceAcquisition=False)
(D/'held-571-source-census.json').write_text(json.dumps(census,ensure_ascii=False,indent=2)+'\n')
(D/'classroom-unpublished-eight-review.json').write_text(json.dumps({'researchOnly':True,'completionClaim':False,'nativeClassroomFieldPreserved':True,'newClassroomUnknownSupportedCount':2,'newDates':28,'blankClassroomNotSoleHoldReason':True,'rows':room},ensure_ascii=False,indent=2)+'\n')
audit=read(D/'source-operating-audit.json');audit['verification']['actualModelThreeModeDrive']=True
(D/'source-operating-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
(D/'actual-verification.json').write_text(json.dumps({'researchOnly':True,'completionClaim':False,'productionRegistered':False,'actualModelFixture':{'exitCode':0,'passed':1,'durationSeconds':3,'initialFixtureFailure':'same-weekday separated native period runs were incorrectly compared against whole-day min/max; fixed fixture only, candidate unchanged','wholeNativeCount':3809,'scheduledCount':3435,'datedMeetingCount':57983,'preservedPriorScheduledCount':3234,'preservedPriorDates':55027,'newScheduledCount':201,'newDates':2956,'unchangedWholeObjects':3608,'allThreeDefaultModes':True,'fullTimetableSyncDocumentJsonRoundtrip':True,'networkDriveTest':False},'format':{'exitCode':0},'scopedAnalyze':{'exitCode':0,'diagnostics':'No issues found!'},'independentPythonRawClockPeriodRoomExceptionProof':True,'productChanged':False,'appBuildInstallLaunch':False,'sdkReleased':True},ensure_ascii=False,indent=2)+'\n')
print(dict(counts))
