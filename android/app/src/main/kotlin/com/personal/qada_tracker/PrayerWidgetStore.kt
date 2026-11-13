package com.personal.qada_tracker

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import org.json.JSONObject
import java.io.File
import java.util.Calendar

internal enum class WidgetWriteResult { SAVED, CLEARED, STALE_DAY, BALANCE_CONFLICT, UNAVAILABLE, NOT_STARTED, TIMES_UNAVAILABLE }

internal object PrayerWidgetStore {
    private fun database(context: Context, writable: Boolean): SQLiteDatabase? {
        val file = File(context.filesDir, "journal.sqlite")
        // Opening the widget never creates or replaces a journal. First launch
        // of Flutter owns schema initialization/migration and the start date.
        if (!file.exists()) return null
        return SQLiteDatabase.openDatabase(file.path, null,
            if (writable) SQLiteDatabase.OPEN_READWRITE else SQLiteDatabase.OPEN_READONLY)
    }

    private fun read(db: SQLiteDatabase): JSONObject? = db.rawQuery(
        "SELECT document FROM journal WHERE id = 1", null
    ).use { cursor -> if (cursor.moveToFirst()) JSONObject(cursor.getString(0)) else null }

    fun read(context: Context): JSONObject? = database(context, false)?.use { read(it) }

    fun toggle(context: Context, prayer: String, expectedDay: String,
                clock: () -> Calendar = { Calendar.getInstance() }): WidgetWriteResult {
        require(prayer in PrayerWidgetPolicy.prayers)
        val db = database(context, true) ?: return WidgetWriteResult.UNAVAILABLE
        db.use {
            db.beginTransaction()
            try {
                // Resolve the local day after obtaining the write lock. A stale
                // launcher view must refresh before recording a different day.
                val now = clock()
                val date = ReminderPolicy.day(now)
                if (date != expectedDay) return WidgetWriteResult.STALE_DAY
                val root = read(db) ?: return WidgetWriteResult.UNAVAILABLE
                PrayerWidgetPolicy.validate(root, date)
                val clearing = PrayerWidgetPolicy.status(root, date, prayer) == "performed"
                if (!clearing) {
                    // Check the saved source and dated timetable under the same
                    // write lock as the journal. No network or Flutter is needed.
                    val calendar = try { PrayerTimeStore.calendar(db) } catch (_: Exception) { null }
                    val key = root.optJSONObject("prayerTimes")?.optJSONObject("place")?.optString("key")
                    val times = calendar?.entries?.filter { it.date == date }
                    if (calendar == null || key != calendar.key || times?.size != 5) return WidgetWriteResult.TIMES_UNAVAILABLE
                    val time = times.firstOrNull { it.prayer == prayer } ?: return WidgetWriteResult.TIMES_UNAVAILABLE
                    if (now.timeInMillis < time.at) return WidgetWriteResult.NOT_STARTED
                }
                val next = try { PrayerWidgetPolicy.toggle(root, date, prayer) }
                    catch (_: WidgetBalanceConflict) { return WidgetWriteResult.BALANCE_CONFLICT }
                db.execSQL("UPDATE journal SET document = ? WHERE id = 1", arrayOf(next.toString()))
                db.setTransactionSuccessful()
                return if (clearing) WidgetWriteResult.CLEARED else WidgetWriteResult.SAVED
            } finally { db.endTransaction() }
        }
    }
}
