package com.personal.qada_tracker

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
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
import org.robolectric.annotation.SQLiteMode
import org.robolectric.shadows.ShadowAlarmManager
import java.io.File
import java.util.Calendar
import java.util.TimeZone

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33, 35])
@SQLiteMode(SQLiteMode.Mode.NATIVE)
class PrayerNotificationTest {
    private lateinit var context: Context
    private lateinit var file: File
    private lateinit var oldZone: TimeZone
    private val key = "waktusolat-v2:kuala_lumpur:3.1390:101.6869"
    private val names = PrayerTimePolicy.names
    private fun at(day: Int, hour: Int, minute: Int = 0): Long = Calendar.getInstance(TimeZone.getTimeZone("Asia/Kuala_Lumpur")).apply {
        clear(); set(2026, Calendar.NOVEMBER, day, hour, minute)
    }.timeInMillis
    private var time = 0L
    private fun clock(day: Int = 14, hour: Int = 11, minute: Int = 0) { time = at(day, hour, minute) }
    private fun journal(): JSONObject = JSONObject().put("version", 1).put("startDate", "2026-11-14")
        .put("reminderEnabled", true).put("records", JSONObject())
        .put("prayerTimes", JSONObject().put("notifications", true).put("place", JSONObject()
            .put("key", key).put("label", "Kuala Lumpur").put("latitude", 3.139).put("longitude", 101.6869)))
    private fun save(root: JSONObject = journal()) {
        val slots = (14..30).flatMap { day -> names.mapIndexed { index, prayer ->
            val hour = listOf(5,13,16,19,20)[index]
            PrayerSlot(prayer, at(day,hour), "2026-11-$day", "%02d:00".format(hour))
        }}
        SQLiteDatabase.openOrCreateDatabase(file,null).use { db ->
            db.execSQL("CREATE TABLE IF NOT EXISTS journal(id INTEGER PRIMARY KEY, document TEXT NOT NULL)")
            db.execSQL("CREATE TABLE IF NOT EXISTS prayer_calendar(id INTEGER PRIMARY KEY, document TEXT NOT NULL)")
            db.execSQL("INSERT OR REPLACE INTO journal VALUES(1,?)", arrayOf(root.toString()))
            db.execSQL("INSERT OR REPLACE INTO prayer_calendar VALUES(1,?)", arrayOf(SavedPrayerCalendar(key,"Asia/Kuala_Lumpur",at(14,10),slots,"WLY01").json().toString()))
        }
    }
    private fun prayerIntent(prayer: String): Intent {
        val alarms = shadowOf(context.getSystemService(AlarmManager::class.java)).scheduledAlarms
        return Intent(shadowOf(alarms.first { shadowOf(it.operation).savedIntent.getStringExtra("prayer") == prayer }.operation).savedIntent)
    }
    @Before fun setup() {
        oldZone=TimeZone.getDefault(); TimeZone.setDefault(TimeZone.getTimeZone("Asia/Kuala_Lumpur"))
        context=RuntimeEnvironment.getApplication()
        file=File(context.filesDir,"journal.sqlite"); file.delete()
        clock()
        ShadowAlarmManager.setAutoSchedule(false)
        ShadowAlarmManager.setCanScheduleExactAlarms(true)
        shadowOf(RuntimeEnvironment.getApplication()).grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
        save()
    }
    @After fun cleanup() { file.delete(); TimeZone.setDefault(oldZone) }

    @Test fun scheduledPrayerCarriesPayloadPostsNotificationAndSchedulesTomorrow() {
        PrayerTimeAlarms.configure(context,true,time)
        val alarms=shadowOf(context.getSystemService(AlarmManager::class.java))
        assertEquals(5,alarms.scheduledAlarms.size)
        val intent=prayerIntent("zohor")
        assertEquals(key,intent.getStringExtra("source"))
        assertEquals(at(14,13),intent.getLongExtra("at",0))
        clock(hour=13)
        PrayerTimeAlarms.deliver(context,intent,time)
        val manager=context.getSystemService(NotificationManager::class.java)
        val posted=manager.activeNotifications.single { it.id==10002 }.notification
        assertEquals("Time for Zohor",posted.extras.getString(Notification.EXTRA_TITLE))
        assertTrue(shadowOf(posted.contentIntent).savedIntent.getBooleanExtra(PrayerTimeAlarms.OPEN,false))
        assertEquals(at(15,13),prayerIntent("zohor").getLongExtra("at",0))
        PrayerTimeAlarms.deliver(context,intent,time)
        assertEquals(1,manager.activeNotifications.size)
    }

    @Test fun staleInexactAlarmIsNotReplayedAsAnOnTimePrayerAlert() {
        ShadowAlarmManager.setCanScheduleExactAlarms(false)
        PrayerTimeAlarms.configure(context,true,time)
        val intent=prayerIntent("zohor")
        clock(hour=13,minute=25)
        PrayerTimeAlarms.deliver(context,intent,time)
        assertTrue(context.getSystemService(NotificationManager::class.java).activeNotifications.isEmpty())
    }
    @Test fun delayedAlertsStopAtNextPrayerAndDoNotReplayOldEvents() {
        ShadowAlarmManager.setCanScheduleExactAlarms(false)
        PrayerTimeAlarms.configure(context,true,time)
        val intent=prayerIntent("maghrib")
        clock(hour=20)
        PrayerTimeAlarms.deliver(context,intent,time)
        assertTrue(context.getSystemService(NotificationManager::class.java).activeNotifications.isEmpty())
        clock(day=15,hour=11)
        PrayerTimeAlarms.deliver(context,intent,time)
        assertTrue(context.getSystemService(NotificationManager::class.java).activeNotifications.isEmpty())
    }

    @Test fun exactAlertsStayStrictAndNeverNotifyEarly() {
        PrayerTimeAlarms.configure(context,true,time)
        val intent=prayerIntent("zohor")
        PrayerTimeAlarms.deliver(context,intent,at(14,12,59))
        PrayerTimeAlarms.deliver(context,intent,at(14,13,25))
        assertTrue(context.getSystemService(NotificationManager::class.java).activeNotifications.isEmpty())
    }

    @Test fun permissionRevocationAndPrayerChannelBlockingSuppressPosts() {
        PrayerTimeAlarms.configure(context,true,time)
        val intent=prayerIntent("zohor")
        shadowOf(RuntimeEnvironment.getApplication()).denyPermissions(Manifest.permission.POST_NOTIFICATIONS)
        PrayerTimeAlarms.deliver(context,intent,at(14,13))
        val manager=context.getSystemService(NotificationManager::class.java)
        assertTrue(manager.activeNotifications.isEmpty())
        shadowOf(RuntimeEnvironment.getApplication()).grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
        manager.deleteNotificationChannel("prayer_times")
        manager.createNotificationChannel(NotificationChannel("prayer_times","Prayer times",NotificationManager.IMPORTANCE_NONE))
        PrayerTimeAlarms.deliver(context,intent,at(14,13))
        assertTrue(manager.activeNotifications.isEmpty())
    }

    @Test fun testNotificationUsesPrayerChannelWithoutChangingRecordsOrDeliveryTokens() {
        PrayerTimeAlarms.configure(context,true,time)
        val before=PrayerTimeStore.config(context)
        PrayerTimeAlarms.sendTest(context)
        val posted=context.getSystemService(NotificationManager::class.java).activeNotifications.single().notification
        assertEquals("prayer_times",posted.channelId)
        assertEquals("Prayer notification test",posted.extras.getString(Notification.EXTRA_TITLE))
        assertEquals(before,PrayerTimeStore.config(context))
        assertTrue(context.getSharedPreferences("prayer_time_alarms",Context.MODE_PRIVATE).getStringSet("sent",emptySet())!!.isEmpty())
        assertEquals(5,shadowOf(context.getSystemService(AlarmManager::class.java)).scheduledAlarms.size)
    }

    @Test fun dailyChannelCanBeDisabledWhilePrayerAlertsStayAllowed() {
        PrayerReminders.createChannel(context)
        PrayerTimeAlarms.channel(context)
        val manager=context.getSystemService(NotificationManager::class.java)
        manager.deleteNotificationChannel("daily_check_in")
        manager.createNotificationChannel(NotificationChannel("daily_check_in","Check-in",NotificationManager.IMPORTANCE_NONE))
        val access=PrayerReminders.access(context)
        assertEquals(false,access["notifications"])
        assertEquals(true,access["appNotifications"])
        assertEquals(true,access["prayerNotifications"])
        PrayerTimeAlarms.sendTest(context)
        assertTrue(manager.activeNotifications.isNotEmpty())
    }

    @Test fun optingOutClearsPendingPrayerAlarmsAndNotifications() {
        PrayerTimeAlarms.configure(context,true,time)
        val intent=prayerIntent("zohor")
        PrayerTimeAlarms.deliver(context,intent,at(14,13))
        val root=journal()
        root.getJSONObject("prayerTimes").put("notifications",false)
        save(root)
        PrayerTimeAlarms.configure(context,true,at(14,13,1))
        assertTrue(shadowOf(context.getSystemService(AlarmManager::class.java)).scheduledAlarms.isEmpty())
        assertTrue(context.getSystemService(NotificationManager::class.java).activeNotifications.isEmpty())
    }

    @Test fun forcedRepairRestoresAlarmsLostWhileAppWasClosed() {
        PrayerTimeAlarms.configure(context,true,time)
        val manager=context.getSystemService(AlarmManager::class.java)
        shadowOf(manager).scheduledAlarms.toList().forEach { alarm -> alarm.operation?.let { manager.cancel(it) } }
        assertTrue(shadowOf(manager).scheduledAlarms.isEmpty())
        PrayerTimeAlarms.configure(context,true,time)
        assertEquals(5,shadowOf(manager).scheduledAlarms.size)
    }

    @Test fun dailyCheckInPostsForOneUnrecordedPrayerAndClearsOnlyWhenAllAreConfirmed() {
        val root=journal()
        val row=JSONObject().apply { names.dropLast(1).forEach { put(it,"performed") } }
        root.getJSONObject("records").put("2026-11-14",row)
        save(root)
        val now=Calendar.getInstance().apply { timeInMillis=at(14,23) }
        PrayerReminders.sync(context,true,now)
        PrayerReminders.deliver(context,"2026-11-14",now)
        val manager=context.getSystemService(NotificationManager::class.java)
        assertTrue(manager.activeNotifications.any { it.id==2300 })
        row.put("subuh","missed"); save(root)
        PrayerReminders.sync(context,true,now)
        assertTrue(manager.activeNotifications.any { it.id==2300 })
        row.put("isyak","missed"); save(root)
        PrayerReminders.sync(context,true,now)
        assertTrue(manager.activeNotifications.isEmpty())
        PrayerReminders.deliver(context,"2026-11-14",now)
        assertTrue(manager.activeNotifications.isEmpty())
    }

}
