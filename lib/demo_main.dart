/// Recruiter demo entry point. Android continues to use lib/main.dart.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'controller.dart';
import 'database.dart';
import 'main.dart' show QadaApp;
import 'model.dart';
import 'prayer_times_api.dart';
import 'prayer_times_controller.dart';
import 'prayer_times_models.dart';

// Frozen after all five sample start times. Never implies current live times.
final demoNow = DateTime.utc(2026, 11, 13, 13);

Journal demoJournal() {
  var journal = Journal(
    startDate: DateTime(2026, 11, 10),
    theme: AppTheme.light,
  );
  journal = journal.setStatuses(DateTime(2026, 11, 11), {
    for (final p in Prayer.values) p: PrayerStatus.performed,
  }, demoNow);
  journal = journal.setStatuses(DateTime(2026, 11, 12), {
    Prayer.subuh: PrayerStatus.missed,
    Prayer.zohor: PrayerStatus.performed,
    Prayer.asar: PrayerStatus.missed,
    Prayer.maghrib: PrayerStatus.performed,
    Prayer.isyak: PrayerStatus.performed,
  }, demoNow);
  return journal.setStatuses(demoNow, {
    Prayer.subuh: PrayerStatus.performed,
  }, demoNow);
}

class DemoTimesApi extends PrayerTimesApi {
  DemoTimesApi() : super(http.Client());
  @override
  Future<PrayerCalendar> fetch(PrayerPlace place, DateTime now) async {
    const times = ['05:48', '13:00', '16:22', '18:58', '20:11'];
    return PrayerCalendar.fromJson({
      'version': 1,
      'sourceKey': place.key,
      'zone': 'WLY01',
      'timezone': 'Asia/Kuala_Lumpur',
      'fetchedAt': demoNow.millisecondsSinceEpoch,
      'entries': [
        for (var day = 1; day <= 31; day++)
          for (var i = 0; i < Prayer.values.length; i++)
            {
              'prayer': Prayer.values[i].name,
              'date': dateKey(DateTime.utc(2026, 11, day)),
              'time': times[i],
              'at': DateTime.utc(
                2026,
                11,
                day,
                int.parse(times[i].split(':')[0]) - 8,
                int.parse(times[i].split(':')[1]),
              ).millisecondsSinceEpoch,
            },
      ],
    });
  }
}

class DemoLocation extends PrayerLocation {
  @override
  Future<PrayerPlace> current() async => throw const FormatException(
    'Device location is disabled in this sample demo. Choose a place instead.',
  );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Nunito',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  runApp(const DemoBootstrap());
}

class DemoBootstrap extends StatefulWidget {
  const DemoBootstrap({super.key});
  @override
  State<DemoBootstrap> createState() => _DemoBootstrapState();
}

class _DemoBootstrapState extends State<DemoBootstrap> {
  late final Future<JournalDatabase> database = openDemo();
  Future<JournalDatabase> openDemo() async {
    final db = await JournalDatabase.open();
    final exists = await db.customSelect('SELECT id FROM journal').get();
    if (exists.isEmpty) await db.save(demoJournal());
    return db;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: database,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return MaterialApp(
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.hasError
                      ? 'Browser storage could not open. Allow site storage and reload. This demo needs IndexedDB and WebAssembly.'
                      : 'Opening Qada Tracker demo…',
                ),
              ),
            ),
          ),
        );
      }
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWith((ref) async => snapshot.requireData),
          clockProvider.overrideWithValue(() => demoNow),
          prayerTimesApiProvider.overrideWith((ref) {
            final api = DemoTimesApi();
            ref.onDispose(api.client.close);
            return api;
          }),
          prayerLocationProvider.overrideWithValue(DemoLocation()),
        ],
        child: QadaApp(frame: (_, child) => DemoFrame(child: child)),
      );
    },
  );
}

class DemoFrame extends ConsumerStatefulWidget {
  const DemoFrame({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<DemoFrame> createState() => _DemoFrameState();
}

class _DemoFrameState extends ConsumerState<DemoFrame> {
  bool resetting = false;
  String? error;
  Future<void> reset() async {
    // A reset also retires Undo actions referring to the previous sample state.
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.clearSnackBars();
    messenger?.removeCurrentSnackBar();
    setState(() {
      resetting = true;
      error = null;
    });
    try {
      await ref.read(journalProvider.notifier).restore(demoJournal());
      ref.invalidate(prayerTimesProvider);
    } catch (_) {
      if (mounted) setState(() => error = 'Reset failed. Please reload.');
    } finally {
      if (mounted) setState(() => resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        error ??
                            'Portfolio demo · 13 Nov 2026\nSample times · Browser-only data · Android alerts/widget unavailable',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: resetting ? null : reset,
                      child: Text(resetting ? 'Resetting…' : 'Reset demo'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: widget.child),
        ],
      ),
    ),
  );
}
