package com.personal.qada_tracker

import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/** Calendar days, not 24-hour durations: survives DST and local timezone changes. */
internal object ReminderPolicy {
    fun day(now: Calendar): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply {
        timeZone = now.timeZone
    }.format(now.time)

    fun next(now: Calendar, lastCheckedDay: String?, minutes: Int = 23 * 60): Calendar {
        require(minutes in 0..1439)
        val target = (now.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, minutes / 60)
            set(Calendar.MINUTE, minutes % 60)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (!target.after(now)) {
            if (lastCheckedDay != day(now)) {
                // Opting in/opening after the chosen time gets one check today.
                return (now.clone() as Calendar).apply { add(Calendar.SECOND, 1) }
            }
            target.add(Calendar.DAY_OF_MONTH, 1)
        }
        return target
    }

    fun hasUnrecordedPrayer(statuses: List<String?>): Boolean = statuses.any { it != "performed" && it != "missed" && it != "exempt" }

    fun shouldNotify(enabled: Boolean, expectedDay: String?, now: Calendar,
                     lastCheckedDay: String?, hasUnrecordedPrayer: Boolean,
                     minutes: Int = 23 * 60): Boolean =
        enabled && expectedDay == day(now) && lastCheckedDay != day(now) &&
            now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE) >= minutes && hasUnrecordedPrayer
}
