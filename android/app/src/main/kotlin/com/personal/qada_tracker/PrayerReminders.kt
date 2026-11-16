package com.personal.qada_tracker

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import android.util.Log
import org.json.JSONObject
import java.io.File
import java.util.Calendar

internal object PrayerReminders {
    private const val ID = 2300
    private const val CHANNEL = "daily_check_in"
    private const val PREFS = "daily_reminder"
    const val CHECK = "com.personal.qada_tracker.CHECK_REMINDER"
    const val OPEN_TODAY = "open_reminder_today"
    private val prayers = listOf("subuh", "zohor", "asar", "maghrib", "isyak")
    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private fun manager(context: Context) = context.getSystemService(NotificationManager::class.java)
    private fun alarms(context: Context) = context.getSystemService(AlarmManager::class.java)

    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= 26) {
            manager(context).createNotificationChannel(NotificationChannel(
                CHANNEL, "Daily prayer check-in", NotificationManager.IMPORTANCE_DEFAULT
            ).apply { description = "A check-in at your chosen time when any prayer is still unrecorded today." })
        }
    }

    fun appNotificationsAllowed(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return false
        if (!manager(context).areNotificationsEnabled()) return false
        return true
    }
    fun notificationsAllowed(context: Context): Boolean = appNotificationsAllowed(context) &&
        (Build.VERSION.SDK_INT < 26 || manager(context).getNotificationChannel(CHANNEL)?.importance != NotificationManager.IMPORTANCE_NONE)
    fun exactAllowed(context: Context): Boolean = Build.VERSION.SDK_INT < 31 || alarms(context).canScheduleExactAlarms()
    fun access(context: Context): Map<String, Boolean> = mapOf(
        "notifications" to notificationsAllowed(context), "appNotifications" to appNotificationsAllowed(context), "exactAlarms" to exactAllowed(context),
        "prayerNotifications" to PrayerTimeAlarms.notificationsAllowed(context)
    )

    private fun pending(context: Context, date: String = ""): PendingIntent = PendingIntent.getBroadcast(
        context, ID, Intent(context, PrayerReminderReceiver::class.java).apply {
            action = CHECK
            putExtra("date", date)
        }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    @Synchronized
    fun sync(context: Context, enabled: Boolean, now: Calendar = Calendar.getInstance()) {
        createChannel(context)
        prefs(context).edit().putBoolean("enabled", enabled).commit()
        if (!enabled) {
            alarms(context).cancel(pending(context))
            manager(context).cancel(ID)
            return
        }
        // Keep a displayed reminder until every prayer is confirmed, including restore.
        val journal = journal(context)
        if (journal != null && !hasUnrecordedPrayer(journal, ReminderPolicy.day(now))) {
            manager(context).cancel(ID)
        }
        schedule(context, now)
    }

    @Synchronized
    fun schedule(context: Context, now: Calendar = Calendar.getInstance()) {
        if (!prefs(context).getBoolean("enabled", false)) return
        val minutes = journal(context)?.optInt("reminderMinutes", 23 * 60) ?: 23 * 60
        val target = ReminderPolicy.next(now, prefs(context).getString("lastChecked", null), minutes)
        val operation = pending(context, ReminderPolicy.day(target))
        // Notification permission can be revoked in Settings without opening the app.
        // Keep the next check, but the receiver rechecks access before posting.
        try {
            if (exactAllowed(context)) {
                alarms(context).setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target.timeInMillis, operation)
            } else {
                alarms(context).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target.timeInMillis, operation)
            }
        } catch (_: SecurityException) {
            // Handle permission revocation racing with scheduling; no exact-alarm bypass.
            alarms(context).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target.timeInMillis, operation)
        }
    }

    private fun journal(context: Context): JSONObject? {
        // path_provider's Android application-support directory is Context.filesDir.
        val file = File(context.filesDir, "journal.sqlite")
        if (!file.exists()) return null
        return try {
            SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
                db.rawQuery("SELECT document FROM journal WHERE id = 1", null).use { cursor ->
                    if (!cursor.moveToFirst()) null else JSONObject(cursor.getString(0)).takeIf {
                    PrayerExemptions.validate(it)
                    it.optInt("version") in 1..2 && it.optJSONObject("records") != null &&
                        (!it.has("reminderMinutes") || (it.opt("reminderMinutes") is Int && it.getInt("reminderMinutes") in 0..1439))
                    }
                }
            }
        } catch (error: Exception) {
            // Never guess that missing/unreadable data means the user missed prayers.
            Log.w("PrayerReminders", "Cannot read journal for reminder", error)
            null
        }
    }

    private fun hasUnrecordedPrayer(journal: JSONObject, date: String): Boolean {
        return ReminderPolicy.hasUnrecordedPrayer(prayers.map { PrayerExemptions.status(journal, date, it) })
    }

    @Synchronized
    fun deliver(context: Context, expectedDay: String?, now: Calendar = Calendar.getInstance()) {
        if (!prefs(context).getBoolean("enabled", false)) return
        val date = ReminderPolicy.day(now)
        val journal = journal(context)
        val minutes = journal?.optInt("reminderMinutes", 23 * 60) ?: 23 * 60
        val notify = journal != null && ReminderPolicy.shouldNotify(
            journal.optBoolean("reminderEnabled", false), expectedDay, now,
            prefs(context).getString("lastChecked", null), hasUnrecordedPrayer(journal, date), minutes
        ) && notificationsAllowed(context)
        // A delayed yesterday alarm must not suppress today's future check.
        if (expectedDay == date && now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE) >= minutes) {
            prefs(context).edit().putString("lastChecked", date).commit()
        }
        if (notify) {
            val open = PendingIntent.getActivity(context, ID, Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra(OPEN_TODAY, true)
            }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            @Suppress("DEPRECATION")
            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else Notification.Builder(context)
            builder.setSmallIcon(R.drawable.notification_icon)
                .setContentTitle(if (journal?.optString("language") == "ms") "Masa untuk jurnal solat anda" else "A moment for your prayer journal")
                .setContentText(if (journal?.optString("language") == "ms") "Masih ada solat belum direkod hari ini. Rekod sebelum tengah malam." else "You still have unrecorded prayers today. Check in before midnight.")
                .setContentIntent(open).setAutoCancel(true)
            if (Build.VERSION.SDK_INT >= 26) {
                val midnight = (now.clone() as Calendar).apply {
                    add(Calendar.DAY_OF_MONTH, 1)
                    set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
                    set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
                }
                builder.setTimeoutAfter(midnight.timeInMillis - now.timeInMillis)
            }
            try { manager(context).notify(ID, builder.build()) } catch (_: SecurityException) {
                // Android 13 permission may have changed since the check above.
            }
        }
        schedule(context, now)
    }
}

class PrayerReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        Thread {
            try {
                if (intent.action == PrayerReminders.CHECK) {
                    PrayerReminders.deliver(context.applicationContext, intent.getStringExtra("date"))
                } else {
                    // Boot, app update, clock/timezone changes, and alarm permission grants.
                    PrayerReminders.schedule(context.applicationContext)
                }
            } catch (error: Exception) {
                Log.w("PrayerReminders", "Reminder check failed", error)
            } finally { pending.finish() }
        }.start()
    }
}
