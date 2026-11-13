package com.personal.qada_tracker

import org.junit.Assert.*
import org.junit.Test

class PrayerTimePolicyTest {
    @Test fun unixTimeIsAnInstantIndependentOfDeviceTimezone() {
        assertEquals(1793483280000L, PrayerTimePolicy.epochMillis(1793483280))
        val formatter = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm", java.util.Locale.US)
        formatter.timeZone = java.util.TimeZone.getTimeZone("Asia/Kuala_Lumpur")
        assertEquals("2026-11-01 05:48", formatter.format(java.util.Date(PrayerTimePolicy.epochMillis(1793483280))))
    }
    @Test fun onlyNextOccurrenceOfEachPrayerIsScheduled() {
        val entries = PrayerTimePolicy.names.flatMap { name -> listOf(
            PrayerSlot(name, 1000L, "2026-11-12", "05:00"),
            PrayerSlot(name, 3000L, "2026-11-13", "05:00"),
            PrayerSlot(name, 5000L, "2026-11-14", "05:00")
        ) }
        val next = PrayerTimePolicy.next(entries, 2000L)
        assertEquals(5, next.size)
        assertTrue(next.all { it.at == 3000L })
        assertEquals(PrayerTimePolicy.names.toSet(), next.map { it.prayer }.toSet())
    }
    @Test fun pastAlarmsAreNotReplayedAfterReboot() {
        assertTrue(PrayerTimePolicy.next(listOf(PrayerSlot("subuh", 1000, "2026-11-12", "05:00")), 2000).isEmpty())
    }
    @Test fun earlyOrStaleBroadcastsDoNotNotify() {
        assertFalse(PrayerTimePolicy.timely(1000000, 999999))
        assertTrue(PrayerTimePolicy.timely(1000000, 1000000))
        assertTrue(PrayerTimePolicy.timely(1000000, 1000000 + 15*60*1000))
        assertFalse(PrayerTimePolicy.timely(1000000, 1000000 + 15*60*1000 + 1))
    }
    @Test fun millisecondsAndInvalidApiTimestampsAreRejected() {
        for (seconds in listOf(-1L,0L,1793483280000L)) {
            try { PrayerTimePolicy.epochMillis(seconds); fail("Accepted invalid timestamp") } catch (_: IllegalArgumentException) { }
        }
    }
}
