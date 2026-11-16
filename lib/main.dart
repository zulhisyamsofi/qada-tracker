import 'localization.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'tracking_settings.dart';
import 'prayer_times_page.dart';
import 'prayer_times_controller.dart';
import 'ui/app_theme.dart';
import 'ui/glass.dart';
import 'home_widget.dart';
import 'prayer_recording_policy.dart';
import 'walkthrough.dart';
import 'ui/history_calendar.dart';
import 'ui/settings_group.dart';

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
      locale: Locale(journal?.language.name ?? 'en'),
      supportedLocales: const [Locale('en'), Locale('ms')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
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
  final updatingPrayers = <String>{};
  final historyScroll = ScrollController();
  final historyCalendarKey = GlobalKey();
  bool walkthroughChecked = false;
  bool walkthroughOpen = false;
  final walkthroughTargets = {
    for (final key in ['prayer']) key: GlobalKey(),
  };
  final navigationKeys = List.generate(4, (_) => GlobalKey());
  late final ReminderService reminders;
  late final HomeWidgetService homeWidget;
  final titles = const ['Today', 'Qada', 'History', 'Settings'];
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
    historyScroll.dispose();
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
            persist: false,
            duration: const Duration(seconds: 4),
            content: Text(
              tr(context, error.toString().replaceFirst('Bad state: ', '')),
            ),
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
          title: Text(tr(context, title)),
          content: Text(tr(context, message)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr(context, 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr(context, label)),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(journalProvider);
    final pendingCounts =
        data.asData?.value.pendingPrayerCounts(today) ?? <DateTime, int>{};
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
              tr(context, titles[tab]),
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
                tr(
                  context,
                  DateFormat(
                    'EEE, d MMM yyyy',
                    Localizations.localeOf(context).languageCode,
                  ).format(today),
                ),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: tr(
              context,
              Theme.of(context).brightness == Brightness.dark
                  ? 'Switch to light mode'
                  : 'Switch to dark mode',
            ),
            onPressed: data.hasValue ? toggleTheme : null,
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_outlined,
            ),
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
                Text(
                  tr(
                    context,
                    'Unable to open your journal. Your stored data has not been reset.',
                  ),
                ),
                const SizedBox(height: 16),
                Text(tr(context, '$error')),
                TextButton(
                  onPressed: () {
                    ref.invalidate(databaseProvider);
                    ref.invalidate(journalProvider);
                  },
                  child: Text(tr(context, 'Retry')),
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
              1 => qadaPage(j),
              2 => historyPage(j, pendingCounts),
              _ => settingsPage(j),
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
            pendingPrayerCount: pendingCounts.values.fold(
              0,
              (sum, count) => sum + count,
            ),
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
          tr(context, title),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          tr(context, subtitle),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
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
              Text(tr(context, label))
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: Text(tr(context, label))),
                  const SizedBox(width: 4),
                  labelAction,
                ],
              ),
            const SizedBox(height: 6),
            Text(
              tr(context, value),
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (detail != null) Text(tr(context, detail)),
          ],
        ),
      ),
    ),
  );
  Widget todayPage(Journal j) {
    final count = Prayer.values
        .where(
          (p) =>
              j.status(today, p) == PrayerStatus.performed ||
              j.replacementFor(today, p) != null,
        )
        .length;
    final required = j.requiredPrayers(today).length;
    final exempt = 5 - required;
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
        padding: const EdgeInsets.all(20),
        children: [
          GlassCard(
            frosted: true,
            color: Theme.of(context).colorScheme.primaryContainer,
            radius: 30,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(
                            context,
                            required == 0
                                ? 'No prayers to record today'
                                : '$count of $required prayers recorded today',
                          ),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr(
                            context,
                            required == 0
                                ? 'Today is exempt. Your previous records are preserved.'
                                : 'A small moment to reflect and keep track.',
                          ),
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: required == 0 ? 0 : count / required,
                            strokeWidth: 7,
                            strokeCap: StrokeCap.round,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: .14),
                            semanticsLabel: tr(
                              context,
                              'Daily prayer progress',
                            ),
                            semanticsValue: tr(
                              context,
                              '$count of $required required prayers performed',
                            ),
                          ),
                        ),
                        Text(
                          tr(
                            context,
                            required == 0 ? 'Exempt' : '$count/$required',
                          ),
                          style: TextStyle(
                            fontSize: required == 0 ? 14 : 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (exempt > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(
                    tr(
                      context,
                      '$exempt ${exempt == 1 ? 'prayer' : 'prayers'} exempt today',
                    ),
                  ),
                  TextButton(
                    onPressed: trackingSettings,
                    child: Text(tr(context, 'Manage exemptions')),
                  ),
                ],
              ),
            ),
          if (!valid && required > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                tr(
                  context,
                  data.isLoading
                      ? 'Loading prayer times…'
                      : 'Times unavailable · pull down to retry',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          for (final p in Prayer.values) prayerCard(j, today, p),
        ],
      ),
    );
  }

  Future<void> trackingSettings() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .85,
        child: const TrackingSettings(),
      ),
    ),
  );

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

  Widget prayerCard(Journal j, DateTime date, Prayer p) {
    final status = j.status(date, p);
    final replacement = j.replacementFor(date, p);
    final replaced = replacement != null;
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
    final (icon, label) = replaced
        ? (Icons.task_alt, 'Qada completed')
        : switch (status) {
            PrayerStatus.performed => (Icons.check_circle_outline, 'Performed'),
            PrayerStatus.missed => (
              Icons.error_outline_rounded,
              'Missed · added to qada',
            ),
            PrayerStatus.exempt => (
              Icons.pause_circle_outline,
              'Exempt · no qada',
            ),
            PrayerStatus.unrecorded => (
              early ? Icons.schedule : Icons.radio_button_unchecked,
              'Unrecorded',
            ),
          };
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final performed = status == PrayerStatus.performed || replaced;
    final missed = status == PrayerStatus.missed && !replaced;
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
      margin: const EdgeInsets.only(bottom: 10),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(
                    context,
                    '${p.label}${isToday ? ' (${time?.time ?? '--:--'})' : ''}',
                  ),
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
                        tr(
                          context,
                          needsReview ? 'Unrecorded · needs review' : label,
                        ),
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
            );
            Widget button(bool done) {
              final selected = done ? performed : missed;
              final tint = done ? green : red;
              return Semantics(
                selected: selected,
                label: tr(context, '${p.label}: ${done ? 'Done' : 'Missed'}'),
                child: OutlinedButton(
                  key: ValueKey(
                    '${done ? 'done' : 'missed'}-${dateKey(date)}-${p.name}',
                  ),
                  onPressed:
                      updatingPrayers.contains('${dateKey(date)}/${p.name}')
                      ? null
                      : () => choosePrayerAction(date, p, done),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tint,
                    backgroundColor: selected
                        ? tint.withValues(alpha: dark ? .20 : .14)
                        : tint.withValues(alpha: .04),
                    side: BorderSide(
                      color: tint.withValues(alpha: selected ? 1 : .65),
                      width: selected ? 1.8 : 1,
                    ),
                    minimumSize: const Size(72, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    textStyle: theme.textTheme.labelLarge?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(tr(context, done ? 'Done' : 'Missed')),
                ),
              );
            }

            final stacked =
                constraints.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(14) > 18;
            final buttons = Row(
              mainAxisSize: stacked ? MainAxisSize.max : MainAxisSize.min,
              children: [
                if (stacked) Expanded(child: button(true)) else button(true),
                const SizedBox(width: 8),
                if (stacked) Expanded(child: button(false)) else button(false),
              ],
            );
            return Column(
              key: isToday && p == Prayer.subuh
                  ? walkthroughTargets['prayer']
                  : null,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (stacked) ...[
                  details,
                  const SizedBox(height: 12),
                  buttons,
                ] else
                  Row(
                    children: [
                      Expanded(child: details),
                      const SizedBox(width: 10),
                      buttons,
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> choosePrayerAction(
    DateTime day,
    Prayer prayer,
    bool done,
  ) async {
    final key = '${dateKey(day)}/${prayer.name}';
    if (!updatingPrayers.add(key)) return;
    setState(() {});
    try {
      final journal = ref.read(journalProvider).requireValue;
      if (done &&
          journal.status(day, prayer) == PrayerStatus.missed &&
          journal.replacementFor(day, prayer) == null) {
        await completeDatedPrayer(day, prayer);
      } else {
        await act(
          () => controller.change((current) {
            final linked = current.replacementFor(day, prayer);
            final status = current.status(day, prayer);
            final selected = done
                ? status == PrayerStatus.performed || linked != null
                : status == PrayerStatus.missed && linked == null;
            final updated = linked == null ? current : current.undo(linked.id);
            return updated.setStatuses(day, {
              prayer: selected
                  ? PrayerStatus.unrecorded
                  : done
                  ? PrayerStatus.performed
                  : PrayerStatus.missed,
            }, ref.read(clockProvider)());
          }),
        );
      }
    } finally {
      updatingPrayers.remove(key);
      if (mounted) setState(() {});
    }
  }

  Widget historyPage(Journal j, Map<DateTime, int> pendingCounts) {
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final hasSelection =
        selectedDay != null &&
        !selectedDay!.isBefore(earliestJournalDay) &&
        selectedDay!.isBefore(today);
    final selected = hasSelection ? selectedDay! : yesterday;
    final firstDay =
        !hasSelection && !j.days(today).any((day) => day.isBefore(today));
    void openToday() => setState(() {
      tab = 0;
      selectedDay = null;
    });
    return ListView(
      key: const ValueKey('history-page'),
      controller: historyScroll,
      padding: const EdgeInsets.all(20),
      children: [
        heading(
          'Your prayer journal',
          'Tracking since ${DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(j.startDate)}',
        ),
        if (firstDay)
          GlassCard(
            key: const ValueKey('history-first-day'),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.history_rounded),
                  const SizedBox(height: 12),
                  Text(
                    tr(
                      context,
                      'Your prayer history will appear here tomorrow.',
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      context,
                      'Record today’s prayers on Today. You can select an earlier date to add older records.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: openToday,
                    child: Text(tr(context, 'Go to Today')),
                  ),
                ],
              ),
            ),
          ),
        GlassCard(
          key: historyCalendarKey,
          child: HistoryCalendar(
            selectedDate: firstDay ? today : selected,
            showSelection: !firstDay,
            today: today,
            pendingPrayerCounts: pendingCounts,
            exemptDays: j.days(today).where(j.fullyExempt).toSet(),
            completedDays: j
                .days(today)
                .where(
                  (day) => Prayer.values.every(
                    (p) =>
                        j.status(day, p) == PrayerStatus.performed ||
                        j.replacementFor(day, p) != null,
                  ),
                )
                .toSet(),
            onDateChanged: (date) {
              if (date.isBefore(today)) setState(() => selectedDay = date);
            },
            onTodaySelected: openToday,
          ),
        ),
        if (!firstDay) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              tr(
                context,
                DateFormat(
                  'EEEE, d MMMM',
                  Localizations.localeOf(context).languageCode,
                ).format(selected),
              ),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (selected.isBefore(j.startDate))
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                tr(
                  context,
                  'Optional history before tracking began. Saving a prayer adds '
                  'this day only; other earlier dates stay outside your totals.',
                ),
                style: TextStyle(fontSize: 12),
              ),
            ),
          for (final p in Prayer.values) prayerCard(j, selected, p),
        ],
      ],
    );
  }

  Widget qadaPage(Journal j) => ListView(
    key: const ValueKey('qada-page'),
    padding: const EdgeInsets.all(20),
    children: [
      qadaSummary(j),
      if (j.starting.values.any((n) => n > 0) ||
          j.replacements.any((e) => e.missedDate == null))
        GlassCard(
          child: ExpansionTile(
            title: Text(tr(context, 'Earlier records')),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  tr(
                    context,
                    'Existing balances and undated replacements are preserved. They do not identify which dates were settled. Use an existing replacement from a missed prayer to link it without reducing the balance again. Older starting balances are read-only until reconciled.',
                  ),
                ),
              ),
              for (final p in Prayer.values)
                if ((j.starting[p] ?? 0) > 0)
                  ListTile(
                    title: Text(p.label),
                    trailing: Text('${j.starting[p]}'),
                  ),
            ],
          ),
        ),
      const SizedBox(height: 12),
      replacementHistory(j),
      const SizedBox(height: 24),
      progressContent(j),
    ],
  );

  Future<void> undoLinkedReplacement(QadaEntry entry) async {
    if (await confirm(
      'Undo qada?',
      'This will reopen the missed prayer and restore one outstanding qada.',
      label: 'Undo',
    )) {
      await act(() => controller.change((j) => j.undo(entry.id)));
    }
  }

  Future<void> completeDatedPrayer(DateTime day, Prayer prayer) async {
    final j = ref.read(journalProvider).requireValue;
    final previous = j.replacements
        .where(
          (e) =>
              e.missedDate == null &&
              e.prayer == prayer &&
              !dayOnly(e.completedAt.toLocal()).isBefore(dayOnly(day)),
        )
        .toList();
    final choice = previous.isEmpty && j.balance(prayer) > 0
        ? 'new'
        : await showDialog<String>(
            context: context,
            builder: (context) => SimpleDialog(
              title: Text(tr(context, 'Complete qada')),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    tr(
                      context,
                      'Already recorded this replacement? Use an existing entry to avoid counting it twice.',
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    tr(
                      context,
                      '${prayer.label} · ${DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(day)}',
                    ),
                  ),
                ),
                if (j.balance(prayer) > 0)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, 'new'),
                    child: Text(tr(context, 'Record new completion')),
                  ),
                for (final entry in previous)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, entry.id),
                    child: Text(
                      tr(
                        context,
                        'Use existing replacement: ${entry.quantity} × ${DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(entry.completedAt.toLocal())}',
                      ),
                    ),
                  ),
                if (j.balance(prayer) == 0 && previous.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      tr(
                        context,
                        'No balance is available for a new completion. Review earlier replacement entries first.',
                      ),
                    ),
                  ),
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context),
                  child: Text(tr(context, 'Cancel')),
                ),
              ],
            ),
          );
    if (choice == null) return;
    await act(() async {
      if (choice == 'new') {
        final id = await controller.completeMiss(day, prayer);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              persist: false,
              duration: const Duration(seconds: 4),
              content: Text(tr(context, 'Qada completed')),
              action: SnackBarAction(
                label: tr(context, 'Undo'),
                onPressed: () =>
                    act(() => controller.change((j) => j.undo(id))),
              ),
            ),
          );
      } else {
        await controller.linkReplacement(day, prayer, choice);
      }
    });
  }

  Future<void> showMissedPrayers(Prayer prayer) async {
    final journal = ref.read(journalProvider).requireValue;
    final dates =
        journal.records.entries
            .where(
              (row) =>
                  row.value[prayer] == PrayerStatus.missed &&
                  journal.replacementFor(parseDay(row.key), prayer) == null,
            )
            .map((row) => parseDay(row.key))
            .where((day) => !day.isAfter(today))
            .toList()
          ..sort((a, b) => b.compareTo(a));
    final date = await showDialog<DateTime>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(tr(context, '${prayer.label} · outstanding qada')),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (journal.replacements.any(
                (e) => e.prayer == prayer && e.missedDate == null,
              ))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    tr(
                      context,
                      'Earlier unlinked replacements may already cover some dates. Link an existing replacement when recording Done.',
                    ),
                  ),
                ),
              if (dates.isEmpty)
                Text(tr(context, 'No dated missed prayers for this prayer.'))
              else
                SizedBox(
                  height:
                      (dates.length *
                              72.0 *
                              MediaQuery.textScalerOf(context).scale(16) /
                              16)
                          .clamp(64.0, MediaQuery.sizeOf(context).height * .45),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: dates.length,
                    itemBuilder: (context, index) {
                      final day = dates[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final label = Text(
                              DateFormat.yMMMd(
                                Localizations.localeOf(context).languageCode,
                              ).format(day),
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            );
                            final open = TextButton.icon(
                              key: ValueKey(
                                'open-miss-${dateKey(day)}-${prayer.name}',
                              ),
                              onPressed: () => Navigator.pop(context, day),
                              icon: const Icon(
                                Icons.calendar_month_outlined,
                                size: 18,
                              ),
                              label: Text(tr(context, 'Open date')),
                            );
                            if (constraints.maxWidth < 260 ||
                                MediaQuery.textScalerOf(context).scale(16) >
                                    21) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  label,
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: open,
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: label),
                                const SizedBox(width: 12),
                                open,
                              ],
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'Close')),
          ),
        ],
      ),
    );
    if (date == null || !mounted) return;
    setState(() {
      selectedDay = date == today ? null : date;
      tab = date == today ? 0 : 2;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final calendar = historyCalendarKey.currentContext;
      if (mounted && tab == 2 && calendar != null) {
        Scrollable.ensureVisible(calendar, alignment: 0);
      }
    });
  }

  Widget qadaSummary(Journal j) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Text(
          tr(context, 'Outstanding qada'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      for (final p in Prayer.values)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  p.label,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              OutlinedButton(
                key: ValueKey('qada-balance-${p.name}'),
                onPressed: () => showMissedPrayers(p),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(56, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: .5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  '${j.balance(p)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 16),
    ],
  );

  Widget replacementHistory(Journal j) => GlassCard(
    child: ExpansionTile(
      title: Text(tr(context, 'Replacement history')),
      children: [
        if (j.replacements.isEmpty)
          ListTile(title: Text(tr(context, 'No replacements recorded yet.'))),
        for (final entry in j.replacements.reversed)
          ListTile(
            title: Text('${entry.prayer.label} × ${entry.quantity}'),
            subtitle: Text(
              tr(
                context,
                entry.missedDate == null
                    ? 'Earlier replacement · date not linked'
                    : 'For ${DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(entry.missedDate!)}',
              ),
            ),
            trailing: TextButton(
              onPressed: () async {
                if (entry.missedDate != null) {
                  await undoLinkedReplacement(entry);
                } else if (await confirm(
                  'Undo replacement?',
                  'This restores the recorded quantity to your outstanding balance.',
                  label: 'Undo',
                )) {
                  await act(() => controller.change((j) => j.undo(entry.id)));
                }
              },
              child: Text(tr(context, 'Undo')),
            ),
          ),
      ],
    ),
  );

  Widget progressContent(Journal j) {
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
      final full = days.where(j.fullyPerformed).length;
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
          Text(
            tr(context, title),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          metric(
            'Prayers performed',
            '$performed / ${days.fold<int>(0, (n, day) => n + j.requiredPrayers(day).length)}',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading(
          'Progress',
          'Reflect on your records, without scores or penalties.',
        ),
        section('This week · Monday onwards', week),
        const SizedBox(height: 16),
        section(
          DateFormat(
            'MMMM yyyy',
            Localizations.localeOf(context).languageCode,
          ).format(today),
          month,
        ),
      ],
    );
  }

  Future<void> addHomeWidget() async {
    if (await homeWidget.requestPin() || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(context, 'Add your prayer widget')),
        content: Text(
          tr(
            context,
            'Touch and hold an empty space on your home screen, choose Widgets, '
            'then find Qada Tracker. Drag the five-prayer widget onto your home '
            'screen. Tap a prayer to toggle between performed and unrecorded '
            'for today. Tap the background to open the app.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'Done')),
          ),
        ],
      ),
    );
  }

  Widget settingsPage(Journal j) => ListView(
    key: const ValueKey('settings-page'),
    padding: const EdgeInsets.all(20),
    children: [
      SettingsGroup(
        title: 'Preferences',
        icon: Icons.tune_rounded,
        children: [
          SettingsItem(
            key: ValueKey('language-setting-${j.language.name}'),
            title: 'Language / Bahasa',
            icon: Icons.language_rounded,
            control: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: DropdownButtonFormField<AppLanguage>(
                key: const ValueKey('app-language'),
                initialValue: j.language,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                isExpanded: true,
                itemHeight: null,
                borderRadius: BorderRadius.circular(22),
                dropdownColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHigh,
                icon: const Icon(Icons.expand_more_rounded),
                selectedItemBuilder: (context) => [
                  for (final language in AppLanguage.values)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        language == AppLanguage.en
                            ? 'English'
                            : 'Bahasa Melayu',
                      ),
                    ),
                ],
                items: [
                  for (final language in AppLanguage.values)
                    DropdownMenuItem(
                      value: language,
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 58),
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: language == j.language
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                language == AppLanguage.en
                                    ? 'English'
                                    : 'Bahasa Melayu',
                              ),
                            ),
                            if (language == j.language)
                              const Icon(Icons.check_rounded, size: 20),
                          ],
                        ),
                      ),
                    ),
                ],
                onChanged: (language) {
                  if (language != null) {
                    act(
                      () =>
                          controller.change((j) => j.copy(language: language)),
                    );
                  }
                },
              ),
            ),
          ),
          SwitchListTile(
            key: const ValueKey('dark-mode-setting'),
            secondary: const SettingsIcon(Icons.dark_mode_outlined),
            title: Text(tr(context, 'Dark mode')),
            subtitle: Text(
              tr(context, 'Softer tones for your evening check-in.'),
            ),
            value: Theme.of(context).brightness == Brightness.dark,
            onChanged: (_) => toggleTheme(),
          ),
        ],
      ),
      SettingsGroup(
        title: 'Prayer & tracking',
        icon: Icons.mosque_outlined,
        children: [
          SettingsItem(
            title: 'Prayer times & location',
            icon: Icons.schedule_rounded,
            description: j.prayerTimes.place.label,
            onTap: prayerTimeSettings,
          ),
          SettingsItem(
            title: 'Menstrual period & tracking pause',
            icon: Icons.pause_circle_outline,
            description:
                'Set your menstrual period dates so prayers are excluded from tracking and qada.',
            onTap: trackingSettings,
          ),
        ],
      ),
      const ReminderSettings(),
      SettingsGroup(
        title: 'Backups',
        icon: Icons.backup_outlined,
        children: [
          SettingsItem(
            title: 'Export backup',
            icon: Icons.file_upload_outlined,
            description: 'Save a copy of your journal and settings.',
            enabled: !fileBusy,
            onTap: exportBackup,
          ),
          SettingsItem(
            title: 'Restore backup',
            icon: Icons.file_download_outlined,
            description: 'Replace this journal with a saved backup.',
            enabled: !fileBusy,
            onTap: importBackup,
          ),
        ],
      ),
      SettingsGroup(
        title: 'Tools & help',
        icon: Icons.help_outline_rounded,
        children: [
          if (homeWidget.supported)
            SettingsItem(
              title: 'Home-screen widget',
              icon: Icons.widgets_outlined,
              description: 'Five prayer buttons. Tap to mark done.',
              onTap: addHomeWidget,
            ),
          SettingsItem(
            title: 'App walkthrough',
            icon: Icons.explore_outlined,
            description: 'A guided tour of the screens and controls.',
            onTap: startWalkthrough,
          ),
          const SettingsItem(
            title: 'Personal edition',
            icon: Icons.info_outline_rounded,
            description:
                'Prayer times from WaktuSolat / JAKIM. Cloud sync is not enabled.',
          ),
        ],
      ),
    ],
  );

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
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              persist: false,
              duration: const Duration(seconds: 4),
              content: Text(
                tr(context, 'Backup exported. Keep it somewhere safe.'),
              ),
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
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              persist: false,
              duration: const Duration(seconds: 4),
              content: Text(tr(context, 'Backup restored.')),
            ),
          );
      }
    });
    if (mounted) setState(() => fileBusy = false);
  }
}
