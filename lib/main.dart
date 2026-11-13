import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'backup.dart';
import 'controller.dart';
import 'model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: QadaApp()));
}

class QadaApp extends ConsumerWidget {
  const QadaApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journal = ref.watch(journalProvider).asData?.value;
    ThemeData theme(Brightness brightness) {
      final dark = brightness == Brightness.dark;
      return ThemeData(
        useMaterial3: true,
        brightness: brightness,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff175c46),
          brightness: brightness,
        ),
        scaffoldBackgroundColor: dark
            ? const Color(0xff121b17)
            : const Color(0xfff7f5ef),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      );
    }

    return MaterialApp(
      title: 'Qada Tracker',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: switch (journal?.theme ?? AppTheme.system) {
        AppTheme.system => ThemeMode.system,
        AppTheme.light => ThemeMode.light,
        AppTheme.dark => ThemeMode.dark,
      },
      home: const JournalHome(),
    );
  }
}

class JournalHome extends ConsumerStatefulWidget {
  const JournalHome({super.key});
  @override
  ConsumerState<JournalHome> createState() => _JournalHomeState();
}

class _JournalHomeState extends ConsumerState<JournalHome>
    with WidgetsBindingObserver {
  int tab = 0;
  late DateTime today;
  DateTime? selectedDay;
  Timer? midnight;
  bool fileBusy = false;
  final titles = const ['Today', 'History', 'Qada', 'Progress'];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    today = dayOnly(ref.read(clockProvider)());
    scheduleMidnight();
  }

  void scheduleMidnight() {
    midnight?.cancel();
    final now = ref.read(clockProvider)();
    midnight = Timer(
      nextDay(now).difference(now) + const Duration(milliseconds: 100),
      refreshDay,
    );
  }

  void refreshDay() {
    if (!mounted) return;
    setState(() {
      today = dayOnly(ref.read(clockProvider)());
    });
    scheduleMidnight();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refreshDay();
  }

  @override
  void dispose() {
    midnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  JournalController get controller => ref.read(journalProvider.notifier);

  Future<void> act(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    }
  }

  Future<bool> confirm(
    String title,
    String message, {
    String label = 'Confirm',
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(label),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(journalProvider);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titles[tab],
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const Text(
              'QADA TRACKER · YOUR PRIVATE JOURNAL',
              style: TextStyle(fontSize: 10, letterSpacing: 1.3),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: data.hasValue ? () => settings() : null,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Unable to open your journal. Your stored data has not been reset.',
                ),
                const SizedBox(height: 16),
                Text('$error'),
                TextButton(
                  onPressed: () {
                    ref.invalidate(databaseProvider);
                    ref.invalidate(journalProvider);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (j) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: switch (tab) {
              0 => todayPage(j),
              1 => historyPage(j),
              2 => qadaPage(j),
              _ => progressPage(j),
            },
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (index) => setState(() => tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.wb_sunny_outlined),
            selectedIcon: Icon(Icons.wb_sunny),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'History',
          ),
          NavigationDestination(icon: Icon(Icons.restart_alt), label: 'Qada'),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            label: 'Progress',
          ),
        ],
      ),
    );
  }

  Widget heading(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
  Widget metric(String label, String value, {String? detail}) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (detail != null) Text(detail),
        ],
      ),
    ),
  );
  Widget todayPage(Journal j) {
    final count = Prayer.values
        .where((p) => j.status(today, p) == PrayerStatus.performed)
        .length;
    final pending = j.unresolvedDays(today);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        heading(
          'One prayer at a time.',
          DateFormat('EEEE, d MMMM yyyy').format(today),
        ),
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count of 5 prayers recorded today',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: count / 5,
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 12),
                const Text('A small moment to reflect and keep track.'),
              ],
            ),
          ),
        ),
        if (pending.isNotEmpty)
          Card(
            child: ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: Text(
                '${pending.length} ${pending.length == 1 ? 'day needs' : 'days need'} review',
              ),
              subtitle: const Text('Unrecorded prayers are not qada debt.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: review,
            ),
          ),
        const SizedBox(height: 10),
        for (final p in Prayer.values) prayerCard(j, today, p),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'A fresh page each midnight. Your previous records stay saved.',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget prayerCard(Journal j, DateTime date, Prayer p) {
    final status = j.status(date, p);
    final (icon, label) = switch (status) {
      PrayerStatus.performed => (Icons.check_circle_outline, 'Performed'),
      PrayerStatus.missed => (Icons.history, 'Missed · added to qada'),
      PrayerStatus.unrecorded => (Icons.radio_button_unchecked, 'Unrecorded'),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Checkbox(
              value: status == PrayerStatus.performed,
              semanticLabel: '${p.label} performed',
              onChanged: (checked) => act(
                () => controller.statuses(date, {
                  p: checked!
                      ? PrayerStatus.performed
                      : PrayerStatus.unrecorded,
                }),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.label,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(icon, size: 14),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          label,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<PrayerStatus>(
              tooltip: 'Update ${p.label}',
              onSelected: (status) async {
                if (status == PrayerStatus.missed &&
                    !await confirm(
                      'Mark ${p.label} as missed?',
                      'This will count toward your outstanding ${p.label} qada.',
                    )) {
                  return;
                }
                await act(() => controller.statuses(date, {p: status}));
              },
              itemBuilder: (_) => [
                for (final s in PrayerStatus.values)
                  PopupMenuItem(
                    value: s,
                    child: Text(switch (s) {
                      PrayerStatus.unrecorded => 'Leave unrecorded',
                      PrayerStatus.performed => 'Mark performed',
                      PrayerStatus.missed => 'Mark missed',
                    }),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget historyPage(Journal j) {
    final selected =
        selectedDay != null &&
            !selectedDay!.isBefore(j.startDate) &&
            !selectedDay!.isAfter(today)
        ? selectedDay!
        : today;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        heading(
          'Your prayer journal',
          'Tracking since ${DateFormat.yMMMd().format(j.startDate)}',
        ),
        Card(
          child: CalendarDatePicker(
            key: ValueKey(
              '${dateKey(j.startDate)}-${dateKey(today)}-${dateKey(selected)}',
            ),
            initialDate: selected,
            firstDate: j.startDate,
            lastDate: today,
            onDateChanged: (date) => setState(() => selectedDay = date),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            DateFormat('EEEE, d MMMM').format(selected),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        for (final p in Prayer.values) prayerCard(j, selected, p),
        OutlinedButton.icon(
          onPressed: review,
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Review unrecorded days'),
        ),
      ],
    );
  }

  Future<void> review() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final j = ref.watch(journalProvider).requireValue;
        final days = j.unresolvedDays(today);
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .82,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                heading(
                  'A moment to review',
                  'Only confirmed misses add to your qada balance.',
                ),
                if (days.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'You’re all caught up. No previous days need review.',
                    ),
                  ),
                for (final date in days) ...[
                  Text(
                    DateFormat('EEEE, d MMM yyyy').format(date),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final status in [
                        PrayerStatus.performed,
                        PrayerStatus.missed,
                      ])
                        ActionChip(
                          label: Text(
                            status == PrayerStatus.performed
                                ? 'Remaining performed'
                                : 'Remaining missed',
                          ),
                          onPressed: () async {
                            if (!await confirm(
                              'Confirm remaining prayers?',
                              'Mark every unrecorded prayer on ${DateFormat.yMMMd().format(date)} as ${status.name}?',
                            )) {
                              return;
                            }
                            await act(
                              () => controller.change(
                                (current) => current.setStatuses(date, {
                                  for (final p in Prayer.values)
                                    if (current.status(date, p) ==
                                        PrayerStatus.unrecorded)
                                      p: status,
                                }, ref.read(clockProvider)()),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final p in Prayer.values)
                    if (j.status(date, p) == PrayerStatus.unrecorded)
                      prayerCard(j, date, p),
                  const Divider(height: 28),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget qadaPage(Journal j) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      heading(
        'Make room for progress',
        'Your confirmed replacements, one at a time.',
      ),
      metric(
        'Outstanding qada',
        '${j.outstanding}',
        detail: 'Starting balances + confirmed misses − replacements',
      ),
      for (final p in Prayer.values)
        Card(
          child: ListTile(
            title: Text(
              p.label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('${j.balance(p)} outstanding'),
            trailing: FilledButton.tonal(
              onPressed: j.balance(p) > 0 ? () => recordReplacement(p) : null,
              child: const Text('Record'),
            ),
          ),
        ),
      const SizedBox(height: 12),
      Text(
        'Replacement history',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 12),
      if (j.replacements.isEmpty)
        const Text(
          'No replacements recorded yet. Completing qada keeps the original missed prayer in your journal.',
        ),
      for (final e in j.replacements.reversed)
        Card(
          child: ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: Text('${e.prayer.label} × ${e.quantity}'),
            subtitle: Text(
              DateFormat('d MMM yyyy, h:mm a').format(e.completedAt.toLocal()),
            ),
            trailing: TextButton(
              onPressed: () async {
                if (await confirm(
                  'Undo replacement?',
                  'Return ${e.quantity} ${e.prayer.label} to your outstanding balance?',
                  label: 'Undo',
                )) {
                  await act(() => controller.change((j) => j.undo(e.id)));
                }
              },
              child: const Text('Undo'),
            ),
          ),
        ),
    ],
  );

  Future<void> recordReplacement(Prayer p) async {
    final text = TextEditingController(text: '1');
    final form = GlobalKey<FormState>();
    final count = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Record ${p.label} qada'),
        content: Form(
          key: form,
          child: TextFormField(
            controller: text,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Replacements completed',
            ),
            validator: (value) {
              final count = int.tryParse(value ?? '');
              final available = ref
                  .read(journalProvider)
                  .requireValue
                  .balance(p);
              return count == null || count < 1 || count > available
                  ? 'Enter a whole number from 1 to $available.'
                  : null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, int.parse(text.text));
              }
            },
            child: const Text('Record'),
          ),
        ],
      ),
    );
    // Dialog route transitions may still reference its controller briefly.
    Future<void>.delayed(const Duration(seconds: 1), text.dispose);
    if (count != null) await act(() => controller.complete(p, count));
  }

  Widget progressPage(Journal j) {
    final month = DateTime(today.year, today.month);
    final week = DateTime(
      today.year,
      today.month,
      today.day - today.weekday + 1,
    );
    Widget section(String title, DateTime from) {
      final days = j.days(today).where((day) => !day.isBefore(from)).toList();
      final performed = days.fold(
        0,
        (sum, day) =>
            sum +
            Prayer.values
                .where((p) => j.status(day, p) == PrayerStatus.performed)
                .length,
      );
      final full = days
          .where(
            (day) => Prayer.values.every(
              (p) => j.status(day, p) == PrayerStatus.performed,
            ),
          )
          .length;
      final unresolved = days.fold(
        0,
        (sum, day) =>
            sum +
            Prayer.values
                .where((p) => j.status(day, p) == PrayerStatus.unrecorded)
                .length,
      );
      final replacements = j.replacements
          .where(
            (e) =>
                !dayOnly(e.completedAt.toLocal()).isBefore(from) &&
                !dayOnly(e.completedAt.toLocal()).isAfter(today),
          )
          .fold(0, (sum, e) => sum + e.quantity);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          metric(
            'Prayers performed',
            '$performed / ${days.length * 5}',
            detail: '$full fully completed days',
          ),
          metric('Qada replacements completed', '$replacements'),
          metric(
            'Unrecorded prayers',
            '$unresolved',
            detail: 'Includes today. These are not counted as missed.',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        heading(
          'Every step counts',
          'Reflect on your records, without scores or penalties.',
        ),
        section('This week · Monday onwards', week),
        const SizedBox(height: 16),
        section(DateFormat('MMMM yyyy').format(today), month),
      ],
    );
  }

  Future<void> settings() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final j = ref.watch(journalProvider).requireValue;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading(
                  'Your journal, your way',
                  'Stored on this phone. No account or tracking.',
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Past qada starting balances'),
                  subtitle: const Text(
                    'Optional counts from before you began tracking.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: startingBalances,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<AppTheme>(
                  initialValue: j.theme,
                  decoration: const InputDecoration(labelText: 'Appearance'),
                  items: [
                    for (final theme in AppTheme.values)
                      DropdownMenuItem(
                        value: theme,
                        child: Text(switch (theme) {
                          AppTheme.system => 'Follow system',
                          AppTheme.light => 'Light',
                          AppTheme.dark => 'Dark',
                        }),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      act(() => controller.change((j) => j.copy(theme: value)));
                    }
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'Manual backups',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Export a backup regularly and keep it somewhere safe. Backups contain your personal prayer records in plain text. Restore replaces your current journal.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: fileBusy ? null : exportBackup,
                      icon: const Icon(Icons.file_upload_outlined),
                      label: const Text('Export backup'),
                    ),
                    OutlinedButton.icon(
                      onPressed: fileBusy ? null : importBackup,
                      icon: const Icon(Icons.file_download_outlined),
                      label: const Text('Restore backup'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Qada Tracker · Personal edition\nPrayer times, reminders, and cloud sync are not enabled.',
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    ),
  );

  Future<void> startingBalances() async {
    final current = ref.read(journalProvider).requireValue;
    final fields = {
      for (final p in Prayer.values)
        p: TextEditingController(text: '${current.starting[p] ?? 0}'),
    };
    final form = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Starting qada balances'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Only enter prayers owed before tracking began. Daily confirmed misses are added separately.',
                ),
                const SizedBox(height: 16),
                for (final p in Prayer.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: fields[p],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: p.label),
                      validator: (value) {
                        final n = int.tryParse(value ?? '');
                        return n == null || n < 0 || n > 1000000000
                            ? 'Enter a whole number from 0 to 1 billion.'
                            : null;
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              try {
                await controller.change(
                  (j) => j.setStarting({
                    for (final p in Prayer.values)
                      p: int.parse(fields[p]!.text),
                  }),
                );
                if (context.mounted) Navigator.pop(context);
              } catch (error) {
                if (context.mounted) {
                  await showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Balance conflict'),
                      content: Text(error.toString()),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    Future<void>.delayed(const Duration(seconds: 1), () {
      for (final c in fields.values) {
        c.dispose();
      }
    });
  }

  Future<void> exportBackup() async {
    if (fileBusy) return;
    setState(() => fileBusy = true);
    await act(() async {
      final saved = await ref
          .read(backupFilesProvider)
          .write(
            'qada-backup-${dateKey(today)}.json',
            ref.read(journalProvider).requireValue.export(),
          );
      if (saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup exported. Keep it somewhere safe.'),
          ),
        );
      }
    });
    if (mounted) setState(() => fileBusy = false);
  }

  Future<void> importBackup() async {
    if (fileBusy) return;
    setState(() => fileBusy = true);
    await act(() async {
      final contents = await ref.read(backupFilesProvider).read();
      if (contents == null) return;
      final validated = Journal.decode(contents, ref.read(clockProvider)());
      if (!mounted ||
          !await confirm(
            'Replace your journal?',
            'Restore ${validated.records.length} recorded days and ${validated.replacements.length} replacement entries? All current records and settings will be replaced.',
            label: 'Replace and restore',
          )) {
        return;
      }
      await controller.restore(validated);
      if (mounted) {
        setState(() => selectedDay = null);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Backup restored.')));
      }
    });
    if (mounted) setState(() => fileBusy = false);
  }
}
