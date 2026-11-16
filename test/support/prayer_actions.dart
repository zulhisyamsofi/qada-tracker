import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qada_tracker/model.dart';

Finder prayerActions({Prayer? prayer, DateTime? date, bool done = true}) =>
    find.byWidgetPredicate((widget) {
      if (widget is! OutlinedButton || widget.key is! ValueKey<String>) {
        return false;
      }
      final key = (widget.key! as ValueKey<String>).value;
      return key.startsWith(done ? 'done-' : 'missed-') &&
          (prayer == null || key.endsWith('-${prayer.name}')) &&
          (date == null || key.contains(dateKey(date)));
    });
Finder doneButton(Prayer prayer, [DateTime? date]) =>
    prayerActions(prayer: prayer, date: date);
Finder missedButton(Prayer prayer, [DateTime? date]) =>
    prayerActions(prayer: prayer, date: date, done: false);
bool actionSelected(WidgetTester tester, Finder button) =>
    tester
        .widget<Semantics>(
          find.ancestor(of: button, matching: find.byType(Semantics)).first,
        )
        .properties
        .selected ??
    false;
