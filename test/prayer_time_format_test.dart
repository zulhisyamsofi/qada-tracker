import 'package:flutter_test/flutter_test.dart';
import 'package:qada_tracker/prayer_time_format.dart';

void main() {
  test(
    'presentation handles midnight, noon, morning, afternoon and unknown clocks',
    () {
      for (final entry in {
        '00:00': '12:00 AM',
        '05:48': '5:48 AM',
        '12:00': '12:00 PM',
        '13:01': '1:01 PM',
        '23:59': '11:59 PM',
        '--:--': '--:--',
      }.entries) {
        expect(formatPrayerTime(entry.key), entry.value);
      }
    },
  );
}
