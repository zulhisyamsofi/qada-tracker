package com.personal.qada_tracker

import java.util.Calendar
import java.util.TimeZone
import org.junit.Assert.*
import org.junit.Test

class ReminderPolicyTest {
    private fun time(hour: Int, minute: Int = 0, day: Int = 13,
                     zone: String = "Asia/Kuala_Lumpur"): Calendar = Calendar.getInstance(TimeZone.getTimeZone(zone)).apply {
        clear(); set(2026, Calendar.NOVEMBER, day, hour, minute, 0)
    }
    @Test fun schedulesAtElevenInLocalTime() {
        val next = ReminderPolicy.next(time(12), null)
        assertEquals(23, next.get(Calendar.HOUR_OF_DAY))
        assertEquals(0, next.get(Calendar.MINUTE))
        assertEquals("2026-11-13", ReminderPolicy.day(next))
    }
    @Test fun optingInLateChecksOnceThenSchedulesTomorrow() {
        val now = time(23, 30)
        assertEquals(now.timeInMillis + 1000, ReminderPolicy.next(now, null).timeInMillis)
        val next = ReminderPolicy.next(now, "2026-11-13")
        assertEquals("2026-11-14", ReminderPolicy.day(next))
        assertEquals(23, next.get(Calendar.HOUR_OF_DAY))
    }
    @Test fun anyUnrecordedPrayerNotifiesWhileFullyConfirmedDaysDoNot() {
        val now = time(23)
        assertTrue(ReminderPolicy.shouldNotify(true, "2026-11-13", now, null, true))
        assertFalse(ReminderPolicy.shouldNotify(true, "2026-11-13", now, null, false))
        assertTrue(ReminderPolicy.hasUnrecordedPrayer(List(5) { "unrecorded" }))
        assertTrue(ReminderPolicy.hasUnrecordedPrayer(List(5) { null }))
        assertTrue(ReminderPolicy.hasUnrecordedPrayer(listOf("performed", "missed", "performed", "missed", "unrecorded")))
        assertTrue(ReminderPolicy.hasUnrecordedPrayer(listOf("performed", "missed", "performed", "missed", "")))
        assertFalse(ReminderPolicy.hasUnrecordedPrayer(List(5) { "performed" }))
        assertFalse(ReminderPolicy.hasUnrecordedPrayer(List(5) { "missed" }))
        assertFalse(ReminderPolicy.hasUnrecordedPrayer(listOf("performed", "missed", "performed", "missed", "performed")))
    }
    @Test fun disabledDuplicateAndEarlyChecksDoNotNotify() {
        assertFalse(ReminderPolicy.shouldNotify(false, "2026-11-13", time(23), null, true))
        assertFalse(ReminderPolicy.shouldNotify(true, "2026-11-13", time(23), "2026-11-13", true))
        assertFalse(ReminderPolicy.shouldNotify(true, "2026-11-13", time(22), null, true))
    }
    @Test fun delayedAlarmIsNeverSentAfterMidnightOrOnAnotherDay() {
        assertFalse(ReminderPolicy.shouldNotify(true, "2026-11-13", time(0, day = 14), null, true))
        assertFalse(ReminderPolicy.shouldNotify(true, "2026-11-13", time(23, day = 14), null, true))
    }
    @Test fun timezoneChangeUsesTheNewLocalCalendar() {
        val now = time(16, zone = "America/New_York")
        val next = ReminderPolicy.next(now, null)
        assertEquals(now.timeZone, next.timeZone)
        assertEquals(23, next.get(Calendar.HOUR_OF_DAY))
        assertEquals("2026-11-13", ReminderPolicy.day(next))
    }
    @Test fun daylightSavingUsesCalendarDaysInsteadOfTwentyFourHours() {
        val now = Calendar.getInstance(TimeZone.getTimeZone("America/New_York")).apply {
            clear(); set(2026, Calendar.OCTOBER, 31, 23, 0, 0)
        }
        val next = ReminderPolicy.next(now, "2026-10-31")
        assertEquals(25L * 60 * 60 * 1000, next.timeInMillis - now.timeInMillis)
        assertEquals(23, next.get(Calendar.HOUR_OF_DAY))
        assertEquals("2026-11-01", ReminderPolicy.day(next))
    }
    @Test fun customTimeAndDelayedDeliveryStayWithinTheSameLocalDay() {
        val minutes = 21 * 60 + 15
        val next = ReminderPolicy.next(time(12), null, minutes)
        assertEquals(21, next.get(Calendar.HOUR_OF_DAY)); assertEquals(15, next.get(Calendar.MINUTE))
        assertFalse(ReminderPolicy.shouldNotify(true, "2026-11-13", time(21, 14), null, true, minutes))
        assertTrue(ReminderPolicy.shouldNotify(true, "2026-11-13", time(21, 15), null, true, minutes))
        assertTrue(ReminderPolicy.shouldNotify(true, "2026-11-13", time(22), null, true, minutes))
        assertFalse(ReminderPolicy.shouldNotify(true, "2026-11-13", time(0, day=14), null, true, minutes))
        assertEquals("2026-11-14", ReminderPolicy.day(ReminderPolicy.next(time(22), "2026-11-13", minutes)))
    }

}
