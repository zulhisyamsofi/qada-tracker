package com.personal.qada_tracker

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProviderInfo
import android.content.ComponentName
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import android.widget.FrameLayout
import android.widget.TextView
import org.json.JSONArray
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import org.robolectric.annotation.SQLiteMode
import java.io.File
import java.util.Calendar
import java.util.TimeZone
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@SQLiteMode(SQLiteMode.Mode.NATIVE)
class PrayerHomeWidgetTest {
    private lateinit var context: Context
    private lateinit var file: File
    private val today = "2026-11-13"
    private fun clock(zone: String = "Asia/Kuala_Lumpur", year: Int = 2026, month: Int = 11, day: Int = 13, hour: Int = 12): Calendar =
        Calendar.getInstance(TimeZone.getTimeZone(zone)).apply {
            clear(); set(year, month - 1, day, hour, 0, 0)
        }
    private fun journal(): JSONObject = JSONObject().put("version", 1).put("startDate", "2026-11-12")
        .put("theme", "light").put("reminderEnabled", true)
        .put("prayerTimes", JSONObject().put("preserve", "settings").put("place", JSONObject().put("key", "widget-test-place")))
        .put("starting", JSONObject().apply { PrayerWidgetPolicy.prayers.forEach { put(it, 0) } })
        .put("records", JSONObject().put("2026-11-12", JSONObject().put("isyak", "performed")))
        .put("replacements", JSONArray())
    private fun save(root: JSONObject) {
        SQLiteDatabase.openOrCreateDatabase(file, null).use { db ->
            db.execSQL("CREATE TABLE IF NOT EXISTS journal (id INTEGER PRIMARY KEY CHECK (id = 1), document TEXT NOT NULL)")
            db.execSQL("INSERT OR REPLACE INTO journal(id,document) VALUES(1,?)", arrayOf(root.toString()))
            db.execSQL("CREATE TABLE IF NOT EXISTS prayer_calendar (id INTEGER PRIMARY KEY CHECK (id = 1), document TEXT NOT NULL)")
            // Unrelated widget cases use an already-started saved timetable.
            val dates = listOf(today, "2026-11-14", "2026-11-18", ReminderPolicy.day(Calendar.getInstance())).distinct()
            val formatter = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm", java.util.Locale.US).apply { timeZone = TimeZone.getTimeZone("Asia/Kuala_Lumpur") }
            val slots = dates.flatMap { date -> PrayerWidgetPolicy.prayers.map { p -> PrayerSlot(p, formatter.parse("$date 00:00")!!.time, date, "00:00") } }.sortedBy { it.at }
            db.execSQL("INSERT OR REPLACE INTO prayer_calendar(id,document) VALUES(1,?)", arrayOf(SavedPrayerCalendar("widget-test-place", "Asia/Kuala_Lumpur", 0, slots).json().toString()))
        }
    }
    @Before fun setup() {
        context = RuntimeEnvironment.getApplication()
        file = File(context.filesDir, "journal.sqlite")
        file.delete()
    }
    @After fun cleanup() { file.delete() }

    @Test fun fiveBoxesWriteSharedJournalWithoutFlutterAndRepeatedTapsAreIdempotent() {
        val original = journal()
        save(original)
        for (prayer in PrayerWidgetPolicy.prayers) {
            assertEquals(WidgetWriteResult.SAVED, PrayerWidgetStore.perform(context, prayer, today) { clock() })
            assertEquals(WidgetWriteResult.ALREADY_DONE, PrayerWidgetStore.perform(context, prayer, today) { clock() })
        }
        val stored = PrayerWidgetStore.read(context)!!
        assertTrue(PrayerWidgetPolicy.prayers.all { PrayerWidgetPolicy.status(stored, today, it) == "performed" })
        assertEquals("performed", PrayerWidgetPolicy.status(stored, "2026-11-12", "isyak"))
        assertEquals(original.getString("startDate"), stored.getString("startDate"))
        assertEquals(original.getJSONObject("prayerTimes").toString(), stored.getJSONObject("prayerTimes").toString())
        assertTrue(stored.getBoolean("reminderEnabled"))
        assertEquals("light", stored.getString("theme"))
        assertEquals(0, stored.getJSONArray("replacements").length())
    }

    @Test fun missedPrayerCorrectionPreservesLedgerAndRejectsNegativeBalance() {
        val root = journal()
        root.getJSONObject("records").put(today, JSONObject().put("subuh", "missed"))
        root.getJSONArray("replacements").put(JSONObject().put("id", "one").put("prayer", "subuh").put("quantity", 1).put("completedAt", "2026-11-13T10:00:00"))
        save(root)
        val previous = PrayerWidgetStore.read(context)!!.toString()
        assertEquals(WidgetWriteResult.BALANCE_CONFLICT, PrayerWidgetStore.perform(context, "subuh", today) { clock() })
        assertEquals(previous, PrayerWidgetStore.read(context)!!.toString())
        // A starting balance makes the correction valid without changing any replacement.
        root.getJSONObject("starting").put("subuh", 1)
        save(root)
        assertEquals(WidgetWriteResult.SAVED, PrayerWidgetStore.perform(context, "subuh", today) { clock() })
        val stored = PrayerWidgetStore.read(context)!!
        assertEquals(1, stored.getJSONObject("starting").getInt("subuh"))
        assertEquals(root.getJSONArray("replacements").toString(), stored.getJSONArray("replacements").toString())
        assertEquals("performed", PrayerWidgetPolicy.status(stored, today, "subuh"))
    }

    @Test fun midnightAndDelayedTapsNeverWriteYesterdayOrSilentlyMissElapsedDays() {
        save(PrayerWidgetPolicy.perform(journal(), today, "subuh"))
        val tomorrow = clock(day = 14, hour = 0)
        assertEquals(WidgetWriteResult.STALE_DAY, PrayerWidgetStore.perform(context, "zohor", today) { tomorrow })
        assertEquals(WidgetWriteResult.SAVED, PrayerWidgetStore.perform(context, "zohor", "2026-11-14") { tomorrow })
        val nextWeek = clock(day = 18)
        assertEquals(WidgetWriteResult.SAVED, PrayerWidgetStore.perform(context, "asar", "2026-11-18") { nextWeek })
        val stored = PrayerWidgetStore.read(context)!!
        assertEquals("performed", PrayerWidgetPolicy.status(stored, today, "subuh"))
        assertEquals("unrecorded", PrayerWidgetPolicy.status(stored, today, "zohor"))
        assertEquals("performed", PrayerWidgetPolicy.status(stored, "2026-11-14", "zohor"))
        assertFalse(stored.getJSONObject("records").has("2026-11-15"))
        assertEquals("unrecorded", PrayerWidgetPolicy.status(stored, "2026-11-15", "asar"))
        assertEquals("performed", PrayerWidgetPolicy.status(stored, "2026-11-18", "asar"))
    }

    @Test fun writeFailureLeavesOriginalJournalUntouched() {
        save(journal())
        val original = PrayerWidgetStore.read(context)!!.toString()
        SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READWRITE).use {
            it.execSQL("CREATE TRIGGER reject_write BEFORE UPDATE ON journal BEGIN SELECT RAISE(ABORT, 'write failure'); END")
        }
        try { PrayerWidgetStore.perform(context, "subuh", today) { clock() }; fail("Accepted failed write") }
        catch (_: android.database.sqlite.SQLiteException) { }
        assertEquals(original, PrayerWidgetStore.read(context)!!.toString())
    }

    @Test fun unavailableOrUnsupportedJournalIsNeverInitializedOrReplacedByWidget() {
        assertNull(PrayerWidgetStore.read(context))
        assertEquals(WidgetWriteResult.UNAVAILABLE, PrayerWidgetStore.perform(context, "subuh", today) { clock() })
        assertFalse(file.exists())
        val root = journal().put("version", 999)
        save(root)
        try { PrayerWidgetStore.perform(context, "subuh", today) { clock() }; fail("Accepted unsupported version") }
        catch (_: IllegalArgumentException) { }
        assertEquals(root.toString(), PrayerWidgetStore.read(context)!!.toString())
        val view = PrayerHomeWidget.views(context, 1, root, clock()).apply(context, FrameLayout(context))
        assertEquals("Open Qada Tracker to start or refresh", view.findViewById<TextView>(R.id.widget_footer).text.toString())
    }

    @Test fun invalidPrayerOrTrackingDateCannotModifyJournal() {
        val root = journal()
        save(root)
        try { PrayerWidgetStore.perform(context, "invalid", today) { clock() }; fail("Accepted invalid prayer") }
        catch (_: IllegalArgumentException) { }
        root.put("startDate", "2026-11-14")
        save(root)
        try { PrayerWidgetStore.perform(context, "subuh", today) { clock() }; fail("Wrote before tracking start") }
        catch (_: IllegalArgumentException) { }
        assertEquals(root.toString(), PrayerWidgetStore.read(context)!!.toString())
    }

    private fun bind(id: Int) {
        val manager = AppWidgetManager.getInstance(context)
        val provider = ComponentName(context, PrayerHomeWidget::class.java)
        shadowOf(manager).addInstalledProvider(AppWidgetProviderInfo().apply { this.provider = provider })
        shadowOf(manager).setAllowedToBindAppWidgets(true)
        assertTrue(manager.bindAppWidgetIdIfAllowed(id, provider))
    }

    @Test fun allInstancesRefreshFromSameJournalAndScheduleRollover() {
        bind(41); bind(42)
        // Use the actual test clock's local date, as the provider does in Android.
        val date = ReminderPolicy.day(Calendar.getInstance())
        val root = journal().put("startDate", date)
        root.getJSONObject("records").remove("2026-11-12")
        save(PrayerWidgetPolicy.perform(root, date, "subuh"))
        PrayerHomeWidget.refreshAll(context)
        val manager = shadowOf(AppWidgetManager.getInstance(context))
        for (id in listOf(41, 42)) {
            val view = manager.getViewFor(id)
            assertEquals("✓", view.findViewById<TextView>(R.id.widget_subuh_status).text.toString())
            assertEquals("1 of 5 performed · Tap a box to record", view.findViewById<TextView>(R.id.widget_footer).text.toString())
        }
        assertTrue(shadowOf(context.getSystemService(android.app.AlarmManager::class.java)).scheduledAlarms.isNotEmpty())
        // A restore/app correction clears both views on the next sync.
        save(root)
        PrayerHomeWidget.refreshAll(context)
        for (id in listOf(41, 42)) assertEquals("○", manager.getViewFor(id).findViewById<TextView>(R.id.widget_subuh_status).text.toString())
    }

    @Test fun remoteViewsRenderFiveAccessibleButtonsInBothThemes() {
        var root = PrayerWidgetPolicy.perform(journal(), today, "subuh")
        root = PrayerWidgetPolicy.perform(root, today, "zohor")
        for (theme in listOf("light", "dark")) {
            root.put("theme", theme)
            val view = PrayerHomeWidget.views(context, 77, root, clock()).apply(context, FrameLayout(context))
            assertEquals("✓", view.findViewById<TextView>(R.id.widget_subuh_status).text.toString())
            assertEquals("○", view.findViewById<TextView>(R.id.widget_asar_status).text.toString())
            assertEquals("Maghrib, unrecorded. Tap to mark performed for today.", view.findViewById<View>(R.id.widget_maghrib).contentDescription.toString())
            assertEquals("2 of 5 performed · Tap a box to record", view.findViewById<TextView>(R.id.widget_footer).text.toString())
            capture(view, "widget-$theme", 360, 156)
        }
        val narrow = PrayerHomeWidget.views(context, 78, root, clock()).apply(context, FrameLayout(context))
        capture(narrow, "widget-narrow", 280, 130)
        assertTrue(narrow.findViewById<View>(R.id.widget_isyak).right <= 280)
        assertTrue(narrow.findViewById<View>(R.id.widget_footer).bottom <= 130)
        assertEquals(0, narrow.findViewById<TextView>(R.id.widget_maghrib_name).layout.getEllipsisCount(0))
    }

    @Test fun pendingIntentsKeepPrayerDateAndWidgetIdentitySeparate() {
        val view = PrayerHomeWidget.views(context, 7, journal(), clock()).apply(context, FrameLayout(context))
        assertTrue(view.findViewById<View>(R.id.widget_subuh).performClick())
        assertTrue(view.findViewById<View>(R.id.widget_isyak).performClick())
        val broadcasts = shadowOf(RuntimeEnvironment.getApplication()).broadcastIntents.filter { it.action == PrayerHomeWidget.MARK }
        assertEquals(2, broadcasts.size)
        assertEquals("subuh", broadcasts[0].getStringExtra("prayer"))
        assertEquals("isyak", broadcasts[1].getStringExtra("prayer"))
        assertEquals(today, broadcasts[0].getStringExtra("date"))
        assertEquals(7, broadcasts[0].getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1))
        assertNotEquals(broadcasts[0].data, broadcasts[1].data)
    }

    @Test fun launcherClickSavesPrayerRefreshesBothWidgetsAndDismissesCheckIn() {
        bind(91); bind(92)
        val now = Calendar.getInstance()
        val date = ReminderPolicy.day(now)
        val root = journal().put("startDate", date)
        root.getJSONObject("records").remove("2026-11-12")
        save(root)
        PrayerReminders.sync(context, true)
        val notifications = context.getSystemService(android.app.NotificationManager::class.java)
        notifications.notify(2300, android.app.Notification.Builder(context, "daily_check_in")
            .setSmallIcon(R.drawable.notification_icon).setContentTitle("Check in").build())
        assertEquals(1, notifications.activeNotifications.size)
        PrayerHomeWidget.refreshAll(context)
        val manager = shadowOf(AppWidgetManager.getInstance(context))
        assertTrue(manager.getViewFor(91).findViewById<View>(R.id.widget_subuh).performClick())
        shadowOf(android.os.Looper.getMainLooper()).idle()
        val finished = CountDownLatch(1)
        PrayerHomeWidget.execute { finished.countDown() }
        assertTrue("Widget action did not finish", finished.await(5, TimeUnit.SECONDS))
        shadowOf(android.os.Looper.getMainLooper()).idle()
        assertEquals("performed", PrayerWidgetPolicy.status(PrayerWidgetStore.read(context)!!, date, "subuh"))
        for (id in listOf(91, 92)) assertEquals("✓", manager.getViewFor(id).findViewById<TextView>(R.id.widget_subuh_status).text.toString())
        assertTrue(notifications.activeNotifications.isEmpty())
        assertTrue(shadowOf(RuntimeEnvironment.getApplication()).broadcastIntents.any { it.action == PrayerHomeWidget.JOURNAL_CHANGED })
    }

    @Test fun midnightUsesLocalCalendarAcrossDstAndTimezoneChanges() {
        for (zone in listOf("Asia/Kuala_Lumpur", "America/New_York", "Pacific/Auckland")) {
            val now = clock(zone, month = 3, day = 8, hour = 0)
            val next = PrayerWidgetPolicy.nextMidnight(now)
            assertEquals("2026-03-09", ReminderPolicy.day(next))
            assertEquals(0, next.get(Calendar.HOUR_OF_DAY))
            assertEquals(0, next.get(Calendar.MINUTE))
            assertEquals(zone, next.timeZone.id)
        }
    }

    @Test fun widgetRejectsEarlyTapAndAllowsItAtTheExactPrayerInstant() {
        save(journal())
        val slots = PrayerWidgetPolicy.prayers.mapIndexed { i, p ->
            val hour = listOf(5, 13, 16, 19, 20)[i]
            PrayerSlot(p, clock(hour = hour).timeInMillis, today, "%02d:00".format(java.util.Locale.US, hour))
        }
        SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READWRITE).use {
            it.execSQL("UPDATE prayer_calendar SET document = ? WHERE id = 1", arrayOf(SavedPrayerCalendar("widget-test-place", "Asia/Kuala_Lumpur", 0, slots).json().toString()))
        }
        val previous = PrayerWidgetStore.read(context)!!.toString()
        assertEquals(WidgetWriteResult.NOT_STARTED, PrayerWidgetStore.perform(context, "asar", today) { clock(hour = 15).apply { set(Calendar.MINUTE, 59); set(Calendar.SECOND, 59); set(Calendar.MILLISECOND, 999) } })
        assertEquals(previous, PrayerWidgetStore.read(context)!!.toString())
        assertEquals(WidgetWriteResult.SAVED, PrayerWidgetStore.perform(context, "asar", today) { clock(hour = 16) })
        assertEquals("performed", PrayerWidgetPolicy.status(PrayerWidgetStore.read(context)!!, today, "asar"))
    }

    @Test fun missingWrongPlaceWrongDateAndMalformedTimesCannotBypassWidgetGate() {
        for (kind in listOf("missing", "place", "date", "malformed")) {
            save(journal())
            SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READWRITE).use { db ->
                val original = PrayerTimeStore.calendar(db)!!
                when (kind) {
                    "missing" -> db.execSQL("DELETE FROM prayer_calendar")
                    "place" -> db.execSQL("UPDATE prayer_calendar SET document = ? WHERE id = 1", arrayOf(original.copy(key = "other-place").json().toString()))
                    "date" -> db.execSQL("UPDATE prayer_calendar SET document = ? WHERE id = 1", arrayOf(original.copy(entries = original.entries.filter { it.date != today }).json().toString()))
                    "malformed" -> db.execSQL("UPDATE prayer_calendar SET document = '{bad' WHERE id = 1")
                }
            }
            val previous = PrayerWidgetStore.read(context)!!.toString()
            assertEquals(kind, WidgetWriteResult.TIMES_UNAVAILABLE, PrayerWidgetStore.perform(context, "subuh", today) { clock(hour = 23) })
            assertEquals(previous, PrayerWidgetStore.read(context)!!.toString())
        }
    }

    private fun capture(view: View, name: String, width: Int, height: Int) {
        view.measure(View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY), View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY))
        view.layout(0, 0, width, height)
        if (System.getenv("QADA_CAPTURE_WIDGET") != "1") return
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        view.draw(Canvas(bitmap))
        val dir = File(requireNotNull(System.getProperty("qada.widget.capture.dir")))
        dir.mkdirs()
        File(dir, "$name.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()
    }
}
