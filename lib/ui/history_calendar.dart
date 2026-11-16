import '../localization.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../model.dart';
import 'review_indicators.dart';

/// Editable Gregorian calendar with review markers, independent of qada status.
class HistoryCalendar extends StatefulWidget {
  const HistoryCalendar({
    required this.selectedDate,
    required this.today,
    required this.unrecordedDays,
    required this.onDateChanged,
    this.exemptDays = const {},
    this.completedDays = const {},
    this.onTodaySelected,
    this.showSelection = true,
    super.key,
  });
  final DateTime selectedDate, today;
  final Set<DateTime> unrecordedDays;
  final Set<DateTime> exemptDays;
  final Set<DateTime> completedDays;
  final ValueChanged<DateTime> onDateChanged;
  final VoidCallback? onTodaySelected;
  final bool showSelection;
  @override
  State<HistoryCalendar> createState() => _HistoryCalendarState();
}

class _HistoryCalendarState extends State<HistoryCalendar> {
  late DateTime month;
  DateTime monthOf(DateTime date) => DateTime(date.year, date.month);
  @override
  void initState() {
    super.initState();
    month = monthOf(widget.selectedDate);
  }

  @override
  void didUpdateWidget(HistoryCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (monthOf(oldWidget.selectedDate) != monthOf(widget.selectedDate)) {
      month = monthOf(widget.selectedDate);
    }
    if (month.isAfter(monthOf(widget.today))) month = monthOf(widget.today);
  }

  Future<void> chooseDate() async {
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final candidate = DateTime(
      month.year,
      month.month,
      math.min(widget.selectedDate.day, days),
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: candidate.isAfter(widget.today) ? widget.today : candidate,
      firstDate: earliestJournalDay,
      lastDate: widget.today,
      currentDate: widget.today,
      helpText: tr(context, 'Choose a date'),
    );
    if (!mounted || picked == null) return;
    setState(() => month = monthOf(picked));
    selectDate(picked);
  }

  void selectDate(DateTime date) {
    if (date == widget.today && widget.onTodaySelected != null) {
      widget.onTodaySelected!();
    } else {
      widget.onDateChanged(date);
    }
  }

  Widget dayCell(DateTime date) {
    final theme = Theme.of(context);
    final enabled =
        !date.isBefore(earliestJournalDay) && !date.isAfter(widget.today);
    final selected = widget.showSelection && date == widget.selectedDate;
    final isToday = date == widget.today;
    final pending =
        date.isBefore(widget.today) && widget.unrecordedDays.contains(date);
    final exempt = widget.exemptDays.contains(date);
    final completed = widget.completedDays.contains(date);
    final red = reviewIndicatorColor(context);
    final text = !enabled
        ? theme.colorScheme.onSurface.withValues(alpha: .35)
        : pending
        ? red
        : selected
        ? theme.colorScheme.onPrimary
        : isToday
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;
    final onTap = enabled ? () => selectDate(date) : null;
    return Semantics(
      label:
          '${DateFormat.yMMMMEEEEd(Localizations.localeOf(context).languageCode).format(date)}${isToday ? ', today' : ''}${isToday && widget.onTodaySelected != null ? ', opens Today' : ''}'
          '${completed ? tr(context, ', all five prayers completed') : ''}${pending ? ', has unrecorded prayers, needs review' : ''}${exempt ? ', exempt, no prayers required' : ''}',
      button: true,
      enabled: enabled,
      selected: selected,
      onTap: onTap,
      child: ExcludeSemantics(
        child: SizedBox(
          height: 48,
          child: InkWell(
            key: ValueKey('history-date-${dateKey(date)}'),
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: DecoratedBox(
                    key: ValueKey('history-day-${dateKey(date)}'),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? pending
                                ? red.withValues(alpha: .16)
                                : theme.colorScheme.primary
                          : exempt
                          ? theme.colorScheme.surfaceContainerHighest
                          : null,
                      border: pending
                          ? Border.all(color: red, width: 2)
                          : isToday && !selected
                          ? Border.all(
                              color: theme.colorScheme.primary,
                              width: 1.2,
                            )
                          : null,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Center(
                          child: Text(
                            tr(context, '${date.day}'),
                            style: TextStyle(
                              fontSize: 14,
                              color: text,
                              fontWeight: pending || selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (completed)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: DecoratedBox(
                              key: ValueKey(
                                'history-completed-${dateKey(date)}',
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(1),
                                child: Icon(
                                  Icons.check_rounded,
                                  size: 12,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final theme = Theme.of(context);
    final offset =
        (month.weekday % 7 - localizations.firstDayOfWeekIndex + 7) % 7;
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final rows = (offset + days + 6) ~/ 7;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  key: const ValueKey('history-choose-date'),
                  onPressed: chooseDate,
                  style: TextButton.styleFrom(padding: const EdgeInsets.all(8)),
                  child: Text(
                    tr(
                      context,
                      DateFormat.yMMMM(
                        Localizations.localeOf(context).languageCode,
                      ).format(month),
                    ),
                    textAlign: TextAlign.start,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: tr(context, localizations.previousMonthTooltip),
                onPressed: month.isAfter(monthOf(earliestJournalDay))
                    ? () => setState(
                        () => month = DateTime(month.year, month.month - 1),
                      )
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: tr(context, localizations.nextMonthTooltip),
                onPressed: month.isBefore(monthOf(widget.today))
                    ? () => setState(
                        () => month = DateTime(month.year, month.month + 1),
                      )
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.4,
            child: FocusTraversalGroup(
              child: Column(
                children: [
                  Row(
                    children: [
                      for (var col = 0; col < 7; col++)
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: Center(
                              child: Text(
                                tr(
                                  context,
                                  localizations.narrowWeekdays[(col +
                                          localizations.firstDayOfWeekIndex) %
                                      7],
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  for (var row = 0; row < rows; row++)
                    Row(
                      children: [
                        for (var col = 0; col < 7; col++)
                          Expanded(
                            child:
                                row * 7 + col - offset + 1 < 1 ||
                                    row * 7 + col - offset + 1 > days
                                ? const SizedBox(height: 48)
                                : dayCell(
                                    DateTime(
                                      month.year,
                                      month.month,
                                      row * 7 + col - offset + 1,
                                    ),
                                  ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (widget.onTodaySelected != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                tr(context, 'Tap today’s date to open Today.'),
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (widget.exemptDays.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  const Icon(Icons.pause_circle_outline, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr(context, 'Shaded dates are exempt'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.circle_outlined,
                  size: 16,
                  color: reviewIndicatorColor(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr(context, 'Past days with unrecorded prayers'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
