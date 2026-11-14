package com.personal.qada_tracker

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequest
import androidx.work.PeriodicWorkRequest
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

internal object PrayerTimeAlarms {
    const val OPEN = "open_prayer_times"
    const val CHECK = "com.personal.qada_tracker.PRAYER_TIME"
    private const val CHANNEL = "prayer_times"
    private const val PERIODIC = "prayer_calendar_periodic"
    private const val REFRESH = "prayer_calendar_refresh"
    private fun prefs(context: Context) = context.getSharedPreferences("prayer_time_alarms", Context.MODE_PRIVATE)
    private fun alarms(context: Context) = context.getSystemService(AlarmManager::class.java)
    private fun notifications(context: Context) = context.getSystemService(NotificationManager::class.java)
    fun channel(context: Context) {
        if (Build.VERSION.SDK_INT >= 26) notifications(context).createNotificationChannel(NotificationChannel(CHANNEL, "Prayer times", NotificationManager.IMPORTANCE_DEFAULT).apply { description = "An alert at each of the five prayer times for your selected place." })
    }
    fun notificationsAllowed(context: Context): Boolean = PrayerReminders.appNotificationsAllowed(context) &&
        (Build.VERSION.SDK_INT < 26 || notifications(context).getNotificationChannel(CHANNEL)?.importance != NotificationManager.IMPORTANCE_NONE)
    private fun pending(context: Context, index: Int, slot: PrayerSlot? = null, source: String? = null): PendingIntent = PendingIntent.getBroadcast(
        context, 10001 + index, Intent(context, PrayerTimeReceiver::class.java).apply {
            action = CHECK
            if (slot != null) { putExtra("prayer", slot.prayer); putExtra("at", slot.at) }
            putExtra("source", source)
        }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
    private fun cancel(context: Context, clearNotifications: Boolean = true) {
        for (index in 0..4) {
            alarms(context).cancel(pending(context, index))
            if (clearNotifications) notifications(context).cancel(10001 + index)
        }
    }
    @Synchronized
    fun configure(context: Context, force: Boolean = false, now: Long = System.currentTimeMillis()) {
        channel(context)
        val config = PrayerTimeStore.config(context)
        if (config == null || !config.enabled) {
            cancel(context)
            prefs(context).edit().remove("stamp").remove("source").apply()
            refreshWork(context, null, null, now, false)
            return
        }
        val calendar = PrayerTimeStore.calendar(context)?.takeIf { it.key == config.key }
        val stamp = "${config.key}|${calendar?.fetchedAt}|${PrayerReminders.exactAllowed(context)}"
        if (!force && prefs(context).getString("stamp", null) == stamp) return
        val sourceChanged = prefs(context).getString("source", null) != config.key
        cancel(context, clearNotifications = sourceChanged)
        // Only five alarms are pending. Each delivery schedules the next occurrence.
        // This avoids OS alarm-count limits and works offline through the cache.
        if (calendar != null) for (slot in PrayerTimePolicy.next(calendar.entries, now)) {
            val index = PrayerTimePolicy.names.indexOf(slot.prayer)
            val exact = PrayerReminders.exactAllowed(context)
            val operation = pending(context, index, slot, config.key)
            try {
                if (exact) alarms(context).setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, slot.at, operation)
                else alarms(context).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, slot.at, operation)
            } catch (_: SecurityException) {
                alarms(context).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, slot.at, pending(context, index, slot, config.key))
            }
        }
        prefs(context).edit().putString("stamp", stamp).putString("source", config.key).apply()
        refreshWork(context, config, calendar, now, sourceChanged)
    }
    private fun refreshWork(context: Context, config: PrayerTimeConfig?, calendar: SavedPrayerCalendar?, now: Long, sourceChanged: Boolean) {
        try {
            val work = WorkManager.getInstance(context)
            if (config == null) {
                work.cancelUniqueWork(PERIODIC); work.cancelUniqueWork(REFRESH)
                return
            }
            val constraints = Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()
            val periodic = PeriodicWorkRequest.Builder(PrayerCalendarWorker::class.java, 12, TimeUnit.HOURS)
                .setConstraints(constraints).setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.MINUTES).build()
            work.enqueueUniquePeriodicWork(PERIODIC, ExistingPeriodicWorkPolicy.KEEP, periodic)
            if (calendar == null || !calendar.fresh(now)) {
                val refresh = OneTimeWorkRequest.Builder(PrayerCalendarWorker::class.java).setInitialDelay(1, TimeUnit.MINUTES)
                    .setConstraints(constraints).setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.MINUTES).build()
                work.enqueueUniqueWork(REFRESH, if (sourceChanged) ExistingWorkPolicy.REPLACE else ExistingWorkPolicy.KEEP, refresh)
            }
        } catch (error: Exception) {
            // Already-downloaded prayer alerts must not depend on refresh startup.
            Log.w("PrayerTimeAlarms", "Background refresh unavailable; cached alarms remain scheduled", error)
        }
    }
    @Synchronized
    fun deliver(context: Context, intent: Intent, now: Long = System.currentTimeMillis()) {
        val config = PrayerTimeStore.config(context)
        val calendar = PrayerTimeStore.calendar(context)
        val at = intent.getLongExtra("at", -1)
        val name = intent.getStringExtra("prayer")
        val source = intent.getStringExtra("source")
        val slot = calendar?.entries?.firstOrNull { it.prayer == name && it.at == at }
        val token = "$at|$source|$name"
        val sent = prefs(context).getStringSet("sent", emptySet())!!.toMutableSet()
        val eligible = config?.enabled == true && config.key == source && calendar != null && calendar.key == source && slot != null &&
            PrayerTimePolicy.timely(at, now) && token !in sent && notificationsAllowed(context)
        // Schedule successors first. Do not dismiss the notification we are about to post.
        configure(context, force = true, now = now)
        if (!eligible) return
        val index = PrayerTimePolicy.names.indexOf(slot.prayer)
        val open = PendingIntent.getActivity(context, 10001 + index, Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(OPEN, true)
        }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else Notification.Builder(context)
        builder.setSmallIcon(R.drawable.notification_icon).setContentTitle("Time for ${PrayerTimePolicy.labels[index]}")
            .setContentText("${config.label} · ${slot.time} (${calendar!!.timezone})")
            .setContentIntent(open).setAutoCancel(true).setWhen(at)
        if (Build.VERSION.SDK_INT >= 26) builder.setTimeoutAfter(30 * 60 * 1000L)
        try {
            notifications(context).notify(10001 + index, builder.build())
            sent.add(token)
            prefs(context).edit().putStringSet("sent", sent.sorted().takeLast(400).toSet()).apply()
        } catch (_: SecurityException) { /* Permission was revoked while delivering. */ }
    }

}

class PrayerTimeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        Thread {
            try {
                if (intent.action == PrayerTimeAlarms.CHECK) PrayerTimeAlarms.deliver(context.applicationContext, intent)
                else PrayerTimeAlarms.configure(context.applicationContext, force = true)
            } catch (error: Exception) { Log.w("PrayerTimeAlarms", "Unable to schedule prayer alerts", error) }
            finally { pending.finish() }
        }.start()
    }
}
