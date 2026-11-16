package com.personal.qada_tracker

import org.json.JSONObject
import org.json.JSONArray
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Journal v1/v2 exemption rules shared by alarms and the native widget. */
internal object PrayerExemptions {
    private val names = listOf("subuh", "zohor", "asar", "maghrib", "isyak")
    fun validate(root: JSONObject) {
        require(root.opt("version") is Int && root.getInt("version") in 1..3)
        if (!root.isNull("mutePrayerAlertsWhenExempt")) require(root.opt("mutePrayerAlertsWhenExempt") is Boolean)
        val ids = mutableSetOf<String>()
        var ongoing = 0
        val links = mutableSetOf<String>()
        val replacements = root.optJSONArray("replacements") ?: JSONArray()
        for (i in 0 until replacements.length()) {
            val entry = replacements.getJSONObject(i)
            if (entry.isNull("missedDate")) continue
            require(root.getInt("version") == 3 && entry.opt("missedDate") is String && entry.opt("quantity") is Int && entry.getInt("quantity") == 1)
            val day = entry.getString("missedDate"); val prayer = entry.getString("prayer")
            require(validDate(day) && prayer in names && links.add("$day/$prayer"))
            require(root.getJSONObject("records").getJSONObject(day).getString(prayer) == "missed")
        }
        if (root.isNull("trackingPauses")) return
        require(root.opt("trackingPauses") is JSONArray)
        val periods = root.getJSONArray("trackingPauses")
        require(root.getInt("version") >= 2 || periods.length() == 0)
        for (i in 0 until periods.length()) {
            val p = periods.getJSONObject(i)
            require(p.opt("id") is String && p.getString("id").length in 1..100 && ids.add(p.getString("id")))
            require(p.opt("from") is String && (p.isNull("through") || p.opt("through") is String))
            require(p.isNull("fromPrayer") || p.opt("fromPrayer") is Int)
            require(p.isNull("throughPrayer") || p.opt("throughPrayer") is Int)
            val from = p.getString("from")
            val through = if (p.isNull("through")) null else p.getString("through")
            require(validDate(from) && (through == null || validDate(through)))
            val first = p.optInt("fromPrayer", 0); val last = p.optInt("throughPrayer", 4)
            require(first in 0..4 && last in 0..4 && (through == null || through > from || (through == from && last >= first)))
            if (through == null) require(++ongoing <= 1)
        }
    }
    private fun validDate(value: String): Boolean {
        if (!Regex("\\d{4}-\\d{2}-\\d{2}").matches(value) || value < "1900-01-01" || value > "2200-12-31") return false
        val formatter = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply { isLenient = false }
        return try { formatter.format(formatter.parse(value)!!) == value } catch (_: Exception) { false }
    }
    fun covered(root: JSONObject, date: String, prayer: String): Boolean {
        val index = names.indexOf(prayer); require(index >= 0)
        val periods = root.optJSONArray("trackingPauses") ?: return false
        for (i in 0 until periods.length()) {
            val p = periods.getJSONObject(i)
            val from = p.getString("from")
            val through = if (p.isNull("through")) null else p.getString("through")
            if (date >= from && (through == null || date <= through) &&
                (date != from || index >= p.optInt("fromPrayer", 0)) &&
                (date != through || index <= p.optInt("throughPrayer", 4))) return true
        }
        return false
    }
    fun status(root: JSONObject, date: String, prayer: String): String {
        require(prayer in names)
        val row = root.getJSONObject("records").optJSONObject(date)
        if (row?.has(prayer) == true) {
            val value = row.getString(prayer)
            require(value in setOf("unrecorded", "performed", "missed", "exempt"))
            require(value != "exempt" || root.getInt("version") >= 2)
            return value
        }
        return if (covered(root, date, prayer)) "exempt" else "unrecorded"
    }
    fun alertAllowed(root: JSONObject, at: Long, prayer: String): Boolean {
        if (!root.optBoolean("mutePrayerAlertsWhenExempt", true)) return true
        val date = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(at))
        return status(root, date, prayer) != "exempt"
    }
    fun stamp(root: JSONObject): String {
        val parts = mutableListOf(root.optJSONArray("trackingPauses")?.toString() ?: "[]", root.optBoolean("mutePrayerAlertsWhenExempt", true).toString())
        val records = root.getJSONObject("records")
        for (date in records.keys().asSequence().toList().sorted()) {
            val row = records.getJSONObject(date)
            for (prayer in names) if (row.has(prayer) && (row.getString(prayer) == "exempt" || covered(root, date, prayer))) {
                parts.add("$date/$prayer:${row.getString(prayer)}")
            }
        }
        return MessageDigest.getInstance("SHA-256").digest(parts.joinToString("|").toByteArray()).joinToString("") { "%02x".format(it) }
    }
}
