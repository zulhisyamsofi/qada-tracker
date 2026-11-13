package com.personal.qada_tracker

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONObject
import java.net.URL
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone
import javax.net.ssl.HttpsURLConnection

class PrayerCalendarWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    private fun get(address: String): JSONObject {
        val connection = URL(address).openConnection() as HttpsURLConnection
        connection.connectTimeout = 20000; connection.readTimeout = 20000
        try {
            require(connection.responseCode == 200)
            return JSONObject(connection.inputStream.bufferedReader().use { it.readText() })
        } finally { connection.disconnect() }
    }
    override fun doWork(): Result {
        val config = PrayerTimeStore.config(applicationContext) ?: return Result.success()
        if (!config.enabled) return Result.success()
        val now = System.currentTimeMillis()
        val cached = PrayerTimeStore.calendar(applicationContext)
        if (cached?.key == config.key && cached.fresh(now)) {
            PrayerTimeAlarms.configure(applicationContext, force = true)
            return Result.success()
        }
        return try {
            val anchor = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply { timeInMillis = now; set(Calendar.DAY_OF_MONTH, 1) }
            val current = get("https://api.waktusolat.app/v2/solat/gps/${config.latitude}/${config.longitude}?year=${anchor.get(Calendar.YEAR)}&month=${anchor.get(Calendar.MONTH)+1}")
            val zone = current.getString("zone")
            require(Regex("^[A-Z]{3}\\d{2}$").matches(zone))
            val months = mutableListOf(current)
            for (offset in listOf(-1, 1)) {
                if (isStopped) return Result.success()
                val month = (anchor.clone() as Calendar).apply { add(Calendar.MONTH, offset) }
                months.add(get("https://api.waktusolat.app/v2/solat/$zone?year=${month.get(Calendar.YEAR)}&month=${month.get(Calendar.MONTH)+1}"))
            }
            val slots = mutableListOf<PrayerSlot>()
            for (month in months) {
                require(month.getString("zone") == zone)
                val year = month.getInt("year"); val number = month.getInt("month_number")
                require(year in 2000..2200 && number in 1..12)
                val rows = month.getJSONArray("prayers")
                require(rows.length() > 0)
                for (index in 0 until rows.length()) {
                    val row = rows.getJSONObject(index)
                    val day = row.getInt("day")
                    val date = String.format(Locale.US, "%04d-%02d-%02d", year, number, day)
                    PrayerTimePolicy.names.forEachIndexed { prayerIndex, name ->
                        val at = PrayerTimePolicy.epochMillis(row.getLong(PrayerTimePolicy.apiNames[prayerIndex]))
                        val local = Calendar.getInstance(TimeZone.getTimeZone("Asia/Kuala_Lumpur")).apply { timeInMillis = at }
                        require(local.get(Calendar.YEAR) == year && local.get(Calendar.MONTH)+1 == number && local.get(Calendar.DAY_OF_MONTH) == day)
                        val time = String.format(Locale.US, "%02d:%02d", local.get(Calendar.HOUR_OF_DAY), local.get(Calendar.MINUTE))
                        slots.add(PrayerSlot(name, at, date, time))
                    }
                }
            }
            if (isStopped) return Result.success()
            val candidate = SavedPrayerCalendar(config.key, "Asia/Kuala_Lumpur", now, slots.sortedBy { it.at }, zone)
            val validated = PrayerTimeStore.parse(candidate.json())
            require(validated.fresh(now))
            if (PrayerTimeStore.save(applicationContext, validated)) PrayerTimeAlarms.configure(applicationContext, force = true)
            Result.success()
        } catch (_: Exception) {
            // Keep the existing downloaded timetable and retry with backoff.
            Result.retry()
        }
    }
}
