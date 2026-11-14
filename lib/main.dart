import 'dart:async';
import 'package:flutter/foundation.dart'
    show LicenseRegistry, LicenseEntryWithLineBreaks;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'backup.dart';
import 'controller.dart';
import 'model.dart';
import 'reminders.dart';
import 'reminder_settings.dart';
import 'prayer_times_page.dart';
import 'prayer_times_controller.dart';
import 'ui/app_theme.dart';
import 'ui/glass.dart';
import 'home_widget.dart';
import 'prayer_recording_policy.dart';
import 'walkthrough.dart';
import 'ui/history_calendar.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Nunito',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  runApp(const ProviderScope(child: QadaApp()));
}

class QadaApp extends ConsumerWidget {
  const QadaApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journal = ref.watch(journalProvider).asData?.value;

    return MaterialApp(
      title: 'Qada Tracker',
      debugShowCheckedModeBanner: false,
      theme: QadaTheme.build(Brightness.light),
      darkTheme: QadaTheme.build(Brightness.dark),
      highContrastTheme: QadaTheme.build(Brightness.light, highContrast: true),
      highContrastDarkTheme: QadaTheme.build(
        Brightness.dark,
        highContrast: true,
      ),
      themeAnimationDuration: const Duration(milliseconds: 220),
      builder: (context, child) =>
          GlassBackdrop(child: child ?? const SizedBox()),
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
  Timer? prayerClock;
  bool fileBusy = false;
  bool walkthroughChecked = false;
  bool walkthroughOpen = false;
  final walkthroughTargets = {
    for (final key in ['prayer', 'settings']) key: GlobalKey(),
  };
  final navigationKeys = List.generate(4, (_) => GlobalKey());
  final qadaFormulaTooltip = GlobalKey<TooltipState>();
  late final ReminderService reminders;
  late final HomeWidgetService homeWidget;
  final titles = const ['Today', 'History', 'Qada', 'Progress'];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    today = dayOnly(ref.read(clockProvider)());
    scheduleMidnight();
    prayerClock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && tab == 0) setState(() {});
    });
    reminders = ref.read(reminderServiceProvider);
    homeWidget = ref.read(homeWidgetServiceProvider);
    homeWidget.onJournalChanged = () => act(controller.reload);
    reminders.onOpenToday = () {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        setState(() => tab = 0);
      }
    };
    reminders.onOpenPrayerTimes = () {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        setState(() => tab = 0);
      }
    };
    unawaited(
      reminders.initialPrayerTimesTap().then((open) {
        if (mounted && open) setState(() => tab = 0);
      }),
    );
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
    unawaited(act(controller.reload));
    ref.invalidate(prayerTimesProvider);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refreshDay();
  }

  @override
  void dispose() {
    midnight?.cancel();
    prayerClock?.cancel();
    reminders.onOpenToday = null;
    reminders.onOpenPrayerTimes = null;
    homeWidget.onJournalChanged = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  JournalController get controller => ref.read(journalProvider.notifier);

  Future<void> act(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    }
  }

  Future<void> toggleTheme() {
    final platformDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return act(
      () => controller.change(
        (j) => j.copy(
          theme:
              j.theme == AppTheme.dark ||
                  (j.theme == AppTheme.system && platformDark)
              ? AppTheme.light
              : AppTheme.dark,
        ),
      ),
    );
  }

  Future<void> startWalkthrough() async {
    if (!mounted || walkthroughOpen) return;
    walkthroughOpen = true;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 160),
      pageBuilder: (context, _, _) => AppWalkthrough(
        prepare: (step) async {
          if (!mounted) return null;
          setState(() => tab = step.tab);
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted) return null;
          final key = step.target.startsWith('nav-')
              ? navigationKeys[step.tab]
              : walkthroughTargets[step.target]!;
          final target = key.currentContext;
          if (target == null || !target.mounted) return null;
          await Scrollable.ensureVisible(target, alignment: .12);
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted) return null;
          final box = key.currentContext?.findRenderObject();
          if (box is! RenderBox || !box.attached || !box.hasSize) return null;
          return box.localToGlobal(Offset.zero) & box.size;
        },
        finish: () => controller.change((j) => j.copy(walkthroughSeen: true)),
      ),
    );
    if (!mounted) return;
    setState(() {
      tab = 0;
      walkthroughOpen = false;
    });
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
    final unrecordedDays =
        data.asData?.value.unresolvedDays(today).toSet() ?? <DateTime>{};
    if (data.hasValue && !walkthroughChecked) {
      walkthroughChecked = true;
      if (!data.requireValue.walkthroughSeen) {
        WidgetsBinding.instance.addPostFrameCallback((_) => startWalkthrough());
      }
    }
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: MediaQuery.textScalerOf(context).scale(44) + 20 < 72
            ? 72
            : MediaQuery.textScalerOf(context).scale(44) + 20,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titles[tab],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                letterSpacing: -.4,
              ),
            ),
            if (tab == 0)
              Text(
                DateFormat('EEE, d MMM yyyy').format(today),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: Theme.of(context).brightness == Brightness.dark
                ? 'Switch to light mode'
                : 'Switch to dark mode',
            onPressed: data.hasValue ? toggleTheme : null,
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_outlined,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            key: walkthroughTargets['settings'],
            tooltip: 'Settings',
            onPressed: data.hasValue ? () => settings() : null,
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 14),
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
              1 => historyPage(j, unrecordedDays),
              2 => qadaPage(j),
              _ => progressPage(j),
            },
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: GlassCard(
          frosted: true,
          radius: 36,
          margin: EdgeInsets.zero,
          child: GlassNavigationBar(
            selectedIndex: tab,
            destinationKeys: navigationKeys,
            unrecordedDayCount: unrecordedDays.length,
            onDestinationSelected: (index) => setState(() => tab = index),
          ),
        ),
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
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
  Widget metric(
    String label,
    String value, {
    String? detail,
    Widget? labelAction,
  }) => GlassCard(
    child: SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (labelAction == null)
              Text(label)
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: Text(label)),
                  const SizedBox(width: 4),
                  labelAction,
                ],
              ),
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
    ),
  );
  Widget todayPage(Journal j) {
    final count = Prayer.values
        .where((p) => j.status(today, p) == PrayerStatus.performed)
        .length;
    final data = ref.watch(prayerTimesProvider);
    final valid =
        PrayerRecordingPolicy.timeFor(
          data.asData?.value.calendar,
          j.prayerTimes.place.key,
          today,
          Prayer.subuh,
        ) !=
        null;
    return RefreshIndicator(
      onRefresh: () => ref.read(prayerTimesProvider.notifier).refresh(),
      child: ListView(
        key: const ValueKey('today-prayers'),
        physics: const AlwaysScrollableScrollPhysics(),
        cacheExtent: 2000,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count of 5 prayers recorded today',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: count / 5,
                  minHeight: 3,
                  borderRadius: BorderRadius.circular(4),
                  semanticsLabel: 'Daily prayer progress',
                  semanticsValue: '$count of 5 performed',
                ),
                if (!valid)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      data.isLoading
                          ? 'Loading prayer times…'
                          : 'Times unavailable · pull down to retry',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (final p in Prayer.values) prayerCard(j, today, p, compact: true),
        ],
      ),
    );
  }

  Future<void> prayerTimeSettings() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .82,
        child: const PrayerTimesSettings(),
      ),
    ),
  );

  Widget prayerCard(
    Journal j,
    DateTime date,
    Prayer p, {
    bool compact = false,
  }) {
    final status = j.status(date, p);
    final isToday = dateKey(date) == dateKey(today);
    final calendar = isToday
        ? ref.watch(prayerTimesProvider).asData?.value.calendar
        : null;
    final time = PrayerRecordingPolicy.timeFor(
      calendar,
      j.prayerTimes.place.key,
      date,
      p,
    );
    final early = time != null && ref.read(clockProvider)().isBefore(time.at);
    final (icon, label) = switch (status) {
      PrayerStatus.performed => (Icons.check_circle_outline, 'Performed'),
      PrayerStatus.missed => (
        Icons.error_outline_rounded,
        'Missed · added to qada',
      ),
      PrayerStatus.unrecorded => (
        early ? Icons.schedule : Icons.radio_button_unchecked,
        early ? 'Starts at ${time.time} · Unrecorded' : 'Unrecorded',
      ),
    };
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final performed = status == PrayerStatus.performed;
    final missed = status == PrayerStatus.missed;
    final needsReview = !isToday && status == PrayerStatus.unrecorded;
    final green = dark ? const Color(0xff80d6ae) : const Color(0xff2b8058);
    final red = dark ? const Color(0xffffb4ab) : const Color(0xffb3261e);
    final amber = dark ? const Color(0xfff2c679) : const Color(0xff875510);
    final statusColor = missed
        ? red
        : needsReview
        ? amber
        : performed
        ? green
        : theme.colorScheme.onSurfaceVariant;
    final titleColor = performed && !highContrast
        ? theme.colorScheme.onSurface.withValues(alpha: .72)
        : missed
        ? red
        : theme.colorScheme.onSurface;
    return GlassCard(
      key: ValueKey('prayer-card-${dateKey(date)}-${p.name}'),
      margin: EdgeInsets.only(bottom: compact ? 6 : 10),
      borderColor: performed
          ? green
          : missed
          ? red
          : needsReview
          ? amber
          : null,
      borderWidth: missed
          ? 2.2
          : performed || needsReview
          ? 1.8
          : null,
      color: performed
          ? (dark ? const Color(0xff123c2d) : const Color(0xffe3f5e9))
          : missed
          ? (dark ? const Color(0xff4b2625) : const Color(0xffffe9e6))
          : needsReview
          ? (dark ? const Color(0xff3b3020) : const Color(0xfffff2dc))
          : null,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: compact ? 4 : 10,
          horizontal: 8,
        ),
        child: Row(
          children: [
            Transform.scale(
              key: isToday && p == Prayer.subuh
                  ? walkthroughTargets['prayer']
                  : null,
              scale: 1.2,
              child: Checkbox(
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
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${p.label}${isToday ? ' (${time?.time ?? '--:--'})' : ''}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: performed ? FontWeight.w600 : FontWeight.w800,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        needsReview ? Icons.pending_actions_rounded : icon,
                        size: 14,
                        color: statusColor,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          needsReview ? 'Unrecorded · needs review' : label,
                          style: TextStyle(
                            fontSize: 12,
                            color: statusColor,
                            fontWeight: missed || needsReview
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<PrayerStatus>(
              tooltip: 'Update ${p.label}',
              icon: const Icon(Icons.more_horiz_rounded),
              style: IconButton.styleFrom(
                minimumSize: const Size(48, 48),
                shape: const CircleBorder(),
                side: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: .75),
                  width: 1.1,
                ),
              ),
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

  Widget historyPage(Journal j, Set<DateTime> unrecordedDays) {
    final selected =
        selectedDay != null &&
            !selectedDay!.isBefore(earliestJournalDay) &&
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
        if (unrecordedDays.isNotEmpty)
          GlassCard(
            key: const ValueKey('history-review-prompt'),
            child: ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: Text(
                '${unrecordedDays.length} ${unrecordedDays.length == 1 ? 'day needs' : 'days need'} review',
              ),
              subtitle: const Text('Unrecorded prayers are not qada debt.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: review,
            ),
          ),
        GlassCard(
          child: HistoryCalendar(
            selectedDate: selected,
            today: today,
            unrecordedDays: unrecordedDays,
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
        if (selected.isBefore(j.startDate))
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Optional history before tracking began. Saving a prayer adds '
              'this day only; other earlier dates stay outside your totals.',
              style: TextStyle(fontSize: 12),
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
        labelAction: Tooltip(
          key: qadaFormulaTooltip,
          message:
              'Starting balances + confirmed misses − replacements. '
              'Unrecorded prayers are excluded.',
          triggerMode: TooltipTriggerMode.manual,
          child: Semantics(
            label: 'How outstanding qada is calculated',
            button: true,
            child: IconButton(
              key: const ValueKey('qada-formula-info'),
              onPressed: () =>
                  qadaFormulaTooltip.currentState?.ensureTooltipVisible(),
              icon: const Icon(Icons.info_outline_rounded, size: 20),
            ),
          ),
        ),
      ),
      for (final p in Prayer.values)
        GlassCard(
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
        GlassCard(
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

  Future<void> addHomeWidget() async {
    if (await homeWidget.requestPin() || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add your prayer widget'),
        content: const Text(
          'Touch and hold an empty space on your home screen, choose Widgets, '
          'then find Qada Tracker. Drag the five-prayer widget onto your home '
          'screen. Tap a prayer to toggle between performed and unrecorded '
          'for today. Tap the background to open the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
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
                const ReminderSettings(),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.help_outline_rounded),
                  title: const Text('App walkthrough'),
                  subtitle: const Text(
                    'A guided tour of the screens and controls.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).pop();
                    startWalkthrough();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Prayer times & location'),
                  subtitle: Text(j.prayerTimes.place.label),
                  leading: const Icon(Icons.schedule_rounded),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).pop();
                    prayerTimeSettings();
                  },
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
                if (homeWidget.supported) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.widgets_outlined),
                    title: const Text('Home-screen widget'),
                    subtitle: const Text(
                      'Five prayer buttons. Tap to mark done.',
                    ),
                    trailing: const Icon(Icons.add_circle_outline),
                    onTap: addHomeWidget,
                  ),
                  const SizedBox(height: 16),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dark mode'),
                  subtitle: const Text(
                    'Softer tones for your evening check-in.',
                  ),
                  value: Theme.of(context).brightness == Brightness.dark,
                  onChanged: (enabled) => act(
                    () => controller.change(
                      (j) => j.copy(
                        theme: enabled ? AppTheme.dark : AppTheme.light,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AppTheme>(
                  key: ValueKey(j.theme),
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
                  'Personal edition\nPrayer times from WaktuSolat / JAKIM. Cloud sync is not enabled.',
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
      // Include native widget marks even if its UI-change event is still queued.
      await controller.reload();
      if (!mounted) return;
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
