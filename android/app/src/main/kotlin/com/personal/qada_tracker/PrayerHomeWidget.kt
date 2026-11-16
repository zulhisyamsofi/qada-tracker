package com.personal.qada_tracker

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.widget.RemoteViews
import android.widget.Toast
import org.json.JSONObject
import java.util.Calendar
import java.util.concurrent.Executors

/** Native launcher widget: works without starting a Flutter engine. */
class PrayerHomeWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) = updateAsync(context)
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) = updateAsync(context)
    override fun onEnabled(context: Context) = schedule(context)
    override fun onDisabled(context: Context) = cancel(context)

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            MARK -> {
                val pending = goAsync()
                execute {
                    try {
                        val prayer = intent.getStringExtra("prayer")
                        val expectedDay = intent.getStringExtra("date")
                        val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
                        if (prayer !in PrayerWidgetPolicy.prayers || expectedDay == null || id !in ids(context)) return@execute
                        val result = try { PrayerWidgetStore.toggle(context, prayer!!, expectedDay) }
                            catch (error: Exception) {
                                Log.w("PrayerWidget", "Could not save prayer", error)
                                WidgetWriteResult.UNAVAILABLE
                            }
                        if (result == WidgetWriteResult.SAVED || result == WidgetWriteResult.CLEARED) {
                            context.sendBroadcast(Intent(JOURNAL_CHANGED).setPackage(context.packageName))
                            try {
                                PrayerWidgetStore.read(context)?.let { PrayerReminders.sync(context, it.optBoolean("reminderEnabled", false)) }
                            } catch (error: Exception) { Log.w("PrayerWidget", "Could not refresh check-in reminder", error) }
                        }
                        val label = PrayerWidgetPolicy.labels[PrayerWidgetPolicy.prayers.indexOf(prayer)]
                        val malay = try { PrayerWidgetStore.read(context)?.optString("language") == "ms" } catch (_: Exception) { false }
                        val message = if (malay) when (result) {
                            WidgetWriteResult.SAVED -> "$label direkod untuk hari ini"
                            WidgetWriteResult.CLEARED -> "$label dikembalikan ke belum direkod"
                            WidgetWriteResult.STALE_DAY -> "Hari baharu. Tekan sekali lagi untuk merekod solat hari ini."
                            WidgetWriteResult.BALANCE_CONFLICT -> "Batalkan penggantian qada yang berkenaan dalam aplikasi dahulu."
                            WidgetWriteResult.UNAVAILABLE -> "Tidak dapat disimpan. Buka Qada Tracker dan cuba lagi."
                            WidgetWriteResult.NOT_STARTED -> "Waktu $label belum bermula. Semak waktunya di Hari Ini."
                            WidgetWriteResult.EXEMPT -> "$label dikecualikan. Buka aplikasi untuk mengubahnya."
                            WidgetWriteResult.TIMES_UNAVAILABLE -> "Muat semula waktu solat hari ini dalam aplikasi dahulu."
                        } else when (result) {
                            WidgetWriteResult.SAVED -> "$label recorded for today"
                            WidgetWriteResult.CLEARED -> "$label returned to unrecorded"
                            WidgetWriteResult.STALE_DAY -> "New day. Tap again to record today's prayer."
                            WidgetWriteResult.BALANCE_CONFLICT -> "Undo the matching qada replacement in the app first."
                            WidgetWriteResult.UNAVAILABLE -> "Could not save. Open Qada Tracker and try again."
                            WidgetWriteResult.NOT_STARTED -> "$label hasn't started yet. Check Today for its time."
                            WidgetWriteResult.EXEMPT -> "$label is exempt. Open the app to change this."
                            WidgetWriteResult.TIMES_UNAVAILABLE -> "Refresh today's prayer times in the app first."
                        }
                        Handler(Looper.getMainLooper()).post { Toast.makeText(context, message, Toast.LENGTH_LONG).show() }
                        refreshAll(context)
                    } catch (error: Exception) { Log.w("PrayerWidget", "Widget tap failed", error) }
                    finally { pending.finish() }
                }
            }
            ROLLOVER, Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED -> updateAsync(context)
            else -> super.onReceive(context, intent)
        }
    }

    private fun updateAsync(context: Context) {
        val pending = goAsync()
        execute {
            try { refreshAll(context) }
            catch (error: Exception) { Log.w("PrayerWidget", "Widget refresh failed", error) }
            finally { pending.finish() }
        }
    }

    companion object {
        // Keep the action stable for widgets placed before toggling was added.
        const val MARK = "com.personal.qada_tracker.WIDGET_PERFORM"
        const val ROLLOVER = "com.personal.qada_tracker.WIDGET_MIDNIGHT"
        const val JOURNAL_CHANGED = "com.personal.qada_tracker.WIDGET_JOURNAL_CHANGED"
        private const val ALARM_ID = 2400
        private val executor = Executors.newSingleThreadExecutor()
        private val boxes = intArrayOf(R.id.widget_subuh, R.id.widget_zohor, R.id.widget_asar, R.id.widget_maghrib, R.id.widget_isyak)
        private val names = intArrayOf(R.id.widget_subuh_name, R.id.widget_zohor_name, R.id.widget_asar_name, R.id.widget_maghrib_name, R.id.widget_isyak_name)
        private val symbols = intArrayOf(R.id.widget_subuh_status, R.id.widget_zohor_status, R.id.widget_asar_status, R.id.widget_maghrib_status, R.id.widget_isyak_status)

        internal fun execute(block: () -> Unit) { executor.execute(block) }
        private fun ids(context: Context) = AppWidgetManager.getInstance(context).getAppWidgetIds(ComponentName(context, PrayerHomeWidget::class.java))

        internal fun refreshAll(context: Context) {
            val ids = ids(context)
            if (ids.isEmpty()) { cancel(context); return }
            val now = Calendar.getInstance()
            val root = try { PrayerWidgetStore.read(context) }
                catch (error: Exception) { Log.w("PrayerWidget", "Could not read journal", error); null }
            val manager = AppWidgetManager.getInstance(context)
            for (id in ids) manager.updateAppWidget(id, views(context, id, root, now))
            schedule(context)
        }

        internal fun views(context: Context, widgetId: Int, journal: JSONObject?, now: Calendar): RemoteViews {
            val date = ReminderPolicy.day(now)
            val root = journal?.takeIf {
                try {
                    PrayerWidgetPolicy.validate(it, date)
                    PrayerWidgetPolicy.prayers.forEach { p -> PrayerWidgetPolicy.status(it, date, p) }
                    true
                } catch (_: Exception) { false }
            }
            val systemDark = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
            val dark = when (root?.optString("theme")) { "dark" -> true; "light" -> false; else -> systemDark }
            val ink = android.graphics.Color.parseColor(if (dark) "#EDF9F2" else "#173D31")
            val muted = android.graphics.Color.parseColor(if (dark) "#B5D8CA" else "#4C7163")
            val doneInk = android.graphics.Color.parseColor("#103B2C")
            val open = PendingIntent.getActivity(context, ALARM_ID, Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra(PrayerReminders.OPEN_TODAY, true)
            }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            return RemoteViews(context.packageName, R.layout.prayer_widget).apply {
                setInt(R.id.widget_root, "setBackgroundResource", if (dark) R.drawable.widget_panel_dark else R.drawable.widget_panel_light)
                setOnClickPendingIntent(R.id.widget_root, open)
                setOnClickPendingIntent(R.id.widget_title, open)
                setOnClickPendingIntent(R.id.widget_prayers, open)
                setTextColor(R.id.widget_title, ink)
                for ((index, prayer) in PrayerWidgetPolicy.prayers.withIndex()) {
                    val status = if (root != null) PrayerWidgetPolicy.status(root, date, prayer) else "unrecorded"
                    val performed = status == "performed"
                    val exempt = status == "exempt"
                    val background = when {
                        performed -> R.drawable.widget_box_done
                        status == "missed" && dark -> R.drawable.widget_box_missed_dark
                        status == "missed" -> R.drawable.widget_box_missed_light
                        dark -> R.drawable.widget_box_dark
                        else -> R.drawable.widget_box_light
                    }
                    setInt(boxes[index], "setBackgroundResource", background)
                    setTextColor(names[index], if (exempt) muted else if (performed) doneInk else ink)
                    setTextColor(symbols[index], if (performed) doneInk else muted)
                    setTextViewText(symbols[index], when (status) { "performed" -> "✓"; "missed" -> "!"; "exempt" -> "–"; else -> "○" })
                    val label = PrayerWidgetPolicy.labels[index]
                    setContentDescription(boxes[index], if (root == null) "$label. Open Qada Tracker to start or refresh." else "$label, $status. ${if (exempt) "No qada. Tap to open the app." else if (performed) "Tap to leave unrecorded." else "Tap to mark performed for today."}")
                    val action = if (root == null || exempt) open else PendingIntent.getBroadcast(context, 0,
                        Intent(context, PrayerHomeWidget::class.java).apply {
                            this.action = MARK
                            data = Uri.Builder().scheme("qada-widget").authority("perform").appendPath(widgetId.toString()).appendPath(date).appendPath(prayer).build()
                            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                            putExtra("date", date); putExtra("prayer", prayer)
                        }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                    setOnClickPendingIntent(boxes[index], action)
                }
            }
        }

        private fun alarm(context: Context) = PendingIntent.getBroadcast(context, ALARM_ID,
            Intent(context, PrayerHomeWidget::class.java).setAction(ROLLOVER),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        private fun cancel(context: Context) { context.getSystemService(AlarmManager::class.java).cancel(alarm(context)) }

        private fun schedule(context: Context) {
            if (ids(context).isEmpty()) { cancel(context); return }
            val manager = context.getSystemService(AlarmManager::class.java)
            val at = PrayerWidgetPolicy.nextMidnight(Calendar.getInstance()).timeInMillis
            val operation = alarm(context)
            try {
                if (Build.VERSION.SDK_INT < 31 || manager.canScheduleExactAlarms()) manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, operation)
                else manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, operation)
            } catch (_: SecurityException) { manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, operation) }
        }
    }
}
