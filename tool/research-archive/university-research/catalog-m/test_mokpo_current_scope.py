"""Source-backed scope checks; no production registration implied."""
import json
import pathlib
import unittest
P=pathlib.Path(__file__).parent
class CurrentScopeTests(unittest.TestCase):
    def setUp(self):
        self.whole=json.loads((P/'mokpo-current-public-catalog-educational-20261008.json').read_text())
        self.scoped=json.loads((P/'mokpo-current-four-year-research-educational-20261008.json').read_text())
        self.audit=json.loads((P/'mokpo-current-four-year-scope-audit-20261008.json').read_text())
    def test_actual_whole_and_scope_partition(self):
        key=lambda r:(r['GYOGWAMOK_CD'],r['BUNBAN'])
        excluded={(r['courseCode'],r['section']) for r in self.audit['excludedActualIdentities']}
        whole={key(r) for r in self.whole}; scoped={key(r) for r in self.scoped}
        self.assertEqual((len(whole),len(scoped),len(excluded)),(1350,1307,43))
        self.assertEqual(whole,scoped|excluded);self.assertFalse(scoped&excluded)
    def test_four_year_damyang_retained(self):
        for dept,expected in [('DY010',1),('DY020',2)]:
            self.assertEqual(sum(r['HAKGWA_CD']==dept for r in self.scoped),expected)
        self.assertFalse(any(r['HAKGWA_CD']=='DY050' for r in self.scoped))
    def test_late_clock_original_source_retained(self):
        for code in ['CED006','CED009']:
            row=next(r for r in self.whole if r['GYOGWAMOK_CD']==code)
            self.assertEqual(row['HAKGWA_CD'],'DY050');self.assertIn('27,28,29,30',row['BIGO_TIME'])
        self.assertFalse(self.audit['productionReady'])
    def test_current_normal_public_refresh_unchanged(self):
        audit=json.loads((P/'mokpo-current-public-catalog-recheck-20261008.json').read_text())
        self.assertEqual(audit['currentRows'],1350)
        self.assertEqual(audit['added'],[]);self.assertEqual(audit['removed'],[])
        self.assertEqual(audit['educationalChanges'],[])
        self.assertFalse(any('GYOSU_CD' in r or 'TEL_NO' in r or 'EMAIL' in r for r in self.whole))
if __name__=='__main__':unittest.main()
