"""Publish a finished source-processing batch; verification runs separately.

This does not mark support complete, install, launch, or claim SDK acceptance.
All datasets are prepared before any asset is overwritten. Original asset bytes
are retained as data snapshots for failure recovery, without touching app data.
"""
import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
RESEARCH = ROOT / "work/university-research"
CHECKPOINT = 152


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def write(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    ledger = read(OUT / "staging-ledger.json")
    if not (OUT / "source-processing-finished.json").exists():
        raise ValueError("Finish the processing scope and record deferred sources first")
    prepared = []
    for entry in ledger["sources"]:
        target = ROOT / entry["target"]
        staged = ROOT / entry["stagedFile"]
        if sha(target) != entry["baselineSha256"]:
            raise ValueError("Asset changed since staging: " + str(target))
        if sha(staged) != entry["stagedSha256"]:
            raise ValueError("Staged candidate changed: " + str(staged))
        if sha(ROOT / entry["source"]) != entry["sourceSha256"]:
            raise ValueError("Frozen source changed: " + entry["source"])
        data = read(staged)
        data.update(researchOnly=False, productionIntegrationEnabled=True,
                    completionClaim=False, wholeOperatingVerified=False)
        for course in data["courses"]:
            metadata = course.get("metadata", {})
            if "researchOnly" in metadata:
                metadata["researchOnly"] = False
        prepared.append((entry, target, data))
    snapshot = OUT / "before-projection"
    snapshot.mkdir(exist_ok=True)
    for entry, target, data in prepared:
        backup = snapshot / target.name
        if backup.exists() and backup.read_bytes() != target.read_bytes():
            raise ValueError("Prior projection snapshot exists: " + str(backup))
        backup.write_bytes(target.read_bytes())
    manifest = read(RESEARCH / "checkpoint149-source-manifest.json")
    for entry, target, data in prepared:
        write(target, data)
        record = next((r for r in manifest if r["file"] == entry["target"]), None)
        if record is None:
            record = {"file": entry["target"]}
            manifest.append(record)
        record.update(source=entry["source"], sha256=sha(target),
                      frozenSourceSha256=entry["sourceSha256"])
    write(RESEARCH / f"checkpoint{CHECKPOINT}-source-manifest.json", manifest)
    audit = copy.deepcopy(read(RESEARCH / "checkpoint149-current-packaged-coverage-audit.json"))
    audit["checkpoint"] = CHECKPOINT
    for row in audit["universities"]:
        courses = []
        for entry in row["assetFiles"]:
            path = ROOT / entry["file"]
            entry["sha256"] = sha(path)
            courses.extend(read(path)["courses"])
        row.update(courses=len(courses),
                   scheduleBearingOfferings=sum(bool(c.get("schedules")) for c in courses),
                   serializedMeetings=sum(len(c.get("schedules", [])) for c in courses))
    write(RESEARCH / f"checkpoint{CHECKPOINT}-current-packaged-coverage-audit.json", audit)
    write(OUT / "projection-receipt.json", {
        "checkpoint": CHECKPOINT,
        "priorInstalledCheckpoint": 149,
        "completionClaim": False,
        "sdkVerification": "pending_combined_final_checks",
        "installation": "not_updated",
        "assets": [{"file": e["target"], "sha256": sha(p)} for e, p, _ in prepared],
    })
    print("Projected finished batch; verification and installation remain pending")


if __name__ == "__main__":
    main()
