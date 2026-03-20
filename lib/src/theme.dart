import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color scaffold = Color(0xFFF6F6F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFCFCFE);
  static const Color softSurface = Color(0xFFF3F3F8);
  static const Color ink = Color(0xFF16163F);
  static const Color secondaryInk = Color(0xFF6B6B8D);
  static const Color tertiaryInk = Color(0xFF9D9DB8);
  static const Color outline = Color(0xFFDFDFE8);
  static const Color divider = Color(0xFFECECF2);

  static const Color accent = Color(0xFF6C5CE7);
  static const Color accentDark = Color(0xFF5A4BD6);
  static const Color accentLight = Color(0xFFEDE9FE);
  static const Color accentSuperLight = Color(0xFFF6F4FF);

  static const Color success = Color(0xFF00B894);
  static const Color successLight = Color(0xFFE6FAF5);
  static const Color warning = Color(0xFFE8A317);
  static const Color warningLight = Color(0xFFFFF8EB);
  static const Color danger = Color(0xFFE74C3C);
  static const Color dangerLight = Color(0xFFFDEDEB);
  static const Color info = Color(0xFF4A90D9);
  static const Color infoLight = Color(0xFFEBF2FC);

  static const Color github = Color(0xFF24292F);
  static const Color githubLight = Color(0xFFF0F0F2);
  static const Color jira = Color(0xFF0065FF);
  static const Color jiraLight = Color(0xFFE6F0FF);
  static const Color slack = Color(0xFF611F69);
  static const Color slackLight = Color(0xFFF5EBF6);
  static const Color openai = Color(0xFF10A37F);
  static const Color openaiLight = Color(0xFFE6F8F3);
  static const Color gemini = Color(0xFF4285F4);
  static const Color geminiLight = Color(0xFFE8F0FE);
  static const Color claude = Color(0xFFD97757);
  static const Color claudeLight = Color(0xFFFDF0EB);
}

ThemeData buildEngiTrackTheme() {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: Brightness.light,
    surface: AppColors.surface,
  ).copyWith(
    primary: AppColors.accent,
    onPrimary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    outline: AppColors.outline,
    secondary: AppColors.secondaryInk,
  );

  final ThemeData base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.scaffold,
    dividerColor: AppColors.divider,
    splashFactory: InkSparkle.splashFactory,
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppColors.scaffold,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -0.3,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      elevation: 0,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.accentLight,
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
        (Set<WidgetState> states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.accent : AppColors.tertiaryInk,
            letterSpacing: 0.2,
          );
        },
      ),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>(
        (Set<WidgetState> states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.accent : AppColors.tertiaryInk,
            size: 21,
          );
        },
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: Color(0xFFEDE9FE),
      selectedIconTheme: IconThemeData(color: AppColors.accent, size: 20),
      unselectedIconTheme: IconThemeData(color: AppColors.tertiaryInk, size: 20),
      selectedLabelTextStyle: TextStyle(
        color: AppColors.accent,
        fontWeight: FontWeight.w700,
        fontSize: 13,
        letterSpacing: -0.1,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: AppColors.secondaryInk,
        fontWeight: FontWeight.w500,
        fontSize: 13,
      ),
    ),
    textTheme: base.textTheme.copyWith(
      displaySmall: const TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
        letterSpacing: -1.0,
        height: 1.1,
      ),
      headlineMedium: const TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -0.4,
        height: 1.25,
      ),
      titleLarge: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -0.2,
        height: 1.3,
      ),
      titleMedium: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        height: 1.35,
      ),
      bodyLarge: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.ink,
        height: 1.55,
      ),
      bodyMedium: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.secondaryInk,
        height: 1.5,
      ),
      labelLarge: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      labelMedium: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.tertiaryInk,
        letterSpacing: 0.2,
      ),
    ),
    cardTheme: CardTheme(
      elevation: 0,
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.outline, width: 0.5),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.softSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      hintStyle: const TextStyle(color: AppColors.tertiaryInk, fontSize: 13),
      labelStyle: const TextStyle(color: AppColors.secondaryInk, fontSize: 13),
      floatingLabelStyle: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide.none,
      backgroundColor: AppColors.softSurface,
      selectedColor: AppColors.accentLight,
      labelStyle: const TextStyle(
        color: AppColors.ink,
        fontWeight: FontWeight.w500,
        fontSize: 12,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.accent.withOpacity(0.4),
        disabledForegroundColor: Colors.white.withOpacity(0.7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.outline, width: 0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    ),
    dialogTheme: DialogTheme(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      surfaceTintColor: Colors.transparent,
      backgroundColor: AppColors.surface,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 8,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 0.5,
      space: 0,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.accent;
          }
          return Colors.transparent;
        },
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: const BorderSide(color: AppColors.outline, width: 1.5),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return AppColors.tertiaryInk;
        },
      ),
      trackColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.accent;
          }
          return AppColors.outline;
        },
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
    ),
  );
}
