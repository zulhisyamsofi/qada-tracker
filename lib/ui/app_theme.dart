import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class QadaTheme {
  static ThemeData build(Brightness brightness, {bool highContrast = false}) {
    final dark = brightness == Brightness.dark;
    final primary = dark ? const Color(0xffa4ebd0) : const Color(0xff166b51);
    final foreground = dark ? const Color(0xffedf9f2) : const Color(0xff173d31);
    final muted = dark ? const Color(0xffb5d8ca) : const Color(0xff4c7163);
    final outline = dark ? const Color(0xff6aaf95) : const Color(0xff639c86);
    final surface = dark ? const Color(0xff173a30) : const Color(0xfff4fcf7);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          onPrimary: dark ? const Color(0xff082a20) : Colors.white,
          primaryContainer: dark
              ? const Color(0xff245844)
              : const Color(0xffcaf2df),
          onPrimaryContainer: foreground,
          surface: surface,
          onSurface: foreground,
          onSurfaceVariant: muted,
          outline: outline,
          outlineVariant: outline.withValues(alpha: highContrast ? 1 : .42),
        );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'Nunito',
    );
    final controls = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: 'Nunito',
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
      side: WidgetStateProperty.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.disabled)
              ? outline.withValues(alpha: .24)
              : outline.withValues(alpha: highContrast ? 1 : .8),
          width: states.contains(WidgetState.focused) ? 2 : 1.2,
        ),
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: base.textTheme.copyWith(
        headlineSmall: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 27,
          fontWeight: FontWeight.w800,
          letterSpacing: -.65,
          color: foreground,
          height: 1.2,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 34,
          fontWeight: FontWeight.w800,
          letterSpacing: -.8,
          color: foreground,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: foreground,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: muted,
          height: 1.35,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        toolbarHeight: 72,
        systemOverlayStyle: dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      filledButtonTheme: FilledButtonThemeData(style: controls),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: controls.copyWith(
          backgroundColor: WidgetStatePropertyAll(
            surface.withValues(alpha: .4),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: controls.copyWith(
          minimumSize: const WidgetStatePropertyAll(Size(48, 44)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: controls.copyWith(
          shape: const WidgetStatePropertyAll(CircleBorder()),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(12)),
          foregroundColor: WidgetStatePropertyAll(foreground),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: const EdgeInsets.only(bottom: 10),
        shape: shape.copyWith(side: BorderSide(color: scheme.outlineVariant)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: dark
            ? const Color(0xffa4ebd0)
            : const Color(0xff9ceac5),
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'Nunito',
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w700,
            color: foreground,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 23,
            color: states.contains(WidgetState.selected)
                ? const Color(0xff103b2c)
                : foreground,
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        side: BorderSide(color: outline, width: 1.6),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(scheme.onPrimary),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStatePropertyAll(outline),
        trackOutlineWidth: const WidgetStatePropertyAll(1.2),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface.withValues(alpha: highContrast ? 1 : .75),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(
            color: outline.withValues(alpha: .8),
            width: 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          shape: WidgetStatePropertyAll(shape),
          backgroundColor: WidgetStatePropertyAll(surface),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        color: surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Colors.black.withValues(alpha: dark ? 0.4 : 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        dragHandleColor: outline,
        dragHandleSize: const Size(44, 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: shape.copyWith(side: BorderSide(color: scheme.outlineVariant)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: dark
            ? const Color(0xffd1f5e5)
            : const Color(0xff163e31),
        contentTextStyle: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 14,
          color: dark ? const Color(0xff13382b) : Colors.white,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: primary.withValues(alpha: .16),
        circularTrackColor: primary.withValues(alpha: .15),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surface,
        shape: shape,
        dayStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 24,
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        titleTextStyle: base.textTheme.titleMedium?.copyWith(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
        subtitleTextStyle: base.textTheme.bodySmall?.copyWith(
          fontFamily: 'Nunito',
          fontSize: 13,
          color: muted,
        ),
      ),
    );
  }
}
