package com.personal.qada_tracker

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

internal data class PrayerTimeConfig(val key: String, val label: String, val latitude: Double, val longitude: Double, val enabled: Boolean)
internal data class SavedPrayerCalendar(val key: String, val timezone: String, val fetchedAt: Long, val entries: List<PrayerSlot>, val zone: String = "") {
    fun fresh(now: Long): Boolean {
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply { timeZone = TimeZone.getTimeZone(timezone) }.format(Date(now))
        return entries.count { it.date == today } == 5 && entries.last().at > now + 14 * 24 * 60 * 60 * 1000L
    }
    fun json(): JSONObject = JSONObject().put("version", 1).put("sourceKey", key).put("timezone", timezone).put("fetchedAt", fetchedAt).put("zone", zone)
        .put("entries", JSONArray().apply { entries.forEach { put(JSONObject().put("prayer", it.prayer).put("at", it.at).put("date", it.date).put("time", it.time)) } })
}

internal object PrayerTimeStore {
    private fun database(context: Context, writable: Boolean = false): SQLiteDatabase? {
        val file = File(context.filesDir, "journal.sqlite")
        if (!file.exists()) return null
        return SQLiteDatabase.openDatabase(file.path, null, if (writable) SQLiteDatabase.OPEN_READWRITE else SQLiteDatabase.OPEN_READONLY)
    }
    private fun config(db: SQLiteDatabase): PrayerTimeConfig? = db.rawQuery("SELECT document FROM journal WHERE id = 1", null).use { cursor ->
        if (!cursor.moveToFirst()) return@use null
        val root = JSONObject(cursor.getString(0))
        val settings = root.optJSONObject("prayerTimes") ?: return@use null
        val place = settings.getJSONObject("place")
        val lat = place.getDouble("latitude"); val lon = place.getDouble("longitude")
        require(lat.isFinite() && lon.isFinite() && lat in -90.0..90.0 && lon in -180.0..180.0)
        PrayerTimeConfig(place.getString("key"), place.getString("label"), lat, lon, settings.getBoolean("notifications"))
    }
    fun config(context: Context): PrayerTimeConfig? = try { database(context)?.use { config(it) } } catch (_: Exception) { null }
    fun calendar(context: Context): SavedPrayerCalendar? = try {
        database(context)?.use { calendar(it) }
    } catch (_: Exception) { null }

    internal fun calendar(db: SQLiteDatabase): SavedPrayerCalendar? = db.rawQuery("SELECT document FROM prayer_calendar WHERE id = 1", null).use { cursor ->
        if (!cursor.moveToFirst()) null else parse(JSONObject(cursor.getString(0)))
    }

    fun parse(root: JSONObject): SavedPrayerCalendar {
        require(root.getInt("version") == 1)
        val zone = root.getString("timezone")
        require(TimeZone.getAvailableIDs().contains(zone))
        val formatter = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.US).apply { timeZone = TimeZone.getTimeZone(zone) }
        val seen = mutableSetOf<String>()
        val array = root.getJSONArray("entries")
        val slots = (0 until array.length()).map { index ->
            val row = array.getJSONObject(index)
            val slot = PrayerSlot(row.getString("prayer"), row.getLong("at"), row.getString("date"), row.getString("time"))
            require(slot.prayer in PrayerTimePolicy.names && seen.add("${slot.date}/${slot.prayer}"))
            require(formatter.format(Date(slot.at)) == "${slot.date} ${slot.time}")
            slot
        }.sortedBy { it.at }
        require(slots.isNotEmpty() && slots.groupBy { it.date }.values.all { it.size == 5 })
        return SavedPrayerCalendar(root.getString("sourceKey"), zone, root.getLong("fetchedAt"), slots, root.optString("zone"))
    }

    fun save(context: Context, calendar: SavedPrayerCalendar): Boolean {
        val db = database(context, true) ?: return false
        db.use {
            db.beginTransaction()
            try {
                // A completed request for the old place must not replace a newer selection.
                if (config(db)?.key != calendar.key) return false
                db.execSQL("INSERT OR REPLACE INTO prayer_calendar(id, document) VALUES (1, ?)", arrayOf(calendar.json().toString()))
                db.setTransactionSuccessful()
                return true
            } finally { db.endTransaction() }
        }
    }
}
