/// Timetables keep their validated 24-hour clock; presentation uses AM/PM.
String formatPrayerTime(String time) {
  final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(time);
  if (match == null) return time;
  final hour = int.parse(match[1]!);
  final minute = int.parse(match[2]!);
  if (hour > 23 || minute > 59) return time;
  return '${hour % 12 == 0 ? 12 : hour % 12}:${match[2]} ${hour < 12 ? 'AM' : 'PM'}';
}
