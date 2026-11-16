package com.personal.qada_tracker

import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

internal class WidgetBalanceConflict : IllegalStateException()

/** Shared journal v1/v2 rules for the native launcher writer. No qada is recorded. */
internal object PrayerWidgetPolicy {
    val prayers = listOf("subuh", "zohor", "asar", "maghrib", "isyak")
    val labels = listOf("Subuh", "Zohor", "Asar", "Maghrib", "Isyak")

    fun nextMidnight(now: Calendar): Calendar = (now.clone() as Calendar).apply {
        add(Calendar.DAY_OF_MONTH, 1)
        set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 1); set(Calendar.MILLISECOND, 0)
    }

    private fun validDay(day: String): Boolean {
        if (!Regex("[0-9]{4}-[0-9]{2}-[0-9]{2}").matches(day)) return false
        val formatter = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply { isLenient = false }
        return try { formatter.format(formatter.parse(day)!!) == day } catch (_: Exception) { false }
    }

    fun validate(root: JSONObject, date: String) {
        PrayerExemptions.validate(root)
        require(validDay(date))
        val start = root.getString("startDate")
        require(validDay(start) && start >= "1900-01-01" && start <= date)
        root.getJSONObject("records")
    }

    fun status(root: JSONObject, date: String, prayer: String): String {
        require(prayer in prayers)
        return PrayerExemptions.status(root, date, prayer)

    }

    /** Copy before editing so rejection cannot change even the caller's object. */
    fun toggle(root: JSONObject, date: String, prayer: String): JSONObject {
        validate(root, date)
        if (status(root, date, prayer) != "performed") return perform(root, date, prayer)
        return JSONObject(root.toString()).apply {
            getJSONObject("records").getJSONObject(date).put(prayer, "unrecorded")
        }
    }

    fun perform(root: JSONObject, date: String, prayer: String): JSONObject {
        validate(root, date)
        val status = status(root, date, prayer)
        if (status == "performed") return root
        val entries = root.getJSONArray("replacements")
        for (index in 0 until entries.length()) {
            val entry = entries.getJSONObject(index)
            if (entry.optString("missedDate") == date && entry.getString("prayer") == prayer) throw WidgetBalanceConflict()
        }
        if (status == "missed" && balance(root, prayer) < 1L) throw WidgetBalanceConflict()
        return JSONObject(root.toString()).apply {
            val records = getJSONObject("records")
            val row = records.optJSONObject(date) ?: JSONObject().also { records.put(date, it) }
            row.put(prayer, "performed")
        }
    }

    private fun balance(root: JSONObject, prayer: String): Long {
        var balance = root.getJSONObject("starting").getLong(prayer)
        require(balance in 0L..1000000000L)
        val records = root.getJSONObject("records")
        for (date in records.keys()) if (status(root, date, prayer) == "missed") balance++
        val entries = root.getJSONArray("replacements")
        for (index in 0 until entries.length()) {
            val entry = entries.getJSONObject(index)
            if (entry.getString("prayer") == prayer) {
                val count = entry.getLong("quantity")
                require(count in 1L..1000000000L)
                balance -= count
            }
        }
        return balance
    }
}
