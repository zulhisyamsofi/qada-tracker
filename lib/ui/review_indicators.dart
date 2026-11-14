import 'package:flutter/material.dart';

/// Keep the navigation badge and calendar outlines identical in either theme.
Color reviewIndicatorColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xffffb4ab)
    : const Color(0xffb3261e);

Color reviewIndicatorTextColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xff410e0b)
    : Colors.white;
