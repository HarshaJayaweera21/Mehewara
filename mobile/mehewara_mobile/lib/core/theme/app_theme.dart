import 'package:flutter/material.dart';

/// Design tokens and civic theme matching Stitch Mehewara specifications
class CivicColors {
  // Backgrounds & Surfaces
  static const Color alabaster = Color(0xFFF7F7F2);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFFBFBFA);
  static const Color borderSubtle = Color(0xFFDDE2DE);
  static const Color navBorder = Color(0xFFEBEFEA);
  static const Color segmentBg = Color(0xFFEBEEE9);

  // Forest Green Primary
  static const Color forest = Color(0xFF123C32);
  static const Color forestHover = Color(0xFF0D3028);
  static const Color forestPressed = Color(0xFF09211C);

  // Mint & Energy Accents
  static const Color mintPip = Color(0xFF4FD1A1);
  static const Color mintTint = Color(0xFFE5F6EE);

  // Typography
  static const Color charcoal = Color(0xFF18211E);
  static const Color slateGreen = Color(0xFF68736E);
  static const Color subdued = Color(0xFF8F9995);

  // Status & Priority Badges
  // High Priority
  static const Color badgeHighBg = Color(0xFFFFF7ED);
  static const Color badgeHighText = Color(0xFFC2410C);
  static const Color badgeHighBorder = Color(0xFFFFEDD5);

  // Critical Priority
  static const Color badgeCriticalBg = Color(0xFFFEF2F2);
  static const Color badgeCriticalText = Color(0xFF991B1B);
  static const Color badgeCriticalBorder = Color(0xFFFEE2E2);

  // Medium Priority
  static const Color badgeMediumBg = Color(0xFFFFFBEB);
  static const Color badgeMediumText = Color(0xFFB45309);
  static const Color badgeMediumBorder = Color(0xFFFEF3C7);

  // Low Priority
  static const Color badgeLowBg = Color(0xFFF0F4F2);
  static const Color badgeLowText = Color(0xFF3D5A4C);
  static const Color badgeLowBorder = Color(0xFFE1E8E4);

  // Processing Status (Teal)
  static const Color badgeProcessingBg = Color(0xFFF0FDFA);
  static const Color badgeProcessingText = Color(0xFF0F766E);
  static const Color badgeProcessingBorder = Color(0xFFCCFBF1);

  // Resolved Status (Green)
  static const Color badgeResolvedBg = Color(0xFFF0FDF4);
  static const Color badgeResolvedText = Color(0xFF166534);
  static const Color badgeResolvedBorder = Color(0xFFDCFCE7);

  // Assigned Status (Blue)
  static const Color badgeAssignedBg = Color(0xFFEFF6FF);
  static const Color badgeAssignedText = Color(0xFF1E40AF);
  static const Color badgeAssignedBorder = Color(0xFFDBEAFE);

  // Pin Category Colors
  static const Color pinDrainage = Color(0xFF123C32); // Selected/Drainage
  static const Color pinRoad = Color(0xFFD97706);     // Amber / Road
  static const Color pinElectrical = Color(0xFFCA8A04); // Yellow / Gold
  static const Color pinWaste = Color(0xFF4B6358);      // Slate Green / Waste
  static const Color pinEnvironment = Color(0xFF2E7D32); // Green
}

class CivicShadows {
  static const BoxShadow card = BoxShadow(
    color: Color.fromRGBO(18, 60, 50, 0.08),
    blurRadius: 24,
    offset: Offset(0, 8),
    spreadRadius: -2,
  );

  static const BoxShadow button = BoxShadow(
    color: Color.fromRGBO(18, 60, 50, 0.06),
    blurRadius: 12,
    offset: Offset(0, 4),
  );

  static const BoxShadow subtle = BoxShadow(
    color: Color.fromRGBO(18, 60, 50, 0.04),
    blurRadius: 3,
    offset: Offset(0, 1),
  );
}
