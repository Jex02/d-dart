import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class DDartTheme {
  static const Color primaryMaroon = Color(0xFF7F0000);
  static const Color panelMaroon = Color(0xFF8F1F0D);
  static const Color deepMaroon = Color(0xFF7A0000);
  static const Color gold = Color(0xFFD4AF37);
  static const Color brightGold = Color(0xFFE5A824);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color surface(BuildContext context) =>
      isDark(context) ? const Color(0xFF141416) : Colors.white;

  static Color scaffoldBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF121214) : const Color(0xFFF9F9FB);

  static Color card(BuildContext context) =>
      isDark(context) ? const Color(0xFF1E1E22) : Colors.white;

  static Color cardSubtle(BuildContext context) =>
      isDark(context) ? const Color(0xFF242429) : const Color(0xFFF6F6F6);

  static Color fieldFill(BuildContext context) =>
      isDark(context) ? const Color(0xFF262225) : const Color(0xFFF4EDED);

  static Color maroonTint(BuildContext context) =>
      isDark(context) ? const Color(0xFF2B1A1A) : const Color(0xFFFBF4F4);

  static Color border(BuildContext context) =>
      isDark(context) ? const Color(0xFF33333A) : Colors.grey.shade200;

  static Color outlineBorder(BuildContext context) =>
      isDark(context) ? const Color(0xFF42424C) : const Color(0xFFB0B0B0);

  static Color divider(BuildContext context) =>
      isDark(context) ? const Color(0xFF2E2E35) : Colors.grey.shade300;

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? const Color(0xFFF3F3F5) : const Color(0xFF1E1E1E);

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? const Color(0xFFB5B5BF) : Colors.black54;

  static Color textMuted(BuildContext context) =>
      isDark(context) ? const Color(0xFF8C8C98) : Colors.grey.shade600;

  /// High-contrast accent text (warm gold on dark surfaces, maroon on light).
  static Color accentText(BuildContext context) =>
      isDark(context) ? brightGold : primaryMaroon;

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryMaroon,
          primary: primaryMaroon,
          secondary: gold,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        cardTheme: const CardThemeData(
          color: Colors.white,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Colors.white,
        ),
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryMaroon,
          primary: const Color(0xFFC0392B),
          secondary: gold,
          surface: const Color(0xFF1A1A1E),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121214),
        canvasColor: const Color(0xFF141416),
        cardColor: const Color(0xFF1E1E22),
        cardTheme: const CardThemeData(
          color: Color(0xFF1E1E22),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFF1E1E22),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF1E1E22),
        ),
        dividerColor: const Color(0xFF2E2E35),
      );
}

/// Quick sun/moon icon button to toggle Light and Dark mode from any screen.
class ThemeToggleButton extends StatelessWidget {
  final Color iconColor;
  final double iconSize;

  const ThemeToggleButton({
    super.key,
    this.iconColor = Colors.white,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance.themeModeNotifier,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        return IconButton(
          tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
          icon: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            color: iconColor,
            size: iconSize,
          ),
          onPressed: () => ThemeService.instance.toggle(),
        );
      },
    );
  }
}

/// Shared responsive auto-layout wrapper for mobile phones, tablets, and Flutter Web.
class ResponsiveMobileShell extends StatelessWidget {
  final Widget child;
  final Color? mobileBackground;
  final double maxWidth;
  final double maxHeight;

  const ResponsiveMobileShell({
    super.key,
    required this.child,
    this.mobileBackground,
    this.maxWidth = 460,
    this.maxHeight = 920,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopOrTablet = screenWidth > 600;
    final isDark = DDartTheme.isDark(context);

    if (!isDesktopOrTablet) {
      return Container(
        color: mobileBackground ?? DDartTheme.surface(context),
        child: child,
      );
    }

    return Container(
      color: isDark ? const Color(0xFF0A0A0C) : const Color(0xFF252525),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: child,
        ),
      ),
    );
  }
}
