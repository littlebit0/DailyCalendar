"""Prepare the resumed data batch without running SDK checks or changing assets.

Inputs are explicit frozen sources. Research candidates remain separate from the
verified installed checkpoint until the full processing scope is finished.
"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
RESEARCH = ROOT / "work/university-research"


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def write(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    specs = read(OUT / "source-inputs.json")
    staged = []
    for spec in specs:
        source = ROOT / spec["source"]
        target = ROOT / spec["target"]
        source_bytes_sha = sha(source)
        if source_bytes_sha != spec["sourceSha256"]:
            raise ValueError("Frozen input changed: " + str(source))
        data = read(source)
        baseline = read(target)
        baseline_ids = {c["sourceId"] for c in baseline["courses"]}
        candidate_ids = [c["sourceId"] for c in data["courses"]]
        if set(candidate_ids) != baseline_ids or len(candidate_ids) != len(baseline_ids):
            raise ValueError("Unexpected offering scope change: " + str(source))
        if any(data[k] != baseline[k] for k in ("universityId", "campus", "academicYear", "semester")):
            raise ValueError("University/campus/term changed: " + str(source))
        data.update(researchOnly=True, productionIntegrationEnabled=False, completionClaim=False)
        destination = OUT / (target.stem + ".staged.json")
        write(destination, data)
        before = {c["sourceId"]: c for c in baseline["courses"]}
        changed = [c["sourceId"] for c in data["courses"] if c != before[c["sourceId"]]]
        staged.append({
            **spec,
            "stagedFile": str(destination.relative_to(ROOT)),
            "stagedSha256": sha(destination),
            "baselineSha256": sha(target),
            "changedSourceIds": changed,
            "scheduleBearingOfferings": sum(bool(c.get("schedules")) for c in data["courses"]),
            "datedMeetings": sum(len(c.get("schedules", [])) for c in data["courses"]),
            "sdkVerification": "not_run",
            "productProjection": "not_done",
        })
    write(OUT / "staging-ledger.json", {
        "date": "2026-10-10",
        "phase": "data_processing",
        "installedCheckpoint": 149,
        "completionClaim": False,
        "sources": staged,
    })
    print("Prepared staged datasets:", len(staged), "SDK/build/install: not run")


if __name__ == "__main__":
    main()
