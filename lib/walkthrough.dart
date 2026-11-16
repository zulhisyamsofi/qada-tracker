import 'localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'controller.dart';
import 'prayer_times_controller.dart';
import 'prayer_times_models.dart';
import 'reminders.dart';

class WalkthroughStep {
  const WalkthroughStep(
    this.tab,
    this.target,
    this.icon,
    this.title,
    this.body,
    this.hint, {
    this.notificationSetup = false,
  });
  final int tab;
  final String target;
  final IconData icon;
  final String title;
  final String body;
  final String hint;
  final bool notificationSetup;
}

const walkthroughSteps = [
  WalkthroughStep(
    0,
    'nav-0',
    Icons.waving_hand_outlined,
    'Welcome to your prayer journal',
    'Keep track of your five daily prayers, review earlier days, and complete qada directly from a missed prayer. This short tour shows you where to tap.',
    'Use the three tabs at the bottom to move around. The tour never changes your prayer records.',
  ),
  WalkthroughStep(
    0,
    'prayer',
    Icons.check_box_outlined,
    'Record a prayer on Today',
    'Tap a prayer’s checkbox after performing it. Tap again to return it to Unrecorded. You can record today’s prayers once their prayer time has started.',
    'Use the three-dot menu beside a prayer to confirm a miss. An unticked prayer is unrecorded, never automatically missed. Manage menstrual period dates and tracking pauses in Settings.',
  ),
  WalkthroughStep(
    0,
    'settings',
    Icons.schedule_rounded,
    'Choose your prayer-time location',
    'Prayer times appear beside each prayer. Tap the gear, then Prayer times & location in Settings to choose a Malaysian place or use your device location.',
    'The next step lets you choose prayer-time reminders. You can change the place or use device location in Settings → Prayer times & location. Both reminder switches are together under Settings → Notifications.',
  ),
  WalkthroughStep(
    0,
    'nav-0',
    Icons.notifications_active_outlined,
    'Prayer-time reminders',
    'Get an alert at each of the five prayer times. Choose the place whose timetable you want to follow.',
    'Reminders are selected for first-time setup. Enable & continue asks Android for notification permission. Skipping leaves your existing settings unchanged. You can disable reminders anytime in Settings → Notifications.',
    notificationSetup: true,
  ),
  WalkthroughStep(
    1,
    'nav-1',
    Icons.calendar_month_outlined,
    'Review your Records',
    'Records opens on yesterday for reviewing and correcting earlier days. Its red badge counts past days with unrecorded prayers; red rings identify those dates. Tap today’s calendar date to return to Today.',
    'The review prompt above Records’ calendar opens earlier unrecorded prayers. Review one prayer at a time or confirm the remaining prayers together. Untouched dates before tracking began do not create debt.',
  ),
  WalkthroughStep(
    2,
    'nav-2',
    Icons.bar_chart_rounded,
    'See your Progress',
    'Progress shows weekly and monthly prayers performed, fully completed days, qada replacements, and unrecorded prayers.',
    'Unrecorded totals help you find gaps to review. They are separate from missed prayers and never add to your qada balance.',
  ),
  WalkthroughStep(
    0,
    'settings',
    Icons.settings_outlined,
    'Make it yours in Settings',
    'Tap the gear for language, appearance, the home-screen widget, and the Notifications group, including a daily check-in at your chosen time if any required prayer is still unrecorded.',
    'Export a manual backup regularly. Restore replaces your journal after confirmation. You can replay this tour here with App walkthrough.',
  ),
];

/// A tour over the real screens, with an explicit notification consent step. The modal route blocks all taps
/// through the spotlight, so exploring the guide cannot alter prayer records.
class AppWalkthrough extends ConsumerStatefulWidget {
  const AppWalkthrough({
    required this.prepare,
    required this.finish,
    super.key,
  });
  final Future<Rect?> Function(WalkthroughStep) prepare;
  final Future<void> Function() finish;
  @override
  ConsumerState<AppWalkthrough> createState() => _AppWalkthroughState();
}

class _AppWalkthroughState extends ConsumerState<AppWalkthrough> {
  int index = 0;
  late bool wantNotifications;
  late PrayerPlace notificationPlace;

  @override
  void initState() {
    super.initState();
    final journal = ref.read(journalProvider).requireValue;
    wantNotifications =
        ref.read(reminderServiceProvider).supported &&
        (!journal.walkthroughSeen || journal.prayerTimes.notifications);
    notificationPlace = journal.prayerTimes.place;
  }

  Future<void> next() async {
    if (saving || preparing) return;
    if (!walkthroughSteps[index].notificationSetup) {
      await loadStep(index + 1);
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await updatePrayerNotifications(
        ref,
        enabled: wantNotifications,
        place: notificationPlace,
      );
      if (!mounted) return;
      setState(() => saving = false);
      await loadStep(index + 1);
    } on FormatException catch (failure) {
      if (mounted) {
        setState(() {
          saving = false;
          wantNotifications = false;
          error = failure.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'Could not save reminder settings. Please try again.';
        });
      }
    }
  }

  Widget notificationControls() {
    final service = ref.watch(reminderServiceProvider);
    final access = ref.watch(reminderAccessProvider).asData?.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: const ValueKey('walkthrough-place'),
          initialValue: notificationPlace.id,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: tr(context, 'Prayer-time place'),
          ),
          items: [
            if (!malaysiaPlaces.any((p) => p.id == notificationPlace.id))
              DropdownMenuItem(
                value: notificationPlace.id,
                child: Text(tr(context, notificationPlace.label)),
              ),
            for (final place in malaysiaPlaces)
              DropdownMenuItem(
                value: place.id,
                child: Text(tr(context, place.label)),
              ),
          ],
          onChanged: saving
              ? null
              : (id) {
                  if (id != null && id != notificationPlace.id) {
                    setState(() {
                      notificationPlace = malaysiaPlaces.firstWhere(
                        (p) => p.id == id,
                      );
                    });
                  }
                },
        ),
        SwitchListTile(
          key: const ValueKey('walkthrough-prayer-alerts'),
          contentPadding: EdgeInsets.zero,
          title: Text(tr(context, 'Prayer-time notifications')),
          subtitle: Text(
            tr(
              context,
              service.supported
                  ? 'Five daily alerts. Turn off anytime in Settings.'
                  : 'Available on Android.',
            ),
          ),
          value: wantNotifications,
          onChanged: saving || !service.supported
              ? null
              : (value) => setState(() {
                  wantNotifications = value;
                  error = null;
                }),
        ),
        if (service.supported && access?.exactAlarms == false) ...[
          Text(
            tr(
              context,
              'For precise timing, also allow alarms & reminders. Android may delay alerts without this access.',
            ),
          ),
          TextButton(
            onPressed: saving
                ? null
                : () async {
                    try {
                      await service.openAlarmSettings();
                    } catch (_) {
                      if (mounted) {
                        setState(
                          () => error =
                              'Could not open Android alarm settings. You can try later in Settings.',
                        );
                      }
                    }
                    if (mounted) ref.invalidate(reminderAccessProvider);
                  },
            child: Text(tr(context, 'Allow alarms & reminders')),
          ),
        ],
        if (error != null && service.supported)
          TextButton(
            onPressed: saving
                ? null
                : () async {
                    try {
                      await service.openNotificationSettings();
                    } catch (_) {
                      if (mounted) {
                        setState(
                          () => error =
                              'Could not open Android notification settings. You can try later in Settings.',
                        );
                      }
                    }
                    if (mounted) ref.invalidate(reminderAccessProvider);
                  },
            child: Text(tr(context, 'Android notification settings')),
          ),
      ],
    );
  }

  Rect? focus;
  bool preparing = true;
  bool saving = false;
  String? error;
  Size? viewport;
  double? scale;
  int preparation = 0;
  final contentScroll = ScrollController();

  @override
  void dispose() {
    contentScroll.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.sizeOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(16);
    if (size != viewport || textScale != scale) {
      viewport = size;
      scale = textScale;
      WidgetsBinding.instance.addPostFrameCallback((_) => loadStep(index));
    }
  }

  Future<void> loadStep(int next) async {
    if (!mounted) return;
    final request = ++preparation;
    if (contentScroll.hasClients) contentScroll.jumpTo(0);
    setState(() {
      index = next;
      preparing = true;
      focus = null;
    });
    final target = await widget.prepare(walkthroughSteps[next]);
    if (!mounted || request != preparation) return;
    setState(() {
      focus = target;
      preparing = false;
    });
  }

  Future<void> finish() async {
    if (saving || preparing) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.finish();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'Could not save your tour preference. Please try again.';
        });
      }
    }
  }

  Widget navigationButtons(WalkthroughStep step) {
    final primary = FilledButton(
      onPressed: saving || preparing
          ? null
          : index == walkthroughSteps.length - 1
          ? finish
          : next,
      child: Text(
        tr(
          context,
          saving
              ? 'Saving…'
              : index == walkthroughSteps.length - 1
              ? 'Get started'
              : step.notificationSetup && wantNotifications
              ? 'Enable & continue'
              : 'Next',
        ),
      ),
    );
    final back = OutlinedButton(
      onPressed: saving || preparing ? null : () => loadStep(index - 1),
      child: Text(tr(context, 'Back')),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            (constraints.maxWidth < 360 &&
                MediaQuery.textScalerOf(context).scale(16) > 20) ||
            (step.notificationSetup && constraints.maxWidth < 300);
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              primary,
              if (index > 0) ...[const SizedBox(height: 8), back],
            ],
          );
        }
        return Row(
          children: [
            if (index > 0) ...[
              Expanded(child: back),
              const SizedBox(width: 12),
            ],
            Expanded(child: primary),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = walkthroughSteps[index];
    final theme = Theme.of(context);
    final top =
        focus != null &&
        focus!.center.dy > MediaQuery.sizeOf(context).height / 2;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) finish();
      },
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _Spotlight(
                    focus,
                    theme.colorScheme.primaryContainer,
                  ),
                ),
              ),
            ),
            // Absorb input even inside the visually transparent spotlight.
            const Positioned.fill(
              child: ModalBarrier(
                dismissible: false,
                color: Colors.transparent,
              ),
            ),
            SafeArea(
              child: Align(
                alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 500,
                      maxHeight: MediaQuery.sizeOf(context).height < 500
                          ? MediaQuery.sizeOf(context).height -
                                MediaQuery.paddingOf(context).vertical -
                                32
                          : MediaQuery.sizeOf(context).height *
                                (step.notificationSetup ? .74 : .54),
                    ),
                    child: Material(
                      color: theme.colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                        side: BorderSide(color: theme.colorScheme.outline),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    tr(
                                      context,
                                      'Step ${index + 1} of ${walkthroughSteps.length}',
                                    ),
                                    style: theme.textTheme.labelLarge,
                                  ),
                                ),
                                TextButton(
                                  onPressed: saving || preparing
                                      ? null
                                      : finish,
                                  child: Text(tr(context, 'Skip tour')),
                                ),
                              ],
                            ),
                            LinearProgressIndicator(
                              value: (index + 1) / walkthroughSteps.length,
                              borderRadius: BorderRadius.circular(8),
                              minHeight: 4,
                            ),
                            const SizedBox(height: 16),
                            Flexible(
                              flex: 3,
                              child: Scrollbar(
                                key: const ValueKey('walkthrough-scrollbar'),
                                controller: contentScroll,
                                thumbVisibility: true,
                                thickness: 6,
                                child: SingleChildScrollView(
                                  controller: contentScroll,
                                  key: ValueKey(index),
                                  padding: const EdgeInsetsDirectional.only(
                                    end: 20,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        step.icon,
                                        size: 28,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(height: 8),
                                      Semantics(
                                        liveRegion: true,
                                        header: true,
                                        child: Text(
                                          tr(context, step.title),
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(tr(context, step.body)),
                                      if (step.notificationSetup)
                                        notificationControls(),
                                      const SizedBox(height: 12),
                                      DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: theme
                                              .colorScheme
                                              .primaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Text(
                                            tr(context, step.hint),
                                            style: TextStyle(
                                              color: theme
                                                  .colorScheme
                                                  .onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (error != null)
                              Flexible(
                                child: SingleChildScrollView(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Text(
                                      tr(context, error!),
                                      style: TextStyle(
                                        color: theme.colorScheme.error,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 16),
                            navigationButtons(step),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Spotlight extends CustomPainter {
  _Spotlight(this.focus, this.color);
  final Rect? focus;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final hole = focus?.inflate(5).intersect(Offset.zero & size);
    final path = Path()..addRect(Offset.zero & size);
    if (hole != null && !hole.isEmpty) {
      path.addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(20)));
      path.fillType = PathFillType.evenOdd;
    }
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: .72));
    if (hole != null && !hole.isEmpty) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(hole, const Radius.circular(20)),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(_Spotlight oldDelegate) =>
      oldDelegate.focus != focus || oldDelegate.color != color;
}
