"""Token-only privacy correction; no changes to class operating decisions."""
import collections
import hashlib
import importlib.util
import json
from pathlib import Path
from skku_inline_private_education_filter import PHONE

P = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('base', P/'prepare_skku_planned_regular_r25_candidate.py')
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)


def sanitize(value):
    if isinstance(value, str):
        return PHONE.sub('[비공개 정보 제거]', value)
    if isinstance(value, list):
        return [sanitize(x) for x in value]
    if isinstance(value, dict):
        return {k: sanitize(v) for k, v in value.items()}
    return value


def strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, list):
        for x in value:
            yield from strings(x)
    elif isinstance(value, dict):
        for x in value.values():
            yield from strings(x)


def main():
    old_manifest = json.loads((P/'skku-partial-audited-20261008-r27-sha-manifest.json').read_text())
    proof_source = P/'skku-inline-education-repaired-20261008-r26-proof.json'
    proof = json.loads(proof_source.read_text())
    proof_count = sum(len(PHONE.findall(s)) for s in strings(proof))
    safe_proof = P/'skku-inline-education-repaired-20261008-r28-privacy-proof.json'
    proof_sha = base.immutable(safe_proof, sanitize(proof))
    manifest = {**old_manifest, 'campuses': [], 'privacyCorrectionOnlyOverR27': True,
                'privacyMaskedProofContextOccurrences': proof_count,
                'safeRepairedProof': {'path': str(safe_proof), 'sha256': proof_sha},
                'priorR27ManifestSha256': hashlib.sha256((P/'skku-partial-audited-20261008-r27-sha-manifest.json').read_bytes()).hexdigest()}
    changed = []
    dated = 0
    for campus in base.CAMPUSES:
        before = json.loads((P/f'skku-{campus}-2026-2.partial-audited-20261008-r27.json').read_text())
        after = sanitize(before)
        for old, new in zip(before['courses'], after['courses']):
            if old != new:
                changed.append(old['courseCode']+'-'+old['section'])
                assert old['departmentRemarks'] != new['departmentRemarks']
                assert {k:v for k,v in old.items() if k != 'departmentRemarks'} == {k:v for k,v in new.items() if k != 'departmentRemarks'}
            assert old.get('schedules') == new.get('schedules')
            assert old['sourceEducationalMetadata'] == new['sourceEducationalMetadata']
            ref = new.get('sourceEducationalOperatingEvidenceReference')
            if ref and ref.get('file') == proof_source.name:
                ref['file'] = safe_proof.name
        assert not any(PHONE.search(s) for s in strings(after))
        dated += sum(len(c.get('schedules', [])) for c in after['courses'])
        path = P/f'skku-{campus}-2026-2.partial-audited-20261008-r28.json'
        sha = base.immutable(path, after)
        counts = collections.Counter(c['scheduleStatus'] for c in after['courses'])
        manifest['campuses'].append({'campus': campus, 'path': str(path), 'sha256': sha,
                                    'courseCount': len(after['courses']), 'scheduleCounts': dict(counts)})
    assert changed == ['GEDM001-10'] and dated == 38346
    manifest.update(privacyCorrectedCourseCodes=changed, schedulesUnchanged=True,
                    originalEducationalMetadataUnchanged=True,
                    repairedProofEducationEquivalentExceptPrivateTokens=True)
    base.immutable(P/'skku-partial-audited-20261008-r28-sha-manifest.json', manifest)
    print({'privateAssetCourseCorrections': len(changed), 'privateProofContextOccurrencesRemoved': proof_count, 'datedUnchanged': dated})


if __name__ == '__main__':
    main()
