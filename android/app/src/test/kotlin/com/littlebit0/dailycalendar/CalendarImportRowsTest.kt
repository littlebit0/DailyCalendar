package com.littlebit0.dailycalendar

import android.database.MatrixCursor
import android.provider.CalendarContract
import java.util.TimeZone
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class CalendarImportRowsTest {
    private val hour = CalendarImportRows.HOUR_MILLIS
    private val day = CalendarImportRows.DAY_MILLIS
    private val deviceZone = TimeZone.getDefault()

    @Before fun useSeoul() = TimeZone.setDefault(TimeZone.getTimeZone("Asia/Seoul"))
    @After fun restoreZone() = TimeZone.setDefault(deviceZone)

    @Test fun durationsTheProviderStoresAreRead() {
        assertEquals(2 * hour, CalendarImportRows.durationMillis("P7200S", false))
        assertEquals(2 * hour, CalendarImportRows.durationMillis("PT2H", false))
        assertEquals(2 * hour, CalendarImportRows.durationMillis("PT7200S", false))
        assertEquals(2 * hour, CalendarImportRows.durationMillis("+PT2H", false))
        assertEquals(7 * day, CalendarImportRows.durationMillis("P1W", false))
        assertEquals(day + 2 * hour, CalendarImportRows.durationMillis("P1DT2H", false))
        assertEquals(90 * 60 * 1000L, CalendarImportRows.durationMillis("PT1H30M", false))
        assertEquals(day, CalendarImportRows.durationMillis("P1D", true))
    }

    @Test fun unreadableDurationsKeepTheDefaultLength() {
        for (value in listOf(null, "", "P", "PT0S", "-PT2H", "2 hours")) {
            assertEquals(hour, CalendarImportRows.durationMillis(value, false))
            assertEquals(day, CalendarImportRows.durationMillis(value, true))
        }
    }

    @Test fun exdateFormsBecomeOccurrenceStarts() {
        val tenSeoul = 1767574800000L // 2026-01-05T10:00+09:00
        assertEquals(listOf(tenSeoul, tenSeoul + 7 * day), CalendarImportRows.exdateMillis("20260105T010000Z,20260112T010000Z", false, null))
        assertEquals(listOf(tenSeoul), CalendarImportRows.exdateMillis("TZID=Asia/Seoul:20260105T100000", false, "UTC"))
        assertEquals(listOf(tenSeoul), CalendarImportRows.exdateMillis("20260105T100000", false, "Asia/Seoul"))
        val midnightSeoul = tenSeoul - 10 * hour
        assertEquals(listOf(midnightSeoul), CalendarImportRows.exdateMillis("20260105T000000Z", true, "UTC"))
        assertEquals(listOf(midnightSeoul), CalendarImportRows.exdateMillis("VALUE=DATE:20260105", true, null))
        assertTrue(CalendarImportRows.exdateMillis("garbage", false, null).isEmpty())
    }

    private val start = 1767574800000L // Monday 2026-01-05 10:00 in Seoul

    private fun cursor(vararg rows: Map<String, Any?>) = MatrixCursor(CalendarImportRows.projection).apply {
        rows.forEach { row -> addRow(CalendarImportRows.projection.map { row[it] }) }
    }

    private fun row(id: Long, vararg values: Pair<String, Any?>) = mapOf(
        CalendarContract.Events._ID to id,
        CalendarContract.Events.CALENDAR_ID to 1L,
        CalendarContract.Events.TITLE to "event $id",
        CalendarContract.Events.ALL_DAY to 0,
        CalendarContract.Events.DELETED to 0,
        *values,
    )

    @Test fun cancelledOccurrenceIsExcludedAndItsRowIsNotImported() {
        val events = CalendarImportRows.read(
            cursor(
                row(
                    1,
                    CalendarContract.Events.DTSTART to start,
                    CalendarContract.Events.DURATION to "P7200S",
                    CalendarContract.Events.RRULE to "FREQ=WEEKLY",
                ),
                row(
                    2,
                    CalendarContract.Events.DTSTART to start + 7 * day,
                    CalendarContract.Events.DTEND to start + 7 * day,
                    CalendarContract.Events.STATUS to CalendarContract.Events.STATUS_CANCELED,
                    CalendarContract.Events.ORIGINAL_ID to "1",
                    CalendarContract.Events.ORIGINAL_INSTANCE_TIME to start + 7 * day,
                    CalendarContract.Events.ORIGINAL_ALL_DAY to 0,
                ),
            ),
        )
        assertEquals(setOf("1"), events.keys)
        assertEquals(start + 2 * hour, events["1"]!!["endMilliseconds"])
        assertEquals(listOf(start + 7 * day), events["1"]!!["excludedMilliseconds"])
    }

    @Test fun movedOccurrenceIsExcludedAndImportedOnceAtItsNewTime() {
        val moved = start + 14 * day + 3 * hour
        val events = CalendarImportRows.read(
            cursor(
                row(
                    1,
                    CalendarContract.Events.DTSTART to start,
                    CalendarContract.Events.DURATION to "PT2H",
                    CalendarContract.Events.RRULE to "FREQ=WEEKLY",
                    CalendarContract.Events.EXDATE to "20260112T010000Z",
                ),
                row(
                    3,
                    CalendarContract.Events.DTSTART to moved,
                    CalendarContract.Events.DTEND to moved + 2 * hour,
                    CalendarContract.Events.ORIGINAL_ID to "1",
                    CalendarContract.Events.ORIGINAL_INSTANCE_TIME to start + 14 * day,
                    CalendarContract.Events.ORIGINAL_ALL_DAY to 0,
                ),
            ),
        )
        assertEquals(listOf(start + 7 * day, start + 14 * day), events["1"]!!["excludedMilliseconds"])
        assertEquals(moved, events["3"]!!["startMilliseconds"])
        assertFalse(events["3"]!!.containsKey("recurrenceRule"))
        assertFalse(events["3"]!!.containsKey("excludedMilliseconds"))
    }

    @Test fun allDayExceptionUsesTheLocalDayOfTheOriginalOccurrence() {
        val utcMidnight = 1767571200000L // 2026-01-05T00:00Z
        val events = CalendarImportRows.read(
            cursor(
                row(
                    1,
                    CalendarContract.Events.ALL_DAY to 1,
                    CalendarContract.Events.DTSTART to utcMidnight,
                    CalendarContract.Events.DURATION to "P1D",
                    CalendarContract.Events.RRULE to "FREQ=DAILY",
                ),
                row(
                    2,
                    CalendarContract.Events.ALL_DAY to 1,
                    CalendarContract.Events.DTSTART to utcMidnight + day,
                    CalendarContract.Events.DTEND to utcMidnight + day,
                    CalendarContract.Events.STATUS to CalendarContract.Events.STATUS_CANCELED,
                    CalendarContract.Events.ORIGINAL_ID to "1",
                    CalendarContract.Events.ORIGINAL_INSTANCE_TIME to utcMidnight + day,
                    CalendarContract.Events.ORIGINAL_ALL_DAY to 1,
                ),
            ),
        )
        val localMidnight = utcMidnight - 9 * hour
        assertEquals(localMidnight, events["1"]!!["startMilliseconds"])
        assertEquals(listOf(localMidnight + day), events["1"]!!["excludedMilliseconds"])
    }

    @Test fun plainAndCancelledSingleEventsAreImportedAsBefore() {
        val events = CalendarImportRows.read(
            cursor(
                row(1, CalendarContract.Events.DTSTART to start, CalendarContract.Events.DTEND to start + hour),
                row(
                    2,
                    CalendarContract.Events.DTSTART to start,
                    CalendarContract.Events.DTEND to start + hour,
                    CalendarContract.Events.STATUS to CalendarContract.Events.STATUS_CANCELED,
                ),
            ),
        )
        assertEquals(setOf("1", "2"), events.keys)
        assertFalse(events["1"]!!.containsKey("excludedMilliseconds"))
    }
}
