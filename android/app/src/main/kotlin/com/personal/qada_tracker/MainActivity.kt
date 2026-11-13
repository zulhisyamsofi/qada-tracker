package com.personal.qada_tracker

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var permissionResult: MethodChannel.Result? = null
    private val requestCode = 2301

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        PrayerReminders.createChannel(this)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "qada_tracker/reminders").apply {
            setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "sync" -> {
                            PrayerReminders.sync(this@MainActivity, call.argument<Boolean>("enabled") == true)
                            result.success(null)
                        }
                        "access" -> result.success(PrayerReminders.access(this@MainActivity))
                        "requestNotifications" -> {
                            if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                                if (permissionResult != null) result.error("busy", "A permission request is already open.", null)
                                else {
                                    permissionResult = result
                                    requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), requestCode)
                                }
                            } else result.success(PrayerReminders.appNotificationsAllowed(this@MainActivity))
                        }
                        "openAlarmSettings" -> {
                            if (Build.VERSION.SDK_INT >= 31) startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName")))
                            result.success(null)
                        }
                        "openNotificationSettings" -> {
                            val intent = if (Build.VERSION.SDK_INT >= 26) Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                                else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                            startActivity(intent)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) { result.error("reminders", "Unable to update Android reminder settings.", null) }
            }
        }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == this.requestCode) {
            permissionResult?.success(PrayerReminders.appNotificationsAllowed(this))
            permissionResult = null
        }
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra(PrayerReminders.OPEN_TODAY, false)) channel?.invokeMethod("openToday", null)
    }
    override fun onDestroy() {
        permissionResult?.success(false)
        permissionResult = null
        channel?.setMethodCallHandler(null)
        super.onDestroy()
    }
}
