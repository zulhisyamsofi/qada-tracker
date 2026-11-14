import 'package:flutter/material.dart';

class WalkthroughStep {
  const WalkthroughStep(
    this.tab,
    this.target,
    this.icon,
    this.title,
    this.body,
    this.hint,
  );
  final int tab;
  final String target;
  final IconData icon;
  final String title;
  final String body;
  final String hint;
}

const walkthroughSteps = [
  WalkthroughStep(
    0,
    'nav-0',
    Icons.waving_hand_outlined,
    'Welcome to your prayer journal',
    'Keep track of your five daily prayers, review earlier days, and record qada replacements. This short tour shows you where to tap.',
    'Use the four tabs at the bottom to move around. The tour never changes your prayer records.',
  ),
  WalkthroughStep(
    0,
    'prayer',
    Icons.check_box_outlined,
    'Record a prayer on Today',
    'Tap a prayer’s checkbox after performing it. Tap again to return it to Unrecorded. You can record today’s prayers once their prayer time has started.',
    'Use the three-dot menu beside a prayer to confirm a miss. An unticked prayer is unrecorded, never automatically missed.',
  ),
  WalkthroughStep(
    0,
    'times',
    Icons.schedule_rounded,
    'Choose your prayer-time location',
    'Prayer times appear beside each prayer. Tap the location card’s settings button to choose a Malaysian place or use your device location.',
    'Prayer-time notifications are optional. Enable them in Prayer times & location and allow the Android permissions when asked.',
  ),
  WalkthroughStep(
    1,
    'nav-1',
    Icons.calendar_month_outlined,
    'Maintain your History',
    'Open History, choose a date in the calendar, then use the same checkboxes and three-dot menus to edit its prayers. Earlier dates are editable too.',
    'Today shows a review prompt when earlier days have unrecorded prayers. Review one prayer at a time or confirm the remaining prayers together. Untouched dates before tracking began do not create debt.',
  ),
  WalkthroughStep(
    2,
    'nav-2',
    Icons.restart_alt_rounded,
    'Keep your qada balance',
    'Qada includes only your starting balances and confirmed misses, minus replacements. Tap Record beside a prayer, enter a quantity, and save it after completing the replacements.',
    'Use Undo in replacement history to correct an entry. Recording qada keeps the original miss and does not tick today’s prayer. Record becomes available when that prayer has an outstanding balance.',
  ),
  WalkthroughStep(
    3,
    'nav-3',
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
    'Tap the gear for past qada starting balances, appearance, the home-screen widget, and the optional daily reminder when nothing has been recorded by 11 PM.',
    'Export a manual backup regularly. Restore replaces your journal after confirmation. You can replay this tour here with App walkthrough.',
  ),
];

/// A read-only tour over the real screens. The modal route blocks all taps
/// through the spotlight, so exploring the guide cannot alter prayer records.
class AppWalkthrough extends StatefulWidget {
  const AppWalkthrough({
    required this.prepare,
    required this.finish,
    super.key,
  });
  final Future<Rect?> Function(WalkthroughStep) prepare;
  final Future<void> Function() finish;
  @override
  State<AppWalkthrough> createState() => _AppWalkthroughState();
}

class _AppWalkthroughState extends State<AppWalkthrough> {
  int index = 0;
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
                          : MediaQuery.sizeOf(context).height * .54,
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
                                    'Step ${index + 1} of ${walkthroughSteps.length}',
                                    style: theme.textTheme.labelLarge,
                                  ),
                                ),
                                TextButton(
                                  onPressed: saving || preparing
                                      ? null
                                      : finish,
                                  child: const Text('Skip tour'),
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
                              child: Scrollbar(
                                controller: contentScroll,
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  controller: contentScroll,
                                  key: ValueKey(index),
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
                                          step.title,
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(step.body),
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
                                            step.hint,
                                            style: TextStyle(
                                              color: theme
                                                  .colorScheme
                                                  .onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (error != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 12,
                                          ),
                                          child: Text(
                                            error!,
                                            style: TextStyle(
                                              color: theme.colorScheme.error,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                if (index > 0) ...[
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: saving || preparing
                                          ? null
                                          : () => loadStep(index - 1),
                                      child: const Text('Back'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: FilledButton(
                                    onPressed: saving || preparing
                                        ? null
                                        : index == walkthroughSteps.length - 1
                                        ? finish
                                        : () => loadStep(index + 1),
                                    child: Text(
                                      saving
                                          ? 'Saving…'
                                          : index == walkthroughSteps.length - 1
                                          ? 'Get started'
                                          : 'Next',
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
