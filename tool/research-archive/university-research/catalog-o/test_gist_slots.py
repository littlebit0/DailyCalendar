import json,unittest
from extract_gist_slots import ROOT,extract

class GistSlotsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.slots,cls.unknown=extract(json.loads((ROOT/'gist-whole-coordinate-fixture.json').read_text()))
    def at(self,row,col):return next(s for s in self.slots if s['row']==row and s['column']==col)
    def test_individual_clocks_override_named_grid_block(self):
        self.assertEqual(self.at(3,22)['publishedClock'],{'startMinute':540,'endMinute':600})
        self.assertEqual(self.at(54,22)['publishedClock'],{'startMinute':960,'endMinute':1070})
        self.assertEqual(self.at(54,23)['publishedClock'],{'startMinute':780,'endMinute':1070})
    def test_explicit_saturday_overrides_weekday_column(self):
        s=next(s for s in self.slots if s['rawCode']=='AX5245')
        self.assertEqual(s['weekday'],6)
        self.assertEqual(s['publishedClock'],{'startMinute':480,'endMinute':780})
    def test_korean_hour_range_and_end_only(self):
        s=next(s for s in self.slots if s['rawCode'].startswith('EC3101') and '13시~17시' in s['title'])
        self.assertEqual(s['publishedClock'],{'startMinute':780,'endMinute':1020})
        s=next(s for s in self.slots if s['rawCode']=='AI2001' and '~ 17:00' in s['title'])
        self.assertEqual(s['publishedClock']['endMinute'],1020)
    def test_alias_sections_never_invented(self):
        ai=self.at(3,22)
        self.assertEqual([i['code'] for i in ai['identities']],['AI4101','AI5101','EC5302','EC4223'])
        self.assertTrue(all(i['publishedSection'] is None for i in ai['identities']))
        self.assertEqual(self.at(54,22)['identities'][0]['publishedSection'],'01')
        self.assertEqual([i['publishedSection'] for i in self.at(13,27)['identities']],['1','2','3'])
        self.assertEqual([i['publishedSection'] for i in self.at(13,28)['identities']],['01','02'])
    def test_mooc_not_assumed_regular_attendance(self):
        self.assertTrue(self.at(3,3)['deliveryUnverified'])
        self.assertEqual(self.at(3,3)['rawCode'],'HS2507\nLH2507')

if __name__=='__main__':unittest.main()
