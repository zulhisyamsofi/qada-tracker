import 'package:flutter/widgets.dart';

String tr(BuildContext context, String text) {
  if (Localizations.localeOf(context).languageCode != 'ms') return text;
  final exact = malay[text];
  if (exact != null) return exact;
  for (final entry in _patterns) {
    final match = entry.$1.firstMatch(text);
    if (match != null) {
      var i = 0;
      return entry.$2.replaceAllMapped(RegExp(r'\{value\}'), (_) {
        final value = match.group(++i) ?? '';
        return malay[value] ?? value;
      });
    }
  }
  if (text.contains('\n')) {
    return text.split('\n').map((line) => tr(context, line)).join('\n');
  }
  return text
      .replaceAll(', today', malay[', today']!)
      .replaceAll(', opens Today', malay[', opens Today']!)
      .replaceAll(
        ', has unrecorded prayers, needs review',
        malay[', has unrecorded prayers, needs review']!,
      )
      .replaceAll(
        ', exempt, no prayers required',
        malay[', exempt, no prayers required']!,
      );
}

final _patterns = malay.entries
    .where((e) => e.key.contains('{value}'))
    .map(
      (e) => (
        RegExp(
          '^${e.key.split('{value}').map(RegExp.escape).join('(.*?)')}\$',
          dotAll: true,
        ),
        e.value,
      ),
    )
    .toList();

const malay = <String, String>{
  'Today': 'Hari Ini',
  'History': 'Sejarah',
  'Qada': 'Qada',
  'Progress': 'Kemajuan',
  'Settings': 'Tetapan',
  'Language / Bahasa': 'Bahasa / Language',
  'Cancel': 'Batal',
  'Confirm': 'Sahkan',
  'Save': 'Simpan',
  'Done': 'Selesai',
  'OK': 'OK',
  'Next': 'Seterusnya',
  'Back': 'Kembali',
  'Retry': 'Cuba lagi',
  'Remove': 'Buang',
  'Resume': 'Sambung',
  'Undo': 'Buat asal',
  'Saving…': 'Menyimpan…',
  'Performed': 'Ditunaikan',
  'Unrecorded': 'Belum direkod',
  'Missed · added to qada': 'Tertinggal · ditambah ke qada',
  'Exempt · no qada': 'Dikecualikan · tiada qada',
  'Exempt': 'Dikecualikan',
  'Unrecorded · needs review': 'Belum direkod · perlu disemak',
  'Mark missed': 'Tandakan tertinggal',
  'Mark performed': 'Tandakan ditunaikan',
  'Leave unrecorded': 'Biarkan belum direkod',
  'Mark required (unrecorded)': 'Tandakan wajib (belum direkod)',
  'Your prayer journal': 'Jurnal solat anda',
  'Your journal, your way': 'Jurnal mengikut cara anda',
  'Stored on this phone. No account or tracking.':
      'Disimpan pada telefon ini. Tiada akaun atau penjejakan.',
  'A small moment to reflect and keep track.':
      'Luangkan masa untuk muhasabah dan merekod solat.',
  'No prayers to record today': 'Tiada solat untuk direkod hari ini',
  'Today is exempt. Your previous records are preserved.':
      'Hari ini dikecualikan. Rekod terdahulu dikekalkan.',
  'Manage exemptions': 'Urus pengecualian',
  '{value} of {value} prayers recorded today':
      '{value} daripada {value} solat direkod hari ini',
  '{value} of {value} required prayers performed':
      '{value} daripada {value} solat wajib ditunaikan',
  '{value} {value} exempt today': '{value} solat dikecualikan hari ini',
  'Tracking since {value}': 'Mula merekod pada {value}',
  '{value} day needs review': '{value} hari perlu disemak',
  '{value} days need review': '{value} hari perlu disemak',
  'Tap today’s date to open Today.':
      'Tekan tarikh hari ini untuk membuka Hari Ini.',
  'Past days with unrecorded prayers':
      'Hari terdahulu dengan solat belum direkod',
  'Shaded dates are exempt': 'Tarikh berlorek dikecualikan',
  'Your prayer history will appear here tomorrow.':
      'Sejarah solat anda akan dipaparkan di sini esok.',
  'Record today’s prayers on Today. You can select an earlier date to add older records.':
      'Rekod solat hari ini di Hari Ini. Pilih tarikh terdahulu untuk menambah rekod lama.',
  'Go to Today': 'Ke Hari Ini',
  'Choose a date': 'Pilih tarikh',
  'A moment to review': 'Masa untuk menyemak',
  'Review unrecorded days': 'Semak hari belum direkod',
  'Only confirmed misses add to your qada balance.':
      'Hanya solat yang disahkan tertinggal ditambah ke baki qada.',
  'Unrecorded prayers are not qada debt.':
      'Solat belum direkod bukan hutang qada.',
  'You’re all caught up. No previous days need review.':
      'Semua sudah disemak. Tiada hari terdahulu perlu disemak.',
  'Remaining missed': 'Baki tertinggal',
  'Remaining performed': 'Baki ditunaikan',
  'Confirm remaining prayers?': 'Sahkan baki solat?',
  'Mark {value} as missed?': 'Tandakan {value} sebagai tertinggal?',
  'This will count toward your outstanding {value} qada.':
      'Ini akan ditambah ke baki qada {value} anda.',
  'Mark every unrecorded prayer on {value} as {value}?':
      'Tandakan semua solat belum direkod pada {value} sebagai {value}?',
  'Make room for progress': 'Langkah menuju kemajuan',
  'Your confirmed replacements, one at a time.':
      'Rekod penggantian solat anda satu demi satu.',
  'Outstanding qada': 'Baki qada',
  'How outstanding qada is calculated': 'Cara baki qada dikira',
  'Starting balances + confirmed misses − replacements. Unrecorded prayers are excluded.':
      'Baki permulaan + solat disahkan tertinggal − penggantian. Solat belum direkod tidak dikira.',
  '{value} outstanding': '{value} baki',
  'Record': 'Rekod',
  'Record {value} qada': 'Rekod qada {value}',
  'Replacements completed': 'Penggantian ditunaikan',
  'Replacement history': 'Sejarah penggantian',
  '1 {value} qada recorded.': '1 qada {value} direkod.',
  'Record one {value} qada completed': 'Rekod satu qada {value} ditunaikan',
  'Undo replacement?': 'Batalkan penggantian?',
  'Return {value} {value} to your outstanding balance?':
      'Kembalikan {value} {value} ke baki qada anda?',
  'No replacements recorded yet. Completing qada keeps the original missed prayer in your journal.':
      'Belum ada penggantian direkod. Qada mengekalkan rekod asal solat tertinggal dalam jurnal.',
  'Every step counts': 'Setiap langkah bermakna',
  'Reflect on your records, without scores or penalties.':
      'Semak rekod anda tanpa markah atau penalti.',
  'This week · Monday onwards': 'Minggu ini · mulai Isnin',
  'Prayers performed': 'Solat ditunaikan',
  'Qada replacements completed': 'Penggantian qada ditunaikan',
  'Unrecorded prayers': 'Solat belum direkod',
  '{value} fully completed days': '{value} hari lengkap',
  'Includes today. These are not counted as missed.':
      'Termasuk hari ini. Ini tidak dikira sebagai tertinggal.',
  'Notifications': 'Pemberitahuan',
  'Prayer-time notifications': 'Pemberitahuan waktu solat',
  'Alerts for your selected prayers.': 'Peringatan untuk solat yang dipilih.',
  'Daily check-in reminder': 'Peringatan rekod harian',
  'Daily check-in time': 'Waktu peringatan harian',
  'Notify me for': 'Ingatkan saya untuk',
  'No prayer alerts selected.': 'Tiada peringatan solat dipilih.',
  'Both reminders are off.': 'Kedua-dua peringatan dimatikan.',
  '{value} · phone local time': '{value} · waktu tempatan telefon',
  '{value} · if any of today’s prayers are still unrecorded.':
      '{value} · jika ada solat hari ini belum direkod.',
  'Choose prayer-time alerts, a daily check-in, or both. Android permission alone does not turn these reminders on.':
      'Pilih peringatan waktu solat, rekod harian, atau kedua-duanya. Kebenaran Android sahaja tidak mengaktifkan peringatan ini.',
  'Allow alarms & reminders': 'Benarkan penggera & peringatan',
  'Android notification settings': 'Tetapan pemberitahuan Android',
  'Android notification permission is blocked.':
      'Kebenaran pemberitahuan Android disekat.',
  'The Prayer times notification channel is blocked.':
      'Saluran pemberitahuan waktu solat disekat.',
  'Daily check-in notifications are blocked in Android settings.':
      'Pemberitahuan rekod harian disekat dalam tetapan Android.',
  'Allow alarms & reminders for on-time delivery. Android may delay or skip inexact alerts.':
      'Benarkan penggera dan peringatan untuk penghantaran tepat waktu. Android mungkin melambatkan peringatan yang tidak tepat.',
  'Notifications are blocked. Enable them in Android notification settings.':
      'Pemberitahuan disekat. Aktifkannya dalam tetapan pemberitahuan Android.',
  'Reminders are available on Android.': 'Peringatan tersedia pada Android.',
  'Unable to update notification settings. Please try again.':
      'Tetapan pemberitahuan tidak dapat dikemas kini. Sila cuba lagi.',
  'Menstrual period & tracking pause': 'Tempoh haid & jeda rekod',
  'Set your menstrual period dates so prayers are excluded from tracking and qada.':
      'Tetapkan tarikh haid supaya solat dikecualikan daripada rekod dan qada.',
  'Set your menstrual period dates to exclude prayers from tracking and qada. Dates are confirmed by you; the app does not predict your cycle. Existing performed and missed records stay unchanged.':
      'Tetapkan tarikh haid untuk mengecualikan solat daripada rekod dan qada. Anda mengesahkan tarikh sendiri; aplikasi tidak meramal kitaran haid. Rekod solat ditunaikan dan tertinggal dikekalkan.',
  'Add period dates': 'Tambah tarikh haid',
  'Choose menstrual period dates': 'Pilih tarikh haid',
  'Confirm exempt dates?': 'Sahkan tarikh pengecualian?',
  'Pause tracking': 'Jeda rekod',
  'Pause tracking from today': 'Jeda rekod mulai hari ini',
  'Resume tracking': 'Sambung rekod',
  'Confirm pause': 'Sahkan jeda',
  'First exempt prayer': 'Solat pertama dikecualikan',
  'First prayer to track': 'Solat pertama untuk direkod',
  'Tomorrow': 'Esok',
  'Ongoing until you resume': 'Berterusan sehingga anda menyambung',
  'No exempt date ranges or ongoing pause.':
      'Tiada julat tarikh pengecualian atau jeda aktif.',
  'Choose the first exempt prayer today. Earlier prayers and existing performed/missed records stay unchanged. The pause continues until you resume.':
      'Pilih solat pertama yang dikecualikan hari ini. Solat sebelumnya serta rekod ditunaikan/tertinggal dikekalkan. Jeda berterusan sehingga anda menyambung.',
  'Choose the first prayer to track today. Earlier prayers remain exempt. Existing confirmations stay unchanged.':
      'Pilih solat pertama untuk direkod hari ini. Solat sebelumnya kekal dikecualikan. Rekod disahkan dikekalkan.',
  'Silence prayer alerts for exempt prayers':
      'Senyapkan peringatan solat dikecualikan',
  'Daily check-ins also ignore exempt prayers. Your reminder preferences are kept for when tracking resumes.':
      'Peringatan harian juga mengabaikan solat dikecualikan. Pilihan peringatan disimpan untuk apabila rekod disambung.',
  'Remove this exempt period?': 'Buang tempoh pengecualian ini?',
  'Unrecorded prayers in this period will need review again. Existing performed, missed, and individually exempt records stay unchanged.':
      'Solat belum direkod dalam tempoh ini perlu disemak semula. Rekod ditunaikan, tertinggal dan pengecualian individu dikekalkan.',
  '{value} · from {value}': '{value} · mulai {value}',
  '{value} · through {value}': '{value} · hingga {value}',
  'App walkthrough': 'Panduan aplikasi',
  'A guided tour of the screens and controls.':
      'Panduan skrin dan kawalan aplikasi.',
  'Dark mode': 'Mod gelap',
  'Softer tones for your evening check-in.':
      'Warna lembut untuk rekod pada waktu malam.',
  'Switch to light mode': 'Tukar ke mod cerah',
  'Switch to dark mode': 'Tukar ke mod gelap',
  'Home-screen widget': 'Widget skrin utama',
  'Five prayer buttons. Tap to mark done.':
      'Lima butang solat. Tekan untuk menandakan selesai.',
  'Add your prayer widget': 'Tambah widget solat anda',
  'Prayer times & location': 'Waktu solat & lokasi',
  'Choose your prayer-time location': 'Pilih lokasi waktu solat',
  'Place': 'Tempat',
  'Use device location': 'Guna lokasi peranti',
  'Refresh times': 'Muat semula waktu',
  'Prayer-time place': 'Lokasi waktu solat',
  'Loading prayer times…': 'Memuatkan waktu solat…',
  'Times unavailable · pull down to retry':
      'Waktu tidak tersedia · tarik ke bawah untuk cuba lagi',
  'Zone {value} · Times shown in {value}':
      'Zon {value} · Waktu dipaparkan dalam {value}',
  'Times appear beside each prayer on Today. Choose a Malaysian place or use your current location.':
      'Waktu dipaparkan di sebelah setiap solat di Hari Ini. Pilih tempat di Malaysia atau gunakan lokasi semasa.',
  'Location is requested only when you tap this button. The selected coordinates are sent to WaktuSolat to find the Malaysian prayer zone.':
      'Lokasi diminta hanya apabila anda menekan butang ini. Koordinat dihantar ke WaktuSolat untuk mendapatkan zon solat Malaysia.',
  'Unable to load prayer times. Check your connection or choose another place.':
      'Waktu solat tidak dapat dimuatkan. Semak sambungan atau pilih tempat lain.',
  'Could not complete this action. Choose a place or try again.':
      'Tindakan tidak dapat diselesaikan. Pilih tempat atau cuba lagi.',
  'Downloaded through {value}.': 'Dimuat turun melalui {value}.',
  'Source: WaktuSolat API · JAKIM zone timetable. Check the selected zone against your local mosque or e-Solat, especially near zone boundaries.':
      'Sumber: API WaktuSolat · Jadual zon JAKIM. Semak zon yang dipilih dengan masjid setempat atau e-Solat, terutamanya berhampiran sempadan zon.',
  'Past qada starting balances': 'Baki permulaan qada terdahulu',
  'Optional counts from before you began tracking.':
      'Bilangan pilihan sebelum anda mula merekod.',
  'Starting qada balances': 'Baki permulaan qada',
  'Only enter prayers owed before tracking began. Daily confirmed misses are added separately.':
      'Masukkan hanya hutang solat sebelum mula merekod. Solat harian disahkan tertinggal ditambah secara berasingan.',
  'Enter a whole number from 0 to 1 billion.':
      'Masukkan nombor bulat dari 0 hingga 1 bilion.',
  'Enter a whole number from 1 to {value}.':
      'Masukkan nombor bulat dari 1 hingga {value}.',
  'Manual backups': 'Sandaran manual',
  'Export backup': 'Eksport sandaran',
  'Restore backup': 'Pulihkan sandaran',
  'Backup exported. Keep it somewhere safe.':
      'Sandaran dieksport. Simpan di tempat yang selamat.',
  'Backup restored.': 'Sandaran dipulihkan.',
  'Replace your journal?': 'Gantikan jurnal anda?',
  'Replace and restore': 'Ganti dan pulihkan',
  'Restore {value} recorded days and {value} replacement entries? All current records and settings will be replaced.':
      'Pulihkan {value} hari rekod dan {value} entri penggantian? Semua rekod dan tetapan semasa akan diganti.',
  'Export a backup regularly and keep it somewhere safe. Backups contain your personal prayer records in plain text. Restore replaces your current journal.':
      'Eksport sandaran secara berkala dan simpan dengan selamat. Sandaran mengandungi rekod solat peribadi dalam teks biasa. Pemulihan menggantikan jurnal semasa.',
  'Balance conflict': 'Konflik baki',
  'Unable to open your journal. Your stored data has not been reset.':
      'Jurnal tidak dapat dibuka. Data tersimpan anda tidak dipadam.',
  'Skip tour': 'Langkau panduan',
  'Get started': 'Mula',
  'Enable & continue': 'Aktifkan & teruskan',
  'Step {value} of {value}': 'Langkah {value} daripada {value}',
  'Welcome to your prayer journal': 'Selamat datang ke jurnal solat anda',
  'Record a prayer on Today': 'Rekod solat di Hari Ini',
  'Prayer-time reminders': 'Peringatan waktu solat',
  'Maintain your History': 'Urus Sejarah anda',
  'Keep your qada balance': 'Urus baki qada anda',
  'See your Progress': 'Lihat Kemajuan anda',
  'Make it yours in Settings': 'Sesuaikan melalui Tetapan',
  'Keep track of your five daily prayers, review earlier days, and record qada replacements. This short tour shows you where to tap.':
      'Rekod lima solat harian, semak hari terdahulu dan rekod penggantian qada. Panduan ringkas ini menunjukkan tempat untuk ditekan.',
  'Use the four tabs at the bottom to move around. The tour never changes your prayer records.':
      'Gunakan empat tab di bawah untuk navigasi. Panduan ini tidak mengubah rekod solat anda.',
  'Tap a prayer’s checkbox after performing it. Tap again to return it to Unrecorded. You can record today’s prayers once their prayer time has started.':
      'Tekan kotak solat selepas menunaikannya. Tekan sekali lagi untuk kembali ke Belum direkod. Solat hari ini boleh direkod selepas masuk waktunya.',
  'Get an alert at each of the five prayer times. Choose the place whose timetable you want to follow.':
      'Terima peringatan pada setiap lima waktu solat. Pilih lokasi jadual waktu yang ingin diikuti.',
  'Available on Android.': 'Tersedia pada Android.',
  'Five daily alerts. Turn off anytime in Settings.':
      'Lima peringatan harian. Matikan pada bila-bila masa dalam Tetapan.',
  'For precise timing, also allow alarms & reminders. Android may delay alerts without this access.':
      'Untuk waktu tepat, benarkan juga penggera dan peringatan. Android mungkin melambatkan peringatan tanpa akses ini.',
  'Could not save your tour preference. Please try again.':
      'Pilihan panduan tidak dapat disimpan. Sila cuba lagi.',
  'Could not save reminder settings. Please try again.':
      'Tetapan peringatan tidak dapat disimpan. Sila cuba lagi.',
  "Daily prayer progress": "Kemajuan solat harian",
  "Could not open Android alarm settings. You can try later in Settings.":
      "Tetapan penggera Android tidak dapat dibuka. Cuba lagi melalui Tetapan.",
  "Could not open Android notification settings. You can try later in Settings.":
      "Tetapan pemberitahuan Android tidak dapat dibuka. Cuba lagi melalui Tetapan.",
  "Export a manual backup regularly. Restore replaces your journal after confirmation. You can replay this tour here with App walkthrough.":
      "Eksport sandaran manual secara berkala. Pemulihan menggantikan jurnal selepas pengesahan. Anda boleh mengulang panduan melalui Panduan aplikasi.",
  "History opens on yesterday for reviewing and correcting earlier days. Its red badge counts past days with unrecorded prayers; red rings identify those dates. Tap today’s calendar date to return to Today.":
      "Sejarah dibuka pada tarikh semalam untuk menyemak dan membetulkan hari terdahulu. Lencana merah mengira hari dengan solat belum direkod; bulatan merah menandakan tarikhnya. Tekan tarikh hari ini untuk kembali ke Hari Ini.",
  "Optional history before tracking began. Saving a prayer adds this day only; other earlier dates stay outside your totals.":
      "Sejarah pilihan sebelum mula merekod. Menyimpan solat hanya menambah hari ini; tarikh terdahulu yang lain tidak termasuk dalam jumlah anda.",
  "Personal edition\nPrayer times from WaktuSolat / JAKIM. Cloud sync is not enabled.":
      "Edisi peribadi\nWaktu solat daripada WaktuSolat / JAKIM. Penyegerakan awan tidak diaktifkan.",
  "Prayer times appear beside each prayer. Tap the gear, then Prayer times & location in Settings to choose a Malaysian place or use your device location.":
      "Waktu dipaparkan di sebelah setiap solat. Tekan ikon tetapan, kemudian Waktu solat & lokasi untuk memilih tempat di Malaysia atau lokasi peranti.",
  "Progress shows weekly and monthly prayers performed, fully completed days, qada replacements, and unrecorded prayers.":
      "Kemajuan menunjukkan solat mingguan dan bulanan yang ditunaikan, hari lengkap, penggantian qada dan solat belum direkod.",
  "Qada includes only your starting balances and confirmed misses, minus replacements. Tap Record beside a prayer, enter a quantity, and save it after completing the replacements.":
      "Qada merangkumi baki permulaan dan solat disahkan tertinggal, ditolak penggantian. Tekan Rekod di sebelah solat, masukkan bilangan dan simpan selepas menunaikan penggantian.",
  "Reminders are selected for first-time setup. Enable & continue asks Android for notification permission. Skipping leaves your existing settings unchanged. You can disable reminders anytime in Settings → Notifications.":
      "Peringatan dipilih untuk persediaan kali pertama. Aktifkan & teruskan meminta kebenaran pemberitahuan Android. Melangkau mengekalkan tetapan sedia ada. Matikan pada bila-bila masa dalam Tetapan → Pemberitahuan.",
  "Tap the gear for past qada starting balances, appearance, the home-screen widget, and the Notifications group, including a daily check-in at your chosen time if any required prayer is still unrecorded.":
      "Tekan ikon tetapan untuk baki permulaan qada, paparan, widget dan Pemberitahuan, termasuk peringatan harian pada waktu pilihan jika ada solat wajib belum direkod.",
  "The next step lets you choose prayer-time reminders. You can change the place or use device location in Settings → Prayer times & location. Both reminder switches are together under Settings → Notifications.":
      "Langkah seterusnya membolehkan anda memilih peringatan waktu solat. Tukar tempat atau gunakan lokasi peranti dalam Tetapan → Waktu solat & lokasi. Kedua-dua suis peringatan berada dalam Tetapan → Pemberitahuan.",
  "The review prompt above History’s calendar opens earlier unrecorded prayers. Review one prayer at a time or confirm the remaining prayers together. Untouched dates before tracking began do not create debt.":
      "Pautan semakan di atas kalendar Sejarah membuka solat terdahulu yang belum direkod. Semak satu solat atau sahkan baki solat serentak. Tarikh sebelum mula merekod yang tidak diubah tidak mewujudkan hutang.",
  "Touch and hold an empty space on your home screen, choose Widgets, then find Qada Tracker. Drag the five-prayer widget onto your home screen. Tap a prayer to toggle between performed and unrecorded for today. Tap the background to open the app.":
      "Tekan lama ruang kosong pada skrin utama, pilih Widget, kemudian cari Qada Tracker. Seret widget lima solat ke skrin utama. Tekan solat untuk menukar antara ditunaikan dan belum direkod bagi hari ini. Tekan latar untuk membuka aplikasi.",
  "Unrecorded totals help you find gaps to review. They are separate from missed prayers and never add to your qada balance.":
      "Jumlah belum direkod membantu mencari rekod untuk disemak. Ia berasingan daripada solat tertinggal dan tidak menambah baki qada.",
  "Use Undo in replacement history to correct an entry. Recording qada keeps the original miss and does not tick today’s prayer. Record becomes available when that prayer has an outstanding balance.":
      "Gunakan Buat asal dalam sejarah penggantian untuk membetulkan entri. Rekod qada mengekalkan rekod tertinggal asal dan tidak menandakan solat hari ini. Rekod tersedia apabila solat mempunyai baki qada.",
  "Use the three-dot menu beside a prayer to confirm a miss. An unticked prayer is unrecorded, never automatically missed. Manage menstrual period dates and tracking pauses in Settings.":
      "Gunakan menu tiga titik di sebelah solat untuk mengesahkan solat tertinggal. Kotak kosong bermaksud belum direkod, bukan tertinggal secara automatik. Urus tarikh haid dan jeda rekod dalam Tetapan.",
  "Invalid backup contents. No data was changed.":
      "Kandungan sandaran tidak sah. Tiada data diubah.",
  "Unsupported backup version.": "Versi sandaran tidak disokong.",
  "Choose a valid daily reminder time.":
      "Pilih waktu peringatan harian yang sah.",
  "Choose the first prayer to track.": "Pilih solat pertama untuk direkod.",
  "Choose a date between 1 January 1900 and today.":
      "Pilih tarikh antara 1 Januari 1900 dan hari ini.",
  "Enter a nonnegative whole count for each prayer (maximum 1 billion).":
      "Masukkan bilangan bulat bukan negatif bagi setiap solat (maksimum 1 bilion).",
  "This change would make {value} negative. Undo the corresponding qada replacement first.":
      "Perubahan ini akan menjadikan baki {value} negatif. Batalkan penggantian qada yang berkenaan dahulu.",
  "{value} starts at {value} ({value}). You can mark it performed then.":
      "Waktu {value} bermula pada {value} ({value}). Anda boleh menandakan ditunaikan selepas itu.",
  "Refresh today’s prayer times for {value} before marking {value} performed.":
      "Muat semula waktu solat hari ini untuk {value} sebelum menandakan {value} ditunaikan.",
  "Choose a quantity between 1 and {value}.":
      "Pilih bilangan antara 1 hingga {value}.",
  "{value} – {value}\n\nUnrecorded prayers on these dates will be exempt. Existing performed and missed records will stay unchanged. Exempt prayers do not add qada or require review.":
      "{value} – {value}\n\nSolat belum direkod pada tarikh ini akan dikecualikan. Rekod ditunaikan dan tertinggal dikekalkan. Solat dikecualikan tidak menambah qada atau memerlukan semakan.",
  "History · {value} day needs review": "Sejarah · {value} hari perlu disemak",
  "History · {value} days need review": "Sejarah · {value} hari perlu disemak",
  "History, {value} past day with unrecorded prayers":
      "Sejarah, {value} hari terdahulu dengan solat belum direkod",
  "History, {value} past days with unrecorded prayers":
      "Sejarah, {value} hari terdahulu dengan solat belum direkod",
  "{value} performed": "{value} ditunaikan",
  "{value} exempt; no prayer to record":
      "{value} dikecualikan; tiada solat untuk direkod",
  "performed": "ditunaikan",
  "missed": "tertinggal",
  "unrecorded": "belum direkod",
  "Invalid calendar date.": "Tarikh kalendar tidak sah.",
  "Invalid exempt date range.": "Julat tarikh pengecualian tidak sah.",
  "Invalid prayer notification preferences.":
      "Pilihan pemberitahuan solat tidak sah.",
  "Invalid replacement entry.": "Entri penggantian tidak sah.",
  "Invalid replacement timestamp.": "Masa penggantian tidak sah.",
  "Invalid starting balance.": "Baki permulaan tidak sah.",
  "Invalid tracking start date.": "Tarikh mula merekod tidak sah.",
  "Missing starting balances.": "Baki permulaan tidak lengkap.",
  "Record date outside supported period.":
      "Tarikh rekod di luar tempoh yang disokong.",
  "Duplicate replacement entry.": "Entri penggantian berulang.",
  "Duplicate or overlapping ongoing tracking pauses.":
      "Jeda rekod berulang atau bertindih.",
  "This pause has already ended.": "Jeda ini telah tamat.",
  "Reminders are not available in this build.":
      "Peringatan tidak tersedia dalam versi ini.",
  "Prayer-time alerts are unavailable in this build.":
      "Peringatan waktu solat tidak tersedia dalam versi ini.",
  "Android could not schedule prayer-time alerts.":
      "Android tidak dapat menjadualkan peringatan waktu solat.",
  "Android could not schedule the reminder. Try reopening the app.":
      "Android tidak dapat menjadualkan peringatan. Cuba buka semula aplikasi.",
  "Unable to read Android notification settings.":
      "Tetapan pemberitahuan Android tidak dapat dibaca.",
  ", today": ", hari ini",
  ", opens Today": ", buka Hari Ini",
  ", has unrecorded prayers, needs review":
      ", ada solat belum direkod, perlu disemak",
  ", exempt, no prayers required": ", dikecualikan, tiada solat wajib",
  "Records": "Rekod",
  "Review your Records": "Semak Rekod anda",
  "Complete qada": "Tunaikan qada",
  "Qada completed": "Qada ditunaikan",
  "Undo qada": "Batalkan qada",
  "Undo qada?": "Batalkan qada?",
  "Record new completion": "Rekod penggantian baharu",
  "Earlier records": "Rekod terdahulu",
  "Earlier replacement · date not linked":
      "Penggantian terdahulu · tarikh belum dipaut",
  "No replacements recorded yet.": "Belum ada penggantian direkod.",
  "Confirmed misses minus completed replacements. Unrecorded prayers are excluded.":
      "Solat disahkan tertinggal ditolak penggantian ditunaikan. Solat belum direkod tidak dikira.",
  "Correct the original record?": "Betulkan rekod asal?",
  "Mark this prayer performed and remove its linked qada replacement? Your outstanding balance will stay unchanged.":
      "Tandakan solat ditunaikan dan buang penggantian qada yang dipaut? Baki qada kekal sama.",
  "This will reopen the missed prayer and restore one outstanding qada.":
      "Ini membuka semula solat tertinggal dan menambah satu baki qada.",
  "Use existing replacement: {value} × {value}":
      "Guna penggantian sedia ada: {value} × {value}",
  "For {value}": "Untuk {value}",
  "Already recorded this replacement? Use an existing entry to avoid counting it twice.":
      "Sudah merekod penggantian ini? Gunakan entri sedia ada supaya tidak dikira dua kali.",
  "No balance is available for a new completion. Review earlier replacement entries first.":
      "Tiada baki untuk penggantian baharu. Semak entri penggantian terdahulu dahulu.",
  "Existing balances and undated replacements are preserved. They do not identify which dates were settled. Use an existing replacement from a missed prayer to link it without reducing the balance again. Older starting balances are read-only until reconciled.":
      "Baki dan penggantian terdahulu tanpa tarikh dikekalkan. Ia tidak menentukan tarikh yang telah diganti. Pautkan penggantian sedia ada dari solat tertinggal tanpa mengurangkan baki semula. Baki permulaan lama hanya boleh dibaca sehingga diselaraskan.",
  "Choose a missed prayer that has not been replaced.":
      "Pilih solat tertinggal yang belum diganti.",
  "This replacement cannot cover the selected prayer.":
      "Penggantian ini tidak boleh dipaut kepada solat yang dipilih.",
  "Invalid or duplicate linked qada replacement.":
      "Penggantian qada dipaut tidak sah atau berulang.",
  "Records, {value} past day with unrecorded prayers":
      "Rekod, {value} hari terdahulu dengan solat belum direkod",
  "Records, {value} past days with unrecorded prayers":
      "Rekod, {value} hari terdahulu dengan solat belum direkod",
  "Records · {value} day needs review": "Rekod · {value} hari perlu disemak",
  "Records · {value} days need review": "Rekod · {value} hari perlu disemak",
  "Missed prayer records": "Rekod solat tertinggal",
  "Complete a specific prayer below. Earlier unlinked replacements may already cover some records.":
      "Tunaikan qada bagi solat tertentu di bawah. Penggantian terdahulu yang belum dipaut mungkin telah meliputi sesetengah rekod.",
  "Preserved older balances + confirmed misses − completed replacements. Unrecorded prayers are excluded.":
      "Baki terdahulu dikekalkan + solat disahkan tertinggal − penggantian ditunaikan. Solat belum direkod tidak dikira.",
  "Undo qada and change this record?": "Batalkan qada dan ubah rekod ini?",
  "The linked replacement will be removed and this prayer will become unrecorded.":
      "Penggantian dipaut akan dibuang dan solat ini menjadi belum direkod.",
  "Use the three tabs at the bottom to move around. The tour never changes your prayer records.":
      "Gunakan tiga tab di bawah untuk navigasi. Panduan ini tidak mengubah rekod solat anda.",
  "Keep track of your five daily prayers, review earlier days, and complete qada directly from a missed prayer. This short tour shows you where to tap.":
      "Rekod lima solat harian, semak hari terdahulu dan tunaikan qada terus dari solat tertinggal. Panduan ini menunjukkan tempat untuk ditekan.",
  "Records opens on yesterday for reviewing and correcting earlier days. Its red badge counts past days with unrecorded prayers; red rings identify those dates. Tap today’s calendar date to return to Today.":
      "Rekod dibuka pada tarikh semalam untuk menyemak hari terdahulu. Lencana merah mengira hari dengan solat belum direkod; bulatan merah menandakan tarikhnya. Tekan tarikh hari ini untuk kembali ke Hari Ini.",
  "The review prompt above Records’ calendar opens earlier unrecorded prayers. Review one prayer at a time or confirm the remaining prayers together. Untouched dates before tracking began do not create debt.":
      "Pautan semakan di atas kalendar Rekod membuka solat terdahulu yang belum direkod. Semak satu solat atau sahkan baki solat serentak. Tarikh sebelum mula merekod yang tidak diubah tidak mewujudkan hutang.",
  "Tap the gear for language, appearance, the home-screen widget, and the Notifications group, including a daily check-in at your chosen time if any required prayer is still unrecorded.":
      "Tekan ikon tetapan untuk bahasa, paparan, widget dan pemberitahuan, termasuk peringatan harian pada waktu pilihan jika ada solat wajib belum direkod.",
};
