"""Compare all published weekly rows to an independently evidenced course period.

This does not generate a period from a title, a row count, or the semester fallback.
"""
import datetime


def current_period_weekly_rows_consistent(report, course):
    period=course.get('period') if course else None
    rows=report.get('weeklyRows',[])
    if not period or not rows or not all(r.get('activityPresent') for r in rows):
        return False
    start=datetime.date.fromisoformat(period['startDate'])
    end=datetime.date.fromisoformat(period['endDate'])
    if [r['week'] for r in rows]!=list(range(rows[0]['week'],rows[0]['week']+len(rows))):
        return False
    dates=[]
    for row in rows:
        begin=datetime.date(start.year,*map(int,row['startMonthDay'].split('/')))
        finish=datetime.date(start.year,*map(int,row['endMonthDay'].split('/')))
        if not 0<=(finish-begin).days<=6:
            return False
        dates.append((begin,finish))
    if any(dates[index][0]!=dates[index-1][1]+datetime.timedelta(days=1) for index in range(1,len(dates))):
        return False
    # Actual five-week AI bootcamp periods begin at the first printed weekend
    # within a published seven-day teaching week. Keep the independent start;
    # do not expand it backwards to the template week's Tuesday.
    actual_short_period=period.get('kind')=='Last date of final published teaching week; not a claim of actual final weekday meeting'
    start_matches=dates[0][0]<=start<=dates[0][1] if actual_short_period else dates[0][0]==start
    return start_matches and dates[-1][1]==end
