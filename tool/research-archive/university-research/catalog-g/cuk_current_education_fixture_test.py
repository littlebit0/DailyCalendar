"""Offline scope/identity checks; these do not establish operating readiness."""
import hashlib
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parent


def read(name):
    return json.loads((ROOT / name).read_text())


class CurrentEducationTests(unittest.TestCase):
    def test_immutable_current_census(self):
        path = ROOT / 'cuk-current-whole-reconciled-education-next-20261008.json'
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),
                         'ebc444909a9b77a6a5e44ff7d1e4db76f459c9dc7371b7a5532eaf470289c20c')
        rows = json.loads(path.read_text())['courses']
        self.assertEqual(len(rows), 1459)
        self.assertEqual(len({(r['code'], r['section']) for r in rows}), 1459)

    def test_credit_projection_preserves_metadata(self):
        original = read('cuk-current-whole-reconciled-education-next-20261008.json')
        next_data = read('cuk-current-whole-credit-review-next-20261008.json')
        self.assertFalse(next_data['productionReady'])
        self.assertEqual(sum(r['credits'] is not None for r in next_data['courses']), 278)
        for a, b in zip(original['courses'], next_data['courses']):
            for key in a:
                if key != 'credits':
                    self.assertEqual(a[key], b[key])

    def test_dated_exact_section_credit_join_never_changes_current_time(self):
        before = read('cuk-current-whole-credit-review-next-20261008.json')
        after = read('cuk-current-whole-exact-section-credit-next-20261008.json')
        self.assertEqual(sum(r['credits'] is not None for r in after['courses']), 1052)
        for a, b in zip(before['courses'], after['courses']):
            for key in a:
                if key not in ('credits', 'sourceCreditMetadata'):
                    self.assertEqual(a[key], b[key])
            if a['credits'] is not None:
                self.assertEqual(a['credits'], b['credits'])

    def test_actual_current_clock_only_one_to_nine(self):
        proof = read('cuk-current2026-2-direct-clock-proof-20261008.json')
        self.assertEqual(proof['sourceDocumentDate'], '2026-07-13')
        self.assertEqual([r['period'] for r in proof['periods']], list(range(1, 10)))
        self.assertEqual([(r['startMinute'], r['endMinute']) for r in proof['periods']],
                         [(hour * 60, hour * 60 + 50) for hour in range(9, 18)])

    def test_membership_is_not_final_active_scope(self):
        closures = read('cuk-current-public-closure-membership-audit-20261008.json')
        self.assertEqual(closures['closureCount'], 19)
        self.assertEqual(closures['stillPresentExactMatches'], 19)
        self.assertTrue(all('code' not in row for row in closures['closures']))

    def test_historical_exchange_is_not_current_time_projection(self):
        evidence = read('cuk-current2026-2-exchange-credit-crosscheck-20261008.json')
        self.assertEqual(evidence['sourceRowCount'], 1027)
        self.assertEqual(evidence['exactIdentityTitleMatches'], 1023)
        self.assertEqual(evidence['titleConflicts'], [])
        self.assertEqual(sum(x['rawTimeAndRoomEqual'] for x in evidence['matches']), 406)
        self.assertFalse(evidence['productionReady'])


if __name__ == '__main__':
    unittest.main()
