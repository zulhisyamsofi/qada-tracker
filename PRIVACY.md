# Privacy and data handling

Qada Tracker is a personal Android project. It has no account, developer-operated backend, analytics, advertising, or automatic cloud sync.

## On-device data

SQLite stores prayer dates/statuses, dated qada completions, legacy balances, settings, and manually confirmed exemption/pause intervals. Exemptions can reveal menstrual-period information; they are not predictions or medical guidance. The database is in Android app-private storage, not application-level encrypted storage. Device security still matters. Android automatic backup is disabled in the manifest.

The selected place, including saved device coordinates when used, is stored locally. Location is requested in the foreground only when the user chooses the device-location action. Coordinates are rounded to three decimal places (roughly 100 metres); the app does not maintain a location trail or request background location permission.

## External requests

Prayer-time requests go over HTTPS to `api.waktusolat.app`. The selected place coordinates appear in the GPS zone-lookup URL, including coordinates for a dropdown place. Subsequent calendar requests use the resolved zone and month. Android's calendar worker can refresh the timetable in the background using the saved place. The provider can receive these requests, IP address, and ordinary network metadata; its own practices apply. Prayer statuses, qada entries, and exemption intervals are not sent in these requests.

Notifications are scheduled locally by Android, not remote push messages. Permission denial or Android power restrictions can suppress them. Notification contents can be visible on the lock screen according to device settings.

## Export, deletion, and repository samples

Manual backups are unencrypted JSON containing records and settings, including exemption intervals and saved place coordinates. The user chooses the destination with Android's document picker; choosing a cloud-backed destination is an explicit export outside the app. Restore validates the file and asks before replacing local records atomically.

Uninstalling normally removes app-private data. Exported backups remain wherever the user saved them and must be deleted separately. No developer server holds a copy to delete or recover.

Repository tests and current portfolio screenshots use synthetic journal records and sample prayer timetables. Never attach real journals, backup JSON, sensitive screenshots, or device logs to public issues.
