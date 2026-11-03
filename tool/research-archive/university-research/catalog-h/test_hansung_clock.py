import unittest
import hansung_clock as c

class CurrentSourceClock(unittest.TestCase):
    def test_actual75minute_course_and_room_binding(self):
        self.assertEqual(c.schedules('탐구관307  수4~5,목2M~3M'),[{'weekday':3,'startMinute':720,'endMinute':795,'classroom':'탐구관307'},{'weekday':4,'startMinute':630,'endMinute':705,'classroom':'탐구관307'}])
        self.assertEqual(c.schedules('상상관602 월7~8 / 상상관603 수2M~3M')[1]['classroom'],'상상관603')
    def test_actual50minute_and_video_no_slot(self):
        self.assertEqual(c.schedules('온라인강좌 1시간 / 공학관305 화2~3M')[0]['startMinute'],600)
        self.assertEqual(c.schedules('온라인강좌 3시간'),[])
        self.assertEqual(c.clock(5,'10','11M'),(1080,1185))
    def test_preserves_printed_thursday_discrepancy(self):
        self.assertEqual(c.clock(4,'11M','12M'),(1180,1250))
        self.assertEqual(c.clock(1,'11M','12M'),(1165,1240))
    def test_partial_and_saturday_are_not_guessed(self):
        for args in [(1,'5','6M'),(4,'10','11M'),(2,'2M','3M'),(6,'1','3M')]:
            with self.assertRaises(ValueError):c.clock(*args)

if __name__=='__main__':unittest.main()
