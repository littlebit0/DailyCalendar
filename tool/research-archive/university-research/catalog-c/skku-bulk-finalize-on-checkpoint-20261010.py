"""Collect once, classify all current records, freeze final cumulative source packet. No SDK."""
import pathlib,json,time,subprocess,sys,hashlib,datetime
b=pathlib.Path(__file__).parent;src=b/'skku-public-primary-bulk-v192-20261010';proc=b/'skku-primary-bulk-processing-v193-20261010';out=b/'skku-primary-cumulative-v194-20261010';python=sys.executable;last=-1
while True:
 try:state=json.load(open(src/'collection-progress.json'))
 except (ValueError,OSError):time.sleep(5);continue
 n=state.get('processedOfferings',0)
 if n//100!=last//100:
  subprocess.run([python,str(b/'skku-bulk-education-processor-20261010.py'),str(src),str(proc)],check=True);last=n
 if state.get('queueProcessingComplete') or state.get('publicProtectionBoundaryStopped') or state.get('stoppedAtExplicitRequest'):break
 time.sleep(5)
subprocess.run([python,str(b/'skku-bulk-education-processor-20261010.py'),str(src),str(proc)],check=True)
subprocess.run([python,str(b/'skku-bulk-final-candidate-builder-20261010.py'),str(out)],check=True)
# The computer processing queue is outside the candidate and remains explicit unresolved evidence.
summary=json.load(open(proc/'processing-progress.json'));index=b/'SKKU_CONTINUE_PROGRESS_2026-10-10.json';x=json.load(open(index));x['activeBulkCollection']['processedOfferings']=state['processedOfferings'];x['activeBulkCollection']['remainingOfferings']=state['remainingOfferings'];x['activeBulkCollection']['queueProcessingComplete']=state.get('queueProcessingComplete',False);x['bulkProcessorSummary']=summary;x['finalBulkCandidate']=str(out);x['finalBulkCandidateSDKExecuted']=False;x['finalBulkCandidateProductModified']=False;x['finalBulkCandidateManifestSHA256']=hashlib.sha256((out/'source-sha256.json').read_bytes()).hexdigest();x['candidateCounts']=json.load(open(out/'independent-literal-date-validation.json'))['resultCounts'];x['updatedAt']=datetime.datetime.now().astimezone().isoformat();index.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
# Freeze evidence manifests only after final checkpoint; no raw attachments/credentials are saved.
for folder in [src,proc]:
 m={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(folder.iterdir()) if f.is_file() and f.name not in ['source-sha256.json','STOP_REQUESTED']}
 (folder/'source-sha256.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
print('FINAL_READY',out,flush=True)
