package com.personal.qada_tracker


internal data class PrayerSlot(val prayer: String, val at: Long, val date: String, val time: String)
internal object PrayerTimePolicy {
    val names = listOf("subuh", "zohor", "asar", "maghrib", "isyak")
    val labels = listOf("Subuh", "Zohor", "Asar", "Maghrib", "Isyak")
    val apiNames = listOf("fajr", "dhuhr", "asr", "maghrib", "isha")
    fun next(entries: List<PrayerSlot>, now: Long): List<PrayerSlot> = names.mapNotNull { name ->
        entries.filter { it.prayer == name && it.at > now }.minByOrNull { it.at }
    }
    fun timely(at: Long, now: Long): Boolean = now >= at && now - at <= 15 * 60 * 1000L
    fun epochMillis(seconds: Long): Long {
        require(seconds > 0 && seconds < 10000000000L)
        return seconds * 1000L
    }
}
