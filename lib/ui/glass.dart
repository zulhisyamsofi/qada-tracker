import '../localization.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'review_indicators.dart';

class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? const [
                        Color(0xff0b2a21),
                        Color(0xff061e17),
                        Color(0xff10382b),
                      ]
                    : const [
                        Color(0xffedf9f2),
                        Color(0xffe5f7ee),
                        Color(0xffd9f5e8),
                      ],
              ),
            ),
          ),
        ),
        if (!MediaQuery.highContrastOf(context)) ...[
          Positioned(
            top: size.height * .1,
            right: -size.width * .3,
            width: size.width * 1.05,
            height: size.width * 1.05,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: dark
                        ? [
                            const Color(0xff208367).withValues(alpha: .4),
                            Colors.transparent,
                          ]
                        : [
                            const Color(0xff9eeacb).withValues(alpha: .5),
                            Colors.transparent,
                          ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: size.height * .08,
            left: -size.width * .4,
            width: size.width * 1.3,
            height: size.width * 1.3,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: dark
                        ? [
                            const Color(0xff127655).withValues(alpha: .32),
                            Colors.transparent,
                          ]
                        : [
                            const Color(0xff94e6c1).withValues(alpha: .38),
                            Colors.transparent,
                          ],
                  ),
                ),
              ),
            ),
          ),
        ],
        child,
      ],
    );
  }
}

/// Blur is opt-in for the summary/navigation, not every scrolling row.
class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.margin = const EdgeInsets.only(bottom: 10),
    this.color,
    this.borderColor,
    this.borderWidth,
    this.frosted = false,
    this.radius = 24,
    super.key,
  });
  final Widget child;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final Color? borderColor;
  final double? borderWidth;
  final bool frosted;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final contrast = MediaQuery.highContrastOf(context);
    final tint = color ?? theme.colorScheme.surface;
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: contrast
            ? [theme.colorScheme.surface, theme.colorScheme.surface]
            : dark
            ? [
                Color.lerp(
                  tint,
                  const Color(0xff437f6a),
                  .25,
                )!.withValues(alpha: .72),
                tint.withValues(alpha: .52),
              ]
            : [
                Color.lerp(
                  tint,
                  Colors.white,
                  color == null ? .65 : .18,
                )!.withValues(alpha: .86),
                tint.withValues(alpha: .58),
              ],
      ),
      border: Border.all(
        color:
            borderColor ??
            (contrast
                ? theme.colorScheme.outline
                : dark
                ? const Color(0xffa6dbc6).withValues(alpha: .42)
                : Colors.white.withValues(alpha: .94)),
        width: borderWidth ?? (contrast ? 1.8 : 1.2),
      ),
    );
    Widget panel = DecoratedBox(
      decoration: decoration,
      child: Material(type: MaterialType.transparency, child: child),
    );
    if (frosted && !contrast) {
      panel = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: panel,
      );
    }
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: (dark ? Colors.black : const Color(0xff1c7653)).withValues(
              alpha: dark ? 0.08 : 0.015,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: panel,
      ),
    );
  }
}

class GlassNavigationBar extends StatelessWidget {
  const GlassNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.destinationKeys,
    this.pendingPrayerCount = 0,
    super.key,
  });
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<GlobalKey>? destinationKeys;
  final int pendingPrayerCount;
  static const labels = ['Today', 'Qada', 'History', 'Settings'];
  static const icons = [
    Icons.wb_sunny_outlined,
    Icons.restart_alt_rounded,
    Icons.calendar_month_outlined,
    Icons.settings_outlined,
  ];
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final accent = dark ? const Color(0xffa4ebd0) : const Color(0xff9ceac5);
    return Row(
      children: [
        for (var index = 0; index < labels.length; index++)
          Expanded(
            child: Semantics(
              key: destinationKeys?[index],
              button: true,
              selected: index == selectedIndex,
              label: tr(
                context,
                index == 2 && pendingPrayerCount > 0
                    ? 'History, $pendingPrayerCount missed prayers awaiting qada'
                    : labels[index],
              ),
              onTap: () => onDestinationSelected(index),
              child: ExcludeSemantics(
                child: Tooltip(
                  message: tr(
                    context,
                    index == 2 && pendingPrayerCount > 0
                        ? 'History, $pendingPrayerCount missed prayers awaiting qada'
                        : labels[index],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: InkWell(
                      onTap: () => onDestinationSelected(index),
                      borderRadius: BorderRadius.circular(31),
                      child: AnimatedContainer(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 160),
                        constraints: const BoxConstraints(minHeight: 64),
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 2,
                        ),
                        decoration: BoxDecoration(
                          color: index == selectedIndex
                              ? accent
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(31),
                          border: Border.all(
                            color: index == selectedIndex
                                ? Colors.white.withValues(alpha: .35)
                                : Colors.transparent,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (index == 2)
                              Badge(
                                key: const ValueKey('history-review-badge'),
                                label: Text(
                                  tr(context, '$pendingPrayerCount'),
                                  textScaler: MediaQuery.textScalerOf(
                                    context,
                                  ).clamp(maxScaleFactor: 1.3),
                                ),
                                textStyle: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                                isLabelVisible: pendingPrayerCount > 0,
                                backgroundColor: reviewIndicatorColor(context),
                                textColor: reviewIndicatorTextColor(context),
                                child: Icon(
                                  icons[index],
                                  size: 23,
                                  color: index == selectedIndex
                                      ? const Color(0xff103b2c)
                                      : theme.colorScheme.onSurface,
                                ),
                              )
                            else
                              Icon(
                                index == 0 && index == selectedIndex
                                    ? Icons.wb_sunny_rounded
                                    : icons[index],
                                size: 23,
                                color: index == selectedIndex
                                    ? const Color(0xff103b2c)
                                    : theme.colorScheme.onSurface,
                              ),
                            const SizedBox(height: 4),
                            // Fit full destination names in the fixed tab
                            // bar; tooltips and semantics retain their labels.
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                tr(context, labels[index]),
                                maxLines: 1,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: index == selectedIndex
                                      ? FontWeight.w800
                                      : FontWeight.w700,
                                  color: index == selectedIndex
                                      ? const Color(0xff103b2c)
                                      : theme.colorScheme.onSurface,
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
      ],
    );
  }
}
