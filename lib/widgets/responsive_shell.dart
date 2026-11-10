import 'package:flutter/material.dart';

class DDartTheme {
  static const Color primaryMaroon = Color(0xFF7F0000);
  static const Color panelMaroon = Color(0xFF8F1F0D);
  static const Color deepMaroon = Color(0xFF7A0000);
  static const Color gold = Color(0xFFD4AF37);
  static const Color brightGold = Color(0xFFE5A824);
}

/// Shared responsive auto-layout wrapper for mobile phones, tablets, and Flutter Web.
class ResponsiveMobileShell extends StatelessWidget {
  final Widget child;
  final Color mobileBackground;
  final double maxWidth;
  final double maxHeight;

  const ResponsiveMobileShell({
    super.key,
    required this.child,
    this.mobileBackground = Colors.white,
    this.maxWidth = 460,
    this.maxHeight = 920,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopOrTablet = screenWidth > 600;

    if (!isDesktopOrTablet) {
      return Container(color: mobileBackground, child: child);
    }

    return Container(
      color: const Color(0xFF252525),
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
