# WorkManager persists this class name across app updates and constructs it reflectively.
# Preserve that entry point while R8 shrinks the rest of the Android application.
-keep class com.personal.qada_tracker.PrayerCalendarWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
